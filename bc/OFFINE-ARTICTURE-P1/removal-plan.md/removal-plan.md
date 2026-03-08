# Removal Plan — Local-First Cleanup

## Category 1: SupabaseSyncService — Legacy per-entity sync methods (unused)

**File:** `lib/services/sync/supabase_sync_service.dart`

| Method | Lines |
|--------|-------|
| `syncAffirmations` | 48–77 |
| `syncPriorities` | 79–106 |
| `syncMeals` | 108–128 |
| `syncGratitude` | 130–158 |
| `syncSelfCare` | 161–184 |
| `syncShowerBath` | 186–209 |
| `syncTomorrowNotes` | 211–239 |

**Related:** None (no callers).

---

## Category 2: SupabaseSyncService — syncEntry + SyncWorker.retrySync (unused pair)

**File:** `lib/services/sync/supabase_sync_service.dart`
- `syncEntry` — lines 13–36

**File:** `lib/services/sync/sync_worker.dart`
- `retrySync` — lines 154–176

**Related:** `retrySync` calls `syncEntry`; no other callers.

---

## Category 3: SyncWorker — Unused periodic sync

**File:** `lib/services/sync/sync_worker.dart`

| Method | Lines |
|--------|-------|
| `startPeriodicSync` | 178–183 |
| `stopPeriodicSync` | 185–187 |

**Related:** None (never invoked).

---

## Category 4: EntryService — Duplicate _isOnline

**File:** `lib/services/entry_service.dart`

| Item | Lines |
|------|-------|
| `_connectivity` field | 13 |
| `_isOnline` method | 15–37 |
| `dart:io` import | 1 |
| `connectivity_plus` import | 3 |

**Replace with:** `ConnectivityService().isOnline()` (add `connectivity_service.dart` import).

**Related:** `loadEntryForDate` calls `_isOnline()` at line 49 — change to `ConnectivityService().isOnline()`.

---

## Category 5: SupabaseSyncService — Debug prints

**File:** `lib/services/sync/supabase_sync_service.dart`

| Line | Content |
|------|---------|
| 821 | `print('🔥 STREAK DEBUG: RPC call successful...')` |
| 833 | `print('🔥 STREAK DEBUG: Streaks marked as synced')` |
| 837 | `print('🔥 STREAK DEBUG: Marking ${habitsData.length} habits...')` |
| 850 | `print('🔥 STREAK DEBUG: batchUpdateStreakData END - success')` |
| 853 | `print('🔥 STREAK DEBUG: RPC call failed...')` |

---

## Summary

| Category | Files | Lines removed (approx) |
|----------|-------|------------------------|
| 1. Legacy sync methods | supabase_sync_service.dart | ~188 |
| 2. syncEntry + retrySync | supabase_sync_service.dart, sync_worker.dart | ~46 |
| 3. Periodic sync | sync_worker.dart | ~9 |
| 4. _isOnline consolidation | entry_service.dart | ~24 (net) |
| 5. Debug prints | supabase_sync_service.dart | ~5 |
| **Total** | | **~272** |
