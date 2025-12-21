# **DEPLOYMENT GUIDE: Fix Jobs Stuck in Processing State**

## **📋 OVERVIEW**

This guide provides step-by-step instructions to deploy fixes that prevent jobs from getting stuck in 'processing' state.

**Estimated Time:** 5 minutes  
**Risk Level:** Very Low (only adds safety checks)  
**Breaking Changes:** None

---

## **✅ WHAT'S FIXED**

### **Critical Fixes**
1. ✅ **Filtered Jobs Reset** - Jobs filtered by timezone are reset to 'pending'
2. ✅ **Users Error Reset** - Jobs reset if users fetch fails
3. ✅ **Timezone Error Reset** - Jobs reset if timezone calculation fails
4. ✅ **Crash Handler Reset** - Safety net for unexpected crashes
5. ✅ **Auto-Reset Stuck Jobs** - Self-healing for old stuck jobs

---

## **🚀 DEPLOYMENT STEPS**

### **Step 1: Cleanup Existing Stuck Jobs (1 minute)**

**Run this SQL in Supabase Dashboard → SQL Editor:**

```sql
-- Reset jobs stuck in processing for > 10 minutes
UPDATE analysis_queue
SET status = 'pending'
WHERE status = 'processing'
  AND updated_at < NOW() - INTERVAL '10 minutes';

-- Verify cleanup
SELECT 
    COUNT(*) as stuck_jobs_reset,
    COUNT(*) FILTER (WHERE status = 'processing') as still_processing
FROM analysis_queue
WHERE updated_at < NOW() - INTERVAL '10 minutes';
```

**Expected:** Should show stuck jobs reset to 'pending'

---

### **Step 2: Deploy Updated Edge Function (1 minute)**

**From project root:**

```bash
# Deploy process-ai-queue function
supabase functions deploy process-ai-queue
```

**If not linked:**
```bash
supabase link --project-ref <your-project-ref>
supabase functions deploy process-ai-queue
```

**Expected:** `Deployed Function process-ai-queue`

---

### **Step 3: Verify Deployment (2 minutes)**

**Check Function Logs:**
```bash
supabase functions logs process-ai-queue --limit 20
```

**Test Function:**
```bash
# Manual invocation
supabase functions invoke process-ai-queue
```

**Check for Reset Messages:**
Look for logs like:
- `[PROCESS] Resetting X jobs that didn't pass timezone filter back to pending`
- `[PROCESS] ✅ Reset X filtered jobs to pending`
- `[PROCESS] Found X stuck jobs (>10 min), resetting to pending`

---

### **Step 4: Verify No Stuck Jobs (1 minute)**

**Check Queue Status:**
```sql
-- Check for stuck jobs
SELECT 
    id,
    analysis_type,
    status,
    attempts,
    updated_at,
    NOW() - updated_at as time_stuck
FROM analysis_queue
WHERE status = 'processing'
ORDER BY updated_at DESC;
```

**Expected:** 
- No jobs stuck > 10 minutes
- Recent jobs (< 10 min) are actively processing

---

## **✅ VALIDATION CHECKLIST**

After deployment, verify:

- [ ] Existing stuck jobs cleaned up (SQL query)
- [ ] Edge function deployed successfully
- [ ] Function logs show reset messages
- [ ] No new stuck jobs appear
- [ ] Normal processing still works
- [ ] Failed jobs retry correctly
- [ ] Timezone filtering works correctly

---

## **🔍 TESTING SCENARIOS**

### **Test 1: Timezone Filter Reset**
1. Create entry today (before midnight)
2. Wait for cron to run
3. Verify job is claimed but filtered out
4. Check logs for reset message
5. Verify job status = 'pending' (not stuck)

### **Test 2: Error Handling**
1. Manually trigger function
2. Check logs for any reset messages
3. Verify no jobs stuck in 'processing'

### **Test 3: Auto-Reset Stuck Jobs**
1. Manually set a job to 'processing' with old timestamp
2. Wait for next cron run
3. Verify job is auto-reset to 'pending'

---

## **📊 MONITORING**

### **Key Metrics to Watch**

```sql
-- Stuck jobs count (should be 0)
SELECT COUNT(*) 
FROM analysis_queue 
WHERE status = 'processing' 
  AND updated_at < NOW() - INTERVAL '10 minutes';

-- Jobs by status
SELECT status, COUNT(*) 
FROM analysis_queue 
GROUP BY status;

-- Recent processing activity
SELECT 
    status,
    COUNT(*) as count,
    MAX(updated_at) as latest_update
FROM analysis_queue
WHERE updated_at > NOW() - INTERVAL '1 hour'
GROUP BY status;
```

---

## **🐛 TROUBLESHOOTING**

### **Issue: Jobs Still Getting Stuck**

**Check:**
1. Verify function is deployed (check logs)
2. Check for reset messages in logs
3. Verify SQL cleanup ran successfully
4. Check for errors in function logs

**Solution:**
```sql
-- Manual reset if needed
UPDATE analysis_queue
SET status = 'pending'
WHERE status = 'processing'
  AND updated_at < NOW() - INTERVAL '5 minutes';
```

### **Issue: Too Many Resets**

**Check:**
- Verify timezone calculations are correct
- Check if jobs are being claimed too early
- Review logs for patterns

**Solution:**
- This is expected behavior - jobs reset when filtered
- They'll be processed when ready (target_date <= yesterday)

---

## **📝 CHANGES SUMMARY**

### **Code Changes**
- ✅ Added reset logic for filtered-out jobs
- ✅ Added reset on users fetch error
- ✅ Added reset on timezone calculation error
- ✅ Added reset in error handler (safety net)
- ✅ Added auto-reset for old stuck jobs

### **No Breaking Changes**
- ✅ All existing functionality preserved
- ✅ No database schema changes
- ✅ No API changes
- ✅ Backward compatible

---

## **🎯 SUCCESS CRITERIA**

After deployment:
- ✅ No jobs stuck in 'processing' > 10 minutes
- ✅ Filtered jobs automatically reset
- ✅ Error scenarios handled gracefully
- ✅ Self-healing mechanism active
- ✅ Normal processing unaffected

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-05  
**Status:** Ready for Deployment

