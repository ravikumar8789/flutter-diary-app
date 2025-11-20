# **CRON JOBS SETUP GUIDE - SUPABASE pg_cron**

This guide walks you through setting up automated batch processing using Supabase's pg_cron extension.

---

## **PREREQUISITES**

Before starting, ensure you have:
- ✅ Executed all SQL queries from `plan_supabase.md`
- ✅ Deployed all edge functions (ai-analyze-daily, ai-analyze-monthly, process-ai-queue, populate-analysis-queue)
- ✅ Access to Supabase SQL Editor
- ✅ Your Supabase project reference
- ✅ Your Supabase service role key

---

## **STEP 1: CHECK IF pg_cron IS AVAILABLE**

### **1.1 Check Extension Availability**

Run this query in Supabase SQL Editor:

```sql
-- Check if pg_cron extension is available
SELECT * FROM pg_available_extensions WHERE name = 'pg_cron';
```

**Expected Result:**
- If you see a row with `name = 'pg_cron'`, the extension is available ✅
- If no rows returned, pg_cron is not available on your plan ❌

**If pg_cron is NOT available:**
- You'll need to use **Option B (GitHub Actions)** or **Option C (External Scheduler)** from `DEPLOYMENT_COMMANDS.md`
- Or upgrade your Supabase plan to one that supports pg_cron

---

## **STEP 2: ENABLE pg_cron EXTENSION**

### **2.1 Enable the Extension**

Run this query in Supabase SQL Editor:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

**Expected Result:**
- Should return: `CREATE EXTENSION` (if not already enabled)
- Or: `NOTICE: extension "pg_cron" already exists` (if already enabled)

### **2.2 Verify Extension is Enabled**

```sql
-- Verify pg_cron is enabled
SELECT extname, extversion 
FROM pg_extension 
WHERE extname = 'pg_cron';
```

**Expected Result:**
- Should return 1 row with `extname = 'pg_cron'` and a version number

---

## **STEP 3: GET YOUR PROJECT DETAILS**

Before setting up cron jobs, you need:

### **3.1 Get Your Project Reference**

1. Go to Supabase Dashboard
2. Click on your project
3. Go to **Settings** → **API**
4. Find **Project URL** - it looks like: `https://abcdefghijklmnop.supabase.co`
5. Your **Project Reference** is the part before `.supabase.co`: `abcdefghijklmnop`

**Or get it from SQL:**
```sql
-- Get project reference from current database
SELECT current_database();
-- This might not give you the exact ref, so use Dashboard method
```

### **3.2 Get Your Service Role Key**

1. Go to Supabase Dashboard
2. Click on your project
3. Go to **Settings** → **API**
4. Find **service_role** key (under **Project API keys**)
5. **⚠️ IMPORTANT**: This is a secret key - keep it safe!

**⚠️ SECURITY NOTE**: Never commit service role keys to git or share them publicly.

---

## **STEP 4: SET UP CRON JOB FOR `populate-analysis-queue`**

This job runs **every 5 minutes** to check for users who need analysis and add jobs to the queue.

### **4.1 Create the Cron Job**

Replace the placeholders in this query with your actual values:

