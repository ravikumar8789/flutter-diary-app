# Feature design doc — Privacy, PIN & lock

> **Scope:** 4-digit **PIN**, **privacy lock** toggle, **secure storage** for hashes, **security questions** for recovery, **auto-lock** after idle time, **lockout** after failed attempts, and **app lifecycle** hooks.  
> **Canonical names** (feature list / dashboard): **Privacy Lock**, **PIN Lock**, **PIN Setup**, **Change PIN**, **PIN Recovery**, **Security Questions** — use the slice you touch for `change_reviews.team_key`.

---

## 0. Document control

| Field | Value |
|-------|--------|
| **Feature name (canonical)** | **Privacy Lock** (master toggle + policy); **PIN Lock** (entry UI); **PIN Setup** / **Change PIN** / **PIN Recovery** / **Security Questions** (sub-flows) |
| **Short slug** | `privacy-pin-lock` |
| **Doc version** | `0.1` |
| **Last updated** | `2026-04-03` |
| **Owner / maintainer** | `[TBD]` |
| **Reviewers (default)** | Anyone changing `PinAuthService`, `privacy_lock_provider`, or PIN screens |
| **Status of this doc** | `Draft` |

---

## 1. Summary

### 1.1 One-line purpose

Protect diary access with an optional **4-digit PIN**, stored as a **salted SHA-256 hash** in **secure storage**, with **SharedPreferences** for lock policy, **auto-lock** after configurable idle minutes, **progressive lockout** after failed attempts, and **security-question** verification for recovery.

### 1.2 Elevator pitch

When **Privacy Lock** is enabled in Profile, the user completes **PIN Setup** (and can configure **Security Questions**). On cold start, **`AppWrapper`** shows **`PinLockScreen`** until the correct PIN is entered (or recovery succeeds). **`AppLifecycleService`** calls **`checkAutoLock()`** when returning to background so the app can lock after **`autoLockTimeout`** minutes without activity. Wrong PINs increment failures; after **5** failures a **time-based lockout** applies. Disabling privacy lock clears PIN and security data from secure storage and prefs.

### 1.3 In scope / out of scope

| In scope | Out of scope |
|----------|----------------|
| `PinAuthService` — hash, prefs, secure keys | Server-side PIN (none — local only) |
| `PrivacyLockNotifier` + enums `PrivacyLockState` / `PinEntryState` | **Privacy Policy** legal screen content (`privacy_policy_screen.dart`) |
| `PinLockScreen`, `PinSetupScreen`, `ChangePinScreen`, `PinRecoveryScreen` | Biometric / Face ID (unless added later) |
| `PinNumberPad` widget | Account deletion flow (only clears lock via `disablePrivacyLock` when relevant) |
| `AppWrapper` gate in `main.dart` | Supabase `privacy_lock_enabled` sync field (see `user_data` / sync — cross-feature) |

---

## 2. Product & UX

### 2.1 User-facing surfaces

- **Screens:** `PinLockScreen` (unlock / lockout / recovery entry), `PinSetupScreen`, `ChangePinScreen`, `PinRecoveryScreen`, Profile toggle for Privacy Lock.
- **Entry points:** Enable lock from Profile → PIN setup flow; cold start when lock enabled; return from background when auto-lock triggers.
- **Journeys:** Enable → set PIN → (optional) security questions → use app → background → foreground may require PIN again after timeout; Forgot PIN → recovery with answers → reset PIN.

### 2.2 UX principles & constraints

- **PIN format:** exactly **4 digits** (`RegExp(r'^\d{4}$')`).
- **Auto-lock:** `0` minutes = never auto-lock (`shouldLockApp`); default **5** minutes when enabling lock.
- **Lockout messaging:** Uses `remainingLockoutTime` (minutes) from prefs.
- **Secure UX:** No raw PIN persisted; only hash in `FlutterSecureStorage`.

### 2.3 Related product docs

- `FEATURES CONTROL/feature-list.md` — Privacy Lock, PIN Lock, PIN Setup, Change PIN, PIN Recovery, Security Questions

---

## 3. Technical architecture

### 3.1 Stack & layers

| Layer | Details |
|-------|---------|
| **Client** | Flutter screens + `PinNumberPad` |
| **State** | Riverpod `privacyLockProvider` → `PrivacyLockNotifier` |
| **Persistence** | `flutter_secure_storage` (PIN hash, questions text, answer hashes); `shared_preferences` (flags, times, attempts, lockout) |
| **Crypto** | `package:crypto` SHA-256 for PIN (with per-hash salt) and answers (normalized lowercase trim) |

### 3.2 Key modules & file paths

```
lib/
  providers/privacy_lock_provider.dart    # PrivacyLockState, PinEntryState, PrivacyLockNotifier
  services/pin_auth_service.dart          # All storage + hashing + lockout logic
  services/app_lifecycle_service.dart     # checkAutoLock on lifecycle
  screens/pin_lock_screen.dart
  screens/pin_setup_screen.dart
  screens/change_pin_screen.dart
  screens/pin_recovery_screen.dart
  widgets/pin_number_pad.dart
  main.dart                               # AppWrapper → PinLockScreen vs SplashScreen
```

