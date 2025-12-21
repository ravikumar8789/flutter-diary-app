# **DEPLOYMENT GUIDE: Target Date UTC Conversion & Infinite Recursion Fix**

## **📋 QUICK OVERVIEW**

**What Changed:**
- `target_date` now stores UTC date (entry_date + 1 day converted to UTC)
- SQL-level filtering with time check prevents same-day early processing
- Removed per-job timezone calculations (faster processing)
- Fixed infinite recursion issue
- **No `next_retry_at` used** (avoids unnecessary delays)

**Time Required:** 10-15 minutes  
**Risk Level:** Low (backward compatible)

---

## **🚀 DEPLOYMENT STEPS**

### **Step 1: Update Database Functions**

**Location:** Supabase Dashboard → SQL Editor

**1.1 Update `process_analysis_queue_batch` function:**

Copy and run this SQL:

```sql
-- This updates the function to calculate target_date as (entry_date + 1 day) → UTC
-- See: supabase/migrations/004_process_analysis_queue_batch.sql
```

**OR** run the migration file directly:
```bash
# If using Supabase CLI
supabase db push
```

**Verification:**
```sql
-- Test the function
SELECT * FROM process_analysis_queue_batch();
-- Should return counts without errors
```

---

**1.2 Update `claim_pending_jobs` function:**

Copy and run this SQL (includes time check to prevent same-day early processing):

```sql
-- This adds target_date filter with time check:
-- target_date < CURRENT_DATE OR (target_date = CURRENT_DATE AND hour >= 10)
-- Prevents same-day early processing (most timezones have tomorrow midnight between 10:00-14:00 UTC)
-- See: supabase/migrations/006_remove_next_retry_at_logic.sql (lines 33-45)
```

**OR** run the migration file directly:
```bash
# If using Supabase CLI
supabase db push
```

**Verification:**
```sql
-- Test the function
SELECT * FROM claim_pending_jobs(5);
-- Should only return jobs with:
-- - target_date < CURRENT_DATE (past dates)
-- - OR target_date = CURRENT_DATE AND current hour >= 10 (same day, after 10:00 UTC)
```

---

### **Step 2: Deploy Edge Function**

**Location:** Terminal (in project root)

```bash
# Deploy process-ai-queue function
supabase functions deploy process-ai-queue
```

**Verification:**
```bash
# Check function logs
supabase functions logs process-ai-queue --limit 10
```

---

### **Step 3: Verify Deployment**

**3.1 Check Queue Processing:**

```sql
-- Check pending jobs
SELECT 
    id, 
    analysis_type, 
    target_date, 
    status,
    created_at
FROM analysis_queue 
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 10;
```

**Expected:**
- New jobs should have `target_date` as UTC date
- Only jobs with `target_date <= CURRENT_DATE` should be claimable

---

**3.2 Monitor Processing:**

```bash
# Watch function logs in real-time
supabase functions logs process-ai-queue --follow
```

**Look for:**
- ✅ `Progress made, self-invoking next batch` (when eligible jobs exist)
- ✅ `No progress made, skipping self-invocation` (when only ineligible jobs remain)
- ❌ No infinite recursion loops

---

**3.3 Test with Sample Data:**

```sql
-- Create a test entry (if needed)
-- The populate-analysis-queue cron will pick it up
-- Check target_date calculation
SELECT 
    aq.id,
    aq.analysis_type,
    aq.target_date,
    e.entry_date,
    u.timezone
FROM analysis_queue aq
JOIN entries e ON e.id = aq.entry_id
JOIN users u ON u.id = aq.user_id
WHERE aq.status = 'pending'
ORDER BY aq.created_at DESC
LIMIT 5;
```

**Expected:**
- Daily jobs: `target_date` = UTC date when tomorrow midnight occurs
- Weekly/Monthly: `target_date` = week_start/month_start (unchanged)

---

## **✅ SUCCESS CRITERIA**

1. ✅ New jobs have correct `target_date` (UTC date)
2. ✅ Only eligible jobs are claimed (`target_date <= CURRENT_DATE`)
3. ✅ No infinite recursion (logs show progress check)
4. ✅ Processing is faster (no per-job timezone calculations)
5. ✅ All job types work (daily, weekly, monthly, catchup)

---

## **🔄 ROLLBACK PLAN**

If issues occur:

**1. Revert Edge Function:**
```bash
# Deploy previous version
git checkout HEAD~1 supabase/functions/process-ai-queue/index.ts
supabase functions deploy process-ai-queue
```

**2. Revert Database Functions:**
```sql
-- Revert to previous version
-- Run the old SQL from backup or git history
```

**3. Clean Up Stuck Jobs (if needed):**
```sql
-- Reset stuck jobs
UPDATE analysis_queue
SET status = 'pending'
WHERE status = 'processing'
  AND updated_at < NOW() - INTERVAL '10 minutes';
```

---

## **📝 NOTES**

- **Backward Compatible:** Old jobs will still be processed correctly
- **No App Changes:** Flutter app doesn't need updates
- **Weekly/Monthly:** Unchanged (still use week_start/month_start)
- **DST Safe:** PostgreSQL handles timezone transitions automatically

---

## **🐛 TROUBLESHOOTING**

**Issue: Jobs not being processed**
- Check: `target_date <= CURRENT_DATE` filter
- Verify: Jobs have correct `target_date` values
- Solution: Wait for next hour (when CURRENT_DATE matches)

**Issue: Infinite recursion**
- Check: Logs for "No progress made" message
- Verify: Progress check is working
- Solution: Should be fixed by this deployment

**Issue: Wrong target_date values**
- Check: User timezone is correct
- Verify: SQL function calculation
- Solution: Re-run migration

---

**Deployment Date:** ___________  
**Deployed By:** ___________  
**Status:** ☐ Pending | ☐ Deployed | ☐ Verified

