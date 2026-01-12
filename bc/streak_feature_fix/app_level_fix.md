# App-Level Fix Plan - Streak & Grace System

## What Needs to be Fixed

### 1. **trackTaskCompletion()** - Remove Trigger Dependency
**Current:** Relies on DB trigger, has fallback if trigger fails
**Fix:** Always calculate pieces in app, update `habits_daily` + `streaks` directly

### 2. **getGraceStatus()** - Replace DB Function
**Current:** Calls `calculate_grace_days_from_habits()` DB function
**Fix:** Use simple query to sum pieces, calculate grace days in app

### 3. **_calculateStreak()** - Use entry_date (BUG)
**Current:** Uses `created_at` timestamp (wrong field)
**Fix:** Use `entry_date` field for accurate streak calculation

### 4. **Streak Recalculation** - Missing on Entry Save
**Current:** Only recalculates on user data load
**Fix:** Recalculate streak when entry is saved/updated

### 5. **calculateStreakWithGrace()** - Replace DB Function
**Current:** Calls DB function for grace days
**Fix:** Use app-level grace status calculation

---

## Flow After Fix

### Task Completion Flow
```
User completes task (diary/affirmations/gratitude/self-care)
    ↓
trackTaskCompletion() called
    ↓
1. Get/create habits_daily record for today
2. Update task completion flag
3. Calculate pieces: 0.5 × completed_tasks
4. Update habits_daily.grace_pieces_earned
5. Sum all pieces from habits_daily
6. Calculate grace days: floor(total_pieces / 10) max 5
7. Update streaks.grace_pieces_total
8. Update streaks.freeze_credits
```

### Streak Calculation Flow
```
Entry saved/updated
    ↓
Recalculate streak:
1. Fetch entries with entry_date (not created_at)
2. Sort by entry_date (newest first)
3. Count consecutive days from today backwards
4. Check if user wrote today (habits_daily.wrote_entry)
    ↓
If wrote today:
    → Calculate normal streak
    → Update streaks.current, longest, last_entry_date
    ↓
If didn't write today:
    → Check days since last entry
    → If 1 day missed + grace days available:
        → Auto-use grace day
        → Maintain current streak
    → If multiple days missed:
        → Use multiple grace days if available
        → Or reset streak to 0
```

### Grace Status Flow
```
getGraceStatus() called
    ↓
1. Query habits_daily for today's record
2. Calculate pieces_today from task flags
3. Query all habits_daily records
4. Sum all grace_pieces_earned
5. Calculate grace_days: floor(total / 10) max 5
6. Return status with progress percentage
```

---

## Timezone Handling

**Current:** ✅ Already handled correctly
- App uses `DateTime.now()` (local timezone)
- Dates stored as strings: `YYYY-MM-DD` format
- `entry_date` field is date-only (no timezone issues)
- `habits_daily.date` is date-only

**No changes needed** - timezone is app-level, not DB-level

---

## Files to Modify

1. **lib/services/grace_system_service.dart**
   - `trackTaskCompletion()` - Remove trigger check, always calculate
   - `getGraceStatus()` - Replace DB function with query

2. **lib/services/user_data_service.dart**
   - `_calculateStreak()` - Use `entry_date` instead of `created_at`
   - `_fetchUserStats()` - Use `entry_date` in query
   - Add streak recalculation helper

3. **lib/providers/entry_provider.dart**
   - Add streak recalculation after entry save

4. **lib/services/entry_service.dart** (if needed)
   - Trigger streak recalculation on save

---

## Key Changes Summary

**trackTaskCompletion():**
- Remove lines 102-110 (trigger verification)
- Always calculate pieces (not as fallback)
- Always update streaks table

**getGraceStatus():**
- Remove `.rpc('calculate_grace_days_from_habits')`
- Use simple `.from('habits_daily').select()` query
- Calculate in app

**_calculateStreak():**
- Change `entry['created_at']` → `entry['entry_date']`
- Update query to select `entry_date` field

**Streak Recalculation:**
- Call after entry save in `entry_provider.dart`
- Use `calculateStreakWithGrace()` method

---

## Testing Checklist

- [ ] Task completion updates pieces correctly
- [ ] Grace days calculate correctly (10 pieces = 1 day)
- [ ] Streak uses entry_date (not created_at)
- [ ] Streak recalculates on entry save
- [ ] Grace days auto-use on missed day
- [ ] Visual progress indicator shows correct data

