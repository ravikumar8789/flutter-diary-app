# Splash, History & Local 60-Day Plan

**Goal:** Light Splash startup, 60-day local retention, History driven by local DB, entry insights stored locally for 2 months. Flow: **user input → local → sync queue → Supabase**.

**Note:** Streak calculation refinements deferred; focus on making the whole app work with this flow.

---

## 1. Design Summary

| Area | Current | Target |
|------|---------|--------|
| **Retention** | 7 days | 60 days |
| **Splash fetch** | Week or today (needsFetch), cleanup 7d | Login: full 60-day. Resume: gap from last_open to today |
| **History entries** | Local-first (2 months) | Same; driven by local DB |
| **History insights** | Supabase only | Local-first, lazy population |
| **Insight storage** | `yesterday_insight` (1 row) | Keep + add `entry_insights_local` (60 days) |

---

## 2. Data Flow (Target)

```
User input → Local DB → sync_queue → processSyncQueue → Supabase
                ↑
         Read from local first (entries, insights, profile, settings, streaks)
```

### Splash (Login vs Resume)

**On Splash (online), we always fetch:**
- User details (profile, settings)
- Streak details
- Entries from `last_open` to today (or full 60 days on login)
- Yesterday insight

| Scenario | Fetch | Store last_open |
|----------|-------|------------------|
| **Login (online)** | Full 60-day entries + insights, profile, settings, streaks, yesterday insight | Yes (today) |
| **Resume (online)** | Gap: entries from `last_open` to today + profile, settings, streaks, yesterday insight | Yes (today) |
| **Offline** | None; read from SQLite only | No |

### last_open (stored on device)

- **Where:** SharedPreferences (via DataSyncFlagService or new key).
- **When stored:** After every successful fetch (login or resume).
- **When cleared:** Logout.
- **Use on resume:** Fetch entries from `last_open` date to today; merge into local; update `last_open = today`.

**Example:** User opens app on device A after 7 days of writing on device B. `last_open` = 7 days ago → fetch 7 days → merge → `last_open = today`.

**Multi-device (same day):** Even if `last_open` is today (e.g. user opened app this morning), we still fetch from today to today. This catches entries written on another device later that same day.

---

- **History:** Read 2 months from local DB. Load more → fetch from Supabase, store locally.
- **History insights:** Read from `entry_insights_local` first; if missing and online → fetch from Supabase, store locally.

---

## 3. Phase Overview

| Phase | Scope | Dependencies |
|-------|-------|--------------|
| **3.1** | 60-day retention (replace 7-day cleanup) | — |
| **3.2** | Splash: login vs resume, last_open storage | 3.1 |
| **3.3** | `entry_insights_local` table + helper | — |
| **3.4** | History insight: local-first, lazy store | 3.3 |
| **3.5** | Cleanup `entry_insights_local` (60 days) | 3.3 |

---

## 4. Phase 3.1 — 60-Day Retention

### 4.1 Change retention from 7 to 60 days

**Files:** `lib/services/database/database_manager.dart`, `lib/services/entry_service.dart`, `lib/services/database/local_entry_service.dart`

- `DatabaseManager.clearOldEntries`: change default `retentionDays` from 7 to 60.
- `EntryService.cleanupOldEntries`: same.
- `LocalEntryService.clearOldEntries`: pass through; no change if it uses param.

### 4.2 Replace Splash cleanup: 7-day → 60-day

**File:** `lib/screens/splash_screen.dart`

- **Offline path (line ~117):** Replace `cleanupOldEntries(retentionDays: 7)` with `cleanupOldEntries(retentionDays: 60)`.
- **Online path (line ~169):** Same replacement.

**Rationale:** 60-day retention keeps History's 2-month view local. Run cleanup on Splash startup (both paths).

---

## 5. Phase 3.2 — Splash: Login vs Resume, last_open

### 5.1 Detect login vs resume

- **Login:** User just authenticated (e.g. from LoginScreen, `currentUser` was null → now has value). Or: `last_open` is null (fresh install, post-logout).
- **Resume:** User was already logged in; `last_open` exists in SharedPreferences.

**Implementation:** Check `DataSyncFlagService.getLastFetchDate()`:
- `null` → treat as **login** (full 60-day fetch).
- Non-null → treat as **resume** (gap fetch from that date to today).

### 5.2 last_open storage (DataSyncFlagService)

**File:** `lib/services/data_sync_flag_service.dart`

Add:

- `getLastFetchDate() async => DateTime?` — Read stored date from SharedPreferences. Returns null if not set.
- `setLastFetchDate(DateTime date)` — Store date (e.g. `DateFormat('yyyy-MM-dd').format(date)`). Call after every successful fetch.
- Keep `clearLastFetchDate()` — already called on logout.

Reuse or replace `needsDataFetch` / `clearNeedsDataFetch` with the above. Remove the old 7-day vs today logic.

