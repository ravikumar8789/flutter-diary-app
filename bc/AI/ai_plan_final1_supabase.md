# Supabase Implementation Steps - AI Feature

## **Overview**

This document provides step-by-step instructions for implementing the AI feature changes in Supabase (database, functions, and scheduling).

---

## **STEP 1: CREATE HOMESCREEN INSIGHTS TABLE**

### **1.1 Create Migration File**

**File:** `supabase/migrations/004_create_homescreen_insights.sql`

**SQL:**
```sql
-- Create homescreen_insights table
CREATE TABLE IF NOT EXISTS public.homescreen_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_id uuid NOT NULL REFERENCES public.entries(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  insight_1 text NOT NULL,  -- How they are improving
  insight_2 text NOT NULL,  -- How they are lacking
  insight_3 text NOT NULL,  -- What is best thing
  insight_4 text NOT NULL,  -- What can be achieved
  insight_5 text NOT NULL,  -- Why they may be lacking (if progress low)
  generated_at timestamp with time zone DEFAULT now(),
  status text DEFAULT 'success' CHECK (status IN ('pending', 'success', 'error')),
  error_message text,
  CONSTRAINT unique_entry_homescreen_insights UNIQUE (entry_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_homescreen_insights_user_id 
  ON public.homescreen_insights(user_id);

CREATE INDEX IF NOT EXISTS idx_homescreen_insights_entry_id 
  ON public.homescreen_insights(entry_id);

CREATE INDEX IF NOT EXISTS idx_homescreen_insights_generated_at 
  ON public.homescreen_insights(generated_at DESC);

-- RLS Policies
ALTER TABLE public.homescreen_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own homescreen insights" 
  ON public.homescreen_insights
  FOR SELECT 
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert homescreen insights" 
  ON public.homescreen_insights
  FOR INSERT 
  WITH CHECK (true);  -- Service role bypasses RLS

CREATE POLICY "Service role can update homescreen insights" 
  ON public.homescreen_insights
  FOR UPDATE 
  USING (true);
```

**Run in Supabase SQL Editor**

---

## **STEP 2: CREATE AI ANALYSIS QUEUE TABLE**

### **2.1 Create Migration File**

**File:** `supabase/migrations/005_create_ai_analysis_queue.sql`

**SQL:**
```sql
-- Create ai_analysis_queue table
CREATE TABLE IF NOT EXISTS public.ai_analysis_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_id uuid NOT NULL REFERENCES public.entries(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  processed boolean DEFAULT false,
  processed_at timestamp with time zone,
  retry_count integer DEFAULT 0,
  max_retries integer DEFAULT 3,
  error_message text,
  CONSTRAINT unique_entry_queue UNIQUE (entry_id)
);

-- Indexes for queue processing
CREATE INDEX IF NOT EXISTS idx_ai_queue_unprocessed 
  ON public.ai_analysis_queue(processed, created_at) 
  WHERE processed = false;

CREATE INDEX IF NOT EXISTS idx_ai_queue_entry_id 
  ON public.ai_analysis_queue(entry_id);

CREATE INDEX IF NOT EXISTS idx_ai_queue_user_id 
  ON public.ai_analysis_queue(user_id);

-- RLS Policies (service role only)
ALTER TABLE public.ai_analysis_queue ENABLE ROW LEVEL SECURITY;

-- No user access (internal queue only)
CREATE POLICY "Service role only" 
  ON public.ai_analysis_queue
  FOR ALL 
  USING (false)  -- No user access
  WITH CHECK (false);
```

**Run in Supabase SQL Editor**

---

## **STEP 3: CREATE ENTRY COMPLETION CHECK FUNCTION**

### **3.1 Create Migration File**

**File:** `supabase/migrations/006_create_completion_check_function.sql`

