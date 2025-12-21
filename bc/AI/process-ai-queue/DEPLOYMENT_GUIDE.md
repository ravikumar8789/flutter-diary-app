# **DEPLOYMENT GUIDE: REMOVING `next_retry_at` LOGIC**

## **📋 OVERVIEW**

This guide provides step-by-step instructions to deploy the changes that remove `next_retry_at` logic from the AI queue processing system.

**Estimated Time:** 15-20 minutes  
**Risk Level:** Low (backward compatible, column remains)  
**Rollback:** Easy (revert code changes only)

---

## **⚠️ PRE-DEPLOYMENT CHECKLIST**

Before starting, ensure:

- [ ] Database backup is created
- [ ] Staging environment tested (if available)
- [ ] Current system is stable
- [ ] You have Supabase CLI installed and configured
- [ ] You have access to Supabase Dashboard
- [ ] Edge functions are deployed from local machine

---

## **📦 STEP 1: UPDATE DATABASE FUNCTIONS**

### **1.1 Update `claim_pending_jobs` Function**

**Location:** Supabase Dashboard → SQL Editor

**Action:** Run this SQL:

```sql
-- Update claim_pending_jobs to remove next_retry_at check
CREATE OR REPLACE FUNCTION public.claim_pending_jobs(
    p_batch_size integer DEFAULT 20,
    p_max_retry_at timestamptz DEFAULT NOW()  -- Parameter kept for backward compatibility, but not used
) RETURNS TABLE (
    id uuid,
    user_id uuid,
    analysis_type text,
    target_date date,
    entry_id uuid,
    week_start date,
    month_start date,
    attempts integer,
    max_attempts integer,
    next_retry_at timestamptz,  -- Still returned for backward compatibility
    created_at timestamptz
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE public.analysis_queue
    SET 
        status = 'processing',
        updated_at = NOW()
    WHERE analysis_queue.id IN (
        SELECT aq.id
        FROM public.analysis_queue aq
        WHERE aq.status = 'pending'
          -- Removed: AND aq.next_retry_at <= p_max_retry_at
          -- Now only checks status = 'pending'
        ORDER BY aq.created_at ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED  -- Prevents concurrent access
    )
    RETURNING 
        analysis_queue.id,
        analysis_queue.user_id,
        analysis_queue.analysis_type,
        analysis_queue.target_date,
        analysis_queue.entry_id,
        analysis_queue.week_start,
        analysis_queue.month_start,
        analysis_queue.attempts,
        analysis_queue.max_attempts,
        analysis_queue.next_retry_at,
        analysis_queue.created_at;
END;
$$;

-- Update function comment
COMMENT ON FUNCTION public.claim_pending_jobs IS 'Atomically claims pending jobs for processing, preventing race conditions. Uses FOR UPDATE SKIP LOCKED to ensure no duplicate processing. No longer uses next_retry_at for filtering.';
```

**Verification:**
```sql
-- Test the function
SELECT * FROM claim_pending_jobs(5);
-- Should return pending jobs (if any exist)
```

---

### **1.2 Update Database Index**

**Location:** Supabase Dashboard → SQL Editor

**Action:** Run this SQL:

```sql
-- Drop old index
DROP INDEX IF EXISTS idx_analysis_queue_status_retry;

-- Create new index without next_retry_at
CREATE INDEX IF NOT EXISTS idx_analysis_queue_status_created 
ON public.analysis_queue(status, created_at)
WHERE status = 'pending';

-- Verify index was created
SELECT 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE tablename = 'analysis_queue' 
  AND indexname LIKE 'idx_analysis_queue%';
```

**Expected Result:** Should show `idx_analysis_queue_status_created` index.

---

### **1.3 Update `process_analysis_queue_batch` Function**

**Location:** Supabase Dashboard → SQL Editor

**Action:** Run this SQL (full function replacement):