```sql
-- Schedule populate-analysis-queue to run every 5 minutes
SELECT cron.schedule(
  'populate-analysis-queue',  -- Job name (unique identifier)
  '*/5 * * * *',              -- Cron schedule: every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Replace:**
- `YOUR_PROJECT_REF` with your project reference (from Step 3.1)
- `YOUR_SERVICE_ROLE_KEY` with your service role key (from Step 3.2)

**Example:**
```sql
SELECT cron.schedule(
  'populate-analysis-queue',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://abcdefghijklmnop.supabase.co/functions/v1/populate-analysis-queue',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Expected Result:**
- Should return: `schedule` with a job ID number (e.g., `1`)

---

## **STEP 5: SET UP CRON JOB FOR `process-ai-queue`**

This job runs **every minute** to process pending jobs from the queue.

### **5.1 Create the Cron Job**

Replace the placeholders in this query:

```sql
-- Schedule process-ai-queue to run every minute
SELECT cron.schedule(
  'process-ai-queue',  -- Job name (unique identifier)
  '* * * * *',         -- Cron schedule: every minute
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Replace:**
- `YOUR_PROJECT_REF` with your project reference
- `YOUR_SERVICE_ROLE_KEY` with your service role key

**Expected Result:**
- Should return: `schedule` with a job ID number (e.g., `2`)

---

## **STEP 6: VERIFY CRON JOBS ARE SET UP**

### **6.1 List All Cron Jobs**

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
- Should show 2 jobs:
  - `populate-analysis-queue` (runs every 5 minutes)
  - `process-ai-queue` (runs every minute)
- Both should have `active = true`

### **6.2 Check Specific Job Details**

```sql
-- Check populate-analysis-queue job
SELECT * FROM cron.job WHERE jobname = 'populate-analysis-queue';

-- Check process-ai-queue job
SELECT * FROM cron.job WHERE jobname = 'process-ai-queue';
```

---

## **STEP 7: TEST THE CRON JOBS MANUALLY**

Before waiting for the cron schedule, test the jobs manually to ensure they work.

### **7.1 Test `populate-analysis-queue` Manually**

Run this in Supabase SQL Editor:

```sql
-- Manually trigger populate-analysis-queue
SELECT net.http_post(
  url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
  headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
  body := '{}'::jsonb
) AS request_id;
```

**Check Results:**
1. Wait a few seconds
2. Check if jobs were added to queue:
   ```sql
   SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';
   ```
3. Check function logs in Supabase Dashboard → Edge Functions → Logs

### **7.2 Test `process-ai-queue` Manually**

First, ensure there are pending jobs in the queue:

```sql
-- Check pending jobs
SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';
```

If there are pending jobs, test the processor:

```sql
-- Manually trigger process-ai-queue
SELECT net.http_post(
  url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
  headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
  body := '{}'::jsonb
) AS request_id;
```

**Check Results:**
1. Wait a few seconds
2. Check queue status:
   ```sql
   SELECT status, COUNT(*) 
   FROM analysis_queue 
   GROUP BY status;
   ```
3. Some jobs should move from `pending` to `completed` or `processing`

---

## **STEP 8: MONITOR CRON JOB EXECUTION**

### **8.1 View Cron Job Execution History**

```sql
-- View recent cron job executions
SELECT 
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;
```

**What to Look For:**
- `status = 'succeeded'` - Job executed successfully ✅
- `status = 'failed'` - Job failed ❌
- `return_message` - Contains error details if failed

### **8.2 Check for Errors**

```sql
-- View failed cron job executions
SELECT 
  jobid,
  command,
  status,
  return_message,
  start_time
FROM cron.job_run_details
WHERE status = 'failed'
ORDER BY start_time DESC
LIMIT 10;
```

### **8.3 Monitor Queue Population**

```sql
-- Check how many jobs were queued in the last hour
SELECT 
  analysis_type,
  COUNT(*) as queued_count,
  MIN(created_at) as first_queued,
  MAX(created_at) as last_queued
FROM analysis_queue
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY analysis_type;
```

### **8.4 Monitor Queue Processing**

```sql
-- Check queue processing stats
SELECT 
  status,
  analysis_type,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (processed_at - created_at))) as avg_processing_seconds
FROM analysis_queue
WHERE processed_at IS NOT NULL
GROUP BY status, analysis_type;
```

---

## **STEP 9: VERIFY AUTOMATED EXECUTION**

After setting up cron jobs, wait a few minutes and verify they're running automatically.

### **9.1 Wait for First Execution**

- **populate-analysis-queue**: Should run within 5 minutes
- **process-ai-queue**: Should run within 1 minute

### **9.2 Check Execution Logs**

```sql
-- Check if jobs have run in the last 10 minutes
SELECT 
  jobid,
  start_time,
  status,
  return_message
FROM cron.job_run_details
WHERE start_time > NOW() - INTERVAL '10 minutes'
ORDER BY start_time DESC;
```

### **9.3 Verify Queue is Being Populated**

```sql
-- Check if new jobs are being added
SELECT 
  created_at,
  analysis_type,
  status,
  user_id