**SQL:**
```sql
-- Function to check if entry has all 4 sections complete
CREATE OR REPLACE FUNCTION public.check_entry_completion(entry_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  has_morning_ritual boolean := false;
  has_wellness boolean := false;
  has_gratitude boolean := false;
  has_diary boolean := false;
BEGIN
  -- 1. Check Morning Ritual (affirmations OR priorities)
  SELECT EXISTS(
    SELECT 1 FROM public.entry_affirmations 
    WHERE entry_id = entry_uuid 
    AND jsonb_array_length(affirmations) > 0
  ) OR EXISTS(
    SELECT 1 FROM public.entry_priorities 
    WHERE entry_id = entry_uuid 
    AND jsonb_array_length(priorities) > 0
  ) INTO has_morning_ritual;

  -- 2. Check Wellness Tracker (meals OR self_care)
  SELECT EXISTS(
    SELECT 1 FROM public.entry_meals 
    WHERE entry_id = entry_uuid 
    AND (breakfast IS NOT NULL OR lunch IS NOT NULL OR dinner IS NOT NULL OR water_cups > 0)
  ) OR EXISTS(
    SELECT 1 FROM public.entry_self_care 
    WHERE entry_id = entry_uuid 
    AND (sleep = true OR get_up_early = true OR fresh_air = true OR 
         learn_new = true OR balanced_diet = true OR podcast = true OR 
         me_moment = true OR hydrated = true OR read_book = true OR exercise = true)
  ) INTO has_wellness;

  -- 3. Check Gratitude
  SELECT EXISTS(
    SELECT 1 FROM public.entry_gratitude 
    WHERE entry_id = entry_uuid 
    AND jsonb_array_length(grateful_items) > 0
  ) INTO has_gratitude;

  -- 4. Check Diary (text >= 50 chars)
  SELECT EXISTS(
    SELECT 1 FROM public.entries 
    WHERE id = entry_uuid 
    AND diary_text IS NOT NULL 
    AND length(trim(diary_text)) >= 50
  ) INTO has_diary;

  -- Return true only if ALL 4 sections are complete
  RETURN has_morning_ritual AND has_wellness AND has_gratitude AND has_diary;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.check_entry_completion(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_entry_completion(uuid) TO service_role;
```

**Run in Supabase SQL Editor**

**Test:**
```sql
-- Test with a real entry_id
SELECT public.check_entry_completion('your-entry-id-here');
```

---

## **STEP 4: CREATE QUEUE TRIGGER FUNCTION**

### **4.1 Create Migration File**

**File:** `supabase/migrations/007_create_queue_trigger_function.sql`

**SQL:**
```sql
-- Function to queue AI analysis when entry is complete
CREATE OR REPLACE FUNCTION public.queue_ai_analysis_on_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  entry_uuid uuid;
  user_uuid uuid;
  is_complete boolean;
  insight_exists boolean;
BEGIN
  -- Get entry_id from trigger context
  IF TG_TABLE_NAME = 'entries' THEN
    entry_uuid := NEW.id;
    user_uuid := NEW.user_id;
  ELSIF TG_TABLE_NAME IN ('entry_affirmations', 'entry_priorities', 'entry_meals', 
                           'entry_gratitude', 'entry_self_care') THEN
    entry_uuid := NEW.entry_id;
    SELECT user_id INTO user_uuid FROM public.entries WHERE id = entry_uuid;
  END IF;

  -- Skip if entry_id or user_id is null
  IF entry_uuid IS NULL OR user_uuid IS NULL THEN
    RETURN NEW;
  END IF;

  -- Check if entry is complete
  SELECT public.check_entry_completion(entry_uuid) INTO is_complete;

  -- Only proceed if entry is complete
  IF is_complete THEN
    -- Check if insight already exists (avoid duplicate analysis)
    SELECT EXISTS(
      SELECT 1 FROM public.entry_insights 
      WHERE entry_id = entry_uuid 
      AND status = 'success'
    ) INTO insight_exists;

    -- If no insight exists, add to queue
    IF NOT insight_exists THEN
      INSERT INTO public.ai_analysis_queue (entry_id, user_id)
      VALUES (entry_uuid, user_uuid)
      ON CONFLICT (entry_id) DO NOTHING;  -- Prevent duplicates
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.queue_ai_analysis_on_completion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.queue_ai_analysis_on_completion() TO service_role;
```

**Run in Supabase SQL Editor**

---

## **STEP 5: CREATE DATABASE TRIGGERS**

### **5.1 Create Migration File**

**File:** `supabase/migrations/008_create_completion_triggers.sql`

