# History Feature – Offline Support Implementation Plan

## Goals

1. **Non-blocking when offline** – History screen opens instantly with local 2-month data, no fetch errors
2. **Online refresh** – Single fetch for mood map + months when online; connectivity listener when user comes online
3. **Calendar date tap** – Check connectivity first: offline → "No internet"; online + no entry → "No entry"; online + entry → show entry
4. **Load More / Mood chip** – Check connectivity; if offline → "No internet" SnackBar
5. **Error logging** – Ensure all paths have appropriate error codes

---

## Deferred (Implement Later)

- Calendar screen showing all mood when user is **offline** (currently shows mood from 2-month local data only)
- Mood chip selector showing total count when user is **offline** (currently shows count from 2-month local data only)

---

## Phase 1: HistoryService – Local-Only Support

### 1.1 `getEntriesForMonth` – Add `useLocalOnly` Parameter

**File:** `lib/services/history_service.dart`

- Add optional `bool useLocalOnly = false` to `getEntriesForMonth`
- When `useLocalOnly == true`, call `_dataFetchService.fetchEntriesWithJoins(..., useLocalOnly: true)` for both current and previous month
- When `_dataFetchService == null` and `useLocalOnly == true`, use direct Supabase fallback is not applicable; ensure we use DataFetchService (provider-injected)

**Error logging:** Already present in catch (ERRHIST001). Keep as-is.

---

### 1.2 `getEntryByDate` – Add `useLocalOnly` Parameter

**File:** `lib/services/history_service.dart`

- Add optional `bool useLocalOnly = false` to `getEntryByDate`
- Pass through to `fetchEntriesWithJoins(..., useLocalOnly: useLocalOnly)` when using DataFetchService
- Direct Supabase fallback: when `useLocalOnly == true`, read from local only (DataFetchService must support this; if no DataFetchService, we cannot do local-only for single date – document this)

**Error logging:** ERRHIST002 present. Keep as-is.

---

### 1.3 New Method: `getMoodMapAndMonthsWithEntries` (Single Fetch)

**File:** `lib/services/history_service.dart`

- New method: `Future<({Map<String, int> moodMap, List<String> monthsWithEntries})?> getMoodMapAndMonthsWithEntries(String userId)`
- Single Supabase call: `fetchEntriesWithSelect(userId, startDate, endDate, select: 'entry_date, mood_score')` with full range (e.g. 10 years ago to now)
- Build `moodMap`: `dateStr -> moodScore`
- Build `monthsWithEntries`: unique month keys from dates, sorted ascending
- Return both; on error log (new code: `ERRHIST013`) and return null

**Error logging:** Add `ERRHIST013` for fetch failure.

---

## Phase 2: HistoryProvider – Offline-First Logic

### 2.1 `loadCurrentMonth` – Local-Only on Init

**File:** `lib/providers/history_provider.dart`

**Changes:**

1. Check connectivity at start: `final isOnline = await ConnectivityService().isOnline();`
2. If **offline**:
   - Call `getEntriesForMonth(..., useLocalOnly: true)` for current + previous month
   - Skip `getMonthsWithEntries` entirely
   - Derive `monthsWithEntries` from loaded entries: unique months from `allEntries`, sorted
   - Build `moodMap` from loaded entries via `_buildMoodMap(allEntries)`
   - Set state; **no Supabase calls**
3. If **online**:
   - Call `getEntriesForMonth` (local-first, may hit Supabase if local empty) for current + previous month
   - **Remove** `getMonthsWithEntries` from here – it will be provided by `loadCalendarMoodData` (single fetch)
   - Build `moodMap` from loaded entries; set `monthsWithEntries` to empty or derived from entries (temporary; `loadCalendarMoodData` will overwrite with full data)

**Non-blocking:** Use `ConnectivityService().isOnline()` – it is async but fast. Do not block UI; show loading until first result. If offline, local read is fast (SQLite).

