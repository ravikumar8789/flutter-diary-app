# **QUICK REFERENCE: Removing `next_retry_at` Logic**

## **🚀 Quick Deploy Commands**

### **1. Database Changes (Supabase Dashboard → SQL Editor)**

```sql
-- Run the migration file
-- Copy contents from: supabase/migrations/006_remove_next_retry_at_logic.sql
-- Or run individual steps from DEPLOYMENT_GUIDE.md
```

### **2. Deploy Edge Function**

```bash
# From project root
supabase functions deploy process-ai-queue

# Or with project ref
supabase functions deploy process-ai-queue --project-ref <your-project-ref>
```

### **3. Verify**

```bash
# Check logs
supabase functions logs process-ai-queue --limit 20

# Test function
supabase functions invoke process-ai-queue
```

---

## **📝 What Changed?**

### **Edge Function (`process-ai-queue/index.ts`)**
- ✅ Removed exponential backoff calculation
- ✅ Removed `next_retry_at` assignment on retry
- ✅ Removed `next_retry_at` check for remaining jobs
- ✅ Removed `p_max_retry_at` parameter (optional)

### **Database Functions**
- ✅ `claim_pending_jobs`: Removed `next_retry_at <= NOW()` check
- ✅ `process_analysis_queue_batch`: Removed `next_retry_at` calculation and insertion
- ✅ Index: Changed from `(status, next_retry_at, created_at)` to `(status, created_at)`

---

## **✅ What Still Works?**

- ✅ Hourly cron processing
- ✅ `target_date <= yesterday` filtering (prevents today's entries)
- ✅ Retry logic (hourly, not exponential)
- ✅ Atomic job claiming
- ✅ Batch processing
- ✅ Recursive self-invocation

---

## **🔍 Key Points**

1. **No `next_retry_at` needed** - Hourly cron provides natural retry timing
2. **`target_date` filter is sufficient** - Prevents processing today's entries
3. **Simpler = Better** - Less code, fewer edge cases, better performance
4. **Backward compatible** - Column remains, old values ignored

---

## **📊 Before vs After**

| Aspect | Before | After |
|--------|--------|-------|
| Retry Timing | Exponential (2, 4, 8 min) | Hourly (cron) |
| Index Size | 3 columns | 2 columns (33% smaller) |
| Query Complexity | Time + Date check | Date check only |
| Code Complexity | Higher | Lower |
| Reliability | Good | Better |

---

## **🐛 Troubleshooting**

**Jobs not processing?**
```sql
-- Check pending jobs
SELECT COUNT(*) FROM analysis_queue WHERE status = 'pending';

-- Check target_date
SELECT target_date, CURRENT_DATE - 1 as yesterday 
FROM analysis_queue 
WHERE status = 'pending' 
LIMIT 10;
```

**Function errors?**
```bash
# Check logs
supabase functions logs process-ai-queue --limit 50
```

**Index issues?**
```sql
-- Verify index exists
SELECT indexname FROM pg_indexes 
WHERE tablename = 'analysis_queue';
```

---

## **📚 Full Documentation**

- **Implementation Report:** `process-aiqueue-refine1.md`
- **Deployment Guide:** `DEPLOYMENT_GUIDE.md`
- **Migration File:** `supabase/migrations/006_remove_next_retry_at_logic.sql`

---

**Last Updated:** 2025-01-XX