**SQL:**
```sql
-- Trigger on entries table (diary_text updates)
DROP TRIGGER IF EXISTS trigger_ai_on_entry_update ON public.entries;
CREATE TRIGGER trigger_ai_on_entry_update
AFTER INSERT OR UPDATE OF diary_text ON public.entries
FOR EACH ROW
WHEN (NEW.diary_text IS NOT NULL AND length(trim(NEW.diary_text)) >= 50)
EXECUTE FUNCTION public.queue_ai_analysis_on_completion();

-- Trigger on entry_affirmations
DROP TRIGGER IF EXISTS trigger_ai_on_affirmations_update ON public.entry_affirmations;
CREATE TRIGGER trigger_ai_on_affirmations_update
AFTER INSERT OR UPDATE ON public.entry_affirmations
FOR EACH ROW
EXECUTE FUNCTION public.queue_ai_analysis_on_completion();

-- Trigger on entry_priorities
DROP TRIGGER IF EXISTS trigger_ai_on_priorities_update ON public.entry_priorities;
CREATE TRIGGER trigger_ai_on_priorities_update
AFTER INSERT OR UPDATE ON public.entry_priorities
FOR EACH ROW
EXECUTE FUNCTION public.queue_ai_analysis_on_completion();

-- Trigger on entry_meals
DROP TRIGGER IF EXISTS trigger_ai_on_meals_update ON public.entry_meals;
CREATE TRIGGER trigger_ai_on_meals_update
AFTER INSERT OR UPDATE ON public.entry_meals
FOR EACH ROW
EXECUTE FUNCTION public.queue_ai_analysis_on_completion();

-- Trigger on entry_gratitude
DROP TRIGGER IF EXISTS trigger_ai_on_gratitude_update ON public.entry_gratitude;
CREATE TRIGGER trigger_ai_on_gratitude_update
AFTER INSERT OR UPDATE ON public.entry_gratitude
FOR EACH ROW
EXECUTE FUNCTION public.queue_ai_analysis_on_completion();

-- Trigger on entry_self_care
DROP TRIGGER IF EXISTS trigger_ai_on_self_care_update ON public.entry_self_care;
CREATE TRIGGER trigger_ai_on_self_care_update
AFTER INSERT OR UPDATE ON public.entry_self_care
FOR EACH ROW
EXECUTE FUNCTION public.queue_ai_analysis_on_completion();
```

**Run in Supabase SQL Editor**

**Test:**
```sql
-- Test trigger by updating an entry
-- Should see entry appear in ai_analysis_queue if complete
SELECT * FROM public.ai_analysis_queue ORDER BY created_at DESC LIMIT 5;
```

---

## **STEP 6: MODIFY AI-ANALYZE-DAILY EDGE FUNCTION**

### **6.1 Update Function Logic**

**File:** `supabase/functions/ai-analyze-daily/index.ts`

**Key Changes:**

1. **Fetch Past 5 Days Data:**
```typescript
// Fetch past 5 days entries for context
const fiveDaysAgo = new Date()
fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5)

const { data: pastEntries } = await supabase
  .from('entries')
  .select('id, diary_text, mood_score, entry_date')
  .eq('user_id', user_id)
  .gte('entry_date', fiveDaysAgo.toISOString().split('T')[0])
  .lte('entry_date', entry.entry_date)
  .order('entry_date', { ascending: false })
  .limit(5)

// Fetch past insights if available
const { data: pastInsights } = await supabase
  .from('entry_insights')
  .select('insight_text, processed_at')
  .in('entry_id', pastEntries?.map(e => e.id) || [])
  .eq('status', 'success')
  .order('processed_at', { ascending: false })
```

2. **Enhanced Prompt:**
```typescript
const userPrompt = `User's Daily Entry Context:
- Current mood: ${entry.mood_score || 'N/A'}/5
- Entry date: ${entry.entry_date}
- Today's diary text: "${entry.diary_text.substring(0, 1000)}"
- Morning ritual completed: ${morningRitualStatus}
- Wellness activities: ${wellnessSummary}
- Gratitude items: ${gratitudeCount}

Past 5 Days Context (if available):
- Mood trend: ${moodTrend}
- Consistency: ${consistencyScore}%
- Entries completed: ${pastEntries?.length || 0}/5
- Key patterns: ${extractPatterns(pastEntries)}
- Previous insights: ${summarizePastInsights(pastInsights)}

