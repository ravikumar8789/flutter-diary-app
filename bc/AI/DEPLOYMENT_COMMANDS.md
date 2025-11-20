# Deployment Commands - AI Feature

## **Prerequisites**

1. Supabase CLI installed and logged in
2. All database migrations completed (Steps 1-5 from `ai_plan_final1_supabase.md`)
3. Environment variables set in Supabase dashboard

---

## **STEP 1: Deploy Modified ai-analyze-daily Function**

```bash
cd supabase/functions
supabase functions deploy ai-analyze-daily
```

**Verify:**
- Function deployed successfully
- No errors in deployment logs

---

## **STEP 2: Deploy New process-ai-queue Function**

```bash
supabase functions deploy process-ai-queue
```

**Verify:**
- Function created successfully
- Can be invoked manually for testing

---

## **STEP 3: Deploy New scheduled-daily-analysis Function**

```bash
supabase functions deploy scheduled-daily-analysis
```

**Verify:**
- Function created successfully
- Can be invoked manually for testing

---

## **STEP 4: Test Functions Manually**

### **Test ai-analyze-daily:**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"entry_id": "YOUR_ENTRY_ID", "user_id": "YOUR_USER_ID"}' \
  "YOUR_SUPABASE_URL/functions/v1/ai-analyze-daily"
```

### **Test process-ai-queue:**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "YOUR_SUPABASE_URL/functions/v1/process-ai-queue"
```

### **Test scheduled-daily-analysis:**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "YOUR_SUPABASE_URL/functions/v1/scheduled-daily-analysis"
```

---

## **STEP 5: Set Up Scheduled Execution**

### **Option A: Using Supabase Dashboard (Recommended)**

1. Go to Supabase Dashboard → Database → Cron Jobs
2. Create new cron job for `process-ai-queue`:
   - Schedule: `*/1 * * * *` (every minute)
   - Function: `process-ai-queue`
   - Method: POST
   - Headers: `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`

3. Create new cron job for `scheduled-daily-analysis`:
   - Schedule: `0 0 * * *` (daily at midnight UTC)
   - Function: `scheduled-daily-analysis`
   - Method: POST
   - Headers: `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`

### **Option B: Using GitHub Actions**

Create `.github/workflows/supabase-cron.yml`:

```yaml
name: Supabase AI Cron Jobs

on:
  schedule:
    - cron: '*/1 * * * *'  # Every minute (process queue)
    - cron: '0 0 * * *'     # Daily at midnight (scheduled analysis)
  workflow_dispatch:

jobs:
  process-queue:
    runs-on: ubuntu-latest
    if: github.event.schedule == '*/1 * * * *' || github.event_name == 'workflow_dispatch'
    steps:
      - name: Process AI Queue
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/process-ai-queue"

  daily-analysis:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 0 * * *'
    steps:
      - name: Scheduled Daily Analysis
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/scheduled-daily-analysis"
```

**Set GitHub Secrets:**
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

---

## **STEP 6: Verify Deployment**

### **Check Functions:**
```bash
supabase functions list
```

Should show:
- `ai-analyze-daily`
- `process-ai-queue`
- `scheduled-daily-analysis`

### **Check Database:**
```sql
-- Verify tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('homescreen_insights', 'ai_analysis_queue');

-- Verify functions exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('check_entry_completion', 'queue_ai_analysis_on_completion');

-- Verify triggers exist
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public' 
AND trigger_name LIKE 'trigger_ai_%';
```

---

## **STEP 7: Monitor Functions**

### **View Function Logs:**
```bash
supabase functions logs ai-analyze-daily
supabase functions logs process-ai-queue
supabase functions logs scheduled-daily-analysis
```

### **Check Queue Status:**
```sql
-- Unprocessed items
SELECT COUNT(*) FROM ai_analysis_queue WHERE processed = false;

-- Recent queue activity
SELECT * FROM ai_analysis_queue 
ORDER BY created_at DESC 
LIMIT 10;
```

### **Check Insights:**
```sql
-- Recent homescreen insights
SELECT * FROM homescreen_insights 
ORDER BY generated_at DESC 
LIMIT 5;

-- Recent entry insights
SELECT * FROM entry_insights 
WHERE status = 'success'
ORDER BY processed_at DESC 
LIMIT 5;
```

---

## **TROUBLESHOOTING**

### **Function Not Deploying:**
- Check Supabase CLI is logged in: `supabase login`
- Verify project linked: `supabase link --project-ref YOUR_PROJECT_REF`
- Check function syntax errors

### **Queue Not Processing:**
- Verify cron job is running
- Check function logs for errors
- Verify queue has items: `SELECT * FROM ai_analysis_queue WHERE processed = false`

### **Insights Not Saving:**
- Check OpenAI API key is set
- Verify `homescreen_insights` table exists
- Check function logs for errors

---

## **ROLLBACK (if needed)**

### **Disable Functions:**
```bash
# Functions can't be "disabled" but you can remove triggers
# See Step 12 in ai_plan_final1_supabase.md for SQL rollback
```

### **Remove Cron Jobs:**
- Delete from Supabase Dashboard → Database → Cron Jobs
- Or remove GitHub Actions workflow file

---

**End of Deployment Commands**
