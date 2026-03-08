# Habit Daily Ensure After Login — Fix Plan

## Problem

When user logs in, navigation goes **Login → Home** (no Splash). Home runs prefetch in `_runPrefetchAndWait`, but it does **not** call `ensureHabitsDailyFromEntries`. Splash (online path) does call it.

**Impact:** After login via Home, `habits_daily` for today may be missing or stale → streak/grace calculations can be wrong.

---

## Fix

Add `DataPrefetchService.ensureHabitsDailyFromEntries(userId)` to Home prefetch, in the same place as Splash: **after all fetches complete, before `setLastFetchDate`**.

---

## Implementation

**File:** `lib/screens/home_screen.dart`  
**Method:** `_runPrefetchAndWait`  
**Location:** Inside the `if (needsFetch)` try block, after `fetchAndStoreYesterdayInsight`, before `setLastFetchDate`.

**Change:**

```dart
await DataPrefetchService.fetchAndStoreYesterdayInsight(
  userId,
  dataFetchService,
);
await DataPrefetchService.ensureHabitsDailyFromEntries(userId);  // ADD
await DataSyncFlagService.setLastFetchDate(today);
```

---

## Verification

1. Logout → Login → Home loads.
2. Confirm streak/grace card shows correct values.
3. Confirm no regression when coming from Splash (resume path).

---

## Notes

- No extra error handling: `ensureHabitsDailyFromEntries` already catches and logs internally.
- Same order as Splash; no flow changes.
- No other files to modify.