Please generate exactly 5 insights (2-3 lines each):

1. **Improvement Insight:** How is the user improving? What positive changes or growth do you notice compared to past days?

2. **Lacking Insight:** What areas is the user lacking or struggling with? Be gentle and constructive.

3. **Best Thing Insight:** What is the best thing happening in their life right now? What should they celebrate?

4. **Achievement Insight:** What can they achieve? What realistic goals or next steps can they take?

5. **Progress Insight:** If progress is low, why might they be lacking? What barriers or challenges might be preventing growth? If progress is good, what is working well?

Keep each insight:
- 2-3 lines maximum
- Specific to their data
- Actionable and encouraging
- Non-judgmental
- Based on comparison with past 5 days when available`
```

3. **Parse 5 Insights from Response:**
```typescript
// Parse OpenAI response to extract 5 insights
const insights = parseInsightsFromResponse(openaiResponse)

// Save to homescreen_insights
const { error: homescreenError } = await supabase
  .from('homescreen_insights')
  .upsert({
    entry_id: entry_id,
    user_id: user_id,
    insight_1: insights.improvement,
    insight_2: insights.lacking,
    insight_3: insights.bestThing,
    insight_4: insights.achievement,
    insight_5: insights.progress,
    status: 'success'
  }, {
    onConflict: 'entry_id'
  })
```

4. **Add Completion Check:**
```typescript
// Check completion before analysis
const { data: isComplete } = await supabase.rpc('check_entry_completion', {
  entry_uuid: entry_id
})

if (!isComplete) {
  return new Response(
    JSON.stringify({ 
      success: false, 
      message: 'Entry incomplete - all 4 sections required' 
    }),
    { 
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    }
  )
}
```

**Deploy:**
```bash
supabase functions deploy ai-analyze-daily
```

---

## **STEP 7: CREATE PROCESS-AI-QUEUE EDGE FUNCTION**

### **7.1 Create New Function**

**File:** `supabase/functions/process-ai-queue/index.ts`

**Code:**
```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch unprocessed queue items older than 5 seconds
    const fiveSecondsAgo = new Date(Date.now() - 5000).toISOString()
    
    const { data: queueItems, error: queueError } = await supabase
      .from('ai_analysis_queue')
      .select('id, entry_id, user_id, retry_count, max_retries')
      .eq('processed', false)
      .lt('created_at', fiveSecondsAgo)
      .lt('retry_count', supabase.raw('max_retries'))
      .limit(10)  // Process 10 at a time

    if (queueError) throw queueError

    if (!queueItems || queueItems.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No items to process', processed: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let processed = 0
    let failed = 0

    for (const item of queueItems) {
      try {
        // Double-check completion
        const { data: isComplete, error: checkError } = await supabase.rpc(
          'check_entry_completion',
          { entry_uuid: item.entry_id }
        )

        if (checkError || !isComplete) {
          // Mark as processed (incomplete, skip)
          await supabase
            .from('ai_analysis_queue')
            .update({ 
              processed: true, 
              processed_at: new Date().toISOString(),
              error_message: 'Entry incomplete'
            })
            .eq('id', item.id)
          continue
        }

        // Check if insight already exists
        const { data: existingInsight } = await supabase
          .from('entry_insights')
          .select('id')
          .eq('entry_id', item.entry_id)
          .eq('status', 'success')
          .single()

        if (existingInsight) {
          // Already analyzed, mark as processed
          await supabase
            .from('ai_analysis_queue')
            .update({ 
              processed: true, 
              processed_at: new Date().toISOString()
            })
            .eq('id', item.id)
          continue
        }

        // Call ai-analyze-daily function
        const { data: functionUrl } = await supabase.functions.invoke('ai-analyze-daily', {
          body: {
            entry_id: item.entry_id,
            user_id: item.user_id
          }
        })

        // Mark as processed
        await supabase
          .from('ai_analysis_queue')
          .update({ 
            processed: true, 
            processed_at: new Date().toISOString()
          })
          .eq('id', item.id)

        processed++

      } catch (error) {
        // Increment retry count
        const newRetryCount = item.retry_count + 1
        
        if (newRetryCount >= item.max_retries) {
          // Max retries reached, mark as processed (failed)
          await supabase
            .from('ai_analysis_queue')
            .update({ 
              processed: true, 
              processed_at: new Date().toISOString(),
              error_message: error.message
            })
            .eq('id', item.id)
        } else {
          // Retry later
          await supabase
            .from('ai_analysis_queue')
            .update({ 
              retry_count: newRetryCount,
              error_message: error.message
            })
            .eq('id', item.id)
        }
        
        failed++
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed, 
        failed, 
        total: queueItems.length 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
```

