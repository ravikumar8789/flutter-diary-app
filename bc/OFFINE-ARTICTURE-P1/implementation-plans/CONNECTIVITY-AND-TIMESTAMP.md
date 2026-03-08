# Connectivity Check & Timestamp Comparison — Status & Requirements

---

## 1. Connectivity Check at Every Sync/Fetch

### Requirement
**Before any sync (push) or fetch (pull) from Supabase, check connectivity.** If offline, skip network call.

### Current State

| Location | Checks connectivity? | Notes |
|----------|---------------------|------|
| **SyncWorker.processSyncQueue** | ✅ Yes (line 55) | `if (!await _isOnline()) return;` |
| **SyncWorker.retrySync** | ✅ Yes (line 98) | `if (await _isOnline())` |
| **Splash** | ❌ No | Runs calculateStreakOnAppLaunch, loadUserData, prefetch, processSyncQueue without checking |
| **DataFetchService.fetchStreaks** | ❌ No | Fetches from Supabase directly; fails if offline |
| **DataFetchService** (other fetches) | ❌ No | Same |
| **DataPrefetchService.prefetch7DaysData** | ❌ No | No connectivity check |
| **DataPrefetchService.prefetchTodayData** | ❌ No | Same |
| **ConnectivityService** (on resume) | ✅ Yes | Triggers processSyncQueue when coming online |

### Where to Add Connectivity Check

| Location | Action | Plan |
|----------|--------|------|
| **Splash** | Check `isOnline` before any fetch. If offline → loadUserData(useLocalOnly), skip prefetch, processSyncQueue (no-op). | 2-4, 2-5 |
| **DataFetchService** (all fetch methods) | At start: if `useLocalOnly` → read local only. If not useLocalOnly but offline → read local only, skip Supabase. | 2-5 (useLocalOnly), plus add offline guard |
| **DataPrefetchService** | At start of prefetch7DaysData, prefetchTodayData: if offline → return immediately. | 2-4 |
| **processSyncQueue** | Already checks. ✅ | — |

### Implementation Note
Add `ConnectivityService.isOnline()` or `InternetAddress.lookup('google.com')` at:
- Splash: before calculateStreakOnAppLaunch, loadUserData, prefetch
- DataPrefetchService: start of prefetch methods
- DataFetchService: optional — useLocalOnly covers offline path when called from loadUserData. For direct fetches (e.g. from UI), consider adding offline guard.

---

## 2. Timestamp Comparison Before Merge/Write/Sync

### Requirement
**When merging fetched Supabase data into local:** Only overwrite when `Supabase.updated_at > local.last_sync_at` (or local empty). Never overwrite local if local is newer.

### Current State

| Location | Timestamp compare? | Logic |
|----------|--------------------|-------|
| **DataFetchService.fetchStreaks** | ❌ No | Always overwrites when Supabase returns (lines 535–562). No `Supabase.updated_at` vs `local.last_sync_at` check. |
| **UserDataService.calculateStreakOnAppLaunch** | ⚠️ Partial | Uses `local.last_sync_at == null` as "always overwrite" (destructive). No proper Supabase vs local compare. |
| **DataPrefetchService._storeEntriesWithRelatedData** | ❌ No | Always overwrites with `ConflictAlgorithm.replace`. No `Supabase.updated_at` vs `local.updated_at` per entry. |
| **DataFetchService** (users, user_settings, entries) | ❌ No | 1-3 adds local-first read; no timestamp merge when storing from Supabase. |
| **Sync (push to Supabase)** | N/A | We push local → Supabase. No merge. Timestamp is for PULL (fetch) merge only. |

### What Exists Today
- **Streak:** `is_synced == 0` → return local, don't overwrite (good). But when `is_synced == 1`, we always overwrite with Supabase — no timestamp compare.
- **Entries:** DataPrefetchService always overwrites. No per-entry `Supabase.updated_at` vs `local.updated_at`.
- **Users, user_settings:** No fetch-and-merge logic yet (1-3 adds local read; 2-4 adds fetchAndMerge with timestamp).

### Planned (Implementation Plans)

| Plan | What it adds |
|------|--------------|
| **2-6** | Remove destructive `last_sync_at = null`. Replace overwrite condition with timestamp compare in calculateStreakOnAppLaunch. |
| **2-4** | fetchAndMergeUserProfile, fetchAndMergeUserSettings, fetchAndMergeStreaks with timestamp merge. |
| **4-10** | DataFetchService.fetchStreaks: add `Supabase.updated_at` vs `local.last_sync_at` before storing. |

### To Do Later (Not Yet in Plans)
- **DataPrefetchService._storeEntriesWithRelatedData:** Per-entry timestamp compare (`Supabase.updated_at` vs `local.updated_at`) before overwrite. Currently always overwrites.
- **Users, user_settings:** 2-4 covers fetchAndMerge with timestamp. Verify when implemented.

---

## 3. Summary

| Item | Status | Action |
|------|--------|--------|
| Connectivity at sync (processSyncQueue) | ✅ Done | — |
| Connectivity at Splash | ❌ Missing | Add in 2-4, 2-5 |
| Connectivity at prefetch | ❌ Missing | Add in 2-4 |
| Connectivity at DataFetchService fetch | ❌ Missing | useLocalOnly in 2-5 covers loadUserData path |
| Timestamp: fetchStreaks | ❌ Missing | Add in 4-10 |
| Timestamp: calculateStreakOnAppLaunch | ⚠️ Destructive | Fix in 2-6 |
| Timestamp: fetchAndMerge (users, settings, streak) | 📋 Planned | 2-4 |
| Timestamp: DataPrefetchService entries | ❌ Missing | **Do later** — add per-entry compare before overwrite |
