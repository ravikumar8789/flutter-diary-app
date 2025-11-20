-- ============================================
-- AI ERRORS LOG - STEP BY STEP SETUP
-- Run each section separately in Supabase SQL Editor
-- ============================================

-- ============================================
-- STEP 1: Create the table
-- ============================================
CREATE TABLE IF NOT EXISTS public.ai_errors_log (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  
  -- Request Identification
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  entry_id uuid REFERENCES public.entries(id) ON DELETE SET NULL,
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  
  -- Error Details
  error_code text NOT NULL,
  error_message text NOT NULL,
  error_type text NOT NULL CHECK (error_type IN (
    'openai_api_error',
    'supabase_error',
    'validation_error',
    'network_error',
    'timeout_error',
    'rate_limit_error',
    'data_error',
    'unknown_error'
  )),
  error_severity text NOT NULL CHECK (error_severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
  
  -- Request Context
  request_body jsonb,
  request_duration_ms integer,
  retry_attempt integer DEFAULT 0,
  
  -- System Context
  edge_function_name text NOT NULL,
  environment text DEFAULT 'production',
  deno_version text,
  
  -- Error Stack & Details
  stack_trace text,
  error_details jsonb DEFAULT '{}'::jsonb,
  failed_at_step text,
  
  -- Recovery Info
  auto_retry_attempted boolean DEFAULT false,
  manual_retry_required boolean DEFAULT false,
  resolved_at timestamptz,
  resolution_notes text,
  
  -- Related Data
  related_request_id uuid REFERENCES public.ai_requests_log(id) ON DELETE SET NULL,
  cost_impact_usd numeric(10,6) DEFAULT 0
);

-- ============================================
-- STEP 2: Create indexes for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_ai_errors_user_id ON public.ai_errors_log(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_errors_created_at ON public.ai_errors_log(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_errors_error_type ON public.ai_errors_log(error_type);
CREATE INDEX IF NOT EXISTS idx_ai_errors_severity ON public.ai_errors_log(error_severity);
CREATE INDEX IF NOT EXISTS idx_ai_errors_analysis_type ON public.ai_errors_log(analysis_type);
CREATE INDEX IF NOT EXISTS idx_ai_errors_edge_function ON public.ai_errors_log(edge_function_name);
CREATE INDEX IF NOT EXISTS idx_ai_errors_resolved ON public.ai_errors_log(resolved_at) WHERE resolved_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_errors_unresolved ON public.ai_errors_log(created_at) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_errors_failed_step ON public.ai_errors_log(failed_at_step);

-- ============================================
-- STEP 3: Enable Row Level Security
-- ============================================
ALTER TABLE public.ai_errors_log ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 4: Create RLS Policies
-- ============================================

-- Policy 1: Users can view their own errors
DROP POLICY IF EXISTS "Users can view own AI errors" ON public.ai_errors_log;
CREATE POLICY "Users can view own AI errors" 
  ON public.ai_errors_log
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy 2: Service role can insert (for edge functions)
DROP POLICY IF EXISTS "Service role can insert AI errors" ON public.ai_errors_log;
CREATE POLICY "Service role can insert AI errors"
  ON public.ai_errors_log
  FOR INSERT
  WITH CHECK (true);

-- ============================================
-- STEP 5: Add table comment
-- ============================================
COMMENT ON TABLE public.ai_errors_log IS 'Comprehensive error tracking for AI analysis functions. Captures all error details for debugging and analysis.';

-- ============================================
-- VERIFICATION QUERIES (Run to verify setup)
-- ============================================

-- Check if table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name = 'ai_errors_log';

-- Check if columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'ai_errors_log'
ORDER BY ordinal_position;

-- Check if indexes exist
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename = 'ai_errors_log';

-- Check RLS policies
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename = 'ai_errors_log';

