# Fix: Mood Filter Skip Date Gap

## Problem
`skipUntilDate` used `currentMonth - 60 days`, creating a gap. Initial load uses whole months (Jan + Feb). The 60-day cutoff (e.g. Dec 3) left Dec 4–31 unfetched.

## Solution
Use first day of **previous month** as cutoff so we skip the exact 2 loaded months.

## Change
**File:** `lib/providers/history_provider.dart`  
**In:** `loadMoodFilteredEntries()`

```dart
// Before (buggy):
final skipUntilDate = currentMonth.subtract(const Duration(days: 60));

// After (correct):
final skipUntilDate = DateTime(now.year, now.month - 1, 1);
```

Note: `DateTime(2026, 0, 1)` auto-rolls to Dec 1, 2025 in Dart for January.

## Status
Implemented.

---

## Fix 2: Mood Count Race Condition

**Problem:** loadCurrentMonth overwrote moodMap, losing full metadata when it completed after loadCalendarMoodData.

**Solution:** Merge instead of replace in loadCurrentMonth:
```dart
moodMap: {...state.moodMap, ...allMoodMap},
```

**Status:** Implemented.