**Deploy:**
```bash
supabase functions deploy process-ai-queue
```

---

## **STEP 8: CREATE SCHEDULED-DAILY-ANALYSIS EDGE FUNCTION**

### **8.1 Create New Function**

**File:** `supabase/functions/scheduled-daily-analysis/index.ts`

**Code:**
```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all active users (or batch process)
    // For now, process users who have entries in the last 7 days
    const sevenDaysAgo = new Date()
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7)
    const sevenDaysAgoStr = sevenDaysAgo.toISOString().split('T')[0]

    const { data: activeUsers, error: usersError } = await supabase
      .from('entries')
      .select('user_id, users!inner(timezone)')
      .gte('entry_date', sevenDaysAgoStr)
      .not('user_id', 'is', null)

    if (usersError) throw usersError

    // Get unique users
    const uniqueUsers = [...new Map(
      activeUsers?.map(u => [u.user_id, u]) || []
    ).values()]

    let processed = 0
    let skipped = 0
    let errors = 0

    for (const user of uniqueUsers) {
      try {
        const userTimezone = user.users?.timezone || 'UTC'
        
        // Calculate yesterday's date in user's timezone
        // For simplicity, use UTC and adjust (you may need timezone library)
        const now = new Date()
        const yesterday = new Date(now)
        yesterday.setDate(yesterday.getDate() - 1)
        const yesterdayStr = yesterday.toISOString().split('T')[0]

        // Find yesterday's entry
        const { data: yesterdayEntry, error: entryError } = await supabase
          .from('entries')
          .select('id')
          .eq('user_id', user.user_id)
          .eq('entry_date', yesterdayStr)
          .single()

        if (entryError || !yesterdayEntry) {
          skipped++
          continue
        }

        // Check completion
        const { data: isComplete, error: checkError } = await supabase.rpc(
          'check_entry_completion',
          { entry_uuid: yesterdayEntry.id }
        )

        if (checkError || !isComplete) {
          skipped++
          continue
        }

        // Check if insight already exists
        const { data: existingInsight } = await supabase
          .from('entry_insights')
          .select('id')
          .eq('entry_id', yesterdayEntry.id)
          .eq('status', 'success')
          .single()

        if (existingInsight) {
          skipped++
          continue
        }

        // Call ai-analyze-daily
        await supabase.functions.invoke('ai-analyze-daily', {
          body: {
            entry_id: yesterdayEntry.id,
            user_id: user.user_id
          }
        })

        processed++

      } catch (error) {
        console.error(`Error processing user ${user.user_id}:`, error)
        errors++
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed, 
        skipped, 
        errors,
        total: uniqueUsers.length 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
```

**Deploy:**
```bash
supabase functions deploy scheduled-daily-analysis
```

---

## **STEP 9: SET UP SCHEDULED EXECUTION**

### **9.1 Option A: Supabase pg_cron (if available)**

**SQL:**
```sql
-- Enable pg_cron extension (if available)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule process-ai-queue to run every 15 seconds
SELECT cron.schedule(
  'process-ai-queue',
  '*/15 * * * * *',  -- Every 15 seconds
  $$
  SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Schedule scheduled-daily-analysis to run daily at midnight UTC
SELECT cron.schedule(
  'daily-midnight-analysis',
  '0 0 * * *',  -- Daily at midnight UTC
  $$
  SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/scheduled-daily-analysis',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
```

**Note:** Requires `pg_cron` and `pg_net` extensions. Check if available in your Supabase plan.

### **9.2 Option B: External Cron (GitHub Actions, etc.)**

**GitHub Actions Workflow:** `.github/workflows/supabase-cron.yml`

