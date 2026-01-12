# Remove DB Triggers & Functions - Step by Step Guide

## Overview
Remove database triggers and functions for grace/streak system. Move all logic to app-level.

---

## Step 1: Remove Database Trigger

### Drop the trigger on `habits_daily` table

```sql
DROP TRIGGER IF EXISTS trigger_update_grace_pieces ON public.habits_daily;
```

**What this does:**
- Removes automatic grace pieces calculation when `habits_daily` is updated
- App will now calculate pieces manually

---

## Step 2: Remove Database Functions

### Drop `update_grace_pieces_on_task_completion()` function

```sql
DROP FUNCTION IF EXISTS update_grace_pieces_on_task_completion();
```

**What this does:**
- Removes the function that was triggered on INSERT/UPDATE
- No longer needed since app will calculate pieces

---

### Keep or Replace `calculate_grace_days_from_habits()` function

**Option A: Keep it (simpler for reading)**
- Function is read-only, can keep for convenience
- App can still use it via `.rpc()` call

**Option B: Remove it (fully app-based)**
```sql
DROP FUNCTION IF EXISTS calculate_grace_days_from_habits(uuid, date);
```

**Recommendation:** Keep it for now (read-only, no harm)

---

## Step 3: Verify Removal

### Check triggers are removed
```sql
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public' 
AND event_object_table = 'habits_daily';
```
**Expected:** No rows returned

### Check functions are removed
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'update_grace_pieces_on_task_completion';
```
**Expected:** No rows returned

---

## Step 4: Test After Removal

### Verify app still works
1. Complete a task (diary/affirmations/gratitude/self-care)
2. Check `habits_daily.grace_pieces_earned` is updated
3. Check `streaks.grace_pieces_total` and `freeze_credits` are updated
4. Verify streak calculation works

---

## Summary

**Remove:**
- ✅ Trigger: `trigger_update_grace_pieces`
- ✅ Function: `update_grace_pieces_on_task_completion()`

**Keep (optional):**
- ⚠️ Function: `calculate_grace_days_from_habits()` (read-only, can keep)

**After removal:**
- App will calculate pieces in `GraceSystemService.trackTaskCompletion()`
- App will update `streaks` table directly
- No more trigger dependency

