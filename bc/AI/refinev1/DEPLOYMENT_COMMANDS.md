# **DEPLOYMENT COMMANDS FOR SUPABASE FUNCTIONS**

## **PREREQUISITES**

1. **Install Supabase CLI** (if not already installed):
   ```bash
   npm install -g supabase
   ```

2. **Login to Supabase**:
   ```bash
   supabase login
   ```

3. **Link to your project**:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

---

## **STEP 1: DEPLOY UPDATED FUNCTIONS**

### **1.1 Deploy Updated `ai-analyze-daily`**
```bash
supabase functions deploy ai-analyze-daily
```

**What changed:**
- Simplified to generate single insight (not 5)
- Removed `homescreen_insights` save logic
- Reduced max_tokens from 1500 to 200

---

### **1.2 Deploy New `ai-analyze-monthly`**
```bash
supabase functions deploy ai-analyze-monthly
```

**What's new:**
- Generates monthly insights for completed months
- Saves to `monthly_insights` table
- Requires minimum 10 entries

---

### **1.3 Deploy Updated `process-ai-queue`**
```bash
supabase functions deploy process-ai-queue
```

**What changed:**
- Now processes new `analysis_queue` table
- Routes to `daily`, `weekly`, or `monthly` functions
- Handles retries with exponential backoff

---

### **1.4 Deploy New `populate-analysis-queue`**
```bash
supabase functions deploy populate-analysis-queue
```

**What's new:**
- Populates `analysis_queue` with jobs
- Timezone-aware scheduling
- Checks for daily, weekly, and monthly analysis needs

---

## **STEP 2: SET UP CRON JOBS / SCHEDULERS**

### **Option A: Using Supabase Cron (Recommended)**

If your Supabase plan supports pg_cron extension:

```sql
-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule populate-analysis-queue to run every 5 minutes
SELECT cron.schedule(
  'populate-analysis-queue',
  '*/5 * * * *',  -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);

-- Schedule process-ai-queue to run every minute
SELECT cron.schedule(
  'process-ai-queue',
  '* * * * *',  -- Every minute
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
- `YOUR_PROJECT_REF` with your Supabase project reference
- `YOUR_SERVICE_ROLE_KEY` with your service role key

---

### **Option B: Using External Cron (GitHub Actions, etc.)**

#### **GitHub Actions Example:**

Create `.github/workflows/ai-batch-processing.yml`:

```yaml
name: AI Batch Processing

on:
  schedule:
    # Run populate-analysis-queue every 5 minutes
    - cron: '*/5 * * * *'
    # Run process-ai-queue every minute
    - cron: '* * * * *'
  workflow_dispatch:  # Allow manual trigger

jobs:
  populate-queue:
    runs-on: ubuntu-latest
    steps:
      - name: Populate Analysis Queue
        run: |
          curl -X POST \
            https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json"

  process-queue:
    runs-on: ubuntu-latest
    steps:
      - name: Process Analysis Queue
        run: |
          curl -X POST \
            https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json"
```

**Setup:**
1. Add `SUPABASE_SERVICE_ROLE_KEY` to GitHub Secrets
2. Replace `YOUR_PROJECT_REF` with your project reference

---

### **Option C: Using Supabase Edge Function Scheduler (if available)**

Some Supabase plans support scheduled edge functions. Check your dashboard for "Scheduled Functions" or "Cron Jobs" section.

---

## **STEP 3: VERIFY DEPLOYMENT**

### **3.1 Test Functions Manually**

#### **Test `ai-analyze-daily`:**
```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/ai-analyze-daily \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "entry_id": "YOUR_ENTRY_ID",
    "user_id": "YOUR_USER_ID"
  }'
```

#### **Test `ai-analyze-monthly`:**
```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/ai-analyze-monthly \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "YOUR_USER_ID",
    "month_start": "2024-01-01"
  }'
```

#### **Test `populate-analysis-queue`:**
```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

#### **Test `process-ai-queue`:**
```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

---

### **3.2 Check Function Logs**

```bash
# View logs for a specific function
supabase functions logs ai-analyze-daily

