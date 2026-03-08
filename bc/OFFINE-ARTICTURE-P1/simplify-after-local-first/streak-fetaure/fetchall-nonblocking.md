# fetchAll Non-Blocking Plan

## Goal

Make `HomeSummaryService.fetchAll` fault-tolerant: if any fetch fails, return partial data (streak, today, weekly) instead of failing entirely. Log all errors.

---

## Current Problem

- `Future.wait([_fetchStreak, _fetchTodayProgress, _fetchWeeklySnapshot])` — one failure fails all
- Provider catches and returns empty `HomeSummary` → week card shows 0
- No partial results when e.g. habits_daily empty or DB error

---

## Plan

### 1. Add `_safeFetch<T>` helper in HomeSummaryService

```dart
Future<T?> _safeFetch<T>(Future<T?> Function() fn, String operation, String userId) async {
  try {
    return await fn();
  } catch (e, st) {
    await ErrorLoggingService.logError(ErrorContext.fromException(
      errorCode: 'ERRSYS151',
      severity: ErrorSeverity.medium,
      exception: e,
      stackTrace: st,
      errorContext: {'operation': operation, 'user_id': userId},
    ));
    return null;
  }
}
```

### 2. Replace Future.wait in fetchAll

- Wrap each call: `_safeFetch(() => _fetchStreak(userId), 'fetchStreak', userId)`
- Run all 3 in parallel
- Build `HomeSummary(streak: results[0], today: results[1], weekly: results[2])`
- Remove outer try/catch rethrow — always return partial summary

### 3. Remove rethrow from inner fetches (optional)

- `_fetchStreak`, `_fetchTodayProgress`, `_fetchWeeklySnapshot` — keep their try/catch for logging but let `_safeFetch` catch and return null
- Or: remove rethrow from each so they return null on error (simpler)

### 4. Provider

- Keep provider try/catch for unexpected errors
- On catch: log, return `HomeSummary()` (empty) — last resort only

---

## Files

| File | Change |
|------|--------|
| `lib/services/home_summary_service.dart` | Add _safeFetch, refactor fetchAll |

---

## Verification

- [ ] One fetch fails → others still return; partial data shown
- [ ] All fail → empty summary, errors logged
- [ ] Week card shows data when entries exist, even if today/habits fails

---

## Implemented

- Added `_safeFetch<T>` helper
- Refactored `fetchAll` to use `_safeFetch` for all 3 fetches
- Inner fetches (`_fetchStreak`, `_fetchTodayProgress`) now return null instead of rethrow
- `_fetchWeeklySnapshot` / `_calculateCurrentWeekFromLocal` already returned null on error
