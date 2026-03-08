# Streak Fix — daysDiff == 1

## Bug
`applyGapIfNeeded` treated `daysDiff == 1` (last_entry_date = yesterday) as a gap and reset streak to 0. That overwrote a valid streak (e.g. Supabase had 1) and synced 0.

## Fix
Skip gap logic when `daysDiff == 1`. Yesterday as last_entry_date means the user wrote yesterday; they can still write today.

```dart
if (daysDiff == 1) return; // last_entry_date = yesterday; user can still write today
```

## Result
- Splash: streak 1 from Supabase is kept.
- User writes today → `recalculateStreak` → `currentStreak + 1` → streak 2, syncs correctly.
