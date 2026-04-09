# Feature design doc — `[FEATURE DISPLAY NAME]`

> **Template only.** Copy this file to a new document per feature (e.g. `feature-timezone.md`). Replace bracketed placeholders. Remove sections that do not apply; keep headings for traceability if you prefer.

---

## 0. Document control

| Field | Value |
|-------|--------|
| **Feature name (canonical)** | `[Must match FEATURES CONTROL/feature-list.md and change-dashboard appFeatures.ts]` |
| **Short slug (optional)** | `[e.g. timezone — for filenames and tags only]` |
| **Doc version** | `[0.1]` |
| **Last updated** | `[YYYY-MM-DD]` |
| **Owner / maintainer** | `[Name or role]` |
| **Reviewers (default)** | `[Who usually approves CRs touching this area]` |
| **Status of this doc** | `[Draft | Active | Deprecated]` |

---

## 1. Summary

### 1.1 One-line purpose

`[What this feature does for the user or system in one sentence.]`

### 1.2 Elevator pitch (2–4 sentences)

`[Slightly richer: problem solved, main surfaces, when the user encounters it.]`

### 1.3 In scope / out of scope

| In scope | Out of scope |
|----------|----------------|
| `[…]` | `[…]` |
| `[…]` | `[…]` |

---

## 2. Product & UX

### 2.1 User-facing surfaces

- **Screens / routes / tabs:** `[List or “N/A (background only)”]`
- **Entry points:** `[How user opens this feature]`
- **Primary user journeys:** `[Step bullets]`

### 2.2 UX principles & constraints

`[Accessibility, offline behavior, copy tone, performance expectations.]`

### 2.3 Related product docs

- `[Link or path to FEATURES CONTROL/feature-list.md section, design mocks, Figma, etc.]`

---

## 3. Technical architecture

### 3.1 Stack & layers

| Layer | Details |
|-------|---------|
| **Client (Flutter)** | `[packages, main files]` |
| **State** | `[Provider / Riverpod / etc.]` |
| **Backend** | `[Supabase tables, Edge Functions, third-party APIs]` |
| **Persistence** | `[Local: Drift/Hive; Remote: …]` |

### 3.2 Key modules & file paths

`[Bullet list of directories/files “owned” by this feature — helps code review scope.]`

```
example/
  lib/features/[feature]/...
```

### 3.3 Data model (feature-specific)

| Entity / table | Role |
|----------------|------|
| `[table_or_collection]` | `[what it stores]` |

### 3.4 External dependencies

- **Packages:** `[pub.dev names and versions if notable]`
- **Services:** `[Firebase, RevenueCat, etc.]`
- **Env / secrets:** `[Which .env keys; never paste values here]`

### 3.5 Platform notes

- **Android:** `[quirks]`
- **iOS:** `[quirks]`
- **Web / desktop:** `[if applicable]`

### 3.6 Functions & methods (code map)

> **Primary place to list what developers search for** — public and important private APIs owned by this feature.

#### 3.6.1 Entry points & orchestration

| Symbol (function / method / class) | File path | Role |
|-----------------------------------|-------------|------|
| `[e.g. openFooScreen]` | `[lib/...]` | `[Called from …]` |
| `[…]` | `[…]` | `[…]` |

#### 3.6.2 Services & repositories

| Symbol | File path | Notes |
|--------|-----------|--------|
| `[e.g. FooRepository.get]` | `[lib/...]` | `[caching, errors]` |
| `[…]` | `[…]` | `[…]` |

#### 3.6.3 Widgets / UI building blocks (if notable)

| Widget / builder | File path | When used |
|-------------------|-----------|-----------|
| `[…]` | `[…]` | `[…]` |

#### 3.6.4 Backend / Edge (if applicable)

| Function / route / RPC | Location | Purpose |
|-------------------------|----------|---------|
| `[…]` | `[supabase/functions/…]` | `[…]` |

*(Add rows until complete; use “N/A” blocks if this feature is UI-only or logic-only.)*

### 3.7 Variables, constants & configuration keys

> **Identifiers others grep for** — avoid dumping every local variable; focus on **shared** and **stable** names.

#### 3.7.1 Constants & enums

| Name | Type / file | Value / meaning |
|------|-------------|-----------------|
| `[e.g. kMaxRetries]` | `[lib/...]` | `[…]` |
| `[e.g. FooStatus enum]` | `[lib/...]` | `[states: …]` |

#### 3.7.2 Keys (storage, prefs, routing, analytics)

| Key / route name | Where defined | Purpose |
|------------------|---------------|---------|
| `[SharedPreferences / secure storage key]` | `[file]` | `[…]` |
| `[GoRouter path / name]` | `[file]` | `[…]` |
| `[Analytics / log tag]` | `[file]` | `[…]` |

#### 3.7.3 Environment & remote config

| Name | Notes |
|------|--------|
| `[SUPABASE_* / custom flag — name only]` | `[what it gates]` |

### 3.8 Core logic & behaviour

> **How the feature *thinks*** — algorithms, rules, ordering, and state transitions (not just file paths).

#### 3.8.1 Main flow (happy path)

`[Numbered steps or bullet pipeline: e.g. user action → provider update → service call → persistence → UI.]`

#### 3.8.2 State machine / status rules (if applicable)

