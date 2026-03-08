# Streak Feature — Clean Architecture Plan

## Target Architecture

| Event | Action |
|-------|--------|
| **Splash (online)** | Fetch streak from Supabase → skip overwrite when local newer → overwrite when Supabase newer → apply gap logic if `last_entry_date` < today |
| **Splash (offline)** | Use local streak cache (no fetch) |
| **Local write** | User saves → `recalculateStreak` → `_persistStreak` → add to sync queue |
| **New user / empty local** | Supabase is truth → insert Supabase data (or create empty row) |
| **Display** | All screens read from local `streaks` table |

---

## Phase 1: Fix Timestamp Merge (Local Newer)

### Current Bug
- Uses `local.last_sync_at` for comparison. When local has `is_synced = 0`, `last_sync_at` is null → we overwrite even when local is newer.

### Change
**File:** `lib/services/data_prefetch_service.dart` — `fetchAndMergeStreaks`

| Condition | Action |
|-----------|--------|
| Local empty | Take Supabase (insert) or `ensureStreaksRecordExists` if Supabase null |
| Local has row, `is_synced == 0` | Use `local.updated_at`. If `supabase.updated_at <= local.updated_at` → skip |
| Local has row, `is_synced == 1` | Use `local.last_sync_at`. If `supabase.updated_at <= local.last_sync_at` → skip |

**Logic:**
```dart
// Only when local has row and Supabase has updated_at:
if (localRows.isNotEmpty && supabaseUpdated != null) {
  final isSynced = (localRows.first['is_synced'] as int? ?? 1) == 1;
  final localCompare = isSynced
      ? (localRows.first['last_sync_at'] as String?)
      : (localRows.first['updated_at'] as String?);
  // If local unsynced and no updated_at, skip (don't overwrite unsynced)
  if (localCompare == null && !isSynced) return;
  if (localCompare != null &&
      !DateTime.parse(supabaseUpdated).isAfter(DateTime.parse(localCompare))) {
    return; // skip overwrite
  }
}
```

---

## Phase 2: Replace recalculateStreak with applyGapIfNeeded (Splash Path)

### Current
- After overwrite: `UserDataService.recalculateStreak(userId)` → uses `habits_daily` → wrong on multi-device.

### Change
**File:** `lib/services/data_prefetch_service.dart` — `fetchAndMergeStreaks`

- Remove: `await UserDataService.recalculateStreak(userId);`
- Add: `await UserDataService.applyGapIfNeeded(userId);`

**New function:** `UserDataService.applyGapIfNeeded(String userId)`

- Reads only from `streaks` table: `last_entry_date`, `freeze_credits`, `current`
- If `last_entry_date` is null or `>= today` → return (no gap)
- If `last_entry_date` < today → compute `daysDiff`
  - `daysDiff == 1`: use 1 grace or reset to 0
  - `daysDiff > 1`: use `(daysDiff - 1)` grace or reset to 0
- Updates `streaks` (current, last_entry_date, freeze_credits, updated_at, is_synced=0)
- Calls `addStreakToSyncQueue(userId)` if changed

**Location:** `lib/services/user_data_service.dart`

---

## Phase 3: Keep recalculateStreak for Local Write Path

### No change
- `entry_provider` → `_checkGapsAndRecalculateStreak` → `recalculateStreak` → `calculateStreakWithGrace`
- `calculateStreakWithGrace` uses `habits_daily` — correct when user writes locally (habits_daily is updated by `trackTaskCompletion`)

### Flow
1. User saves entry → `_batchTrackGraceTasks` (updates habits_daily)
2. `_checkGapsAndRecalculateStreak` → `recalculateStreak` → `calculateStreakWithGrace`
3. `_persistStreak` → `addStreakToSyncQueue`

---

## Phase 4: _fetchUserStats — Use streaks.last_entry_date

### Current
- `last_entry_date` from `habits_daily` (most recent date with activity)

### Change
**File:** `lib/services/user_data_service.dart` — `_fetchUserStats`

- Use `streaks.last_entry_date` instead of querying `habits_daily`
- If streaks empty, use null

**Reason:** Single source of truth for streak-related display; avoids habits_daily for stats.

---

## Phase 5: ensureStreaksRecordExists When Supabase Null

### Current
- `response == null` → `ensureStreaksRecordExists(userId)` ✓

### No change
- Already correct for new user / Supabase empty.

---

## Code to Remove (Unused / Redundant)

| Item | File | Reason |
|------|------|--------|
| None | — | No full removal; only replace `recalculateStreak` with `applyGapIfNeeded` in splash path |

---

## Code to Add

| Item | File | Description |
|------|------|-------------|
| `applyGapIfNeeded(userId)` | `user_data_service.dart` | Gap logic using only `streaks` table |

---

## Code to Modify

| File | Change |
|------|--------|
| `data_prefetch_service.dart` | Fix timestamp merge (local.updated_at when is_synced=0); replace `recalculateStreak` with `applyGapIfNeeded` |
| `user_data_service.dart` | Add `applyGapIfNeeded`; in `_fetchUserStats` use `streaks.last_entry_date` instead of habits_daily |

---

## What Stays Unchanged

| Component | Reason |
|-----------|--------|
| `calculateStreakWithGrace` | Used only on local write path; habits_daily is correct there |
| `_calculateStreakFromTodayHabits` | Used by `calculateStreakWithGrace` |
| `_persistStreak` | Used by both paths |
| `_useGraceDayForStreak` | Used by both `calculateStreakWithGrace` and `applyGapIfNeeded` |
| `entry_provider._checkGapsAndRecalculateStreak` | Local write path; keep as is |
| `streak_provider` | Reads from local; no change |
| `SyncWorker` (streak sync) | No change |
| `GraceSystemService` | No change |
| `habits_daily` table | Still used for grace tracking, today progress, local write streak calc |

---

## Summary Checklist

- [x] Phase 1: Fix timestamp merge in `fetchAndMergeStreaks`
- [x] Phase 2: Add `applyGapIfNeeded`, use it instead of `recalculateStreak` in `fetchAndMergeStreaks`
- [x] Phase 3: Confirm local write path unchanged
- [x] Phase 4: `_fetchUserStats` use `streaks.last_entry_date`
- [x] Phase 5: Confirm `ensureStreaksRecordExists` when Supabase null

---

## Call Sites (No Removal)

| Caller | Function | Keep? |
|--------|----------|-------|
| Splash | `fetchAndMergeStreaks` | Yes (modified) |
| Home (post-login prefetch) | `fetchAndMergeStreaks` | Yes |
| entry_provider | `recalculateStreak` | Yes |
| streak_provider | `recalculateStreak` | Yes (via `recalculate()`) |
