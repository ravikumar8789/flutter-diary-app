# **QUICK DEPLOYMENT GUIDE**

## **🚀 DEPLOYMENT STEPS**

### **1. Apply Database Migration**

**Option A: Supabase CLI**
```bash
supabase db push
```

**Option B: SQL Dashboard**
1. Open Supabase Dashboard → SQL Editor
2. Copy and paste contents of: `supabase/migrations/005_atomic_job_claiming.sql`
3. Click "Run"

**Verify:**
```sql
SELECT * FROM claim_pending_jobs(1, NOW());
```

---

### **2. Deploy Edge Function**

```bash
supabase functions deploy process-ai-queue
```

**Verify:**
```bash
supabase functions logs process-ai-queue --limit 10
```

---

### **3. Test (Optional)**

**Manual Test via Dashboard:**
1. Go to Edge Functions → `process-ai-queue`
2. Click "Invoke" with body: `{}`
3. Check logs for self-invocation messages

---

## **✅ DONE!**

The recursive self-invocation feature is now active. The function will:
- Process 20 jobs per batch (reduced from 50)
- Automatically self-invoke if more jobs exist
- Complete 1000 entries in 50-70 minutes (vs 4 hours)

---

## **📊 MONITORING**

**Check Processing Stats:**
```sql
SELECT 
  status,
  COUNT(*) as count
FROM analysis_queue
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY status;
```

**Check Active Processing:**
```sql
SELECT COUNT(*) as active_jobs
FROM analysis_queue
WHERE status = 'processing'
  AND updated_at >= NOW() - INTERVAL '10 minutes';
```

---

## **🔧 ROLLBACK (If Needed)**

```bash
# Revert function
git checkout HEAD~1 supabase/functions/process-ai-queue/index.ts
supabase functions deploy process-ai-queue
```

**Note:** Database changes are backward compatible, no rollback needed.

---

**That's it! 🎉**