# View logs for all functions
supabase functions logs
```

---

### **3.3 Verify Database Changes**

Run these queries in Supabase SQL Editor:

```sql
-- Check if analysis_queue table exists
SELECT COUNT(*) FROM analysis_queue;

-- Check if monthly_insights table exists
SELECT COUNT(*) FROM monthly_insights;

-- Check if homescreen_insights is dropped
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'homescreen_insights';
-- Should return 0 rows
```

---

## **STEP 4: MONITORING**

### **4.1 Monitor Queue Status**

```sql
-- View pending jobs
SELECT 
  analysis_type,
  COUNT(*) as pending_count
FROM analysis_queue
WHERE status = 'pending'
GROUP BY analysis_type;

-- View failed jobs
SELECT 
  id,
  analysis_type,
  error_message,
  attempts
FROM analysis_queue
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 10;
```

### **4.2 Monitor Function Performance**

Check Supabase Dashboard → Edge Functions → Logs for:
- Function execution times
- Error rates
- Success rates

---

## **STEP 5: ROLLBACK (IF NEEDED)**

If you need to rollback:

### **5.1 Rollback Functions**

```bash
# Deploy previous version (if you have it)
supabase functions deploy ai-analyze-daily --version PREVIOUS_VERSION

# Or redeploy from git history
git checkout PREVIOUS_COMMIT
supabase functions deploy ai-analyze-daily
```

### **5.2 Disable Cron Jobs**

```sql
-- Disable populate-analysis-queue cron
SELECT cron.unschedule('populate-analysis-queue');

-- Disable process-ai-queue cron
SELECT cron.unschedule('process-ai-queue');
```

---

## **QUICK DEPLOYMENT SCRIPT**

Create a file `deploy-all.sh`:

```bash
#!/bin/bash

echo "Deploying AI Analysis Functions..."

# Deploy updated functions
echo "Deploying ai-analyze-daily..."
supabase functions deploy ai-analyze-daily

echo "Deploying ai-analyze-monthly..."
supabase functions deploy ai-analyze-monthly

echo "Deploying process-ai-queue..."
supabase functions deploy process-ai-queue

echo "Deploying populate-analysis-queue..."
supabase functions deploy populate-analysis-queue

echo "✅ All functions deployed!"
echo "⚠️  Don't forget to set up cron jobs!"
```

Make it executable:
```bash
chmod +x deploy-all.sh
```

Run it:
```bash
./deploy-all.sh
```

---

## **ENVIRONMENT VARIABLES**

Ensure these are set in Supabase Dashboard → Edge Functions → Settings:

- `SUPABASE_URL` (auto-set)
- `SUPABASE_SERVICE_ROLE_KEY` (auto-set)
- `OPENAI_API_KEY` (you need to set this)

**To set OPENAI_API_KEY:**
```bash
supabase secrets set OPENAI_API_KEY=your_openai_api_key_here
```

Or via Dashboard: Settings → Edge Functions → Secrets

---

## **TROUBLESHOOTING**

### **Function deployment fails:**
- Check you're logged in: `supabase login`
- Check project is linked: `supabase projects list`
- Check function syntax: `deno check supabase/functions/FUNCTION_NAME/index.ts`

### **Cron jobs not running:**
- Verify pg_cron extension is enabled
- Check cron job exists: `SELECT * FROM cron.job;`
- Check cron logs: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`

### **Queue not populating:**
- Check `populate-analysis-queue` function logs
- Verify users have timezone set
- Check function is being called (cron or manual)

### **Queue not processing:**
- Check `process-ai-queue` function logs
- Verify queue has pending items
- Check function is being called (cron or manual)

---

## **NEXT STEPS**

After deployment:

1. ✅ **Run SQL migrations** (from `plan_supabase.md`)
2. ✅ **Deploy functions** (commands above)
3. ✅ **Set up cron jobs** (Option A, B, or C)
4. ✅ **Test functions** (Step 3)
5. ✅ **Monitor** (Step 4)
6. ✅ **Update Flutter app** (see `plan.md` Phase 3)

---

**END OF DEPLOYMENT COMMANDS**

