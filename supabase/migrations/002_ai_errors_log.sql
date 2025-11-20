-- ============================================
-- AI Errors Log Table
-- Comprehensive error tracking for AI functions
-- ============================================

-- Create ai_errors_log table
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

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_ai_errors_user_id ON public.ai_errors_log(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_errors_created_at ON public.ai_errors_log(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_errors_error_type ON public.ai_errors_log(error_type);
CREATE INDEX IF NOT EXISTS idx_ai_errors_severity ON public.ai_errors_log(error_severity);
CREATE INDEX IF NOT EXISTS idx_ai_errors_analysis_type ON public.ai_errors_log(analysis_type);
CREATE INDEX IF NOT EXISTS idx_ai_errors_edge_function ON public.ai_errors_log(edge_function_name);
CREATE INDEX IF NOT EXISTS idx_ai_errors_resolved ON public.ai_errors_log(resolved_at) WHERE resolved_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_errors_unresolved ON public.ai_errors_log(created_at) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ai_errors_failed_step ON public.ai_errors_log(failed_at_step);

-- RLS Policy
ALTER TABLE public.ai_errors_log ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own errors
DROP POLICY IF EXISTS "Users can view own AI errors" ON public.ai_errors_log;
CREATE POLICY "Users can view own AI errors" 
  ON public.ai_errors_log
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Service role can insert (for edge functions)
DROP POLICY IF EXISTS "Service role can insert AI errors" ON public.ai_errors_log;
CREATE POLICY "Service role can insert AI errors"
  ON public.ai_errors_log
  FOR INSERT
  WITH CHECK (true); -- Edge functions use service role key

-- Policy: Admins can view all errors (optional - requires admin role column in users table)
-- Uncomment if you have admin role system:
-- CREATE POLICY "Admins can view all AI errors"
--   ON public.ai_errors_log
--   FOR SELECT
--   USING (
--     EXISTS (
--       SELECT 1 FROM public.users 
--       WHERE id = auth.uid() 
--       AND role = 'admin'
--     )
--   );

-- Add comment to table
COMMENT ON TABLE public.ai_errors_log IS 'Comprehensive error tracking for AI analysis functions. Captures all error details for debugging and analysis.';

