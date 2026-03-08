# Streak — All Places (Fetch / Calculate / Display)

> Task: Make all streak fetching, calculating, displaying work from local `streaks` table only.  
> Exception: Splash screen fetch-from-cloud will be handled later.

---

## 1. Display (UI reads streak for user)

| # | Function | Place | Type |
|---|----------|-------|------|
| 1 | `HomeSummaryService._fetchStreak` | `lib/services/home_summary_service.dart` | display |
| 2 | `userStatsProvider` → `UserDataService._fetchUserStats` | `lib/providers/user_data_provider.dart` → `lib/services/user_data_service.dart` | display |
| 3 | `StreakNotifier.initialize` (local DB) | `lib/providers/streak_provider.dart` | display |
| 4 | `GraceSystemService.getGraceStatus` | `lib/services/grace_system_service.dart` | display |
| 5 | `GraceSystemNotifier._refreshGraceStatus` → `GraceSystemService.getGraceStatus` | `lib/providers/grace_system_provider.dart` | display |

---

## 2. Calculation (reads/writes streak, computes new values)

| # | Function | Place | Type |
|---|----------|-------|------|
| 6 | `UserDataService._calculateStreakFromTodayHabits` | `lib/services/user_data_service.dart` | calculation |
| 7 | `UserDataService.calculateStreakWithGrace` | `lib/services/user_data_service.dart` | calculation |
| 8 | `UserDataService._persistStreak` | `lib/services/user_data_service.dart` | calculation |
| 9 | `UserDataService.recalculateStreak` | `lib/services/user_data_service.dart` | calculation |
| 10 | `UserDataService._useGraceDayForStreak` | `lib/services/user_data_service.dart` | calculation |
| 11 | `UserDataService._getCurrentStreak` | `lib/services/user_data_service.dart` | calculation |
| 12 | `GraceSystemService.trackTaskCompletion` | `lib/services/grace_system_service.dart` | calculation |
| 13 | `GraceSystemService.useGraceDay` | `lib/services/grace_system_service.dart` | calculation |

---

## 3. Other (sync, prefetch, startup — handle later)

| # | Function | Place | Type |
|---|----------|-------|------|
| 14 | `UserDataService.calculateStreakOnAppLaunch` | `lib/services/user_data_service.dart` | other (startup — handle later) |
| 15 | `DataFetchService.fetchStreaks` | `lib/services/data_fetch_service.dart` | other |
| 16 | `DataFetchService.fetchStreaksFromSupabaseOnly` | `lib/services/data_fetch_service.dart` | other |
| 17 | `DataPrefetchService._fetchStreaks` | `lib/services/data_prefetch_service.dart` | other |
| 18 | `DataPrefetchService.fetchAndMergeStreaks` | `lib/services/data_prefetch_service.dart` | other |
| 19 | `UserDataService.ensureStreaksRecordExists` | `lib/services/user_data_service.dart` | other |
| 20 | `UserDataService._ensureStreaksRecordExists` | `lib/services/user_data_service.dart` | other |
| 21 | `SupabaseSyncService.syncStreak` | `lib/services/sync/supabase_sync_service.dart` | other |
| 22 | `SupabaseSyncService.batchUpdateStreakData` | `lib/services/sync/supabase_sync_service.dart` | other |
| 23 | `LocalEntryService.addStreakToSyncQueue` | `lib/services/database/local_entry_service.dart` | other |

---

## 4. Where streak is shown (screens/widgets)

| Screen/Widget | Provider/Source |
|---------------|-----------------|
| Home screen streak card | `homeSummaryProvider` + `userStatsProvider` fallback |
| Home screen grace info | `graceSystemProvider` → `GraceSystemService.getGraceStatus` (local) |
| Streak details modal | `streakProvider` (local DB) |
| Profile screen | `graceSystemProvider` |
| Settings screen | `graceSystemProvider` |
| Entry provider (gap check) | `db.query('streaks')` + `streakProvider.refresh()` |

---

## 5. Done — All 1–13 now local-only

- `HomeSummaryService._fetchStreak` — reads local `streaks` only
- `StreakNotifier.initialize` — reads local `streaks` + `getGraceStatus`
- `UserDataService._getCurrentStreak` — reads local `streaks` only
- `GraceSystemService.getGraceStatus` — removed `dataFetchService` param
- `GraceSystemService.trackTaskCompletion` — removed `dataFetchService` param
- `GraceSystemService.useGraceDay` — removed `dataFetchService` param
- `UserDataService.recalculateStreak` — removed `dataFetchService` param
- `UserDataService.calculateStreakWithGrace` — removed `dataFetchService` param

---

## 6. Already local-only (no change)

- `UserDataService._fetchUserStats` — reads `db.query('streaks')`
- `GraceSystemService.getGraceStatus` — reads `db.query('streaks')`
- `UserDataService._calculateStreakFromTodayHabits` — reads `db.query('streaks')`
- `UserDataService.recalculateStreak` — reads `db.query('streaks')`, calls `calculateStreakWithGrace`
- `UserDataService._useGraceDayForStreak` — reads/writes `db.query/update('streaks')`
- `UserDataService._persistStreak` — writes `db.insert/update('streaks')`
- `GraceSystemService.trackTaskCompletion` — updates local habits_daily, may trigger streak recalc
- `GraceSystemService.useGraceDay` — updates local `streaks`