### 5.3 Splash online — Login path

When `getLastFetchDate() == null`:

```dart
await Future.wait([
  DataPrefetchService.fetchAndMergeUserProfile(user.id, dataFetchService),
  DataPrefetchService.fetchAndMergeUserSettings(user.id, dataFetchService),
  DataPrefetchService.fetchAndMergeStreaks(user.id, dataFetchService),
  DataPrefetchService.fetchAndMergeEntriesWithJoins(user.id, sixtyDaysAgo, today, dataFetchService),
  DataPrefetchService.fetchAndStoreYesterdayInsight(user.id, dataFetchService),
]);
// TODO: fetch 60-day insights (or rely on lazy History fetch)
await DataSyncFlagService.setLastFetchDate(today);
```

### 5.4 Splash online — Resume path

When `getLastFetchDate() != null`:

```dart
final lastOpen = await DataSyncFlagService.getLastFetchDate();
final sixtyDaysAgo = today.subtract(const Duration(days: 60));
// Cap: never fetch more than 60 days (e.g. if lastOpen was 90 days ago)
final startDate = lastOpen != null && lastOpen.isBefore(sixtyDaysAgo)
    ? sixtyDaysAgo
    : (lastOpen ?? sixtyDaysAgo);
final fetchStart = DateTime(startDate.year, startDate.month, startDate.day);

await Future.wait([
  DataPrefetchService.fetchAndMergeUserProfile(user.id, dataFetchService),
  DataPrefetchService.fetchAndMergeUserSettings(user.id, dataFetchService),
  DataPrefetchService.fetchAndMergeStreaks(user.id, dataFetchService),
  DataPrefetchService.fetchAndMergeEntriesWithJoins(user.id, fetchStart, today, dataFetchService),
  DataPrefetchService.fetchAndStoreYesterdayInsight(user.id, dataFetchService),
]);
await DataSyncFlagService.setLastFetchDate(today);
```

### 5.5 Splash offline path

- `cleanupOldEntries(retentionDays: 60)` + `clearEntryInsightsOlderThan(retentionDays: 60)`.
- `loadUserData(useLocalOnly: true)`.
- `processSyncQueue()` (no-op when offline).
- **Do not** update `last_open` (no fetch occurred).

### 5.6 DataPrefetchService

- Add or extend `fetchAndMergeEntriesWithJoins` to accept a date range (startDate, endDate). Already exists.
- Add `fetchAndStoreInsightsForDateRange` for 60-day insights on login, if desired. **Optional:** can rely on lazy fetch in History instead.

---

## 6. Phase 3.3 — entry_insights_local Table

### 6.1 Schema

**Table:** `entry_insights_local`

```sql
CREATE TABLE entry_insights_local (
  entry_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  entry_date TEXT NOT NULL,
  id TEXT NOT NULL,
  summary TEXT,
  insight_text TEXT,
  insight_details TEXT,
  sentiment_label TEXT,
  topics TEXT,
  processed_at TEXT NOT NULL
);
```

- One row per entry. `entry_id` = PK.
- `entry_date` for 60-day cleanup.
- `topics` stored as JSON string if needed for `HistoryDailyInsight`.

### 6.2 Migration

**File:** `lib/services/database/database_manager.dart`

- Bump `_version` to 8.
- In `_onUpgrade`: if `oldVersion < 8`, call `_createEntryInsightsLocalTable(db)`.
- In `_createTables`: add `entry_insights_local` for fresh installs.

### 6.3 EntryInsightStorageHelper extension

**File:** `lib/services/entry_insight_storage_helper.dart`

Add:

- `storeEntryInsightLocal(userId, entryId, entryDate, Map<String, dynamic> insight)` — INSERT OR REPLACE.
- `getEntryInsightFromLocal(entryId)` — returns `HistoryDailyInsight?` or null.
- `clearEntryInsightsOlderThan(retentionDays: 60)` — DELETE WHERE entry_date < cutoff.

Keep existing `yesterday_insight` methods unchanged.

---

## 7. Phase 3.4 — History Insight: Local-First, Lazy Store

### 7.1 HistoryService.fetchInsightForEntry

**File:** `lib/services/history_service.dart`

**New flow:**

1. Check local: `EntryInsightStorageHelper.getEntryInsightFromLocal(entryId)`.
2. If found → return.
3. If not found and online → fetch from Supabase (`entry_insights`).
4. If Supabase returns data → `EntryInsightStorageHelper.storeEntryInsightLocal(...)`, then return.
5. If offline or Supabase empty → return null.

### 7.2 DataFetchService

- Add `fetchInsightForEntryFromSupabase(entryId)` if not exists, or reuse existing Supabase query logic from `HistoryService`.
- `HistoryService` can call `DataFetchService` for Supabase fetch, then pass result to `EntryInsightStorageHelper.storeEntryInsightLocal`.

### 7.3 Entry date for storage