**Error logging:** ERRHIST005 already present. Add context: `'offline': !isOnline` in errorContext.

---

### 2.2 `loadCalendarMoodData` – Sequential, Single Fetch When Online

**File:** `lib/providers/history_provider.dart`

**Order:** Must run **after** `loadCurrentMonth` (see Phase 3.1).

**Changes:**

1. If **offline**: Do not fetch. Build `moodMap` from `state.entries` via `_buildMoodMap(state.entries)`. Derive `monthsWithEntries` from `state.entries` (unique months). Set state. No Supabase.
2. If **online**: Call new `getMoodMapAndMonthsWithEntries(userId)`:
   - Get `moodMap` and `monthsWithEntries` from single fetch
   - Merge: `moodMap = {...state.moodMap, ...fetchedMoodMap}` (fetched takes precedence)
   - Update `monthsWithEntries` from fetch result (enables Load More button)
   - Set state

**Error logging:** ERRHIST010 for fetch failure. Add `ERRHIST014` if `getMoodMapAndMonthsWithEntries` returns null (low severity).

---

### 2.3 `loadPreviousMonth` – Connectivity Check

**File:** `lib/providers/history_provider.dart`

- At start: `final isOnline = await ConnectivityService().isOnline();`
- If **offline**: Do not fetch. Return a signal (e.g. `Future<bool?> loadPreviousMonth(...)` returning `false` = offline) so UI can show "No internet"
- If **online**: Proceed as today

**Error logging:** ERRHIST006 present. Add `'offline_blocked': true` in errorContext when we skip due to offline.

---

### 2.4 `loadMoodFilteredEntries` – Connectivity Check

**File:** `lib/providers/history_provider.dart`

- At start: `final isOnline = await ConnectivityService().isOnline();`
- If **offline**: Do not fetch. Return signal for UI to show "No internet"
- If **online**: Proceed as today

**Error logging:** ERRHIST012 present. Add `'offline_blocked': true` when skipped.

---

### 2.5 `getEntryByDate` – Connectivity Check + Local-First

**File:** `lib/providers/history_provider.dart`

**Logic:**

1. Check connectivity: `final isOnline = await ConnectivityService().isOnline();`
2. If **offline**:
   - Check if date is in `state.entries` (within loaded 2 months)
   - If yes: return entry from `state.entries`
   - If no: return `null` with a flag (e.g. `HistoryEntryResult(entry: null, wasOffline: true)`) so UI shows "No internet" instead of "No entry"
3. If **online**:
   - Call `_service.getEntryByDate(userId, date)` (existing, local-first via DataFetchService)
   - If entry found → return entry
   - If not found → return `null` with `wasOffline: false` → UI shows "No entry for this date"

**API change:** Consider `Future<({HistoryEntry? entry, bool wasOffline})> getEntryByDate(DateTime date)` to distinguish "offline" vs "no entry".

