# Splash Fetch + Home Prefetch — Single Architecture Merge

## Goal

1. One unified fetch method for Splash and Home
2. Fully non-blocking: per-fetch try/catch, log fully, never rethrow
3. Remove dead/unused code after merge
4. Optimized: parallel fetches, minimal args

---

## Unified Method

### Add `fetchAndMergeAllForOpen`

**Location:** `DataPrefetchService`

**Signature:**
```dart
static Future<void> fetchAndMergeAllForOpen({
  required String userId,
  required DataFetchService dataFetchService,
  DateTime? lastFetchDate,
}) async
```

**Logic:**
1. Compute `today`, `sixtyDaysAgo`, `fetchStart` from `lastFetchDate`
2. Run 5 fetches in parallel via `Future.wait` with `_safeFetch` wrapper
3. `setLastFetchDate(today)`
4. Return (caller does invalidate)

**fetchStart:**
```dart
final fetchStart = lastFetchDate == null
    ? sixtyDaysAgo
    : (lastFetchDate.isBefore(sixtyDaysAgo)
        ? sixtyDaysAgo
        : DateTime(lastFetchDate.year, lastFetchDate.month, lastFetchDate.day));
```

---

## Non-Blocking: `_safeFetch` Wrapper

Each fetch wrapped so one failure does not block others:

```dart
static Future<void> _safeFetch(
  Future<void> Function() fn,
  String operation,
  String userId, {
  Map<String, dynamic>? extraContext,
}) async {
  try {
    await fn();
  } catch (e, st) {
    await ErrorLoggingService.logMediumError(
      error: ErrorContext.fromException(
        errorCode: 'ERRSYS170',
        severity: ErrorSeverity.medium,
        exception: e,
        stackTrace: st,
        errorContext: {
          'operation': operation,
          'user_id': userId,
          ...?extraContext,
        },
      ),
    );
  }
}
```

**Log fully:** Include `operation`, `user_id`, `stackTrace`, optional `extraContext` (e.g. `start_date`, `end_date`).

---

## Call Flow

| Caller | Args | Post-call |
|--------|------|-----------|
| Splash (online) | `lastFetchDate` from getLastFetchDate | invalidate providers, loadUserData |
| Home (login path) | `lastFetchDate` (null when needsFetch) | invalidate providers, _triggerSyncOnLand |

---

## Remove / Modify

### Remove (unused in lib)

| Item | File | Reason |
|------|------|--------|
| `prefetch7DaysData` | data_prefetch_service.dart | Not called from any lib code |
| `prefetchTodayData` | data_prefetch_service.dart | Not called from any lib code |
| `_fetchEntriesWithJoins` | data_prefetch_service.dart | Only used by prefetch7DaysData — remove with it |
| `_fetchHabits` | data_prefetch_service.dart | Only used by prefetch7DaysData — remove with it |
| `storeEntriesWithRelatedData` | data_prefetch_service.dart | Not called; EntryStorageHelper used directly |

### Keep (used by unified method)

| Item | Used by |
|------|---------|
| `fetchAndMergeUserProfile` | fetchAndMergeAllForOpen |
| `fetchAndMergeUserSettings` | fetchAndMergeAllForOpen |
| `fetchAndMergeStreaks` | fetchAndMergeAllForOpen |
| `fetchAndMergeEntriesWithJoins` | fetchAndMergeAllForOpen |
| `fetchAndStoreYesterdayInsight` | fetchAndMergeAllForOpen |

### Make internal (optional)

Keep `fetchAndMerge*` as-is; unified method calls them. No need to make them private — they're already used only by Splash/Home which will switch to the unified method.

---

## Implementation Order

1. **Add `_safeFetch`** in DataPrefetchService
2. **Add `fetchAndMergeAllForOpen`** — uses Future.wait + _safeFetch for each fetch, setLastFetchDate
3. **Splash:** Replace inline fetch block with `fetchAndMergeAllForOpen`; keep invalidate + loadUserData
4. **Home:** Replace inline fetch block with `fetchAndMergeAllForOpen`; keep invalidate + _triggerSyncOnLand
5. **Remove:** prefetch7DaysData, prefetchTodayData, _fetchEntriesWithJoins, _fetchHabits, storeEntriesWithRelatedData

---

## Files

| File | Change |
|------|--------|
| `lib/services/data_prefetch_service.dart` | Add import data_sync_flag_service; add _safeFetch, fetchAndMergeAllForOpen; remove 5 unused methods |
| `lib/screens/splash_screen.dart` | Call fetchAndMergeAllForOpen; keep invalidate + loadUserData |
| `lib/screens/home_screen.dart` | Call fetchAndMergeAllForOpen; keep invalidate + _triggerSyncOnLand |

---

## Verification

- [ ] Splash online: fetch runs, partial data on single failure
- [ ] Home login: fetch runs, partial data on single failure
- [ ] All failures logged with operation, user_id, stackTrace
- [ ] No references to removed methods in lib