- `HistoryService.fetchInsightForEntry` receives `entryId` only. Need `entry_date` for `entry_insights_local`.
- **Implementation:** Pass `entryDate` from History screen. Update `_ExpandableInsightsCard` to accept `entryDate: DateTime` and pass to `fetchInsightForEntry(entryId, entryDate: date)`. Call site: `_buildExpandableInsightsCard(entry)` has `entry.entry.entryDate`.

---

## 8. Phase 3.5 — Cleanup entry_insights_local (60 Days)

### 8.1 When to run

- On Splash startup (with `clearOldEntries`), or
- In a shared cleanup routine that runs both `clearOldEntries(60)` and `clearEntryInsightsOlderThan(60)`.

### 8.2 Implementation

**File:** `lib/services/entry_insight_storage_helper.dart`

```dart
static Future<void> clearEntryInsightsOlderThan({int retentionDays = 60}) async {
  final db = await DatabaseManager().database;
  final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
  final cutoffStr = cutoff.toIso8601String().split('T')[0];
  await db.delete(
    'entry_insights_local',
    where: 'entry_date < ?',
    whereArgs: [cutoffStr],
  );
}
```

### 8.3 Call site

- **Splash:** After `loadUserData`, call `EntryInsightStorageHelper.clearEntryInsightsOlderThan(retentionDays: 60)` (or combine with entries cleanup in a single "cleanup old data" step).

---

## 9. Execution Order

| Step | Phase | Action |
|------|-------|--------|
| 1 | 3.1 | Change `clearOldEntries` default to 60; replace Splash 7-day cleanup with 60-day |
| 2 | 3.2 | DataSyncFlagService: add `getLastFetchDate`, `setLastFetchDate`; Splash: login vs resume, gap fetch |
| 3 | 3.3 | Add `entry_insights_local` table, migration v8, helper methods |
| 4 | 3.4 | HistoryService.fetchInsightForEntry: local-first, lazy store |
| 5 | 3.5 | Add `clearEntryInsightsOlderThan(60)` and call from Splash cleanup |

---

## 10. Files to Modify

| File | Changes |
|------|---------|
| `lib/services/database/database_manager.dart` | Add `entry_insights_local`, migration v8; `clearOldEntries` default 60 |
| `lib/services/entry_service.dart` | `cleanupOldEntries` default 60 (if not passed) |
| `lib/screens/splash_screen.dart` | Login vs resume; full 60-day (login) or gap fetch (resume); 60-day cleanup; insights cleanup |
| `lib/services/entry_insight_storage_helper.dart` | Add store/get/clear for `entry_insights_local` |
| `lib/services/history_service.dart` | `fetchInsightForEntry`: local-first, lazy store; add entryDate param |
| `lib/screens/history_screen.dart` | Pass entryDate to _ExpandableInsightsCard and fetchInsightForEntry |
| `lib/services/data_prefetch_service.dart` | Support variable date range (60-day login, gap resume); called from Splash |
| `lib/services/data_sync_flag_service.dart` | Add `getLastFetchDate()`, `setLastFetchDate()`; replace needsFetch with login/resume logic |
| `lib/services/database/user_data_cleanup_service.dart` | Add `entry_insights_local`, `yesterday_insight` to logout cleanup |

---

## 11. Logout Cleanup

**File:** `lib/services/database/user_data_cleanup_service.dart`

Add to `clearUserData` (before entries):

- `await db.delete('entry_insights_local', where: 'user_id = ?', whereArgs: [userId]);`
- `await db.delete('yesterday_insight', where: 'user_id = ?', whereArgs: [userId]);`

**SharedPreferences:** Call `DataSyncFlagService.clearLastFetchDate()` on logout (already done in `profile_screen.dart`, `login_screen.dart`). Ensures next login does full 60-day fetch.

---

## 12. Verification Checklist

- [ ] **Login (online):** Full 60-day fetch; `last_open` stored
- [ ] **Resume (online):** Gap fetch from `last_open` to today; `last_open` updated
- [ ] **Multi-device:** User writes on device B for 7 days, opens device A → fetches 7 days, merges
- [ ] Splash offline: no network, reads from SQLite; `last_open` not updated
- [ ] History: 2 months from local DB; Load more fetches from Supabase
- [ ] History insight: tap day → local first; if missing and online → fetch, store, show
- [ ] Offline History: entries from local; insights from local (or null if never fetched)
- [ ] 60-day cleanup: entries and entry_insights_local pruned on startup
- [ ] yesterday_insight unchanged for Home screen
- [ ] User input → local → sync queue → Supabase (no direct Supabase writes for entries)
- [ ] Logout: clears entry_insights_local, yesterday_insight

---

## 13. Rollback

- Revert code changes.
- `entry_insights_local` table can remain (no harm) or add migration to drop in next version.
- Restore `needsDataFetch` and 7-day cleanup if needed.