```sql
-- Update process_analysis_queue_batch to remove next_retry_at
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
            EXTRACT(DOW FROM (current_utc_time AT TIME ZONE u.timezone))::int AS user_dow
            -- Removed: calculate_next_midnight_utc(...) AS next_retry_at
        FROM public.users u
        WHERE u.timezone IS NOT NULL
          AND (u.timezone = 'UTC' OR u.timezone ~ '^[A-Za-z_]+/[A-Za-z_]+$')
    ),
    daily_candidates AS (
        SELECT
            uc.user_id,
            e.id AS entry_id,
            e.entry_date
            -- Removed: uc.next_retry_at
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
            status
            -- Removed: next_retry_at
        )
        SELECT
            dc.user_id,
            'daily',
            dc.entry_date,
            dc.entry_id,
            'pending'
            -- Removed: dc.next_retry_at
        FROM daily_candidates dc
        RETURNING user_id
    ),
    catchup_entries AS (
        SELECT
            uc.user_id,
            e.id AS entry_id,
            e.entry_date
            -- Removed: uc.next_retry_at
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
            status
            -- Removed: next_retry_at
        )
        SELECT
            ce.user_id,
            'daily',
            ce.entry_date,
            ce.entry_id,
            'pending'
            -- Removed: ce.next_retry_at
        FROM catchup_entries ce
        RETURNING user_id
    ),
    weekly_candidates AS (
        SELECT
            uc.user_id,
            prev_week.week_start
            -- Removed: uc.next_retry_at
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
            status
            -- Removed: next_retry_at
        )
        SELECT
            wc.user_id,
            'weekly',
            wc.week_start,
            wc.week_start,
            'pending'
            -- Removed: wc.next_retry_at
        FROM weekly_candidates wc
        RETURNING user_id
    ),
    monthly_candidates AS (
        SELECT
            uc.user_id,
            prev_month.month_start
            -- Removed: uc.next_retry_at
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
            status
            -- Removed: next_retry_at
        )
        SELECT
            mc.user_id,
            'monthly',
            mc.month_start,
            mc.month_start,
            'pending'
            -- Removed: mc.next_retry_at
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

**Verification:**
```sql
-- Test the function
SELECT * FROM process_analysis_queue_batch();
-- Should return counts (may be zeros if no entries to queue)
```

---

## **📝 STEP 2: UPDATE EDGE FUNCTION CODE**

### **2.1 Update `process-ai-queue/index.ts`**

**Location:** `supabase/functions/process-ai-queue/index.ts`

**Changes Needed:**

1. **Remove `next_retry_at` from retry logic (Line ~401-410)**
2. **Remove `next_retry_at` from remaining jobs check (Line ~427)**

**Action:** Update the file with these changes:

```typescript
// Change 1: Retry logic (around line 400)
// OLD:
const backoffMinutes = Math.pow(2, newAttempts) // 2, 4, 8 minutes
const nextRetry = new Date(Date.now() + backoffMinutes * 60000)

await supabase
  .from('analysis_queue')
  .update({
    status: 'pending',
    attempts: newAttempts,
    next_retry_at: nextRetry.toISOString(),
    error_message: errorMessage
  })
  .eq('id', job.id)

// NEW:
await supabase
  .from('analysis_queue')
  .update({
    status: 'pending',
    attempts: newAttempts,
    error_message: errorMessage
    // Removed next_retry_at - hourly cron handles retries
  })
  .eq('id', job.id)
```

```typescript
// Change 2: Remaining jobs check (around line 423)
// OLD:
const { data: remainingJobs, error: remainingError } = await supabase
  .from('analysis_queue')
  .select('id')
  .eq('status', 'pending')
  .lte('next_retry_at', new Date().toISOString())
  .limit(1)

// NEW:
const { data: remainingJobs, error: remainingError } = await supabase
  .from('analysis_queue')
  .select('id')
  .eq('status', 'pending')
  // Removed next_retry_at check - not needed
  .limit(1)
```

**Note:** Also update the `claim_pending_jobs` RPC call to remove `p_max_retry_at` parameter (optional, kept for backward compatibility):

```typescript
// Line ~79 - Optional: Remove parameter (or keep for backward compatibility)
const { data: claimedJobs, error: claimError } = await supabase.rpc('claim_pending_jobs', {
  p_batch_size: BATCH_SIZE
  // Removed: p_max_retry_at: now.toISOString()
})
```

---

## **🚀 STEP 3: DEPLOY EDGE FUNCTION**

### **3.1 Prerequisites**

Ensure you have:
- Supabase CLI installed: `supabase --version`
- Logged in: `supabase login`
- Linked to project: `supabase link --project-ref <your-project-ref>`

### **3.2 Deploy Command**

**From project root directory:**

```bash
# Navigate to supabase functions directory (if not already there)
cd supabase/functions

# Deploy process-ai-queue function
supabase functions deploy process-ai-queue

# Or from project root:
supabase functions deploy process-ai-queue --project-ref <your-project-ref>
```

### **3.3 Verify Deployment**

**Check function logs:**
```bash
supabase functions logs process-ai-queue --limit 20
```

**Expected:** Should see function starting without errors.

---

## **✅ STEP 4: VERIFICATION**

### **4.1 Test Database Functions**

**Test `claim_pending_jobs`:**
```sql
-- Should return pending jobs (if any)
SELECT * FROM claim_pending_jobs(5);
```

**Test `process_analysis_queue_batch`:**
```sql
-- Should return counts
SELECT * FROM process_analysis_queue_batch();
```

### **4.2 Test Edge Function**

**Manual Invocation:**
```bash
# Invoke function manually
supabase functions invoke process-ai-queue

