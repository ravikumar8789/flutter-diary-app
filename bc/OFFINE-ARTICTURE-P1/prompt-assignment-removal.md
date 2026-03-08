# Prompt Assignment & Prompts — Full Cleanup Plan

**Goal:** Remove all app code that fetches from `prompt_assignments` and `prompts` tables.  
**Scope:** App code only. Database tables remain unchanged.

---

## 1. Summary

| Item | Action |
|------|--------|
| Supabase calls removed | 2 per home load (`prompt_assignments`, `prompts`) |
| UI impact | None (prompt data never displayed) |
| Offline benefit | Eliminates ERRSYS155, ERRDATA206, ERRDATA228 errors when offline |

---

## 2. Files to Modify

| File | Changes |
|------|----------|
| `lib/services/home_summary_service.dart` | Remove `_fetchPromptMotivation`, simplify `fetchAll` |
| `lib/models/home_summary_models.dart` | Remove `PromptMotivationSummary`, remove `prompt` from `HomeSummary` |
| `lib/models/utility_models.dart` | Remove `Prompt` and `PromptAssignment` classes (optional) |

---

## 3. Step-by-Step Plan

### Step 3.1 — `lib/services/home_summary_service.dart`

**3.1.1** In `fetchAll`, change `Future.wait` from 4 to 3 items:

```dart
// BEFORE
final results = await Future.wait([
  _fetchStreak(userId),
  _fetchTodayProgress(userId, now),
  _fetchWeeklySnapshot(userId, thisWeekStart, prevWeekStart),
  _fetchPromptMotivation(userId),
]);

return HomeSummary(
  streak: results[0] as StreakSummary?,
  today: results[1] as TodayProgressSummary?,
  weekly: results[2] as WeeklySnapshotSummary?,
  prompt: results[3] as PromptMotivationSummary?,
);

// AFTER
final results = await Future.wait([
  _fetchStreak(userId),
  _fetchTodayProgress(userId, now),
  _fetchWeeklySnapshot(userId, thisWeekStart, prevWeekStart),
]);

return HomeSummary(
  streak: results[0] as StreakSummary?,
  today: results[1] as TodayProgressSummary?,
  weekly: results[2] as WeeklySnapshotSummary?,
);
```

**3.1.2** Delete the entire `_fetchPromptMotivation` method (lines ~364–452).

---

### Step 3.2 — `lib/models/home_summary_models.dart`

**3.2.1** Remove `PromptMotivationSummary` class (lines 59–68).

**3.2.2** Update `HomeSummary` — remove `prompt` field and `PromptMotivationSummary`:

```dart
class HomeSummary {
  final StreakSummary? streak;
  final TodayProgressSummary? today;
  final WeeklySnapshotSummary? weekly;
  const HomeSummary({
    this.streak,
    this.today,
    this.weekly,
  });
}
```

**3.2.3** Confirm no usages of `summary.prompt` in codebase (currently none).

---

### Step 3.3 — `lib/models/utility_models.dart` (optional)

**3.3.1** Remove `Prompt` class (lines 3–38).

**3.3.2** Remove `PromptAssignment` class (lines 40–76).

**Note:** Ensure no other file imports or uses these. Current grep shows they are unused.

---

## 4. Verification Checklist

- [ ] `flutter analyze` passes
- [ ] Home screen loads without errors (online)
- [ ] Home screen loads without errors (offline)
- [ ] No `prompt_assignments` or `prompts` in codebase (except this plan)
- [ ] No ERRSYS155, ERRDATA206, ERRDATA228 in logs when offline

---

## 5. Execution Order

1. Modify `home_summary_service.dart` (remove fetch, delete `_fetchPromptMotivation`)
2. Modify `home_summary_models.dart` (remove `PromptMotivationSummary`, remove `prompt` from `HomeSummary`)
3. Optionally remove `Prompt` and `PromptAssignment` from `utility_models.dart`
4. Run `flutter analyze` and manual test

---

## 6. Rollback

If needed: revert changes and restore `_fetchPromptMotivation` + `PromptMotivationSummary`. Tables are unchanged, so no DB rollback.
