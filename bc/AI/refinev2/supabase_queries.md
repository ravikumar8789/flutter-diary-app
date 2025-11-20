# **SUPABASE SQL QUERIES - AI INSIGHTS REFINEMENT**

## **OVERVIEW**

This document contains all SQL queries needed to update the cron job schedules for the refined AI insights batch processing system.

**Key Changes:**
- `populate-analysis-queue`: Keep running every 5 minutes (no change)
- `process-ai-queue`: Change from every minute to **midnight only** (`'0 0 * * *'`)

---

## **PREREQUISITES**

Before running these queries, ensure you have:
1. ✅ Your Supabase project reference (from Dashboard → Settings → API)
2. ✅ Your service role key (from Dashboard → Settings → API)
3. ✅ `pg_cron` extension enabled
4. ✅ `pg_net` extension enabled (for `net.http_post`)

---

## **STEP 1: GET YOUR PROJECT DETAILS**

### **1.1 Get Project Reference**

1. Go to Supabase Dashboard
2. Click on your project
3. Go to **Settings** → **API**
4. Find **Project URL** - it looks like: `https://abcdefghijklmnop.supabase.co`
5. Your **Project Reference** is the part before `.supabase.co`: `abcdefghijklmnop`

**Example:** If URL is `https://foqoterfgxoiwoxvuxqi.supabase.co`, then reference is `foqoterfgxoiwoxvuxqi`

### **1.2 Get Service Role Key**

1. In the same **Settings** → **API** page
2. Find **service_role** key under **Project API keys**
3. Copy the full key (starts with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)

**⚠️ SECURITY NOTE:** Never commit service role keys to git or share them publicly.

---

## **STEP 2: CHECK CURRENT CRON JOBS**

### **2.1 List All Cron Jobs**

Run this query to see all existing cron jobs:

```sql
-- View all scheduled cron jobs
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active
FROM cron.job
ORDER BY jobid;
```

**Expected Result:**
- Should show existing jobs including `populate-analysis-queue` and `process-ai-queue`
- Note the `jobid` for each job (you'll need it for unscheduling)

---

## **STEP 3: UNSCHEDULE EXISTING JOBS (IF NEEDED)**

### **3.1 Unschedule `populate-analysis-queue` (Optional)**

If you want to recreate it from scratch:

```sql
-- Unschedule existing populate-analysis-queue job
SELECT cron.unschedule('populate-analysis-queue');
```

**Expected Result:**
- Returns `unschedule` if job existed and was removed
- Returns error if job doesn't exist (that's okay)

### **3.2 Unschedule `process-ai-queue` (Required)**

We need to unschedule this to change the schedule:

```sql
-- Unschedule existing process-ai-queue job
SELECT cron.unschedule('process-ai-queue');
```

**Expected Result:**
- Returns `unschedule` if job existed and was removed
- Returns error if job doesn't exist (that's okay)

---

## **STEP 4: UPDATE `populate-analysis-queue` CRON JOB**

### **4.1 Schedule (Keep Every 5 Minutes)**

This job runs **every 5 minutes** to queue today's entries and catch up on missed entries.

**Replace placeholders:**
- `YOUR_PROJECT_REF` → Your project reference (from Step 1.1)
- `YOUR_SERVICE_ROLE_KEY` → Your service role key (from Step 1.2)

