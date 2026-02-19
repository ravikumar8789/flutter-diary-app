# Streak Miscalculation After Reset - Implementation Plan

## Executive Summary

**Problem:** Streak stays at 0 in Supabase when user writes (new users or after manual reset). Also, `today_date` changes to today on app open even when user does nothing.

**Root Causes:**
1. **fetchStreaks** overwrites local streak with Supabase when cache is invalidated, even when local has unsynced changes (`is_synced=0`). Sync is debounced 3s, so Supabase is stale.
2. **calculateStreakOnAppLaunch** treats `today_date == null` as "new day" and resets + pushes to Supabase on every app open.

**Principle:** Minimal changes. No flow changes. No impact on other features.

---

## Fix 1: fetchStreaks - Respect Unsynced Local Data

### File
`lib/services/data_fetch_service.dart`

### Location
Inside `fetchStreaks` fetcher, right after `if (localStreak.isNotEmpty)` block starts (around line 442).

### Change
Add **first-priority check**: If local has unsynced changes, return local immediately. Do NOT fetch from Supabase or overwrite.

### Implementation

```dart
if (localStreak.isNotEmpty) {
  final streak = localStreak.first;

  // CRITICAL: If local has unsynced changes, do NOT overwrite with Supabase
  // (Supabase may be stale; sync is debounced 3s)
  final isSynced = (streak['is_synced'] as int? ?? 0) == 1;
  if (!isSynced) {
    return {
      'user_id': streak['user_id'],
      'current': streak['current'],
      'longest': streak['longest'],
      'last_entry_date': streak['last_entry_date'],
      'freeze_credits': streak['freeze_credits'],
      'grace_pieces_total': streak['grace_pieces_total'],
      'updated_at': streak['updated_at'],
      'today_date': streak['today_date'],
      'today_diary': streak['today_diary'],
      'today_affirmations': streak['today_affirmations'],
      'today_gratitude': streak['today_gratitude'],
      'today_self_care_count': streak['today_self_care_count'],
      'today_grace_pieces': streak['today_grace_pieces'],
    };
  }

  // ... rest of existing logic (dateChanged, lastSyncAt, etc.)
}
```

### Order of Checks (unchanged for synced records)
1. **NEW:** `is_synced == 0` → return local (no fetch)
2. `dateChanged` → fall through to fetch
3. `!dateChanged` + `lastSyncAt` within 15 min → return local
4. Otherwise → fetch from Supabase

### Edge Cases Handled
| Case | Before | After |
|------|--------|-------|
| New user writes, fetchStreaks runs before sync | Overwrites local 1 with Supabase 0 | Returns local 1 |
| Reset user writes, fetchStreaks runs before sync | Overwrites local 1 with Supabase 0 | Returns local 1 |
| Synced record, lastSyncAt within 15 min | Returns local | Same |
| Synced record, date changed | Fetches Supabase | Same |
| Empty local | Fetches Supabase | Same |

### Impact
- **Streak calculation:** Fixed
- **Grace system:** No change (reads from local)
- **Home summary:** No change (gets correct local data)
- **Multi-device:** Improved (local pending changes preserved)

---

## Fix 2: calculateStreakOnAppLaunch - Don't Treat Null as New Day

### File
`lib/services/user_data_service.dart`

### Location
Line 1018, inside `calculateStreakOnAppLaunch`.

### Change
Only treat as "new day" when `streakTodayDate` is a **non-null date** that differs from today. When `streakTodayDate` is null, go to else branch (same-day logic).

### Implementation

```dart
// 4. Check if today_date matches today
final streakTodayDate = supabaseStreak['today_date'] as String?;
// Only reset when we have a previous date AND it's a different calendar day.
// Null = not yet set (new user / no activity) → don't overwrite on app open.
final isNewDay = streakTodayDate != null && streakTodayDate != todayDateStr;
print(
  '🔥 STREAK DEBUG: Streak today_date: $streakTodayDate, App today: $todayDateStr, isNewDay: $isNewDay',
);
```

