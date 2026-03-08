# Splash Screen — Functions, Calculations, Read/Write

## Functions Called

| Function | Description |
|----------|-------------|
| `Supabase.instance.client.auth.currentUser` | Get current auth user |
| `userDataProvider.clearUserData()` | Reset user state to empty |
| `ConnectivityService().isOnline()` | Check network (Connectivity + DNS lookup) |
| `userDataProvider.loadUserData(useLocalOnly: true)` | Load profile/stats/prefs from local SQLite only |
| `userDataProvider.loadUserData()` | Load profile/stats/prefs (local or Supabase) |
| `DataSyncFlagService.getLastFetchDate()` | Read last fetch date from SharedPreferences |
| `DataPrefetchService.fetchAndMergeUserProfile()` | Fetch user from Supabase, merge into local users |
| `DataPrefetchService.fetchAndMergeUserSettings()` | Fetch settings from Supabase, store in user_settings |
| `DataPrefetchService.fetchAndMergeStreaks()` | Fetch streaks from Supabase, merge into local streaks |
| `DataPrefetchService.fetchAndMergeEntriesWithJoins()` | Fetch entries+joins from Supabase, merge into local |
| `DataPrefetchService.fetchAndStoreYesterdayInsight()` | Fetch yesterday insight from Supabase, store locally |
| `DataSyncFlagService.setLastFetchDate(today)` | Write last fetch date to SharedPreferences |
| `ref.invalidate(homeSummaryProvider)` | Invalidate home summary cache |
| `ref.invalidate(yesterdayInsightProvider)` | Invalidate yesterday insight cache |
| `SyncWorker().processSyncQueue()` | Push local unsynced entries + sync_queue to Supabase |
| `_navigateToHomeOrAuthBasedOnUserData()` | Decide Home vs Auth based on userData state |
| `_navigateToAuth()` | Replace with LoginScreen |
| `_navigateToHome()` | Replace with HomeScreen |

---

## Calculations

| Calculation | Description |
|-------------|-------------|
| `today = DateTime(now.year, now.month, now.day)` | Today at midnight (local) |
| `sixtyDaysAgo = today - 60 days` | Start of 60-day window |
| `fetchStart` | If lastFetchDate null → sixtyDaysAgo; else max(lastFetchDate, sixtyDaysAgo) |
| `supabaseUpdated.isAfter(localLastSync)` | Timestamp merge: overwrite only when Supabase newer |
| `UserDataService.recalculateStreak()` | Recompute streak from habits_daily, persist to streaks |
| `UserDataService.ensureStreaksRecordExists()` | Create empty streaks row if missing |

---

## Read

| Name | Description | Read type |
|------|-------------|-----------|
| `SharedPreferences.getString(last_fetch_date)` | Last fetch date | offline |
| `db.query('users')` | User profile | offline |
| `db.query('user_settings')` | User settings | offline |
| `db.query('streaks')` | Streak record | offline |
| `Supabase.users.select` | User profile | online |
| `Supabase.user_settings.select` | User settings | online |
| `Supabase.streaks.select` | Streak | online |
| `Supabase.entries+joins` | Entries with related tables | online |
| `Supabase.entry_insights` | Yesterday insight | online |
| `UserDataService.fetchUserData` | Profile + stats + prefs | offline / online |
| `LocalEntryService.hasUnsyncedEntries` | Check is_synced=0 entries | offline |
| `LocalEntryService.hasSyncQueueItems` | Check sync_queue | offline |
| `LocalEntryService.getUnsyncedEntries` | Entries to push | offline |
| `LocalEntryService.getSyncQueueByEntityTypes` | Queue items to push | offline |

---

## Write

| Name | Description | Write type |
|------|-------------|------------|
| `SharedPreferences.setString(last_fetch_date)` | Store last fetch date | offline |
| `db.insert/update('users')` | User profile | offline |
| `db.insert/update('user_settings')` | User settings | offline |
| `db.insert('streaks')` | Streak record | offline |
| `EntryStorageHelper.storeEntriesWithRelatedDataWithMerge` | Entries + affirmations, meals, etc. | offline |
| `EntryInsightStorageHelper.storeYesterdayInsight` | Yesterday insight | offline |
| `EntryInsightStorageHelper.clearYesterdayInsight` | Clear yesterday insight | offline |
| `DataFetchService.storeUserProfile` | Write user to SQLite | offline |
| `DataFetchService.storeUserSettings` | Write settings to SQLite | offline |
| `UserDataService.recalculateStreak` | Recalc and persist streak | offline |
| `UserDataService.ensureStreaksRecordExists` | Insert empty streak row | offline |
| `LocalEntryService.markAsSynced` | Set is_synced=1 on entry | offline |
| `SupabaseSyncService.batchSaveEntry` | Push entry to Supabase | online |
| `SupabaseSyncService.batchUpdateStreakData` | Push streak to Supabase | online |
