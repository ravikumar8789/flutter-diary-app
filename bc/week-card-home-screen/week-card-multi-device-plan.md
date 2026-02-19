# Week Card Multi-Device Fix - Implementation Plan

**Date:** February 2025  
**Issue:** P3 - Week card on Device B shows wrong values when Device A has written entries  
**Root Cause:** Device B only fetches today's data on normal startup; local DB missing rest of week after cleanup

---

## 🎯 OBJECTIVE

Change `needsDataFetch` from bool to date-based logic so Device B fetches full 7 days when last fetch was 2+ days ago, fixing the week card mismatch.

---

## 📊 CURRENT vs NEW LOGIC

| Scenario | Current (bool) | New (date string) |
|----------|----------------|-------------------|
| Fresh install | `null` → true → fetch 7d | `null` → fetch 7d |
| Logout | set true → fetch 7d | remove key → `null` → fetch 7d |
| Login | set true → fetch 7d | remove key → `null` → fetch 7d |
| Same day reopen | false → fetch today | date=today → fetch today |
| Next day | false → fetch today | date=yesterday → fetch today |
| 2+ days gap | false → fetch today ❌ | date=stale → fetch 7d ✓ |

---

## 🔧 IMPLEMENTATION STEPS

### Step 1: Update DataSyncFlagService

**File:** `lib/services/data_sync_flag_service.dart`

#### 1.1 Change storage from bool to string (date)

- **Key:** Keep `needs_data_fetch` (same key for backward compatibility)
- **Storage:** `SharedPreferences.getString()` / `setString()` / `remove()`
- **Value format:** `"YYYY-MM-DD"` (local date only) or key removed = null

#### 1.2 Replace/Add methods

| Method | Current | New |
|--------|---------|-----|
| `needsDataFetch()` | Returns `getBool() ?? true` | Returns `true` if null OR days since stored date ≥ 2 |
| `clearNeedsDataFetch()` | `setBool(false)` | `setString(todayDate)` where todayDate = `DateFormat('yyyy-MM-dd').format(DateTime.now())` |
| `setNeedsDataFetch(bool)` | `setBool(value)` | **Deprecate.** Add `clearLastFetchDate()` → `remove(key)` |

#### 1.3 New `needsDataFetch()` logic (pseudocode)

```dart
static Future<bool> needsDataFetch() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_needsDataFetchKey);
    
    // null = fresh install, logout, error, or legacy bool (getString returns null for old bool)
    if (dateStr == null || dateStr.isEmpty) return true;
    
    // Parse stored date
    final storedDate = DateTime.tryParse(dateStr);
    if (storedDate == null) return true; // Invalid format → safe fetch 7d
    
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final storedDateOnly = DateTime(storedDate.year, storedDate.month, storedDate.day);
    final daysSince = today.difference(storedDateOnly).inDays;
    
    // Future date (clock skew) → treat as today
    if (daysSince < 0) return false;
    
    // 2+ days ago → fetch full week
    if (daysSince >= 2) return true;
    
    // 0 or 1 day → fetch today only
    return false;
  } catch (e) {
    // Error → safe fetch 7d
    return true;
  }
}
```

#### 1.4 New `clearNeedsDataFetch()` (record success)

```dart
static Future<void> clearNeedsDataFetch() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_needsDataFetchKey, todayStr);
  } catch (e) { /* log ERRSYS162 */ }
}
```

#### 1.5 New `clearLastFetchDate()` (for logout/login)

```dart
/// Clears the last fetch date. Next needsDataFetch() will return true (fetch 7 days).
/// Call on logout and login.
static Future<void> clearLastFetchDate() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_needsDataFetchKey);
  } catch (e) { /* log */ }
}
```

#### 1.6 Handle legacy bool migration

- `getString()` on a key that was `setBool()` returns `null` (different type)
- No explicit migration needed; null → fetch 7d (correct)

#### 1.7 Add import

```dart
import 'package:intl/intl.dart';
```

---

### Step 2: Update Login Screen

**File:** `lib/screens/login_screen.dart`

**Change:** Replace `setNeedsDataFetch(true)` with `clearLastFetchDate()`

```dart
// Before
await DataSyncFlagService.setNeedsDataFetch(true);

// After
await DataSyncFlagService.clearLastFetchDate();
```

**Reason:** Login = fresh session, ensure 7-day fetch on next splash/home load.

---

### Step 3: Update Profile Screen (Logout)

**File:** `lib/screens/profile_screen.dart`

**Change:** Replace both `setNeedsDataFetch(true)` with `clearLastFetchDate()`

- Line ~627: Normal logout flow
- Line ~674: Logout error handler (fallback)