| State | Entered when | Valid next states | Side effects |
|-------|----------------|-------------------|--------------|
| `[idle]` | `[…]` | `[loading, error]` | `[…]` |
| `[…]` | `[…]` | `[…]` | `[…]` |

#### 3.8.3 Business rules & invariants

- `[Rule 1: e.g. “never schedule in the past for local midnight”]`
- `[Rule 2: …]`
- **Invariants:** `[what must always hold true after each operation]`

#### 3.8.4 Edge cases & failure modes

| Scenario | Behaviour |
|----------|-----------|
| `[offline]` | `[…]` |
| `[invalid input]` | `[…]` |
| `[race / duplicate call]` | `[…]` |

#### 3.8.5 Pseudocode or sequence (optional)

```
// [Short pseudocode or “see diagram in §12.2”]
```

### 3.9 State management (providers / notifiers)

| Provider / ChangeNotifier / Riverpod symbol | File | What it holds |
|---------------------------------------------|------|----------------|
| `[fooProvider]` | `[path]` | `[state shape]` |
| `[…]` | `[…]` | `[…]` |

---

## 4. Boundaries & coupling

### 4.1 Upstream dependencies (this feature relies on)

`[Other features, core services, auth, sync — list canonical names from feature list.]`

### 4.2 Downstream dependents (features that rely on this)

`[Who breaks if this feature breaks.]`

### 4.3 Shared code hotspots

`[Files many teams touch — extra care on CRs.]`

---

## 5. Change control alignment

> Tie to the diaryapp change system: `changes`, `change_reviews`, `change_tasks`.

### 5.1 Default `primary_feature` usage

`[When a change should list this feature as primary vs affected only.]`

### 5.2 Typical approver (`change_reviews.team_key`)

`[Usually this feature’s name matches one approver row; note if multiple teams always review together.]`

### 5.3 CTASK expectations

- **When Cursor/you usually add CTASKs for this area:** `[e.g. any DB migration, any notification schedule change]`
- **Typical CTASK split:** `[e.g. “implementation” vs “docs” vs “QA”]`
- **Definition of done for this feature’s CTASKs:** `[bullets]`

### 5.4 Risk class (default)

`[ Low | Medium | High ]` — **Rationale:** `[why]`

---

## 6. Operations & quality

### 6.1 Feature flags / kill switches

`[None | name + where defined + default]`

### 6.2 Observability

- **Logging:** `[what to log / tags]`
- **Analytics events:** `[event names]`
- **Crash / error attribution:** `[how to filter to this feature]`

### 6.3 Performance & limits

`[Expected latency, batch sizes, rate limits, background work.]`

### 6.4 Security & privacy

- **PII:** `[handled / not handled]`
- **Permissions:** `[OS permissions, Supabase RLS notes]`

---

## 7. Testing strategy

### 7.1 Critical test cases (manual)

`[Numbered list — happy path + top failures.]`

### 7.2 Automated tests

| Type | Location / pattern |
|------|---------------------|
| Unit | `[…]` |
| Widget / integration | `[…]` |

### 7.3 Test data / fixtures

`[Seeded users, timezones, locales, etc.]`

### 7.4 Regression triggers

`[“When you touch X, always re-test Y.”]`

---

## 8. Releases & migration

### 8.1 Version / release notes habit

`[How this feature is announced — changelog snippet style.]`

### 8.2 Data migrations

`[Typical Supabase migration concerns when this feature changes.]`

### 8.3 Rollback considerations

`[What to revert first; feature-specific rollback notes beyond global rollback_plan on `changes`.]`

---

## 9. Documentation & support

### 9.1 User-facing help

`[Help articles, in-app strings ownership.]`

### 9.2 Runbooks (internal)

`[On-call: “if notifications fail, check …”]`

### 9.3 FAQ / known issues

| Issue | Workaround / status |
|-------|----------------------|
| `[…]` | `[…]` |

---

## 10. Glossary & naming

| Term | Definition |
|------|------------|
| `[…]` | `[…]` |

**Naming conflicts:** `[If “Feature A” in marketing ≠ engineering name, document here.]`

---

## 11. Open questions & decisions log

### 11.1 Open questions

1. `[…]`
2. `[…]`

### 11.2 Decisions (newest first)

| Date | Decision | Rationale |
|------|----------|-----------|
| `[YYYY-MM-DD]` | `[…]` | `[…]` |

---

## 12. Appendix

### 12.1 References

- `[Links to specs, RFCs, tickets]`

### 12.2 Diagrams (optional)

`[Mermaid or “see Figma page X”.]`

### 12.3 Changelog of *this* doc

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| `0.1` | `[date]` | `[who]` | Initial doc from template |

---

## Template usage notes (delete this section from feature copies)

- Keep **canonical feature name** identical to `FEATURES CONTROL/feature-list.md` and `change-dashboard/src/data/appFeatures.ts`.
- One file per feature is enough; subdomains can be subsections or separate docs if huge.
- Prefer tables and bullets over prose for scanability during CAB / reviews.
- **§3.6–§3.9** are where you capture **functions/methods**, **variables/constants/keys**, and **logic** (flows, rules, state). Fill these early — they are the main engineering reference for reviews and CTASKs.
- Link to `chnage-table-feilds.md`, `change-rview-feilds.md`, and `change-task-feilds.md` from your team wiki if helpful — do not duplicate full DB schemas here.
