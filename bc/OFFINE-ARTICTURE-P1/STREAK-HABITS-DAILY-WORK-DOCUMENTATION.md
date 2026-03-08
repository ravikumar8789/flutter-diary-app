# Streak & habits_daily — Full Work Documentation

> Complete step-by-step record from offline structure to current state.  
> Last updated: 2025-02-26

---

## Step 1: Offline Structure (Base Plan)

**Source:** `bc/OFFINE-ARTICTURE-P1/DISCUSSION/base-plan.md`, `plan1.md`

- **Local-first:** Everything on Supabase → store locally too. Write locally first → sync when online.
- **SQLite:** `users`, `user_settings`, `entries`, `streaks`, `habits_daily`, `sync_queue`.
- **Startup online:** 3 parallel calls (profile+settings, entries, streak) → store in SQLite.
- **Startup offline:** Read local only.
- **Streak:** No calc on startup. Calculate on entry save → store local → add to sync queue.

---

## Step 2: Initial Problem — Streak Not Syncing After Manual Supabase Update

**What we saw:**
- User manually updated today's entry in Supabase and set `last_entry_date` to 26.
- Today is 27. User opens app, writes more, sync runs.
- Entry details sync correctly.
- Streak does not increase.
- `last_entry_date` in Supabase stays 26 (not updated to 27).

**Where:** Splash fetch → entry save → sync queue → streak not persisted.

---

## Step 3: Root Cause — habits_daily Never Populated from Fetch

**What we found:**
- `habits_daily` is local-only (removed from Supabase).
- `habits_daily` is only populated by `trackTaskCompletion` when user saves diary/affirmations/gratitude/self_care.
- When we fetch entries from Supabase, `storeEntriesWithRelatedData` stores entries + related tables but does NOT create `habits_daily` rows.
- If user only changes mood/tags, `trackTaskCompletion` never runs → `habits_daily` for today stays empty.
- `calculateStreakWithGrace` checks `completedToday` from `habits_daily` for today. Empty → `completedToday = false`.
- Falls into gap logic, uses grace, never calls `_persistStreak` with `lastEntryIso: "27"`.

**Files:** `entry_storage_helper.dart`, `grace_system_service.dart`, `user_data_service.dart`, `entry_provider.dart`.

---

## Step 4: Streak Architecture Plan (final.md)

**Plan:** Clean streak architecture with timestamp merge and gap logic.

| Phase | Change |
|-------|--------|
| Phase 1 | Fix timestamp merge in `fetchAndMergeStreaks` — use `local.updated_at` when `is_synced == 0` |
| Phase 2 | Replace `recalculateStreak` with `applyGapIfNeeded` on splash path |
| Phase 3 | Keep `recalculateStreak` for local write path |
| Phase 4 | `_fetchUserStats` use `streaks.last_entry_date` instead of habits_daily |
| Phase 5 | `ensureStreaksRecordExists` when Supabase null |

**Files:** `data_prefetch_service.dart`, `user_data_service.dart`.

---

## Step 5: applyGapIfNeeded — daysDiff == 1 Bug (final2.md)

**Bug:** `applyGapIfNeeded` treated `daysDiff == 1` (last_entry_date = yesterday) as a gap and reset streak to 0.

**Fix:** Skip gap logic when `daysDiff == 1`. Yesterday as last_entry_date means user wrote yesterday; they can still write today.

```dart
if (daysDiff == 1) return;
```

**File:** `user_data_service.dart` — `applyGapIfNeeded`.

---

## Step 6: habits_daily Creation Plan (habit-daily-creation-plan.md)

**Goal:** Populate `habits_daily` from fetched entries so `completedToday` is correct after fetch.

**Approach:**
- Add `ensureHabitsDailyFromEntries(userId)` in `DataPrefetchService`.
- Run after `Future.wait` on splash, before `setLastFetchDate`.
- Read from local SQLite (entries already stored).
- Map entries → habits_daily: `wrote_entry`, `filled_affirmations`, `filled_gratitude`, `self_care_completed_count`, `grace_pieces_earned`.

**Mapping:**
| habits_daily column | Source |
|--------------------|--------|
| wrote_entry | entries.diary_text not empty |
| filled_affirmations | row exists in entry_affirmations |
| filled_gratitude | row exists in entry_gratitude |
| self_care_completed_count | entry_meals or entry_self_care has content (1/0) |

---

## Step 7: Implementation — Option A