### 3.3 Data model (feature-specific)

| Store | Keys / content |
|-------|----------------|
| **FlutterSecureStorage** | `pin_hash` (`salt:hexdigest`), `security_question_1/2`, `security_answer_1/2` (hashed answers) |
| **SharedPreferences** | `privacy_lock_enabled`, `auto_lock_timeout` (minutes), `last_unlock_time` (ISO string), `failed_attempts`, `lockout_until` (ISO string) |

Remote **user profile** may mirror `privacy_lock_enabled` via `UserDataService` / sync — treat as **sync** concern, not core PIN crypto.

### 3.4 External dependencies

- **Packages:** `flutter_secure_storage`, `shared_preferences`, `crypto`, `flutter_riverpod`
- **Env:** None specific to PIN (no secrets in env for local PIN)

### 3.5 Platform notes

- **iOS / Android:** `FlutterSecureStorage` uses platform keychains/keystore; test on both when changing storage.

### 3.6 Functions & methods (code map)

#### 3.6.1 Entry points & orchestration

| Symbol | File | Role |
|--------|------|------|
| `AppWrapper` | `main.dart` | `privacyLockProvider`: if `isEnabled && !isUnlocked` → `PinLockScreen` |
| `PrivacyLockNotifier._initialize` | `privacy_lock_provider.dart` | Loads enabled, lockout, `shouldLock`, auto-lock timeout from `PinAuthService` |
| `PrivacyLockNotifier.validatePin` / `setupPin` / `changePin` / `enablePrivacyLock` / `disablePrivacyLock` | same | Public API for UI |
| `AppLifecycleService` (privacy section) | `app_lifecycle_service.dart` | `checkAutoLock()` when app backgrounds / resumes |

#### 3.6.2 Services

| Symbol | File | Notes |
|--------|------|--------|
| `PinAuthService.validatePin` | `pin_auth_service.dart` | Constant-time compare of SHA-256 with stored salt |
| `PinAuthService.setupPin` | same | 4-digit validation; `_hashPin` write |
| `PinAuthService.changePin` | same | Validates current, re-hash new; clears `_lastUnlockTimeKey` |
| `PinAuthService.enablePrivacyLock` / `disablePrivacyLock` | same | Prefs + full secure wipe on disable |
| `PinAuthService.shouldLockApp` | same | No unlock timestamp → lock; idle vs `autoLockTimeout` |
| `PinAuthService.recordFailedAttempt` / `isLockedOut` / `_getLockoutDuration` | same | Progressive lockout (5 → 5 min, … see §3.8) |

#### 3.6.3 Widgets

| Widget | File | When used |
|--------|------|-----------|
| `PinNumberPad` | `widgets/pin_number_pad.dart` | PIN digit entry |
| `PinLockScreen` | `screens/pin_lock_screen.dart` | Full-screen lock; recovery navigation |
| `PinSetupScreen`, `ChangePinScreen`, `PinRecoveryScreen` | `screens/` | Flows |

#### 3.6.4 Backend / Edge

| Location | Purpose |
|----------|---------|
| N/A | PIN never sent to Supabase as plaintext |

### 3.7 Variables, constants & configuration keys

#### 3.7.1 Constants (PinAuthService)

| Name | Meaning |
|------|---------|
| `_pinHashKey`, `_securityQuestion1Key`, … | Secure-storage key strings |
| `_privacyLockEnabledKey`, `_autoLockTimeoutKey`, `_lastUnlockTimeKey`, `_failedAttemptsKey`, `_lockoutUntilKey` | SharedPreferences keys |

#### 3.7.2 Enums (`privacy_lock_provider.dart`)

| Enum | Values |
|------|--------|
| `PrivacyLockState` | `disabled`, `locked`, `unlocked`, `lockout`, `setup` |
| `PinEntryState` | `idle`, `entering`, `validating`, `success`, `failure`, `lockout` |

#### 3.7.3 Environment

| Name | Notes |
|------|--------|
| N/A | — |

### 3.8 Core logic & behaviour

#### 3.8.1 Main flows

1. **Enable:** Profile toggle → `enablePrivacyLock()` → prefs set; user sent to PIN setup → `setupPin` → hash stored.
2. **Unlock:** `validatePin` → on success `recordSuccessfulUnlock()` writes `last_unlock_time`.
3. **Auto-lock:** `shouldLockApp()` true if enabled and (no `last_unlock` **or** idle ≥ `autoLockTimeout` minutes). Lifecycle calls `checkAutoLock()` → notifier sets **locked**.
4. **Failed PIN:** `recordFailedAttempt`; at **≥5** failures, `lockout_until` set; duration from `_getLockoutDuration` (5 / 15 / 30 minutes by band).
5. **Disable:** `disablePrivacyLock` clears prefs keys and **all** secure keys for PIN + security Q&A.

#### 3.8.2 State machine (PrivacyLockState — simplified)

| State | Meaning |
|-------|---------|
| `disabled` | Feature off |
| `locked` | PIN required |
| `unlocked` | User may use app |
| `lockout` | Too many failures until `lockout_until` |
| `setup` | PIN setup in progress |