```sql
-- Schedule populate-analysis-queue to run every 5 minutes
SELECT cron.schedule(
  'populate-analysis-queue',  -- Job name (unique identifier)
  '*/5 * * * *',              -- Cron schedule: every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Example (with real values):**
```sql
SELECT cron.schedule(
  'populate-analysis-queue',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://foqoterfgxoiwoxvuxqi.supabase.co/functions/v1/populate-analysis-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvcW90ZXJmZ3hvaXdveHZ1eHFpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTIxNjM0OSwiZXhwIjoyMDc0NzkyMzQ5fQ.4lKFBtI7E5N4PLzBApZuC2tTjSKyLR2S37rt1L6uBCQ'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Expected Result:**
- Should return: `schedule` with a job ID number (e.g., `1`)

---

## **STEP 5: UPDATE `process-ai-queue` CRON JOB**

### **5.1 Schedule (Change to Midnight Only)**

This job runs **only at midnight (00:00)** to process yesterday's queue.

**Replace placeholders:**
- `YOUR_PROJECT_REF` → Your project reference
- `YOUR_SERVICE_ROLE_KEY` → Your service role key

```sql
-- Schedule process-ai-queue to run only at midnight
SELECT cron.schedule(
  'process-ai-queue',  -- Job name (unique identifier)
  '0 0 * * *',         -- Cron schedule: midnight only (00:00 every day)
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Example (with real values):**
```sql
SELECT cron.schedule(
  'process-ai-queue',
  '0 0 * * *',  -- Changed from '* * * * *' (every minute) to '0 0 * * *' (midnight only)
  $$
  SELECT net.http_post(
    url := 'https://foqoterfgxoiwoxvuxqi.supabase.co/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvcW90ZXJmZ3hvaXdveHZ1eHFpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTIxNjM0OSwiZXhwIjoyMDc0NzkyMzQ5fQ.4lKFBtI7E5N4PLzBApZuC2tTjSKyLR2S37rt1L6uBCQ'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Expected Result:**
- Should return: `schedule` with a job ID number (e.g., `2`)

**Note:** Since we process 10 jobs per run, if there are more than 10 jobs, the function will need to run multiple times. We can add additional cron jobs for 00:01, 00:02, etc., or let it process in batches (see Step 6).

---

## **STEP 6: ADDITIONAL MIDNIGHT RUNS (OPTIONAL)**

### **6.1 Add Multiple Runs for Large Queues**

If you expect more than 10 jobs per day, you can add additional cron jobs to run at 00:01, 00:02, etc.:

```sql
-- Additional run at 00:01 (1 minute after midnight)
SELECT cron.schedule(
  'process-ai-queue-001',
  '1 0 * * *',  -- 00:01 every day
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- Additional run at 00:02 (2 minutes after midnight)
SELECT cron.schedule(
  'process-ai-queue-002',
  '2 0 * * *',  -- 00:02 every day
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- Add more as needed (00:03, 00:04, etc.)
```

**Recommendation:** Start with just the midnight run (Step 5). Add more if you see jobs piling up.

---

## **STEP 7: VERIFY CRON JOBS ARE SET UP**

### **7.1 List All Cron Jobs Again**

```sql
-- View all scheduled cron jobs
SELECT 
  jobid,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname IN ('populate-analysis-queue', 'process-ai-queue', 'process-ai-queue-001', 'process-ai-queue-002')
ORDER BY jobid;
```

**Expected Result:**
- Should show:
  - `populate-analysis-queue` with schedule `*/5 * * * *` (every 5 minutes)
  - `process-ai-queue` with schedule `0 0 * * *` (midnight only)
  - Any additional runs you added

### **7.2 Check Job Details**

```sql
-- Get detailed info about a specific job
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active,
  jobname
FROM cron.job
WHERE jobname = 'process-ai-queue';
```

---

## **STEP 8: TEST THE SETUP**

### **8.1 Manually Trigger `populate-analysis-queue`**

Test the queue population function:

```sql
-- Manually trigger populate-analysis-queue
SELECT net.http_post(
  url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
  ),
  body := '{}'::jsonb
) AS request_id;
```

**Expected Result:**
- Should return a `request_id`
- Check function logs in Supabase Dashboard → Edge Functions → Logs

### **8.2 Check Queue Status**

```sql
-- Check pending jobs in queue
SELECT 
  target_date,
  analysis_type,
  status,
  COUNT(*) as count
FROM analysis_queue
WHERE status = 'pending'
GROUP BY target_date, analysis_type, status
ORDER BY target_date DESC, analysis_type;
```

### **8.3 Manually Trigger `process-ai-queue` (Test)**

**⚠️ WARNING:** Only test this if you have jobs with `target_date = yesterday` in the queue.

```sql
-- Manually trigger process-ai-queue (for testing)
SELECT net.http_post(
  url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
  ),
  body := '{}'::jsonb
) AS request_id;
```

---

## **STEP 9: MONITORING QUERIES**

### **9.1 Check Queue Population Status**

```sql
-- Count jobs queued today
SELECT 
  target_date,
  analysis_type,
  COUNT(*) as queued_count
FROM analysis_queue
WHERE created_at >= CURRENT_DATE
GROUP BY target_date, analysis_type
ORDER BY target_date DESC;
```

### **9.2 Check Processing Status**

```sql
-- Check jobs processed today
SELECT 
  target_date,
  analysis_type,
  status,
  COUNT(*) as count
FROM analysis_queue
WHERE processed_at >= CURRENT_DATE
GROUP BY target_date, analysis_type, status
ORDER BY target_date DESC, status;
```

### **9.3 Check Failed Jobs**

```sql
-- Check failed jobs
SELECT 
  id,
  user_id,
  analysis_type,
  target_date,
  error_message,
  attempts,
  created_at,
  processed_at
FROM analysis_queue
WHERE status = 'failed'
ORDER BY processed_at DESC
LIMIT 20;
```

### **9.4 Check Pending Jobs by Date**

```sql
-- Count pending jobs by target_date
SELECT 
  target_date,
  COUNT(*) as pending_count
FROM analysis_queue
WHERE status = 'pending'
GROUP BY target_date
ORDER BY target_date DESC;
```

---

## **STEP 10: TROUBLESHOOTING**

### **10.1 If Cron Job Not Running**

```sql
-- Check if cron extension is enabled
SELECT extname, extversion 
FROM pg_extension 
WHERE extname = 'pg_cron';

-- Check if pg_net extension is enabled
SELECT extname, extversion 
FROM pg_extension 
WHERE extname = 'pg_net';
```

### **10.2 If Jobs Are Not Processing**

```sql
-- Check if there are jobs ready to process
SELECT 
  target_date,
  COUNT(*) as ready_count
FROM analysis_queue
WHERE status = 'pending'
  AND next_retry_at <= NOW()
GROUP BY target_date;
```

### **10.3 Update Existing Cron Job Schedule**

If you need to change the schedule without unscheduling:

```sql
-- Update schedule for existing job (example: change to every 10 minutes)
SELECT cron.alter_job(
  (SELECT jobid FROM cron.job WHERE jobname = 'populate-analysis-queue'),
  schedule := '*/10 * * * *'
);
```

### **10.4 Delete a Cron Job**

```sql
-- Delete a specific cron job
SELECT cron.unschedule('process-ai-queue-001');
```

---

## **SUMMARY**

### **What Changed:**
1. ✅ `populate-analysis-queue`: Still runs every 5 minutes (no change needed, but can recreate)
2. ✅ `process-ai-queue`: Changed from every minute (`'* * * * *'`) to midnight only (`'0 0 * * *'`)

### **Next Steps:**
1. Deploy updated edge functions:
   ```bash
   supabase functions deploy populate-analysis-queue
   supabase functions deploy process-ai-queue
   ```
2. Run the SQL queries above to update cron schedules
3. Monitor logs for first 24 hours
4. Verify queue population (check every 5 minutes)
5. Verify midnight processing (check at 12:00 AM)

---

## **END OF QUERIES**

All queries are ready to run. Replace placeholders with your actual values and execute step by step.