# Or via Dashboard:
# Edge Functions → process-ai-queue → Invoke
```

**Check Logs:**
```bash
supabase functions logs process-ai-queue --limit 50
```

**Expected Output:**
- Should process pending jobs
- Should not show `next_retry_at` errors
- Should show successful processing

### **4.3 Verify Queue Behavior**

**Check Queue Status:**
```sql
-- Check pending jobs
SELECT 
    id,
    analysis_type,
    target_date,
    status,
    attempts,
    max_attempts,
    next_retry_at,  -- Should be NULL for new jobs
    created_at
FROM analysis_queue
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 10;
```

**Expected:**
- New jobs should have `next_retry_at = NULL`
- Old jobs may have `next_retry_at` values (ignored, no issue)

**Test Retry Behavior:**
1. Create a test job that will fail
2. Wait for it to fail
3. Verify `attempts` increments
4. Verify `status = 'pending'`
5. Wait for next hour cron
6. Verify job is retried

---

## **🔄 STEP 5: MONITORING**

### **5.1 Monitor for 24 Hours**

**Check:**
- [ ] Jobs are processing correctly
- [ ] Failed jobs retry on next hour
- [ ] Today's entries are not processed
- [ ] Yesterday's entries are processed
- [ ] No errors in logs
- [ ] Index performance is good

### **5.2 Key Metrics to Watch**

```sql
-- Pending jobs count
SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';

-- Failed jobs count
SELECT COUNT(*) FROM analysis_queue WHERE status = 'failed';

-- Processing jobs count
SELECT COUNT(*) FROM analysis_queue WHERE status = 'processing';

-- Jobs by status
SELECT status, COUNT(*) 
FROM analysis_queue 
GROUP BY status;
```

---

## **🐛 TROUBLESHOOTING**

### **Issue 1: Function Deployment Fails**

**Solution:**
```bash
# Check Supabase CLI version
supabase --version

# Update if needed
npm install -g supabase

# Try again with verbose output
supabase functions deploy process-ai-queue --debug
```

### **Issue 2: Database Function Errors**

**Solution:**
```sql
-- Check function exists
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'claim_pending_jobs';

-- Check for syntax errors
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'claim_pending_jobs';
```

### **Issue 3: Jobs Not Processing**

**Check:**
```sql
-- Verify pending jobs exist
SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';

-- Check if jobs have target_date <= yesterday
SELECT 
    target_date,
    CURRENT_DATE - 1 as yesterday,
    target_date <= (CURRENT_DATE - 1) as should_process
FROM analysis_queue 
WHERE status = 'pending'
LIMIT 10;
```

### **Issue 4: Index Not Created**

**Solution:**
```sql
-- Check if index exists
SELECT indexname FROM pg_indexes 
WHERE tablename = 'analysis_queue';

-- Recreate if missing
CREATE INDEX IF NOT EXISTS idx_analysis_queue_status_created 
ON public.analysis_queue(status, created_at)
WHERE status = 'pending';
```

---

## **↩️ ROLLBACK PLAN**

If issues occur, rollback is simple:

### **1. Revert Edge Function**

```bash
# Deploy previous version
git checkout HEAD~1 supabase/functions/process-ai-queue/index.ts
supabase functions deploy process-ai-queue
```

### **2. Revert Database Functions**

```sql
-- Restore claim_pending_jobs with next_retry_at check
-- (Use previous version from git or backup)

-- Restore index
DROP INDEX IF EXISTS idx_analysis_queue_status_created;
CREATE INDEX IF NOT EXISTS idx_analysis_queue_status_retry 
ON public.analysis_queue(status, next_retry_at, created_at)
WHERE status = 'pending';
```

**Note:** No data migration needed - `next_retry_at` column still exists.

---

## **📋 DEPLOYMENT CHECKLIST**

Use this checklist during deployment:

- [ ] Database backup created
- [ ] `claim_pending_jobs` function updated
- [ ] Database index updated
- [ ] `process_analysis_queue_batch` function updated
- [ ] Edge function code updated locally
- [ ] Edge function deployed to Supabase
- [ ] Database functions tested
- [ ] Edge function tested manually
- [ ] Queue behavior verified
- [ ] Monitoring setup for 24 hours
- [ ] Team notified of deployment

---

## **📞 SUPPORT**

If you encounter issues:

1. Check Supabase logs: Dashboard → Logs → Edge Functions
2. Check database logs: Dashboard → Logs → Postgres
3. Review error messages in function logs
4. Verify all SQL queries executed successfully
5. Check function deployment status

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Status:** Ready for Deployment

