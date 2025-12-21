# **FIX: Queue Population Function Error**

## **🐛 Problem**

The `process_analysis_queue_batch()` function is failing with error:
```
ERROR: 42846: cannot cast type integer to interval
```

**Root Cause:** Line 159 tries to cast integer directly to interval, which is invalid in PostgreSQL.

---

## **✅ Solution**

Fixed the interval casting issue in the weekly week calculation.

**Changed:**
- ❌ `(EXTRACT(...)::int)::interval` 
- ✅ `(EXTRACT(...)::int * INTERVAL '1 day')`

---

## **🚀 FIX STEPS**

### **Step 1: Apply Fix via SQL Dashboard (Recommended)**

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Open SQL Editor**
   - Click "SQL Editor" in left sidebar
   - Click "New query"

3. **Copy & Run Fixed Function**

   Copy the entire content from: `supabase/migrations/004_process_analysis_queue_batch.sql`
   
   **OR** run this SQL directly:

```sql
CREATE OR REPLACE FUNCTION public.process_analysis_queue_batch()
RETURNS TABLE (
    users_processed bigint,
    daily_jobs_created bigint,
    weekly_jobs_created bigint,
    monthly_jobs_created bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
    current_utc_time timestamptz := NOW();
BEGIN
    WITH user_context AS (
        SELECT
            u.id AS user_id,
            u.timezone,
            ((current_utc_time AT TIME ZONE u.timezone)::date) AS user_today,
            EXTRACT(HOUR FROM (current_utc_time AT TIME ZONE u.timezone))::int AS user_hour,
            EXTRACT(DOW FROM (current_utc_time AT TIME ZONE u.timezone))::int AS user_dow,
            calculate_next_midnight_utc(u.timezone, (current_utc_time AT TIME ZONE u.timezone)::date) AS next_retry_at
        FROM public.users u
        WHERE u.timezone IS NOT NULL
          AND (u.timezone = 'UTC' OR u.timezone ~ '^[A-Za-z_]+/[A-Za-z_]+$')
    ),
    daily_candidates AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            e.id AS entry_id,
            e.entry_date
        FROM user_context uc
        JOIN public.entries e
            ON e.user_id = uc.user_id
           AND e.entry_date = uc.user_today
        WHERE e.diary_text IS NOT NULL
          AND length(e.diary_text) >= 50
          AND check_entry_completion(e.id)
          AND NOT EXISTS (
              SELECT 1
              FROM public.entry_insights ei
              WHERE ei.entry_id = e.id
                AND ei.status = 'success'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.entry_id = e.id
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_daily AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            entry_id,
            status,
            next_retry_at
        )
        SELECT
            dc.user_id,
            'daily',
            dc.entry_date,
            dc.entry_id,
            'pending',
            dc.next_retry_at
        FROM daily_candidates dc
        RETURNING user_id
    ),
    catchup_entries AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            e.id AS entry_id,
            e.entry_date
        FROM user_context uc
        JOIN public.entries e
            ON e.user_id = uc.user_id
        WHERE e.entry_date < uc.user_today
          AND e.entry_date >= ((uc.user_today - INTERVAL '30 days')::date)
          AND e.diary_text IS NOT NULL
          AND length(e.diary_text) >= 50
          AND check_entry_completion(e.id)
          AND NOT EXISTS (
              SELECT 1
              FROM public.entry_insights ei
              WHERE ei.entry_id = e.id
                AND ei.status = 'success'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.entry_id = e.id
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_catchup AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            entry_id,
            status,
            next_retry_at
        )
        SELECT
            ce.user_id,
            'daily',
            ce.entry_date,
            ce.entry_id,
            'pending',
            ce.next_retry_at
        FROM catchup_entries ce
        RETURNING user_id
    ),
    weekly_candidates AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            prev_week.week_start
        FROM user_context uc
        CROSS JOIN LATERAL (
            SELECT (
                (uc.user_today - INTERVAL '7 days')::date - 
                (EXTRACT(DOW FROM (uc.user_today - INTERVAL '7 days')::timestamp)::int * INTERVAL '1 day')
            )::date AS week_start
        ) AS prev_week
        WHERE uc.user_dow = 0
          AND uc.user_hour = 0
          AND (
              SELECT COUNT(*)
              FROM public.entries e
              WHERE e.user_id = uc.user_id
                AND e.entry_date >= prev_week.week_start
                AND e.entry_date < (prev_week.week_start + INTERVAL '7 days')::date
          ) >= 3
          AND NOT EXISTS (
              SELECT 1
              FROM public.weekly_insights wi
              WHERE wi.user_id = uc.user_id
                AND wi.week_start = prev_week.week_start
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.user_id = uc.user_id
                AND aq.analysis_type = 'weekly'
                AND aq.week_start = prev_week.week_start
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_weekly AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            week_start,
            status,
            next_retry_at
        )
        SELECT
            wc.user_id,
            'weekly',
            wc.week_start,
            wc.week_start,
            'pending',
            wc.next_retry_at
        FROM weekly_candidates wc
        RETURNING user_id
    ),
    monthly_candidates AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            prev_month.month_start
        FROM user_context uc
        CROSS JOIN LATERAL (
            SELECT (date_trunc('month', (uc.user_today - INTERVAL '1 month')::timestamp))::date AS month_start
        ) AS prev_month
        WHERE uc.user_hour = 0
          AND EXTRACT(DAY FROM uc.user_today) = 1
          AND (
              SELECT COUNT(*)
              FROM public.entries e
              WHERE e.user_id = uc.user_id
                AND e.entry_date >= prev_month.month_start
                AND e.entry_date < (prev_month.month_start + INTERVAL '1 month')::date
          ) >= 10
          AND NOT EXISTS (
              SELECT 1
              FROM public.monthly_insights mi
              WHERE mi.user_id = uc.user_id
                AND mi.month_start = prev_month.month_start
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.user_id = uc.user_id
                AND aq.analysis_type = 'monthly'
                AND aq.month_start = prev_month.month_start
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_monthly AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            month_start,
            status,
            next_retry_at
        )
        SELECT
            mc.user_id,
            'monthly',
            mc.month_start,
            mc.month_start,
            'pending',
            mc.next_retry_at
        FROM monthly_candidates mc
        RETURNING user_id
    )
    SELECT
        COALESCE((
            SELECT COUNT(DISTINCT user_id)
            FROM (
                SELECT user_id FROM inserted_daily
                UNION ALL
                SELECT user_id FROM inserted_catchup
                UNION ALL
                SELECT user_id FROM inserted_weekly
                UNION ALL
                SELECT user_id FROM inserted_monthly
            ) AS all_users
        ), 0) AS users_processed,
        COALESCE((SELECT COUNT(*) FROM inserted_daily), 0) +
        COALESCE((SELECT COUNT(*) FROM inserted_catchup), 0) AS daily_jobs_created,
        COALESCE((SELECT COUNT(*) FROM inserted_weekly), 0) AS weekly_jobs_created,
        COALESCE((SELECT COUNT(*) FROM inserted_monthly), 0) AS monthly_jobs_created
    INTO users_processed, daily_jobs_created, weekly_jobs_created, monthly_jobs_created;

    RETURN QUERY
    SELECT
        COALESCE(users_processed, 0),
        COALESCE(daily_jobs_created, 0),
        COALESCE(weekly_jobs_created, 0),
        COALESCE(monthly_jobs_created, 0);
END;
$$;
```

