# **IMPLEMENTATION CHECKLIST - AI INSIGHTS REFINEMENT**

## **PRE-IMPLEMENTATION**

### **Files Updated:**
- ✅ `supabase/functions/populate-analysis-queue/index.ts` - Updated with new logic
- ✅ `supabase/functions/process-ai-queue/index.ts` - Updated to process only yesterday's queue
- ✅ `bc/AI/refinev2/supabase_queries.md` - SQL queries for cron schedule updates

---

## **STEP-BY-STEP IMPLEMENTATION**

### **STEP 1: Deploy Edge Functions**

Deploy the updated functions to Supabase:

```bash
# Deploy populate-analysis-queue
supabase functions deploy populate-analysis-queue

# Deploy process-ai-queue
supabase functions deploy process-ai-queue
```

**Expected Output:**
- Functions deployed successfully
- No errors in deployment logs

---

### **STEP 2: Update Cron Schedules in Supabase**

Follow the step-by-step guide in `supabase_queries.md`:

1. **Get your project details:**
   - Project reference (from Dashboard → Settings → API)
   - Service role key (from Dashboard → Settings → API)

2. **Check current cron jobs:**
   ```sql
   SELECT * FROM cron.job;
   ```

3. **Unschedule `process-ai-queue`:**
   ```sql
   SELECT cron.unschedule('process-ai-queue');
   ```

4. **Recreate `populate-analysis-queue` (optional, or keep existing):**
   - Schedule: `'*/5 * * * *'` (every 5 minutes)
   - See `supabase_queries.md` Step 4 for full query

5. **Recreate `process-ai-queue` with new schedule:**
   - Schedule: `'0 0 * * *'` (midnight only)
   - See `supabase_queries.md` Step 5 for full query

6. **Verify cron jobs:**
   ```sql
   SELECT jobid, schedule, jobname FROM cron.job;
   ```

---

### **STEP 3: Test Queue Population**

1. **Manually trigger `populate-analysis-queue`:**
   - Use SQL query from `supabase_queries.md` Step 8.1
   - Or use Supabase Dashboard → Edge Functions → Invoke

2. **Check queue status:**
   ```sql
   SELECT target_date, analysis_type, status, COUNT(*) 
   FROM analysis_queue 
   WHERE status = 'pending'
   GROUP BY target_date, analysis_type, status;
   ```

3. **Verify today's entries are queued:**
   ```sql
   SELECT * FROM analysis_queue 
   WHERE target_date = CURRENT_DATE 
     AND status = 'pending';
   ```

**Expected Result:**
- Today's entries should be queued with `target_date = today`
- Catch-up entries (previous dates) should also be queued

---

### **STEP 4: Test Processing (Manual)**

**⚠️ Only test if you have jobs with `target_date = yesterday`**

1. **Manually trigger `process-ai-queue`:**
   - Use SQL query from `supabase_queries.md` Step 8.3
   - Or use Supabase Dashboard → Edge Functions → Invoke

2. **Check processing results:**
   ```sql
   SELECT * FROM analysis_queue 
   WHERE target_date = CURRENT_DATE - INTERVAL '1 day'
   ORDER BY processed_at DESC;
   ```

**Expected Result:**
- Only yesterday's jobs should be processed
- Today's jobs should remain `pending`

---

### **STEP 5: Monitor First 24 Hours**

1. **Check queue population (every 5 minutes):**
   - Verify entries are being queued throughout the day
   - Check logs in Supabase Dashboard → Edge Functions → Logs

2. **Check midnight processing:**
   - At 12:00 AM, verify `process-ai-queue` runs
   - Check that yesterday's jobs are processed
   - Verify insights are created in `entry_insights` table

3. **Monitor for errors:**
   ```sql
   SELECT * FROM analysis_queue 
   WHERE status = 'failed' 
   ORDER BY processed_at DESC 
   LIMIT 10;
   ```

---

## **VERIFICATION CHECKLIST**

### **Queue Population:**
- [ ] `populate-analysis-queue` runs every 5 minutes
- [ ] Today's entries are queued with `target_date = today`
- [ ] Catch-up entries (previous dates) are queued
- [ ] Entry completion is checked before queuing
- [ ] Logs show queue operations

### **Queue Processing:**
- [ ] `process-ai-queue` runs only at midnight
- [ ] Only yesterday's queue is processed (`target_date = yesterday`)
- [ ] Today's queue remains pending until next day
- [ ] Jobs are processed in batches (10 per run)
- [ ] Insights are saved to `entry_insights` table

### **Weekly Analysis:**
- [ ] Weekly jobs are queued on Sunday at midnight
- [ ] Weekly analysis processes correctly
- [ ] Insights saved to `weekly_insights` table

### **Monthly Analysis:**
- [ ] Monthly jobs are queued on 1st of month at midnight
- [ ] Monthly analysis processes correctly
- [ ] Insights saved to `monthly_insights` table

---

## **ROLLBACK PLAN**

If issues occur:

1. **Revert edge functions:**
   ```bash
   # Deploy previous versions
   git checkout HEAD~1 supabase/functions/populate-analysis-queue
   git checkout HEAD~1 supabase/functions/process-ai-queue
   supabase functions deploy populate-analysis-queue
   supabase functions deploy process-ai-queue
   ```

2. **Revert cron schedule:**
   ```sql
   -- Change back to every minute
   SELECT cron.unschedule('process-ai-queue');
   SELECT cron.schedule(
     'process-ai-queue',
     '* * * * *',  -- Every minute (old schedule)
     $$ ... $$  -- Your function call
   );
   ```

---

## **SUCCESS CRITERIA**

✅ Queue population works every 5 minutes  
✅ Today's entries are queued throughout the day  
✅ Catch-up analysis queues previous date entries  
✅ Processing runs only at midnight  
✅ Only yesterday's queue is processed  
✅ Insights are created successfully  
✅ No errors in logs  
✅ Users see insights in the morning  

---

## **END OF CHECKLIST**

Follow this checklist step by step to ensure successful implementation.

