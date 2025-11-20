# **AI ERROR TRACKING SYSTEM - SETUP GUIDE**

## **📋 STEP-BY-STEP SETUP**

### **STEP 1: Run SQL Migration in Supabase**

1. Open **Supabase Dashboard** → Your Project → **SQL Editor**
2. Copy and paste the entire content from: `supabase/migrations/002_ai_errors_log_step_by_step.sql`
3. Click **Run** (or press Ctrl+Enter)
4. Verify success message

**OR** run each section separately:

**Section 1 - Create Table:**
```sql
CREATE TABLE IF NOT EXISTS public.ai_errors_log (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  entry_id uuid REFERENCES public.entries(id) ON DELETE SET NULL,
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  error_code text NOT NULL,
  error_message text NOT NULL,
  error_type text NOT NULL CHECK (error_type IN (
    'openai_api_error', 'supabase_error', 'validation_error',
    'network_error', 'timeout_error', 'rate_limit_error', 'data_error', 'unknown_error'
  )),
  error_severity text NOT NULL CHECK (error_severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
  request_body jsonb,
  request_duration_ms integer,
  retry_attempt integer DEFAULT 0,
  edge_function_name text NOT NULL,
  environment text DEFAULT 'production',
  deno_version text,
  stack_trace text,
  error_details jsonb DEFAULT '{}'::jsonb,
  failed_at_step text,
  auto_retry_attempted boolean DEFAULT false,
  manual_retry_required boolean DEFAULT false,
  resolved_at timestamptz,
  resolution_notes text,
  related_request_id uuid REFERENCES public.ai_requests_log(id) ON DELETE SET NULL,
  cost_impact_usd numeric(10,6) DEFAULT 0
);
```

**Section 2 - Create Indexes:**
```sql
CREATE INDEX IF NOT EXISTS idx_ai_errors_user_id ON public.ai_errors_log(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_errors_created_at ON public.ai_errors_log(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_errors_error_type ON public.ai_errors_log(error_type);
CREATE INDEX IF NOT EXISTS idx_ai_errors_severity ON public.ai_errors_log(error_severity);
CREATE INDEX IF NOT EXISTS idx_ai_errors_analysis_type ON public.ai_errors_log(analysis_type);
CREATE INDEX IF NOT EXISTS idx_ai_errors_edge_function ON public.ai_errors_log(edge_function_name);
CREATE INDEX IF NOT EXISTS idx_ai_errors_resolved ON public.ai_errors_log(resolved_at) WHERE resolved_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_errors_unresolved ON public.ai_errors_log(created_at) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_errors_failed_step ON public.ai_errors_log(failed_at_step);
```

**Section 3 - Enable RLS:**
```sql
ALTER TABLE public.ai_errors_log ENABLE ROW LEVEL SECURITY;
```

**Section 4 - Create Policies:**
```sql
DROP POLICY IF EXISTS "Users can view own AI errors" ON public.ai_errors_log;
CREATE POLICY "Users can view own AI errors" 
  ON public.ai_errors_log FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can insert AI errors" ON public.ai_errors_log;
CREATE POLICY "Service role can insert AI errors"
  ON public.ai_errors_log FOR INSERT
  WITH CHECK (true);
```

---

### **STEP 2: Deploy Edge Functions to Supabase**

**Command to deploy:**

```bash
# Navigate to project root
cd C:\Users\mrrav\OneDrive\Desktop\diaryapp

# Deploy all edge functions (including updated ones)
supabase functions deploy ai-analyze-daily
supabase functions deploy ai-analyze-weekly
```

**OR deploy both at once:**

```bash
supabase functions deploy ai-analyze-daily ai-analyze-weekly
```

**If you need to link Supabase project first:**

```bash
# Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF

# Then deploy
supabase functions deploy ai-analyze-daily
supabase functions deploy ai-analyze-weekly
```

---

### **STEP 3: Verify Deployment**

**Check in Supabase Dashboard:**
1. Go to **Edge Functions** section
2. Verify `ai-analyze-daily` and `ai-analyze-weekly` are listed
3. Check function logs for any errors

**Test error logging:**
1. Trigger an AI analysis that will fail (e.g., invalid entry_id)
2. Check `ai_errors_log` table in Supabase
3. Verify error was logged with all details

---

## **🔍 VERIFICATION QUERIES**

Run these in Supabase SQL Editor to verify setup:

**1. Check table exists:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'ai_errors_log';
```

**2. Check columns:**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'ai_errors_log'
ORDER BY ordinal_position;
```

**3. Check indexes:**
```sql
SELECT indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename = 'ai_errors_log';
```

**4. Check RLS policies:**
```sql
SELECT policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename = 'ai_errors_log';
```

**5. Test query (should return empty if no errors yet):**
```sql
SELECT COUNT(*) as error_count 
FROM public.ai_errors_log;
```

---

## **📊 USEFUL ANALYSIS QUERIES**

**Error rate by type (last 7 days):**
```sql
SELECT 
  error_type,
  COUNT(*) as error_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ai_errors_log WHERE created_at >= NOW() - INTERVAL '7 days'), 2) as percentage
FROM ai_errors_log
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY error_type
ORDER BY error_count DESC;
```

**Unresolved errors by severity:**
```sql
SELECT 
  error_severity,
  COUNT(*) as count,
  COUNT(DISTINCT user_id) as affected_users
FROM ai_errors_log
WHERE resolved_at IS NULL
GROUP BY error_severity
ORDER BY 
  CASE error_severity
    WHEN 'CRITICAL' THEN 1
    WHEN 'HIGH' THEN 2
    WHEN 'MEDIUM' THEN 3
    WHEN 'LOW' THEN 4
  END;
```

**Most common failure steps:**
```sql
SELECT 
  failed_at_step,
  COUNT(*) as failure_count,
  AVG(request_duration_ms) as avg_duration_ms
FROM ai_errors_log
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY failed_at_step
ORDER BY failure_count DESC;
```

**Errors by user (for support):**
```sql
SELECT 
  user_id,
  COUNT(*) as error_count,
  array_agg(DISTINCT error_type) as error_types,
  MAX(created_at) as last_error
FROM ai_errors_log
WHERE user_id IS NOT NULL
  AND resolved_at IS NULL
GROUP BY user_id
HAVING COUNT(*) > 5
ORDER BY error_count DESC
LIMIT 20;
```

---

## **✅ COMPLETION CHECKLIST**

- [ ] SQL migration executed successfully
- [ ] Table `ai_errors_log` created
- [ ] All indexes created
- [ ] RLS policies created
- [ ] Edge functions deployed
- [ ] Error logger helper file created
- [ ] Both edge functions updated
- [ ] Verification queries run successfully
- [ ] Test error logging works

---

## **🚨 TROUBLESHOOTING**

**Issue: "relation does not exist"**
- Solution: Run SQL migration first

**Issue: "permission denied"**
- Solution: Check RLS policies are created correctly

**Issue: Edge function deployment fails**
- Solution: Check Supabase CLI is installed and linked
- Solution: Verify `_shared` directory structure is correct

**Issue: Import error in edge function**
- Solution: Verify `_shared/ai_error_logger.ts` file exists
- Solution: Check import path is correct

---

**Status:** Ready to deploy  
**Files Created:** ✅  
**SQL Migration:** ✅  
**Edge Functions Updated:** ✅