### Edge Cases Handled
| streakTodayDate | todayDateStr | isNewDay | Action |
|-----------------|--------------|----------|--------|
| null | "2026-02-20" | false | Else branch: create habits_daily for today (empty), no Supabase push |
| "2026-02-19" | "2026-02-20" | true | Reset + push (midnight rollover) |
| "2026-02-20" | "2026-02-20" | false | Same day, populate habits_daily |
| "2026-02-18" | "2026-02-20" | true | Reset + push (multi-day gap) |

### Impact
- **today_date on app open:** Fixed (no change when null)
- **Midnight rollover:** No change (still resets correctly)
- **New user:** No change (else branch creates empty habits_daily)
- **GraceSystemService:** Already uses same null check (line 193) — aligned

---

## Edge Case Matrix (Full Simulation)

| # | Scenario | Fix 1 | Fix 2 | Result |
|---|----------|-------|-------|--------|
| 1 | New user, first write | Return local 1 | N/A | Streak increments ✓ |
| 2 | Reset user, writes | Return local 1 | N/A | Streak increments ✓ |
| 3 | App open, today_date null | N/A | No reset, no push | today_date unchanged ✓ |
| 4 | Midnight (yesterday→today) | N/A | Reset + push | Correct rollover ✓ |
| 5 | Same day, user wrote | Return local if unsynced | Same day branch | No regression ✓ |
| 6 | Multi-device, A opens, B wrote | Preserve local | N/A | Safer ✓ |
| 7 | Sync failure, today_date null, local has data | Return local | No reset | Data preserved ✓ |

---

## Features Verified (No Impact)

| Feature | Verification |
|---------|--------------|
| Streak calculation | Uses habits_daily + streaks; both fixes preserve correct data |
| Grace system | trackTaskCompletion sets today_date; GraceSystemService has same null check |
| Home summary | Reads from fetchStreaks / local; gets correct data |
| Week card | Uses habits_daily; no change |
| Notifications | Uses habits_daily; no change |
| Gap handling | Step 5 in calculateStreakOnAppLaunch unchanged |
| recalculateStreak | Unchanged |
| trackTaskCompletion | Unchanged |

---

## Implementation Order

1. **Fix 1** (data_fetch_service.dart) — prevents overwrite
2. **Fix 2** (user_data_service.dart) — prevents today_date change on open

Both are independent. Can be done in either order.

---

## Testing Checklist

### Fix 1
- [ ] New user: write first entry → streak shows 1 locally and in Supabase after sync
- [ ] Reset user: set streak to 0 in Supabase → write entry → streak shows 1
- [ ] Normal user: write entry → navigate to home quickly → streak correct
- [ ] Synced user: open app → streak unchanged (no regression)

### Fix 2
- [ ] New user: open app only → today_date in Supabase unchanged (or null)
- [ ] User wrote yesterday: open app → today_date not overwritten to today
- [ ] Midnight: open app next day → today_date resets to today (correct)
- [ ] Same day: open app → no change

### Regression
- [ ] Streak display on home
- [ ] Grace days / pieces
- [ ] Week card
- [ ] Notifications
- [ ] Multi-device sync (basic)

---

## Rollback

Both fixes are single-line or small block changes. Revert by:
1. Remove `is_synced` check block in fetchStreaks
2. Revert `isNewDay` to `streakTodayDate != todayDateStr`

---

## Files Changed

| File | Change |
|------|--------|
| `lib/services/data_fetch_service.dart` | Add is_synced check before fetch (≈15 lines) |
| `lib/services/user_data_service.dart` | Change isNewDay condition (1 line) |

---

## Implementation Status

- [x] **Fix 1** applied in `lib/services/data_fetch_service.dart`
- [x] **Fix 2** applied in `lib/services/user_data_service.dart`

---

## Notes

- No DB schema changes
- No provider changes
- No new dependencies
- Aligns with GraceSystemService null handling (grace_system_service.dart:193)