#### 3.8.3 Business rules & invariants

- PIN **must** be 4 numeric digits.
- **Salt** is embedded in stored hash string as `salt:hexdigest` (new salt on each `setupPin` / `changePin` via `_hashPin`).
- Security answers compared after **lowercase + trim** + SHA-256.
- **Invariant:** If `shouldLockApp` errors, service defaults to **locked** (`return true`) for safety.

#### 3.8.4 Edge cases

| Scenario | Behaviour |
|----------|-----------|
| Init failure in `_initialize` | Provider falls back to `disabled` + error log (`ERRSYS079`) |
| Lockout | `PinLockScreen` shows dialog; path to **PIN Recovery** |

#### 3.8.5 Hashing (PIN)

```
_salt = random 16 bytes (base64)
digest = sha256(utf8(pin + salt))
store: "$salt:${digest.toString()}"
```

### 3.9 State management

| Provider | File | Holds |
|----------|------|--------|
| `privacyLockProvider` | `privacy_lock_provider.dart` | `PrivacyLockData` — state, `isEnabled`, `isUnlocked`, `failedAttempts`, `remainingLockoutTime`, `autoLockTimeout`, `errorMessage` |

---

## 4. Boundaries & coupling

### 4.1 Upstream

- **App shell** — `AppWrapper` ordering (PIN before splash).
- **Profile** — toggle and navigation to setup/change/recovery.

### 4.2 Downstream

- **All screens** assume user may be blocked behind `PinLockScreen` at startup.
- **Logout / delete account** flows call `disablePrivacyLock()` where implemented.

### 4.3 Shared hotspots

- `pin_auth_service.dart` — single place for crypto and storage; **high review bar**.

---

## 5. Change control alignment

### 5.1 `primary_feature`

Use **Privacy Lock** for policy/toggle/auto-lock; **PIN Lock** for lock UI; **PIN Setup** / **Change PIN** / **PIN Recovery** / **Security Questions** for targeted flows.

### 5.2 Approver

Match the catalog name for the area changed (e.g. **Privacy Lock** for `PinAuthService` behaviour).

### 5.3 CTASK expectations

Any change to **hashing, storage keys, or lockout thresholds** → separate CTASK for **QA security** + **migration** if stored format changes.

### 5.4 Risk class

**High** — security-sensitive; mistakes leak UX or weaken lock.

---

## 6. Operations & quality

### 6.1 Feature flags

None (local feature).

### 6.2 Observability

- **ErrorLoggingService** — `ERRSYS061`–`069`, `079`, `080` on failures in service/provider paths.

### 6.3 Performance

PIN validation is local and fast; avoid blocking UI isolate on large work.

### 6.4 Security & privacy

- **PII:** Security questions are user-chosen text; answers hashed.
- **Threat model:** Local device compromise bypasses PIN — document for users.

---

## 7. Testing strategy

### 7.1 Manual critical paths

1. Enable lock → set PIN → restart → unlock.
2. Wrong PIN 5× → lockout → wait / recovery.
3. Auto-lock: unlock → background longer than timeout → foreground → PIN required.
4. Change PIN → old PIN fails, new works.
5. Disable lock → no PIN prompt; secure storage cleared.
6. Recovery with security answers → reset flow.

### 7.2 Automated

| Type | Location |
|------|----------|
| Unit | `[TBD]` — `PinAuthService` with fake secure storage / prefs |

### 7.3 Regression triggers

Any edit to **`_hashPin`**, **lockout thresholds**, or **`shouldLockApp`** → full matrix above.

---

## 8. Releases & migration

### 8.1 User-visible

Mention in release notes if recovery flow or lockout behaviour changes.

### 8.2 Data migrations

If hash format changes, need one-time migration or force re-setup — **document** in change ticket.

### 8.3 Rollback

Revert provider + service together; users may need to re-enable lock.

---

## 9. Documentation & support

### 9.1 User-facing

In-app copy on PIN screens; “Forgot PIN” → recovery.

### 9.2 Runbooks

“If user locked out permanently” — recovery or clear app data (last resort).

### 9.3 FAQ

| Issue | Note |
|-------|------|
| Lost PIN + no recovery | Reinstall / clear storage — **data loss** for local secrets |

---

## 10. Glossary

| Term | Definition |
|------|------------|
| **Privacy lock** | Master on/off + auto-lock policy |
| **PIN hash** | Salt + SHA-256; never store raw PIN |

---

## 11. Open questions & decisions

### 11.1 Open questions

1. Add **biometrics** wrapping same unlock?
2. Sync **privacy_lock_enabled** conflict between devices — resolution policy?

### 11.2 Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| `2026-04-03` | Initial doc from code | Baseline audit of `PinAuthService` + provider |

---

## 12. Appendix

### 12.1 References

- `lib/services/pin_auth_service.dart`
- `lib/providers/privacy_lock_provider.dart`
- `bc/CHANGE-SYSTEM/feature-doc-template.md`

### 12.2 Changelog of *this* doc

| Version | Date | Notes |
|---------|------|-------|
| `0.1` | `2026-04-03` | Initial |
