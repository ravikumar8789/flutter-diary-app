# Streak — Simplify Read/Write Flow

## Final Flow

```
App load (Splash, online) → fetchAndMergeStreaks → populate local streaks table
                              ↓
Everything inside app → read/write LOCAL streaks table only
                              ↓
Sync queue (background) → push local changes to Supabase when online
```

---

## Rules

1. **Populate local:** Only splash screen fetches streak from Supabase and writes to local (when online).
2. **Inside app:** All reads and writes use local `streaks` table only.
3. **Sync:** Local → Supabase via sync queue (existing flow). Multi-device sync to be redesigned later.

---

## Removed (this pass)

| Item | File | Reason |
|------|------|--------|
| `fetchAndMergeStreaks` from home prefetch | home_screen.dart | Streak fetch only on splash |
| `_fetchStreaksRemoved` | data_prefetch_service.dart | Dead code; streak populated on splash only |
| `calculateStreakOnAppLaunch` | user_data_service.dart | Dead code, never called; removed entirely |
| `syncStreak` | supabase_sync_service.dart | Replaced by batchUpdateStreakData (sync queue) |
| `fetchStreaks` | data_fetch_service.dart | Unused; splash uses fetchStreaksFromSupabaseOnly |
| `_mapLocalStreakRowToResponse` | data_fetch_service.dart | Only used by removed fetchStreaks |
| `_isSupabaseNewer` | data_fetch_service.dart | Unused; was used by removed fetchStreaks |
| `UserDataService` import | data_fetch_service.dart | Unused after fetchStreaks removal |

---

## Kept

| Item | Purpose |
|------|---------|
| `fetchAndMergeStreaks` on splash | Populate local streak when app loads (online) |
| All local read/write | HomeSummaryService, StreakNotifier, GraceSystemService, UserDataService |
| `addStreakToSyncQueue` | Enqueue when local streak changes (is_synced=0) |
| Sync worker streak processing | Push local streak to Supabase via batchUpdateStreakData |

---

## Later (redesign)

- Multi-device sync
- Streak calculation across devices
