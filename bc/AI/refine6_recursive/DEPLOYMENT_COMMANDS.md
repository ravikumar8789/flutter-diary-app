# **DEPLOYMENT COMMANDS - RECURSIVE SELF-INVOCATION**

## **📋 PREREQUISITES**

1. Ensure you have Supabase CLI installed and logged in
2. Ensure you're in the project root directory
3. Ensure you have database access (SQL Editor in Supabase Dashboard)

---

## **STEP 1: APPLY DATABASE MIGRATION**

### **Option A: Using Supabase CLI (Recommended)**

```bash
# Navigate to project root
cd /path/to/diaryapp

# Apply migration
supabase db push

# Verify migration applied
supabase db diff
```

### **Option B: Using SQL Dashboard (Manual)**

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `supabase/migrations/005_atomic_job_claiming.sql`
3. Paste and execute in SQL Editor
4. Verify function created:

```sql
-- Verify function exists
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'claim_pending_jobs';

-- Test function (should return empty if no pending jobs)
SELECT * FROM claim_pending_jobs(5, NOW());

-- Verify updated_at column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'analysis_queue' 
AND column_name = 'updated_at';
```

**Expected Results:**
- Function `claim_pending_jobs` should exist
- Column `updated_at` should exist in `analysis_queue` table
- Test query should execute without errors

---

## **STEP 2: DEPLOY EDGE FUNCTION**

```bash
# Deploy updated process-ai-queue function
supabase functions deploy process-ai-queue

# Verify deployment
supabase functions list | grep process-ai-queue
```

**Expected Output:**
```
process-ai-queue  deployed
```

---

## **STEP 3: VERIFY DEPLOYMENT**

### **3.1 Check Function Logs**

```bash
# View recent logs
supabase functions logs process-ai-queue --limit 20
```

### **3.2 Test Function Manually**

**Option A: Using Supabase Dashboard**
1. Go to Edge Functions → `process-ai-queue`
2. Click "Invoke" button
3. Use empty body `{}` (cron-triggered simulation)
4. Check response and logs

**Option B: Using cURL**

```bash
# Get your Supabase URL and anon key
SUPABASE_URL="https://your-project.supabase.co"
ANON_KEY="your-anon-key"

# Test function (cron-triggered)
curl -X POST \
  "${SUPABASE_URL}/functions/v1/process-ai-queue" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{}'

# Test function (recursive)
curl -X POST \
  "${SUPABASE_URL}/functions/v1/process-ai-queue" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"recursive": true, "batch_number": 1}'
```

---

## **STEP 4: VERIFY DATABASE FUNCTION**

### **4.1 Test Atomic Job Claiming**

```sql
-- Create a test job (if needed)
INSERT INTO analysis_queue (
  user_id,
  analysis_type,
  target_date,
  entry_id,
  status,
  next_retry_at
) VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'daily',
  CURRENT_DATE - INTERVAL '1 day',
  '00000000-0000-0000-0000-000000000001'::uuid,
  'pending',
  NOW()
);

-- Test claiming function
SELECT * FROM claim_pending_jobs(1, NOW());

-- Verify job status changed to 'processing'
SELECT id, status, updated_at 
FROM analysis_queue 
WHERE status = 'processing' 
ORDER BY updated_at DESC 
LIMIT 5;
```

---

## **STEP 5: MONITORING QUERIES**

### **5.1 Check Processing Stats**

```sql
-- Overall processing stats (last 24 hours)
SELECT 
  status,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (processed_at - created_at))) as avg_processing_time_seconds
FROM analysis_queue
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY status
ORDER BY status;
```

### **5.2 Check Active Processing**

```sql
-- Jobs currently being processed
SELECT COUNT(*) as active_jobs
FROM analysis_queue
WHERE status = 'processing'
  AND updated_at >= NOW() - INTERVAL '10 minutes';
```

### **5.3 Check Pending Jobs**

```sql
-- Pending jobs ready to process
SELECT COUNT(*) as pending_jobs
FROM analysis_queue
WHERE status = 'pending'
  AND next_retry_at <= NOW();
```

### **5.4 Check Recent Processing**

```sql
-- Recent processing activity
SELECT 
  DATE_TRUNC('hour', processed_at) as hour,
  COUNT(*) as jobs_completed,
  AVG(EXTRACT(EPOCH FROM (processed_at - created_at))) as avg_time_seconds
FROM analysis_queue
WHERE status = 'completed'
  AND processed_at >= NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC
LIMIT 24;
```

---

## **STEP 6: ROLLBACK (IF NEEDED)**

### **6.1 Revert Edge Function**

```bash
# Revert to previous version (if using git)
git checkout HEAD~1 supabase/functions/process-ai-queue/index.ts

# Redeploy
supabase functions deploy process-ai-queue
```

### **6.2 Keep Database Changes**

- ✅ Database function `claim_pending_jobs()` is backward compatible
- ✅ Can be used by old function version
- ✅ No rollback needed for DB changes

---

## **✅ VERIFICATION CHECKLIST**

- [ ] Database migration applied successfully
- [ ] Function `claim_pending_jobs()` exists and works
- [ ] Column `updated_at` exists in `analysis_queue` table
- [ ] Edge function deployed successfully
- [ ] Function logs show no errors
- [ ] Manual test returns success response
- [ ] Monitoring queries return expected results

---

## **🚨 TROUBLESHOOTING**

### **Issue: Migration fails**

**Error:** `function claim_pending_jobs already exists`

**Solution:**
```sql
-- Drop and recreate
DROP FUNCTION IF EXISTS public.claim_pending_jobs(integer, timestamptz);
-- Then re-run migration
```

### **Issue: Function deployment fails**

**Error:** `Function not found` or deployment timeout

**Solution:**
```bash
# Check function exists locally
ls supabase/functions/process-ai-queue/

# Verify Supabase link
supabase link --project-ref your-project-ref

# Try deployment again
supabase functions deploy process-ai-queue --no-verify-jwt
```

### **Issue: Self-invocation not working**

**Check:**
1. Function logs for self-invoke errors
2. Database for remaining pending jobs
3. Cron schedule (should still run hourly as backup)

**Debug:**
```sql
-- Check if jobs are stuck
SELECT COUNT(*) 
FROM analysis_queue 
WHERE status = 'processing' 
AND updated_at < NOW() - INTERVAL '10 minutes';
```

---

## **📊 POST-DEPLOYMENT MONITORING**

Monitor for 24-48 hours after deployment:

1. **Processing Time:** Should see batches completing in 80-100 seconds
2. **Self-Invocation:** Check logs for recursive batch messages
3. **Success Rate:** Should be >95% jobs completed
4. **Cron Skips:** Should see occasional "skipping cron run" messages
5. **No Duplicates:** Verify no jobs processed twice

---

**End of Deployment Guide**

