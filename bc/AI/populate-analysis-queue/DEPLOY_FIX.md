# Deploy Queue Fix - Quick Guide

## What Changed?
- Fixed week_start calculation (Sunday-based instead of Monday)
- Added timezone validation
- Added DST documentation

## How to Deploy

### Option 1: Supabase SQL Editor (Easiest)

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Open SQL Editor**
   - Click "SQL Editor" in left sidebar

3. **Copy & Run SQL**
   - Open file: `supabase/migrations/004_process_analysis_queue_batch.sql`
   - Copy **entire file content**
   - Paste into SQL Editor
   - Click "Run" or press `Ctrl+Enter`

4. **Verify Success**
   - Should see: "Success. No rows returned"
   - No errors in output

### Option 2: Supabase CLI (If you have it set up)

```bash
# Navigate to project
cd C:\Users\mrrav\OneDrive\Desktop\diaryapp

# Apply migration
supabase db push
```

---

## What This Does

The SQL file contains:
- `CREATE OR REPLACE FUNCTION` - Updates the existing database function
- No data changes - only function logic updated
- Safe to run - uses `CREATE OR REPLACE` (won't break existing data)

---

## No Edge Function Changes Needed

✅ The Edge Function `populate-analysis-queue` doesn't need changes
- It just calls the database function
- Once database function is updated, Edge Function automatically uses new logic

---

## Verify It Works

After running SQL, test by:

1. **Check function exists:**
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'process_analysis_queue_batch';
```

2. **Test function (optional):**
```sql
SELECT * FROM process_analysis_queue_batch();
```

3. **Monitor cron job:**
- Wait for next cron run (every 5 minutes)
- Check `analysis_queue` table for new weekly jobs
- Verify `week_start` is Sunday-based (not Monday)

---

## That's It! ✅

No Edge Function deployment needed - just run the SQL file.