FROM analysis_queue
WHERE created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;
```

---

## **STEP 10: TROUBLESHOOTING**

### **Problem: Cron jobs not appearing in cron.job table**

**Solution:**
1. Check if pg_cron extension is enabled:
   ```sql
   SELECT * FROM pg_extension WHERE extname = 'pg_cron';
   ```
2. Verify you have permissions to create cron jobs
3. Check for syntax errors in the cron.schedule() call

---

### **Problem: Cron jobs not executing**

**Solution:**
1. Check if jobs are active:
   ```sql
   SELECT jobname, active FROM cron.job;
   ```
2. Check execution history for errors:
   ```sql
   SELECT * FROM cron.job_run_details 
   WHERE status = 'failed' 
   ORDER BY start_time DESC LIMIT 5;
   ```
3. Verify function URLs are correct
4. Verify service role key is correct

---

### **Problem: "net.http_post does not exist"**

**Solution:**
You need to enable the `http` extension:

```sql
-- Enable http extension for making HTTP requests
CREATE EXTENSION IF NOT EXISTS http;
```

---

### **Problem: Functions returning 401 Unauthorized**

**Solution:**
1. Verify service role key is correct
2. Check the Authorization header format in cron job command
3. Ensure service role key hasn't been rotated

---

### **Problem: Functions returning 404 Not Found**

**Solution:**
1. Verify project reference is correct in the URL
2. Verify function names are correct:
   - `populate-analysis-queue`
   - `process-ai-queue`
3. Ensure functions are deployed

---

### **Problem: Queue not populating**

**Solution:**
1. Check `populate-analysis-queue` function logs
2. Verify users have timezone set:
   ```sql
   SELECT COUNT(*) FROM users WHERE timezone IS NOT NULL;
   ```
3. Check if there are entries from yesterday:
   ```sql
   SELECT COUNT(*) FROM entries 
   WHERE entry_date = CURRENT_DATE - 1;
   ```
4. Manually test the function (Step 7.1)

---

### **Problem: Queue not processing**

**Solution:**
1. Check `process-ai-queue` function logs
2. Verify there are pending jobs:
   ```sql
   SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';
   ```
3. Check for errors in queue:
   ```sql
   SELECT * FROM analysis_queue 
   WHERE status = 'failed' 
   ORDER BY created_at DESC LIMIT 5;
   ```
4. Manually test the function (Step 7.2)

---

## **STEP 11: DISABLE/REMOVE CRON JOBS (IF NEEDED)**

### **11.1 Unschedule a Cron Job**

```sql
-- Remove populate-analysis-queue cron job
SELECT cron.unschedule('populate-analysis-queue');

-- Remove process-ai-queue cron job
SELECT cron.unschedule('process-ai-queue');
```

### **11.2 Verify Jobs are Removed**

```sql
-- Check if jobs are removed
SELECT * FROM cron.job WHERE jobname IN ('populate-analysis-queue', 'process-ai-queue');
```

**Expected Result:** Should return 0 rows

---

## **STEP 12: UPDATE CRON JOB SCHEDULE (IF NEEDED)**

If you need to change the schedule:

### **12.1 Remove Old Job**

```sql
SELECT cron.unschedule('populate-analysis-queue');
```

### **12.2 Create New Job with Updated Schedule**

```sql
-- Example: Change to every 10 minutes instead of 5
SELECT cron.schedule(
  'populate-analysis-queue',
  '*/10 * * * *',  -- Every 10 minutes
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

---

## **CRON SCHEDULE REFERENCE**

Common cron schedule patterns:

- `* * * * *` - Every minute
- `*/5 * * * *` - Every 5 minutes
- `*/10 * * * *` - Every 10 minutes
- `0 * * * *` - Every hour (at minute 0)
- `0 */2 * * *` - Every 2 hours
- `0 0 * * *` - Every day at midnight
- `0 0 * * 1` - Every Monday at midnight

**Format:** `minute hour day month weekday`

---

## **MONITORING CHECKLIST**

After setup, regularly check:

- [ ] Cron jobs are active (`SELECT * FROM cron.job;`)
- [ ] Jobs are executing (`SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`)
- [ ] Queue is being populated (`SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';`)
- [ ] Queue is being processed (`SELECT status, COUNT(*) FROM analysis_queue GROUP BY status;`)
- [ ] No failed jobs (`SELECT * FROM analysis_queue WHERE status = 'failed' ORDER BY created_at DESC LIMIT 10;`)
- [ ] Function logs show success (Supabase Dashboard → Edge Functions → Logs)

---

## **SUCCESS CRITERIA**

✅ pg_cron extension enabled  
✅ Both cron jobs created and active  
✅ Jobs executing automatically  
✅ Queue being populated with analysis jobs  
✅ Queue being processed successfully  
✅ No errors in cron execution logs  
✅ Insights being generated for users  

---

## **NEXT STEPS**

After cron jobs are set up and verified:

1. ✅ Monitor for 24 hours to ensure stability
2. ✅ Check that insights are being generated
3. ✅ Verify timezone-aware scheduling is working
4. ✅ Update Flutter app (see `plan.md` Phase 3)

---

**END OF CRON JOBS SETUP GUIDE**