**Choice:** Add `ensureHabitsDailyFromEntries` in `DataPrefetchService` (Option A).

**Changes:**
1. `lib/services/data_prefetch_service.dart` — added `ensureHabitsDailyFromEntries(userId)`.
2. `lib/screens/splash_screen.dart` — call after `Future.wait`, before `setLastFetchDate`.

**Logic:** For each entry in local DB, query related tables, compute flags (0/1), upsert into `habits_daily` with `ConflictAlgorithm.replace`.

---

## Step 8: Scope Issue — 50 Rows Instead of Today Only

**What we saw:**
- Debug sheet showed `habits_daily` has 50 rows.
- Original design: `habits_daily` is one row per day, created only when user saves via `trackTaskCompletion`.

**User feedback:**
- Implementation built habits_daily for ALL entries (50 rows).
- Should only update for **today's** data.
- `filled_*` as 0/1 (already correct).

---

## Step 9: Justification for "Only Today"

**Original design:**
- `trackTaskCompletion` creates/updates one row per date when user saves.
- Incremental per day, not from fetch.

**Correct fix:**
1. Only build today's habits_daily from today's fetched entry.
2. Don't overwrite historical habits_daily (from trackTaskCompletion).
3. Fixes the bug: today's row present → `completedToday` correct.
4. Simpler: one row per fetch.

**Trade-off:** `calculateStreakWithGrace` uses `lastHabit` from habits_daily for `lastEntryDate`. If only today built and user didn't write today, `lastHabit` can be empty. Mitigation: fallback to `streaks.last_entry_date` when `lastHabit` empty.

---

## Step 10: Where We Decided to Stop

**Location:** `lib/services/data_prefetch_service.dart` — `ensureHabitsDailyFromEntries`.

**Current state:**
- Implementation builds habits_daily for **all entries** (e.g. 50 rows).
- User requested scope change to **today only**.
- Change not yet applied.

**What we see:**
- habits_daily has 50 rows (one per entry in local DB).
- Original design expects one row per day, created on save.
- Plan says "only today" — need to restrict to `entry_date == today`.

**Decision:** Stop here for today. Next session: restrict `ensureHabitsDailyFromEntries` to today's entry only; add `streaks.last_entry_date` fallback in `calculateStreakWithGrace` when `lastHabit` empty.

---

## Step 11: Last Issue — Open Item

**Issue:** habits_daily scope too broad (all entries vs today only).

**Root cause:** Implementation followed "for each entry in fetched range" literally; plan was ambiguous. User clarified: only today.

**Resolution:** Pending. Change `ensureHabitsDailyFromEntries` to:
1. Query only today's entry (`entry_date = today`).
2. Build/upsert one habits_daily row for today.
3. Optionally: add `streaks.last_entry_date` fallback in `calculateStreakWithGrace`.

---

## Reference: Key Files

| File | Role |
|------|------|
| `lib/services/data_prefetch_service.dart` | fetchAndMergeStreaks, ensureHabitsDailyFromEntries |
| `lib/services/user_data_service.dart` | applyGapIfNeeded, calculateStreakWithGrace, _persistStreak |
| `lib/services/grace_system_service.dart` | trackTaskCompletion, habits_daily create/update |
| `lib/providers/entry_provider.dart` | _batchTrackGraceTasks, _checkGapsAndRecalculateStreak |
| `lib/screens/splash_screen.dart` | Future.wait, ensureHabitsDailyFromEntries call |
| `lib/services/entry_storage_helper.dart` | storeEntriesWithRelatedData (no habits_daily) |

---

## Reference: Directory Structure

```
bc/OFFINE-ARTICTURE-P1/
├── STREAK-HABITS-DAILY-WORK-DOCUMENTATION.md  (this file)
├── startup-flow.mmd
├── simplify-after-local-first/
│   ├── streak-fetaure/
│   │   ├── final.md              (Phase 1–5 plan)
│   │   ├── final2.md              (daysDiff == 1 fix)
│   │   ├── habit-daily-creation-plan.md
│   │   ├── habits-daliy-full-local.md
│   │   ├── streal-local-only.md
│   │   ├── simplify-read-write.md
│   │   └── fetchall-nonblocking.md
│   ├── splash-screen-work/
│   │   ├── splash-fetch-prefetch-merge.md
│   │   └── splash-screen-work-list.md
│   └── home-screen/
│       └── prefetch-update.md
```
