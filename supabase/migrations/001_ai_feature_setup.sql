-- AI Feature Database Setup
-- Run this entire file in Supabase SQL Editor

-- ============================================
-- Step 1.1: Update entry_insights table
-- ============================================
ALTER TABLE public.entry_insights 
ADD COLUMN IF NOT EXISTS ai_generated BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS analysis_type TEXT CHECK (analysis_type IN ('daily', 'weekly', 'monthly')),
ADD COLUMN IF NOT EXISTS insight_text TEXT,
ADD COLUMN IF NOT EXISTS key_takeaways JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS action_items JSONB DEFAULT '[]'::jsonb;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_entry_insights_entry_id ON public.entry_insights(entry_id);
CREATE INDEX IF NOT EXISTS idx_entry_insights_status ON public.entry_insights(status);

-- ============================================
-- Step 1.2: Update weekly_insights table
-- ============================================
ALTER TABLE public.weekly_insights 
ADD COLUMN IF NOT EXISTS week_end date,
ADD COLUMN IF NOT EXISTS ai_generated BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS mood_trend text CHECK (mood_trend IN ('improving', 'declining', 'stable', 'volatile')),
ADD COLUMN IF NOT EXISTS key_insights text[],
ADD COLUMN IF NOT EXISTS recommendations text[],
ADD COLUMN IF NOT EXISTS habit_correlations jsonb DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS consistency_score numeric(3,2),
ADD COLUMN IF NOT EXISTS entries_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS word_count_total integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS model_version text,
ADD COLUMN IF NOT EXISTS cost_tokens_prompt integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS cost_tokens_completion integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'error')),
ADD COLUMN IF NOT EXISTS error_message text;

-- Add unique constraint (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_user_week' 
        AND conrelid = 'public.weekly_insights'::regclass
    ) THEN
        ALTER TABLE public.weekly_insights 
        ADD CONSTRAINT unique_user_week UNIQUE (user_id, week_start);
    END IF;
END $$;

-- Add index
CREATE INDEX IF NOT EXISTS idx_weekly_insights_user_week ON public.weekly_insights(user_id, week_start);

-- ============================================
-- Step 1.3: Create ai_requests_log table
-- ============================================
CREATE TABLE IF NOT EXISTS public.ai_requests_log (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  entry_id uuid REFERENCES public.entries(id),
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  prompt_tokens integer NOT NULL DEFAULT 0,
  completion_tokens integer NOT NULL DEFAULT 0,
  total_tokens integer NOT NULL DEFAULT 0,
  cost_usd numeric(10,6) NOT NULL DEFAULT 0,
  model_used text DEFAULT 'gpt-4o-mini',
  status text DEFAULT 'success' CHECK (status IN ('success', 'error', 'rate_limited', 'timeout')),
  error_message text,
  request_duration_ms integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ai_requests_user_id ON public.ai_requests_log(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_requests_created_at ON public.ai_requests_log(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_requests_analysis_type ON public.ai_requests_log(analysis_type);
CREATE INDEX IF NOT EXISTS idx_ai_requests_entry_id ON public.ai_requests_log(entry_id);

-- Enable RLS
ALTER TABLE public.ai_requests_log ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own logs
DROP POLICY IF EXISTS "Users can view own AI request logs" ON public.ai_requests_log;
CREATE POLICY "Users can view own AI request logs"
  ON public.ai_requests_log
  FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================
-- Step 1.4: Create ai_prompt_templates table
-- ============================================
CREATE TABLE IF NOT EXISTS public.ai_prompt_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  template_name text UNIQUE NOT NULL,
  system_prompt text NOT NULL,
  user_prompt_template text NOT NULL,
  temperature numeric(3,2) DEFAULT 0.7,
  max_tokens integer DEFAULT 500,
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  version integer DEFAULT 1,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Insert default daily template
INSERT INTO public.ai_prompt_templates (
  template_name, system_prompt, user_prompt_template, 
  temperature, max_tokens, analysis_type, is_active
) VALUES (
  'daily_analysis_v1',
  'You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide helpful, actionable insights. Always be supportive and non-judgmental. Keep responses concise (2-3 sentences maximum).',
  'User''s Recent Context:
- Current mood: {mood_score}/5
- Recent topics: {recent_topics}
- Self-care completion: {self_care_summary}
- Last 3 days mood trend: {mood_trend}

Today''s Entry: "{diary_text}"

Please provide a brief insight (2-3 sentences) that:
1. Acknowledges the emotional tone
2. Offers one supportive observation
3. Gently suggests one actionable next step (if applicable)

Keep it warm, specific, and under 100 words.',
  0.7,
  200,
  'daily',
  true
) ON CONFLICT (template_name) DO NOTHING;

-- Insert default weekly template
INSERT INTO public.ai_prompt_templates (
  template_name, system_prompt, user_prompt_template,
  temperature, max_tokens, analysis_type, is_active
) VALUES (
  'weekly_analysis_v1',
  'You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. Provide insightful weekly summaries that help users understand their emotional patterns and habit impacts. Focus on patterns and practical insights.',
  'Weekly Data Summary:
- Date range: {week_start} to {week_end}
- Entries written: {entries_count}/7
- Average mood: {avg_mood}/5
- Mood scores: {mood_scores}
- Self-care completion: {self_care_summary}
- Key topics mentioned: {weekly_topics}

Habit Analysis:
{habit_correlations}

Please provide:
1. Weekly mood pattern (1-2 sentences)
2. Top 2 positive influences on mood
3. One area for potential improvement
4. Two specific, actionable recommendations for next week

Keep it concise and actionable (under 150 words total).',
  0.5,
  400,
  'weekly',
  true
) ON CONFLICT (template_name) DO NOTHING;

