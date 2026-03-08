# Offline P1 — Execution Order & Flow Verification

**Yes, you can implement serially 1–12 in this order.** Dependencies are satisfied.

---

## 1. Dependency Graph

```
1-1 (users, user_settings tables)
  │
  ├── 1-2 (remove DataRepository) [optional dep: 1-1]
  │     │
  │     └── 1-3 (DataFetchService read from SQLite)
  │           │
  │           ├── 2-4 (Splash: online/offline, 3 fetches)
  │           │     │
  │           │     ├── 2-5 (Splash offline: useLocalOnly)
  │           │     │
  │           │     └── 2-6 (Remove last_sync_at=null) [can run before/after 2-4]
  │           │
  │           ├── 3-7 (Extend sync_queue: streak, user_profile, user_settings)
  │           │     │
  │           │     ├── 3-8 (All writes through queue)
  │           │     ├── 3-9 (SyncWorker processes all entity types)
  │           │     │
  │           │     └── 4-11 (Streak recalc → sync queue)
  │           │
  │           ├── 4-10 (Timestamp comparison for streak) [needs 1-1,1-2,1-3]
  │           │
  │           └── 4-12 (Remove instant sync) [needs 3-7,3-8,3-9,4-11]
```

---

## 2. Recommended Serial Order

| # | Plan | Prerequisites | Notes |
|---|------|---------------|-------|
| 1 | **1-1** | — | Add users, user_settings. DB v3→4. |
| 2 | **1-2** | 1-1 (optional) | Remove DataRepository, unwrap DataFetchService. |
| 3 | **1-3** | 1-1, 1-2 | DataFetchService reads local first; add _read*FromLocal, _fetch*FromSupabaseAndStore. |
| 4 | **2-6** | 1-1, 1-2, 1-3 | Remove destructive last_sync_at=null. Do before 2-4 so calculateStreakOnAppLaunch is fixed. |
| 5 | **2-4** | 1-1, 1-2, 1-3 | Splash: connectivity check, 3 fetches with timestamp merge, replace calculateStreakOnAppLaunch. |
| 6 | **2-5** | 1-1, 1-2, 1-3, 2-4 | Splash offline: useLocalOnly, no network. |
| 7 | **4-10** | 1-1, 1-2, 1-3 | Timestamp comparison in DataFetchService.fetchStreaks. |
| 8 | **3-7** | 1-1, 1-2, 1-3, 2-4–2-6 | Extend sync_queue schema; addStreakToSyncQueue. DB v4→5. |
| 9 | **3-9** | 3-7 | SyncWorker processes entries + streak + user_profile + user_settings. |
| 10 | **3-8** | 3-7 | Remove direct Supabase; all writes via queue. |
| 11 | **4-11** | 3-7, 3-9 | Streak recalc on entry save → addStreakToSyncQueue. |
| 12 | **4-12** | 3-7, 3-8, 3-9, 4-11 | Remove remaining instant sync; queue only. |

---

## 3. Flow Verification

### 3.1 Startup (Online)

```
Auth → isOnline=true → fetchAndMerge* (3 parallel) → store in SQLite (timestamp merge)
     → loadUserData (reads local) → processSyncQueue → Navigate
```

- 2-4: connectivity, 3 fetches, timestamp merge.
- 4-10: streak overwrite only when Supabase.updated_at > local.last_sync_at.
- 2-6: no last_sync_at=null.

### 3.2 Startup (Offline)

```
Auth → isOnline=false → loadUserData(useLocalOnly: true) → cleanupOldEntries
     → processSyncQueue (no-op) → Navigate
```

- 2-5: useLocalOnly prevents any Supabase calls.

### 3.3 Entry Save

```
User saves → _savePendingChangesToLocal (adds to sync_queue via LocalEntryService)
           → _batchTrackGraceTasks → _checkGapsAndRecalculateStreak
           → recalculateStreak → _persistStreak → addStreakToSyncQueue (4-11)
           → processSyncQueue (3-8, 4-12)
```

- 3-8: no batchSaveEntry; local + queue.
- 4-11: no _scheduleStreakSync; addStreakToSyncQueue.
- 4-12: no instant sync anywhere.

### 3.4 Sync (When Online)

```
processSyncQueue → entries (batchSaveEntry) → streak (batchUpdateStreakData)
                 → user_profile (syncUserProfile) → user_settings (syncUserSettings)
```

- 3-9: SyncWorker processes all entity types from queue / unsynced entries.

---

## 4. Potential Issues & Fixes

### 4.1 DB Version Bumps

- **1-1:** v3 → 4 (users, user_settings).
- **3-7:** v4 → 5 (sync_queue entity_type, entity_id).

Ensure `_onUpgrade` uses incremental `if (oldVersion < N)` blocks. Avoid logic that recreates all tables (e.g. line 69–72 in database_manager.dart) for versions ≥ 3.

### 4.2 2-4 vs 2-6 Overlap

- 2-4 may remove `calculateStreakOnAppLaunch` and use `fetchAndMergeStreaks`.
- 2-6 modifies `calculateStreakOnAppLaunch` (remove last_sync_at=null, timestamp compare).

**Fix:** Do 2-6 before 2-4. 2-6 fixes the method; 2-4 then replaces it. If 2-4 removes it entirely, 2-6’s changes are still valid for any remaining callers.

### 4.3 3-8 vs 3-9 Order

- 3-9: SyncWorker processes all types (needs addStreakToSyncQueue, addToSyncQueue from 3-7).
- 3-8: Removes direct Supabase calls from app code.

**Recommended:** 3-9 before 3-8. SyncWorker must be able to process queue before we remove direct sync. 3-8 removes callers; 3-9 ensures SyncWorker handles them.

### 4.4 EntryService Usage

EntryService has `if (online) { sync* }` in many methods. 4-12 removes these. Confirm whether EntryService is still used (vs EntryProvider). If EntryProvider is the main path, EntryService changes are safe.

---

## 5. Summary

| Question | Answer |
|----------|--------|
| Flow correct? | Yes. Local-first, queue-based sync, timestamp merge, offline support. |
| Implement serially? | Yes. Use order in Section 2. |
| Any blocking issues? | DB migration logic; 2-6 before 2-4; 3-9 before 3-8. |
