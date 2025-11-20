# **AI ERROR TRACKING SYSTEM - SUMMARY**

## **✅ WHAT WAS CREATED**

### **1. Error Logger Function**
**File:** `supabase/functions/_shared/ai_error_logger.ts`
- Comprehensive error logging helper
- Auto-detects error type and severity
- Captures all context (request body, stack trace, etc.)

### **2. Updated Edge Functions**
- `ai-analyze-daily/index.ts` - Now logs to `ai_errors_log`
- `ai-analyze-weekly/index.ts` - Now logs to `ai_errors_log`

### **3. Database Migration**
- `002_ai_errors_log.sql` - Complete migration
- `002_ai_errors_log_step_by_step.sql` - Step-by-step version

---

## **🚀 DEPLOYMENT STEPS**

### **STEP 1: Run SQL in Supabase**

**Go to:** Supabase Dashboard → SQL Editor

**Copy and run:**
```sql
-- (Full SQL from 002_ai_errors_log_step_by_step.sql)
```

**OR run sections separately** (see `002_ai_errors_log_step_by_step.sql`)

---

### **STEP 2: Deploy Functions**

**Command:**
```bash
cd C:\Users\mrrav\OneDrive\Desktop\diaryapp
supabase functions deploy ai-analyze-daily
supabase functions deploy ai-analyze-weekly
```

**If not linked:**
```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy ai-analyze-daily
supabase functions deploy ai-analyze-weekly
```

---

### **STEP 3: Verify**

**Check table:**
```sql
SELECT COUNT(*) FROM ai_errors_log;
```

**Check functions:**
- Supabase Dashboard → Edge Functions → Both should be listed

---

## **📊 WHAT GETS LOGGED**

Every AI function error now captures:
- ✅ Error code & message
- ✅ Error type (OpenAI, Supabase, Network, etc.)
- ✅ Severity (CRITICAL, HIGH, MEDIUM, LOW)
- ✅ Request body & duration
- ✅ Stack trace
- ✅ Failed step (fetch_entry, call_openai, save_insight, etc.)
- ✅ User & entry context
- ✅ System info (Deno version, environment)

---

## **🔍 ANALYSIS QUERIES**

**Error rate by type:**
```sql
SELECT error_type, COUNT(*) 
FROM ai_errors_log 
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY error_type;
```

**Unresolved errors:**
```sql
SELECT * FROM ai_errors_log 
WHERE resolved_at IS NULL 
ORDER BY created_at DESC;
```

**Most common failure steps:**
```sql
SELECT failed_at_step, COUNT(*) 
FROM ai_errors_log 
GROUP BY failed_at_step 
ORDER BY COUNT(*) DESC;
```

---

**Status:** ✅ Ready to deploy  
**Files:** ✅ Created  
**Code:** ✅ Updated  
**SQL:** ✅ Ready