```dart
// Before
await DataSyncFlagService.setNeedsDataFetch(true);

// After
await DataSyncFlagService.clearLastFetchDate();
```

**Reason:** Logout = clear state, next login fetches 7 days.

---

### Step 4: Splash Screen – No Logic Change

**File:** `lib/screens/splash_screen.dart`

**No changes to flow.** Existing logic already correct:

- `needsFetch = await DataSyncFlagService.needsDataFetch()` → now uses new date logic
- `if (needsFetch)` → `prefetch7DaysData()` then `clearNeedsDataFetch()`
- `if (!didPrefetch7Days)` → `prefetchTodayData()`

---

### Step 5: Home Screen – No Logic Change

**File:** `lib/screens/home_screen.dart`

**No changes to flow.** `_handlePrefetchAfterLogin` already:

- Calls `needsDataFetch()` → now uses new date logic
- Calls `clearNeedsDataFetch()` on success → now stores date

---

### Step 6: Deprecate setNeedsDataFetch

**File:** `lib/services/data_sync_flag_service.dart`

- Add `@Deprecated('Use clearLastFetchDate() instead')` to `setNeedsDataFetch(bool)`
- Implement: if `value == true` → call `clearLastFetchDate()`; if `value == false` → call `clearNeedsDataFetch()`
- This keeps any unknown callers working during transition

**Or:** Remove `setNeedsDataFetch` entirely and update all callers (login, profile) to use `clearLastFetchDate()`. Recommended: remove and update callers.

---

## 📋 EDGE CASES

| Case | Handling |
|------|----------|
| Fresh install | Key missing → `getString` null → fetch 7d ✓ |
| Error reading prefs | catch → return true → fetch 7d ✓ |
| Invalid date string | `tryParse` null → fetch 7d ✓ |
| Empty string | `isEmpty` → fetch 7d ✓ |
| Future date (clock skew) | `daysSince < 0` → return false → fetch today ✓ |
| Legacy bool in prefs | `getString` on bool key → null → fetch 7d ✓ |
| Same day, 2nd open | date=today, daysSince=0 → fetch today ✓ |
| Next day | date=yesterday, daysSince=1 → fetch today ✓ |
| 2 days gap | date=2d ago, daysSince=2 → fetch 7d ✓ |
| Logout | remove key → null → fetch 7d ✓ |
| Login | remove key → null → fetch 7d ✓ |

---

## 🔒 FLOWS TO PRESERVE (No Regression)

| Flow | Verification |
|------|---------------|
| Fresh install → splash → home | null → 7d fetch → store date |
| Logout → login → splash | remove → null → 7d fetch |
| Daily user (open once/day) | date stored → next day 1d ago → today fetch |
| Same day reopen | date=today → today fetch |
| Device B after 8 days | date=8d ago → 7d fetch ✓ (fix) |
| prefetch7Days fails | Don't call clearNeedsDataFetch → key stays null/stale → retry next time |
| prefetchToday fails | Log, continue; week card may show stale until next 7d fetch |

---

## 📁 FILES TO MODIFY

| File | Changes |
|------|---------|
| `lib/services/data_sync_flag_service.dart` | New logic, new methods, remove/deprecate setNeedsDataFetch |
| `lib/screens/login_screen.dart` | setNeedsDataFetch(true) → clearLastFetchDate() |
| `lib/screens/profile_screen.dart` | setNeedsDataFetch(true) → clearLastFetchDate() (2 places) |

**No changes:** splash_screen.dart, home_screen.dart, data_prefetch_service.dart, home_summary_service.dart

---

## ✅ TESTING CHECKLIST

- [ ] Fresh install: week card shows correct data after first open
- [ ] Logout → login: 7-day fetch runs, week card correct
- [ ] Same day reopen: only today fetched, week card correct
- [ ] Next day open: only today fetched, week card correct
- [ ] Device B after 2+ days: 7-day fetch runs, week card matches Device A
- [ ] prefetch7Days fails: flag not updated, retry on next open
- [ ] Invalid/future date in prefs: falls back to fetch 7d
- [ ] Existing user (legacy bool): getString null → fetch 7d, then stores date

---

## 📊 SUMMARY

- **Storage:** SharedPreferences string `"YYYY-MM-DD"` or key removed
- **Logic:** null or ≥2 days → fetch 7 days; else → fetch today
- **Callers:** Login and logout call `clearLastFetchDate()`; splash/home call `needsDataFetch()` and `clearNeedsDataFetch()` unchanged
- **Backward compat:** Legacy bool key → getString null → fetch 7d
- **No DB migration:** SharedPreferences only