```yaml
name: Supabase AI Cron Jobs

on:
  schedule:
    - cron: '*/1 * * * *'  # Every minute (process queue)
    - cron: '0 0 * * *'     # Daily at midnight (scheduled analysis)
  workflow_dispatch:

jobs:
  process-queue:
    runs-on: ubuntu-latest
    if: github.event.schedule == '*/1 * * * *' || github.event_name == 'workflow_dispatch'
    steps:
      - name: Process AI Queue
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/process-ai-queue"

  daily-analysis:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 0 * * *'
    steps:
      - name: Scheduled Daily Analysis
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/scheduled-daily-analysis"
```

**Set Secrets:**
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

---

## **STEP 10: TESTING**

### **10.1 Test Completion Check**

```sql
-- Test with a real entry
SELECT public.check_entry_completion('your-entry-id');
```

### **10.2 Test Triggers**

```sql
-- Update an entry's diary_text
UPDATE public.entries 
SET diary_text = 'Test diary text with more than 50 characters to trigger the completion check function'
WHERE id = 'your-entry-id';

-- Check if queued
SELECT * FROM public.ai_analysis_queue 
WHERE entry_id = 'your-entry-id';
```

### **10.3 Test Queue Processing**

```bash
# Manually call process-ai-queue
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "YOUR_SUPABASE_URL/functions/v1/process-ai-queue"
```

### **10.4 Test Scheduled Analysis**

```bash
# Manually call scheduled-daily-analysis
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  "YOUR_SUPABASE_URL/functions/v1/scheduled-daily-analysis"
```

### **10.5 Verify Homescreen Insights**

```sql
-- Check if insights were saved
SELECT * FROM public.homescreen_insights 
WHERE entry_id = 'your-entry-id';
```

---

## **STEP 11: MONITORING**

### **11.1 Check Queue Status**

```sql
-- Unprocessed items
SELECT COUNT(*) FROM public.ai_analysis_queue WHERE processed = false;

-- Failed items
SELECT * FROM public.ai_analysis_queue 
WHERE processed = true AND error_message IS NOT NULL
ORDER BY processed_at DESC;
```

### **11.2 Check Analysis Success Rate**

```sql
-- Success rate
SELECT 
  COUNT(*) FILTER (WHERE status = 'success') as successful,
  COUNT(*) FILTER (WHERE status = 'error') as failed,
  COUNT(*) as total
FROM public.entry_insights
WHERE processed_at > NOW() - INTERVAL '24 hours';
```

### **11.3 Check Homescreen Insights**

```sql
-- Recent insights
SELECT * FROM public.homescreen_insights
ORDER BY generated_at DESC
LIMIT 10;
```

---

## **STEP 12: ROLLBACK (if needed)**

### **12.1 Disable Triggers**

```sql
-- Drop all triggers
DROP TRIGGER IF EXISTS trigger_ai_on_entry_update ON public.entries;
DROP TRIGGER IF EXISTS trigger_ai_on_affirmations_update ON public.entry_affirmations;
DROP TRIGGER IF EXISTS trigger_ai_on_priorities_update ON public.entry_priorities;
DROP TRIGGER IF EXISTS trigger_ai_on_meals_update ON public.entry_meals;
DROP TRIGGER IF EXISTS trigger_ai_on_gratitude_update ON public.entry_gratitude;
DROP TRIGGER IF EXISTS trigger_ai_on_self_care_update ON public.entry_self_care;
```

### **12.2 Remove Cron Jobs**

```sql
-- Remove cron jobs (if using pg_cron)
SELECT cron.unschedule('process-ai-queue');
SELECT cron.unschedule('daily-midnight-analysis');
```

---

## **COMPLETION CHECKLIST**

- [ ] Step 1: Homescreen insights table created
- [ ] Step 2: AI analysis queue table created
- [ ] Step 3: Completion check function created and tested
- [ ] Step 4: Queue trigger function created
- [ ] Step 5: Database triggers created and tested
- [ ] Step 6: ai-analyze-daily function modified and deployed
- [ ] Step 7: process-ai-queue function created and deployed
- [ ] Step 8: scheduled-daily-analysis function created and deployed
- [ ] Step 9: Scheduled execution set up (cron)
- [ ] Step 10: All tests passing
- [ ] Step 11: Monitoring in place
- [ ] Ready for Flutter implementation

---

**End of Supabase Implementation Steps**

