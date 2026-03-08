# habits_daily Creation from Fetched Data — Fix Plan

## Reliability (short)

**High.** All fetch data is in local SQLite before this runs. One sequential step after `Future.wait`; no races. Deterministic mapping from entries → habits_daily. Single place, single responsibility.

---

## Plan

### 1. Centralized step: `ensureHabitsDailyFromEntries(userId)`

- **Where:** `DataPrefetchService` (or new `HabitsDailyBuildService`)
- **When:** Right after `Future.wait([...])` on splash, before `setLastFetchDate` / `loadUserData`
- **Input:** `userId` — reads from local SQLite only (entries already stored)

### 2. Flow

```
Splash online path:
  Future.wait([
    fetchAndMergeUserProfile,
    fetchAndMergeUserSettings,
    fetchAndMergeStreaks,
    fetchAndMergeEntriesWithJoins,
    fetchAndStoreYesterdayInsight,
  ])
  → ensureHabitsDailyFromEntries(userId)   ← NEW (centralized)
  → setLastFetchDate
  → loadUserData
```

### 3. Logic (per entry in local DB)

For each `entry` with `entry_date` in the fetched range:

| habits_daily column | Source |
|---------------------|--------|
| `wrote_entry` | `entries.diary_text` not null and not empty |
| `filled_affirmations` | row exists in `entry_affirmations` for `entry_id` |
| `filled_gratitude` | row exists in `entry_gratitude` for `entry_id` |
| `self_care_completed_count` | `entry_meals` or `entry_self_care` has content (1 if any, else 0) |
| `grace_pieces_earned` | 0.5 per completed task, max 2.0 |
| `date` | `entries.entry_date` |
| `user_id` | from entry |
| `id` | UUID (e.g. `const Uuid().v4()`) |

Use `INSERT OR REPLACE` (upsert) so local `trackTaskCompletion` changes are overwritten by fetched data for that date.

### 4. Date range

- Only build for dates we have entries for (no extra queries).
- Fetched range = `fetchStart..today` (same as `fetchAndMergeEntriesWithJoins`).

### 5. Implementation location

- **Option A:** New method in `DataPrefetchService.ensureHabitsDailyFromEntries(userId)` — keeps prefetch logic together.
- **Option B:** New `HabitsDailyBuildService` — clearer separation if this grows.

### 6. Edge cases

| Case | Handling |
|------|----------|
| No entries fetched | No-op, return early |
| Entry has no related rows | `filled_*` = 0, `self_care_completed_count` = 0 |
| Local habits_daily already exists | Upsert overwrites (fetched = source of truth) |
| Offline path | Skip — no fetch, no build |

### 7. Files to touch

- `lib/screens/splash_screen.dart` — add `ensureHabitsDailyFromEntries` call after `Future.wait`
- `lib/services/data_prefetch_service.dart` — add `ensureHabitsDailyFromEntries` (or new service file)
