# **SUPABASE SQL QUERIES - STEP BY STEP**

## **IMPORTANT NOTES**
- Run these queries in **order**
- **Backup** your database before running
- Test in **staging** environment first
- Some operations are **irreversible** (DROP TABLE)

---

## **STEP 1: VERIFY EXISTING STRUCTURE**

### **1.1 Check if timezone column exists in users table**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'users' 
AND column_name = 'timezone';
```

**Expected Result**: Should return 1 row with `timezone` column (type: `text`)

**If Missing**: Run this:
```sql
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS timezone text;
```

**Set Default Timezone for Existing Users** (if needed):
```sql
-- Set default timezone for users without one
UPDATE public.users 
SET timezone = 'UTC' 
WHERE timezone IS NULL;
```

---

## **STEP 2: CREATE NEW TABLES**

### **2.1 Create `analysis_queue` Table**
```sql
-- Create analysis_queue table for batch processing
CREATE TABLE IF NOT EXISTS public.analysis_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly')),
  target_date date NOT NULL,
  entry_id uuid,  -- For daily analysis
  week_start date,  -- For weekly analysis  
  month_start date,  -- For monthly analysis
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  attempts integer DEFAULT 0,
  max_attempts integer DEFAULT 3,
  next_retry_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  processed_at timestamp with time zone,
  CONSTRAINT analysis_queue_pkey PRIMARY KEY (id),
  CONSTRAINT analysis_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);
```

### **2.2 Create Indexes for `analysis_queue`**
```sql
-- Index for pending jobs (most common query)
CREATE INDEX IF NOT EXISTS idx_analysis_queue_pending 
ON public.analysis_queue (status, next_retry_at) 
WHERE status IN ('pending', 'failed');

-- Index for user and type lookups
CREATE INDEX IF NOT EXISTS idx_analysis_queue_user_type 
ON public.analysis_queue (user_id, analysis_type, status);

-- Index for target_date lookups
CREATE INDEX IF NOT EXISTS idx_analysis_queue_target_date 
ON public.analysis_queue (target_date, status);
```

### **2.3 Create `monthly_insights` Table**
```sql
-- Create monthly_insights table
CREATE TABLE IF NOT EXISTS public.monthly_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  month_start date NOT NULL,
  mood_avg numeric,
  entries_count integer DEFAULT 0,
  word_count_total integer DEFAULT 0,
  top_topics text[] DEFAULT '{}'::text[],
  monthly_highlights text,
  growth_areas text[] DEFAULT '{}'::text[],
  achievements text[] DEFAULT '{}'::text[],
  next_month_goals text[] DEFAULT '{}'::text[],
  generated_at timestamp with time zone DEFAULT now(),
  consistency_score numeric,
  habit_analysis jsonb DEFAULT '{}'::jsonb,
  mood_trend_monthly text,
  model_version text,
  cost_tokens_prompt integer DEFAULT 0,
  cost_tokens_completion integer DEFAULT 0,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'error')),
  error_message text,
  CONSTRAINT monthly_insights_pkey PRIMARY KEY (id),
  CONSTRAINT monthly_insights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT unique_user_month UNIQUE (user_id, month_start)
);
```

### **2.4 Create Indexes for `monthly_insights`**
```sql
-- Index for user lookups
CREATE INDEX IF NOT EXISTS idx_monthly_insights_user 
ON public.monthly_insights (user_id, month_start DESC);

-- Index for status filtering
CREATE INDEX IF NOT EXISTS idx_monthly_insights_status 
ON public.monthly_insights (status) 
WHERE status = 'success';
```

---

## **STEP 3: MODIFY EXISTING TABLES**

### **3.1 Remove Columns from `entry_insights`**
```sql
-- Remove key_takeaways column (if exists)
ALTER TABLE public.entry_insights 
DROP COLUMN IF EXISTS key_takeaways;