**Error logging:** ERRHIST007 present. Add handling for offline path (no new code needed if we don't throw).

---

## Phase 3: HistoryScreen – Init Order & Connectivity Listener

### 3.1 Init Order – Sequential Load

**File:** `lib/screens/history_screen.dart`

**Current:**
```dart
ref.read(historyProvider.notifier).loadCurrentMonth();
ref.read(historyProvider.notifier).loadCalendarMoodData();
```

**New (sequential):**
```dart
await ref.read(historyProvider.notifier).loadCurrentMonth();
ref.read(historyProvider.notifier).loadCalendarMoodData();
```

- `loadCurrentMonth` must complete first so `state.entries` is set
- `loadCalendarMoodData` then uses `state.entries` when offline, or fetches when online

---

### 3.2 Connectivity Listener – Refresh When Online

**File:** `lib/screens/history_screen.dart`

- Add `StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription` in state
- In `initState` (after load): subscribe to `Connectivity().onConnectivityChanged`
- When `results.any((r) => r != ConnectivityResult.none)` (user came online):
  - Call `ref.read(historyProvider.notifier).loadCalendarMoodData()` to refresh mood map + months
  - Optionally show subtle SnackBar: "History refreshed"
- In `dispose`: cancel `_connectivitySubscription`

**Import:** `package:connectivity_plus/connectivity_plus.dart`

**Error logging:** If listener callback throws, log with `ERRHIST015` (low severity).

---

### 3.3 Calendar Date Tap – `_handleDateTap` Logic

**File:** `lib/screens/history_screen.dart`

**Flow (no loading UI until fetch is needed):**

1. Check connectivity: `final isOnline = await ConnectivityService().isOnline();`
2. If **offline**:
   - Check if date exists in `state.entries` (by `entryDate`)
   - If yes: show entry detail immediately (no loading, no fetch)
   - If no: show bottom sheet "No internet – Connect to load entries from other dates"
3. If **online**:
   - Show loading bottom sheet
   - Call `getEntryByDate(date)`
   - If entry: show entry detail
   - If null: show "No entry for this date"

**UI:** Reuse existing bottom sheets; add one for "No internet" (similar to analytics offline UI style). Do not show loading when offline.

---

### 3.4 Load More – Show "No internet" When Offline

**File:** `lib/screens/history_screen.dart`

- When user taps Load More, `loadPreviousMonth` is called
- Provider returns `false` or we need a way to signal "offline blocked"
- **Option A:** Provider sets `state.error = 'No internet'` when offline; UI shows SnackBar and clears error
- **Option B:** Provider returns `Future<bool>` – `false` = offline; Screen shows SnackBar on `false`

**Recommended:** Provider returns `Future<bool?>` – `true` = success, `false` = offline (don't fetch), `null` = error. Screen: if `false`, show `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No internet. Connect to load more.')))`

---

### 3.5 Mood Chip – Show "No internet" When Offline

**File:** `lib/screens/history_screen.dart`

- When user taps mood chip and `loadMoodFilteredEntries` is triggered
- Provider checks connectivity; if offline, returns without fetching
- **Option:** Provider exposes `state.offlineBlockedMoodFilter = true` temporarily, or returns a result
- Screen: when mood filter would trigger fetch and we detect offline (e.g. from provider state or callback), show SnackBar "No internet. Connect to filter by mood."

**Implementation:** `loadMoodFilteredEntries` can return `Future<bool>` – `false` = offline. Screen passes a callback or watches state. Simpler: have `loadMoodFilteredEntries` take an `onOffline` callback, or have provider set `state.error` / `state.offlineMessage` that UI reads and shows as SnackBar.

**Recommended:** `loadMoodFilteredEntries` returns `Future<bool?>` – `false` = offline. HistoryScreen's `_handleMoodSelection` calls it and if `false`, shows SnackBar. Need to thread this through – `loadMoodFilteredEntries` is called from `_handleMoodSelection` with a 300ms debounce. When the notifier's method returns `false`, the caller (screen) needs to show SnackBar. So the notifier must return a value. Change `loadMoodFilteredEntries` to `Future<bool> loadMoodFilteredEntries(...)` – returns `true` if fetch attempted/succeeded, `false` if skipped due to offline.

---

## Phase 4: DataFetchService – Support for HistoryService

### 4.1 `fetchEntriesWithJoins` – Already Supports `useLocalOnly`

**File:** `lib/services/data_fetch_service.dart`

- No change needed. `useLocalOnly: true` returns local only.

---

### 4.2 `fetchEntriesWithSelect` – Used by `getMoodMapAndMonthsWithEntries`

**File:** `lib/services/data_fetch_service.dart`

- `getMoodMapAndMonthsWithEntries` will call this (or a similar method). Ensure `fetchEntriesWithSelect` exists and is used. It currently goes to Supabase only – correct for online refresh.

---

## Phase 5: Error Logging Summary

| Code     | Location                         | When                                      |
|----------|----------------------------------|-------------------------------------------|
| ERRHIST005 | loadCurrentMonth catch           | Fetch entries failed                      |
| ERRHIST006 | loadPreviousMonth catch          | Fetch month failed                        |
| ERRHIST007 | getEntryByDate catch             | Fetch entry by date failed                |
| ERRHIST010 | loadCalendarMoodData catch      | Fetch mood map failed                     |
| ERRHIST012 | loadMoodFilteredEntries catch    | Fetch mood filtered entries failed       |
| ERRHIST013 | getMoodMapAndMonthsWithEntries  | **NEW** – Single fetch for mood+months failed |
| ERRHIST014 | loadCalendarMoodData             | **NEW** – getMoodMapAndMonthsWithEntries returned null (low) |
| ERRHIST015 | HistoryScreen connectivity listener | **NEW** – Listener callback threw (low) |

---

## Phase 6: Implementation Order

1. **HistoryService:** Add `useLocalOnly` to `getEntriesForMonth` and `getEntryByDate`; add `getMoodMapAndMonthsWithEntries`
2. **HistoryProvider:** Update `loadCurrentMonth` (connectivity + offline path)
3. **HistoryProvider:** Update `loadCalendarMoodData` (offline = build from entries; online = single fetch)
4. **HistoryProvider:** Update `loadPreviousMonth` and `loadMoodFilteredEntries` (connectivity check, return bool)
5. **HistoryProvider:** Update `getEntryByDate` (connectivity + offline = check state.entries)
6. **HistoryScreen:** Change init to sequential (`await loadCurrentMonth` then `loadCalendarMoodData`)
7. **HistoryScreen:** Add connectivity listener in initState/dispose
8. **HistoryScreen:** Update `_handleDateTap` (connectivity first, then entry/no entry/no internet)
9. **HistoryScreen:** Update Load More button handler – on `false` from provider, show SnackBar
10. **HistoryScreen:** Update mood chip handler – on `false` from provider, show SnackBar
11. **Error logging:** Add ERRHIST013, ERRHIST014, ERRHIST015 where needed

---

## Edge Cases Checklist

| Case | Handling |
|------|----------|
| Offline, no local data | Empty list, no error. Optional "No entries" message. |
| Offline, 2 months local | Show list, mood chips, calendar from local. Load More hidden or disabled. |
| Load More offline | Check connectivity → show "No internet" SnackBar, no fetch. |
| Mood chip offline | Check connectivity → show "No internet" SnackBar, no fetch. |
| Calendar tap, date in 2 months, offline | Entry from state.entries, show detail. |
| Calendar tap, date outside 2 months, offline | Show "No internet – Connect to load entries from other dates". |
| Calendar tap, online, no entry | Show "No entry for this date". |
| Calendar tap, online, entry exists | Fetch (local-first) and show entry. |
| User comes online while on History | Connectivity listener triggers `loadCalendarMoodData` (single fetch). |
| Refresh fails (network error) | Keep existing data; optionally log and show "Couldn't refresh" SnackBar. |
| Empty moodMap | Mood chips show 0; calendar shows no markers. |
| monthsWithEntries empty when offline | Load More hidden. |

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `lib/services/history_service.dart` | `useLocalOnly` params; `getMoodMapAndMonthsWithEntries`; error codes |
| `lib/providers/history_provider.dart` | Connectivity checks; offline paths; return bool for Load More/Mood; `getEntryByDate` offline handling |
| `lib/screens/history_screen.dart` | Sequential init; connectivity listener; `_handleDateTap` connectivity; Load More/Mood SnackBars |
| `lib/services/error_logging_service.dart` | No change (use existing ErrorContext) |

---

## Non-Blocking Guarantee

- **Offline path:** No `await` on Supabase. Only `ConnectivityService().isOnline()` (fast) and SQLite reads.
- **Online path:** Same as today; may hit Supabase but with loading indicator.
- **Connectivity check:** `isOnline()` is async but typically &lt;500ms; acceptable for init.