4. **Click "Run" or press `Ctrl+Enter`**

5. **Verify Success**
   - Should see: "Success. No rows returned"
   - No errors in output

---

### **Step 2: Verify Fix**

**Test the function:**
```sql
SELECT * FROM process_analysis_queue_batch();
```

**Expected:** Should return counts (may be zeros if no entries to queue)

**Check for errors:**
- Should NOT see: `cannot cast type integer to interval`
- Function should execute successfully

---

### **Step 3: Test Queue Population**

**Wait for next cron run (5 minutes) OR manually trigger:**

**Option A: Wait for cron**
- Cron runs every 5 minutes
- Check `analysis_queue` table after next run

**Option B: Manual trigger via Dashboard**
1. Go to Edge Functions → `populate-analysis-queue`
2. Click "Invoke"
3. Check response and logs

**Option C: Manual trigger via SQL**
```sql
-- This will be called by the edge function, but you can test it directly
SELECT * FROM process_analysis_queue_batch();
```

---

### **Step 4: Verify Entries Are Queued**

```sql
-- Check if new jobs were created
SELECT 
    analysis_type,
    status,
    COUNT(*) as count,
    MAX(created_at) as latest_created
FROM analysis_queue
WHERE created_at >= NOW() - INTERVAL '10 minutes'
GROUP BY analysis_type, status
ORDER BY latest_created DESC;
```

**Expected:** Should see new `pending` jobs if entries exist that meet criteria.

---

## **✅ DONE!**

After applying this fix:
- ✅ Function will execute without errors
- ✅ Entries will be queued correctly
- ✅ Cron job will work as expected

---

## **🔍 If Still Not Working**

If entries still aren't being queued after the fix, check:

1. **Entries meet criteria:**
   ```sql
   -- Check if you have entries that should be queued
   SELECT 
       e.id,
       e.entry_date,
       length(e.diary_text) as text_length,
       check_entry_completion(e.id) as is_complete
   FROM entries e
   WHERE e.entry_date = CURRENT_DATE
     AND e.diary_text IS NOT NULL
     AND length(e.diary_text) >= 50
   LIMIT 10;
   ```

2. **Check function logs:**
   ```bash
   supabase functions logs populate-analysis-queue --limit 20
   ```

3. **Check for existing insights:**
   ```sql
   -- If entries already have insights, they won't be queued
   SELECT COUNT(*) 
   FROM entry_insights 
   WHERE status = 'success';
   ```

---

**That's it! The fix is applied and queue population should work again.** 🎉