-- Remove action_items column (if exists)
ALTER TABLE public.entry_insights 
DROP COLUMN IF EXISTS action_items;
```

**Verify Removal:**
```sql
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'entry_insights' 
AND column_name IN ('key_takeaways', 'action_items');
```

**Expected Result**: Should return 0 rows

---

## **STEP 4: ADD PERFORMANCE INDEXES**

### **4.1 Add Timezone Index**
```sql
-- Index for timezone lookups (for batch processing)
CREATE INDEX IF NOT EXISTS idx_users_timezone 
ON public.users (timezone) 
WHERE timezone IS NOT NULL;
```

### **4.2 Add Entry Date Index**
```sql
-- Index for entry date lookups (for yesterday's insight queries)
CREATE INDEX IF NOT EXISTS idx_entries_date_user 
ON public.entries (user_id, entry_date DESC);
```

---

## **STEP 5: DROP OLD TABLES**

### **5.1 Drop `homescreen_insights` Table**
```sql
-- WARNING: This will delete all 5-insight data
-- Make sure you're ready to proceed

-- First, check if table exists and has data
SELECT COUNT(*) as row_count 
FROM public.homescreen_insights;

-- If you want to backup data first (optional):
-- CREATE TABLE homescreen_insights_backup AS 
-- SELECT * FROM public.homescreen_insights;

-- Drop the table
DROP TABLE IF EXISTS public.homescreen_insights CASCADE;
```

### **5.2 Drop Old `ai_analysis_queue` Table**
```sql
-- WARNING: This will delete all pending queue items
-- New system will repopulate automatically

-- Check if table exists
SELECT COUNT(*) as row_count 
FROM public.ai_analysis_queue 
WHERE processed = false;

-- Drop the table
DROP TABLE IF EXISTS public.ai_analysis_queue CASCADE;
```

---

## **STEP 6: ROW LEVEL SECURITY (RLS)**

### **6.1 Enable RLS on `analysis_queue`**
```sql
ALTER TABLE public.analysis_queue ENABLE ROW LEVEL SECURITY;
```

### **6.2 Create RLS Policies for `analysis_queue`**
```sql
-- Users can view their own queue items
CREATE POLICY "Users can view own analysis queue" 
ON public.analysis_queue
FOR SELECT 
USING (auth.uid() = user_id);

-- Service role can do everything (for edge functions)
-- Note: Service role bypasses RLS by default, so no policy needed
```

### **6.3 Enable RLS on `monthly_insights`**
```sql
ALTER TABLE public.monthly_insights ENABLE ROW LEVEL SECURITY;
```

### **6.4 Create RLS Policies for `monthly_insights`**
```sql
-- Users can view their own monthly insights
CREATE POLICY "Users can view own monthly insights" 
ON public.monthly_insights
FOR SELECT 
USING (auth.uid() = user_id);
```

---

## **STEP 7: HELPER FUNCTIONS (OPTIONAL)**

### **7.1 Create Function to Get Date in Timezone**
```sql
-- Helper function for timezone-aware date calculations
CREATE OR REPLACE FUNCTION get_date_in_timezone(
  p_timezone text,
  p_offset_days integer DEFAULT 0
)
RETURNS date
LANGUAGE plpgsql
AS $$
DECLARE
  result_date date;
BEGIN
  -- Get current date in specified timezone, then add offset
  SELECT (NOW() AT TIME ZONE p_timezone)::date + p_offset_days INTO result_date;
  RETURN result_date;
END;
$$;
```

### **7.2 Create Function to Check if Entry Needs Analysis**
```sql
-- Helper function to check if entry needs daily analysis
CREATE OR REPLACE FUNCTION should_analyze_entry(
  p_entry_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  entry_date_val date;
  user_tz text;
  yesterday_date date;
  insight_exists boolean;
BEGIN
  -- Get entry date and user timezone
  SELECT e.entry_date, u.timezone 
  INTO entry_date_val, user_tz
  FROM public.entries e
  JOIN public.users u ON u.id = e.user_id
  WHERE e.id = p_entry_id AND e.user_id = p_user_id;
  
  IF entry_date_val IS NULL OR user_tz IS NULL THEN
    RETURN false;
  END IF;
  
  -- Calculate yesterday in user's timezone
  SELECT (NOW() AT TIME ZONE user_tz)::date - 1 INTO yesterday_date;
  
  -- Check if entry is from yesterday
  IF entry_date_val != yesterday_date THEN
    RETURN false;
  END IF;
  
  -- Check if insight already exists
  SELECT EXISTS(
    SELECT 1 FROM public.entry_insights 
    WHERE entry_id = p_entry_id AND status = 'success'
  ) INTO insight_exists;
  
  RETURN NOT insight_exists;
END;
$$;
```

---

## **STEP 8: VERIFICATION QUERIES**

### **8.1 Verify All Tables Created**
```sql
-- Check if all new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('analysis_queue', 'monthly_insights')
ORDER BY table_name;
```

**Expected Result**: Should return 2 rows

### **8.2 Verify Columns Removed**
```sql
-- Check entry_insights structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'entry_insights'
ORDER BY ordinal_position;
```

**Expected Result**: Should NOT include `key_takeaways` or `action_items`

### **8.3 Verify Old Tables Dropped**
```sql
-- Check if old tables are gone
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('homescreen_insights', 'ai_analysis_queue');
```

**Expected Result**: Should return 0 rows

### **8.4 Verify Indexes Created**
```sql
-- Check indexes on analysis_queue
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'analysis_queue' 
AND schemaname = 'public';
```

**Expected Result**: Should show 3 indexes

### **8.5 Verify RLS Enabled**
```sql
-- Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('analysis_queue', 'monthly_insights');
```

**Expected Result**: `rowsecurity` should be `true` for both

---

## **STEP 9: TEST DATA INSERTION**

### **9.1 Test Insert into `analysis_queue`**
```sql
-- Test daily analysis queue item
INSERT INTO public.analysis_queue (
  user_id,
  analysis_type,
  target_date,
  entry_id,
  status,
  next_retry_at
) VALUES (
  (SELECT id FROM public.users LIMIT 1),  -- Replace with actual user_id
  'daily',
  CURRENT_DATE - 1,
  (SELECT id FROM public.entries WHERE user_id = (SELECT id FROM public.users LIMIT 1) LIMIT 1),
  'pending',
  NOW()
) RETURNING *;
```

### **9.2 Test Insert into `monthly_insights`**
```sql
-- Test monthly insight insert
INSERT INTO public.monthly_insights (
  user_id,
  month_start,
  entries_count,
  status
) VALUES (
  (SELECT id FROM public.users LIMIT 1),  -- Replace with actual user_id
  DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'),
  15,
  'success'
) RETURNING *;
```

### **9.3 Clean Up Test Data**
```sql
-- Remove test data
DELETE FROM public.analysis_queue 
WHERE created_at > NOW() - INTERVAL '1 hour';

DELETE FROM public.monthly_insights 
WHERE created_at > NOW() - INTERVAL '1 hour';
```

---

## **STEP 10: MONITORING QUERIES**

### **10.1 Check Queue Status**
```sql
-- View pending jobs
SELECT 
  analysis_type,
  COUNT(*) as pending_count,
  MIN(created_at) as oldest_job,
  MAX(created_at) as newest_job
FROM public.analysis_queue
WHERE status = 'pending'
GROUP BY analysis_type;
```

### **10.2 Check Failed Jobs**
```sql
-- View failed jobs
SELECT 
  id,
  user_id,
  analysis_type,
  error_message,
  attempts,
  created_at
FROM public.analysis_queue
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 10;
```

### **10.3 Check Processing Stats**
```sql
-- View processing statistics
SELECT 
  analysis_type,
  status,
  COUNT(*) as count,
  AVG(EXTRACT(EPOCH FROM (processed_at - created_at))) as avg_processing_seconds
FROM public.analysis_queue
WHERE processed_at IS NOT NULL
GROUP BY analysis_type, status;
```

---

## **STEP 11: ROLLBACK PLAN (IF NEEDED)**

### **11.1 Restore `homescreen_insights` (if you backed it up)**
```sql
-- If you created a backup table
CREATE TABLE public.homescreen_insights AS 
SELECT * FROM homescreen_insights_backup;
```

### **11.2 Restore Columns (if needed)**
```sql
-- Restore key_takeaways
ALTER TABLE public.entry_insights 
ADD COLUMN IF NOT EXISTS key_takeaways jsonb DEFAULT '[]'::jsonb;

-- Restore action_items
ALTER TABLE public.entry_insights 
ADD COLUMN IF NOT EXISTS action_items jsonb DEFAULT '[]'::jsonb;
```

---

## **FINAL CHECKLIST**

Before deploying to production, verify:

- [ ] `analysis_queue` table created with all columns
- [ ] `monthly_insights` table created with all columns
- [ ] All indexes created successfully
- [ ] `homescreen_insights` table dropped
- [ ] Old `ai_analysis_queue` table dropped
- [ ] `entry_insights` columns removed
- [ ] RLS policies created
- [ ] Test data inserts work
- [ ] Verification queries pass
- [ ] No errors in Supabase logs

---

## **NEXT STEPS**

After running these SQL queries:

1. **Deploy Edge Functions** (see deployment commands)
2. **Set up Cron Jobs** for batch processing
3. **Update Flutter App** with new UI
4. **Test End-to-End** flow
5. **Monitor** queue processing

---

**END OF SQL QUERIES**

