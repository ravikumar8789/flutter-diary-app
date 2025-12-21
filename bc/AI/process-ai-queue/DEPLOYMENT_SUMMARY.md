# **🚀 QUICK DEPLOYMENT GUIDE**

## **⚡ 5-Minute Deployment**

### **Step 1: Database Migration (2 minutes)**

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project
   - Click **SQL Editor** → **New query**

2. **Run Migration**
   - Copy entire contents of: `supabase/migrations/006_remove_next_retry_at_logic.sql`
   - Paste into SQL Editor
   - Click **Run** (or `Ctrl+Enter`)

3. **Verify Success**
   ```sql
   -- Test claim_pending_jobs
   SELECT * FROM claim_pending_jobs(5);
   
   -- Test process_analysis_queue_batch
   SELECT * FROM process_analysis_queue_batch();
   ```

✅ **Expected:** Should return results without errors

---

### **Step 2: Deploy Edge Function (1 minute)**

**From project root directory:**

```bash
# Deploy process-ai-queue function
supabase functions deploy process-ai-queue
```

**If not linked:**
```bash
# Link to project first
supabase link --project-ref <your-project-ref>

# Then deploy
supabase functions deploy process-ai-queue
```

✅ **Expected:** `Deployed Function process-ai-queue`

---

### **Step 3: Verify (2 minutes)**

**Check Function Logs:**
```bash
supabase functions logs process-ai-queue --limit 20
```

**Test Function:**
```bash
# Manual invocation
supabase functions invoke process-ai-queue
```

**Check Queue:**
```sql
-- Verify pending jobs
SELECT 
    id,
    analysis_type,
    target_date,
    status,
    attempts,
    next_retry_at  -- Should be NULL for new jobs
FROM analysis_queue
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 10;
```

✅ **Expected:** 
- Function runs without errors
- Jobs process correctly
- `next_retry_at` is NULL for new jobs

---

## **📋 What Changed?**

| Component | Change |
|-----------|--------|
| **Edge Function** | Removed `next_retry_at` assignment and checks |
| **claim_pending_jobs** | Removed `next_retry_at <= NOW()` filter |
| **process_analysis_queue_batch** | Removed `next_retry_at` calculation |
| **Database Index** | Changed from 3 columns to 2 columns |

---

## **✅ Verification Checklist**

- [ ] Database migration executed successfully
- [ ] Edge function deployed without errors
- [ ] Function logs show no errors
- [ ] Pending jobs can be queried
- [ ] New jobs have `next_retry_at = NULL`
- [ ] Jobs process correctly on next hour cron

---

## **🐛 Quick Troubleshooting**

**Migration fails?**
- Check SQL syntax
- Verify you're in correct project
- Check function dependencies exist

**Function deploy fails?**
```bash
# Check Supabase CLI
supabase --version

# Check login
supabase projects list

# Try with debug
supabase functions deploy process-ai-queue --debug
```

**Jobs not processing?**
```sql
-- Check pending jobs
SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';

-- Check target_date
SELECT target_date, CURRENT_DATE - 1 as yesterday 
FROM analysis_queue 
WHERE status = 'pending';
```

---

## **📚 Full Documentation**

- **Implementation Report:** `process-aiqueue-refine1.md`
- **Detailed Deployment:** `DEPLOYMENT_GUIDE.md`
- **Quick Reference:** `QUICK_REFERENCE.md`

---

**Total Time:** ~5 minutes  
**Risk Level:** Low  
**Rollback:** Easy (revert code only)

