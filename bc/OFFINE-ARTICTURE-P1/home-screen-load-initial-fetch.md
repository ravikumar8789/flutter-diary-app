# Home Screen Offline Fix – Implementation Plan

## Goal

Fix offline errors (ERRDATA226, ERRDATA228, ERRSYS153, ERRHIST001) when Home screen loads. Use local-only when offline; avoid Supabase calls.

---

## Context

- **Splash** already fetches 60 days of entries + today when online. Home screen data is redundant when splash ran.
- **When offline**: Splash doesn't run (or fails). Home providers must not call Supabase.

---

## Phase 1: DataFetchService – Add `useLocalOnly` to `fetchEntryByDate`

**File:** `lib/services/data_fetch_service.dart`

**Change:**
- Add `bool useLocalOnly = false` to `fetchEntryByDate`
- When `useLocalOnly == true`: return local only; if local empty, return `null`. Do not call Supabase.
- When `useLocalOnly == false`: keep current behavior (local first, then Supabase)

**Logic:**
```dart
Future<Entry?> fetchEntryByDate(String userId, DateTime date, {bool forceRefresh = false, bool useLocalOnly = false}) async {
  if (!forceRefresh) {
    final local = await _readEntryByDateFromLocal(userId, date);
    if (local != null) return local;
  }
  if (useLocalOnly) return null;  // NEW: skip Supabase
  try {
    // ... existing Supabase call
  }
}
```

**Do not change:** Error logging (ERRDATA226), other callers.

---

## Phase 2: HomeSummaryService – Use `useLocalOnly` When Offline

**File:** `lib/services/home_summary_service.dart`

**Changes:**
1. Add import: `import 'connectivity_service.dart';`
2. In `_fetchTodayProgress`, before calling `fetchEntryByDate`:
   - `final isOnline = await ConnectivityService().isOnline();`
   - Call `fetchEntryByDate(userId, today, useLocalOnly: !isOnline)`

**Flow preserved:**
- Online: local first, then Supabase if local empty (unchanged)
- Offline: local only; if empty, return null → TodayProgressSummary with empty progress

**Do not change:** `fetchHabitsForDate` (already local-only), `_fetchStreak`, `_fetchWeeklySnapshot`.

---

## Phase 3: recentEntriesProvider – Use `useLocalOnly` When Offline

**File:** `lib/providers/recent_entries_provider.dart`

**Changes:**
1. Add import: `import '../services/connectivity_service.dart';`
2. At start of provider body (after userId check):
   - `final isOnline = await ConnectivityService().isOnline();`
3. Pass `useLocalOnly: !isOnline` to both `getEntriesForMonth` calls:
   - `service.getEntriesForMonth(userId, currentMonth, useLocalOnly: !isOnline)`
   - `service.getEntriesForMonth(userId, previousMonth, useLocalOnly: !isOnline)`

**Flow preserved:**
- Online: local first (splash data), Supabase only if local empty
- Offline: local only; if empty, return `[]`

**Do not change:** Error handling (ERRDATA207), return `[]` on error.

---

## Phase 4: Verify No Regressions

**Callers of `fetchEntryByDate`:**
- `HomeSummaryService._fetchTodayProgress` – updated in Phase 2
- Any other? Grep and ensure default `useLocalOnly: false` keeps current behavior

**Callers of `getEntriesForMonth`:**
- `recentEntriesProvider` – updated in Phase 3
- `HistoryProvider.loadCurrentMonth` – already passes `useLocalOnly` based on connectivity (no change)

---

## Implementation Order

1. **DataFetchService** – Add `useLocalOnly` to `fetchEntryByDate`
2. **HomeSummaryService** – Connectivity check + pass `useLocalOnly`
3. **recentEntriesProvider** – Connectivity check + pass `useLocalOnly`

---

## Errors Fixed

| Error Code | Before | After |
|------------|--------|-------|
| ERRDATA226 | fetchEntryByDate → Supabase when offline | useLocalOnly → no Supabase |
| ERRDATA228 | fetchEntriesWithJoins → Supabase when offline | useLocalOnly → no Supabase |
| ERRSYS153 | _fetchTodayProgress catch | No throw when offline |
| ERRHIST001 | getEntriesForMonth catch | No throw when offline |

---

## Non-Breaking Guarantee

- **Online flow:** Unchanged. Local-first, Supabase when local empty.
- **Splash flow:** Unchanged. Splash fetches; Home reads from local.
- **Auth nav flow:** Unchanged. Home prefetch runs when `lastFetchDate == null`.
- **Other features:** No changes to History, Analytics, Entry provider.
