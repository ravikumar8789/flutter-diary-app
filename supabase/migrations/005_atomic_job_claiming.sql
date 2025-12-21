-- Migration: Atomic Job Claiming for Recursive Self-Invocation
-- Purpose: Prevent race conditions when multiple instances process queue simultaneously
-- Date: 2025-01-XX

-- Function to atomically claim pending jobs
CREATE OR REPLACE FUNCTION public.claim_pending_jobs(
    p_batch_size integer DEFAULT 20,
    p_max_retry_at timestamptz DEFAULT NOW()
) RETURNS TABLE (
    id uuid,
    user_id uuid,
    analysis_type text,
    target_date date,
    entry_id uuid,
    week_start date,
    month_start date,
    attempts integer,
    max_attempts integer,
    next_retry_at timestamptz,
    created_at timestamptz
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    UPDATE public.analysis_queue
    SET 
        status = 'processing',
        updated_at = NOW()
    WHERE analysis_queue.id IN (
        SELECT aq.id
        FROM public.analysis_queue aq
        WHERE aq.status = 'pending'
          AND aq.next_retry_at <= p_max_retry_at
        ORDER BY aq.created_at ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED  -- Prevents concurrent access
    )
    RETURNING 
        analysis_queue.id,
        analysis_queue.user_id,
        analysis_queue.analysis_type,
        analysis_queue.target_date,
        analysis_queue.entry_id,
        analysis_queue.week_start,
        analysis_queue.month_start,
        analysis_queue.attempts,
        analysis_queue.max_attempts,
        analysis_queue.next_retry_at,
        analysis_queue.created_at;
END;
$$;

-- Add index for better performance (if not exists)
CREATE INDEX IF NOT EXISTS idx_analysis_queue_status_retry 
ON public.analysis_queue(status, next_retry_at, created_at)
WHERE status = 'pending';

-- Add updated_at column if not exists (for tracking active processing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'analysis_queue' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.analysis_queue 
        ADD COLUMN updated_at timestamptz DEFAULT NOW();
        
        -- Update existing rows
        UPDATE public.analysis_queue 
        SET updated_at = created_at 
        WHERE updated_at IS NULL;
        
        -- Add comment
        COMMENT ON COLUMN public.analysis_queue.updated_at IS 'Last update timestamp, used to track active processing';
    END IF;
END $$;

-- Add comment to function
COMMENT ON FUNCTION public.claim_pending_jobs IS 'Atomically claims pending jobs for processing, preventing race conditions. Uses FOR UPDATE SKIP LOCKED to ensure no duplicate processing.';

