-- Migration: Remove next_retry_at Logic from Queue Processing
-- Purpose: Simplify queue processing by removing time-based retry logic
-- Date: 2025-01-XX
-- 
-- This migration removes the dependency on next_retry_at for job claiming and processing.
-- The system will now rely solely on hourly cron jobs and target_date filtering.

-- Step 1: Update claim_pending_jobs function to remove next_retry_at check
CREATE OR REPLACE FUNCTION public.claim_pending_jobs(
    p_batch_size integer DEFAULT 20,
    p_max_retry_at timestamptz DEFAULT NOW()  -- Parameter kept for backward compatibility, but not used
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
    next_retry_at timestamptz,  -- Still returned for backward compatibility
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
          -- Filter by target_date: only claim jobs eligible for processing
          -- For daily/catchup: target_date = UTC date when processing should occur
          -- For weekly/monthly: target_date is always in past, so always eligible
          -- Time check prevents same-day early processing (most timezones have tomorrow midnight between 10:00-14:00 UTC)
          AND (
            aq.target_date < CURRENT_DATE  -- Past dates always eligible
            OR (
              aq.target_date = CURRENT_DATE 
              AND EXTRACT(HOUR FROM NOW()) >= 10  -- Same day, after 10:00 UTC
            )
          )
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

-- Update function comment
COMMENT ON FUNCTION public.claim_pending_jobs IS 'Atomically claims pending jobs for processing, preventing race conditions. Uses FOR UPDATE SKIP LOCKED to ensure no duplicate processing. Filters by target_date with time check (target_date < CURRENT_DATE OR target_date = CURRENT_DATE AND hour >= 10) to prevent same-day early processing. Works for all job types: daily/catchup (UTC date when to process), weekly/monthly (always eligible as target_date is in past).';

-- Step 2: Update database index
-- Drop old index that includes next_retry_at
DROP INDEX IF EXISTS idx_analysis_queue_status_retry;

-- Create new index without next_retry_at
CREATE INDEX IF NOT EXISTS idx_analysis_queue_status_created 
ON public.analysis_queue(status, created_at)
WHERE status = 'pending';

-- Add comment to index
COMMENT ON INDEX idx_analysis_queue_status_created IS 'Index for efficiently querying pending jobs by status and creation time. Used by claim_pending_jobs function.';

-- Step 3: Update process_analysis_queue_batch function to remove next_retry_at calculation
CREATE OR REPLACE FUNCTION public.process_analysis_queue_batch()
RETURNS TABLE (
    users_processed bigint,
    daily_jobs_created bigint,
    weekly_jobs_created bigint,
    monthly_jobs_created bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
    current_utc_time timestamptz := NOW();
BEGIN
    WITH user_context AS (
        SELECT
            u.id AS user_id,
            u.timezone,
            ((current_utc_time AT TIME ZONE u.timezone)::date) AS user_today,
            EXTRACT(HOUR FROM (current_utc_time AT TIME ZONE u.timezone))::int AS user_hour,
            EXTRACT(DOW FROM (current_utc_time AT TIME ZONE u.timezone))::int AS user_dow
            -- Removed: calculate_next_midnight_utc(...) AS next_retry_at
            -- No longer needed - hourly cron handles timing
        FROM public.users u
        WHERE u.timezone IS NOT NULL
          AND (u.timezone = 'UTC' OR u.timezone ~ '^[A-Za-z_]+/[A-Za-z_]+$')
    ),
    daily_candidates AS (
        SELECT
            uc.user_id,
            e.id AS entry_id,
            e.entry_date
            -- Removed: uc.next_retry_at
        FROM user_context uc
        JOIN public.entries e
            ON e.user_id = uc.user_id
           AND e.entry_date = uc.user_today
        WHERE e.diary_text IS NOT NULL
          AND length(e.diary_text) >= 50
          AND check_entry_completion(e.id)
          AND NOT EXISTS (
              SELECT 1
              FROM public.entry_insights ei
              WHERE ei.entry_id = e.id
                AND ei.status = 'success'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.entry_id = e.id
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_daily AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            entry_id,
            status
            -- Removed: next_retry_at column
        )
        SELECT
            dc.user_id,
            'daily',
            dc.entry_date,
            dc.entry_id,
            'pending'
            -- Removed: dc.next_retry_at
        FROM daily_candidates dc
        RETURNING user_id
    ),
    catchup_entries AS (
        SELECT
            uc.user_id,
            e.id AS entry_id,
            e.entry_date
            -- Removed: uc.next_retry_at
        FROM user_context uc
        JOIN public.entries e
            ON e.user_id = uc.user_id
        WHERE e.entry_date < uc.user_today
          AND e.entry_date >= ((uc.user_today - INTERVAL '30 days')::date)
          AND e.diary_text IS NOT NULL
          AND length(e.diary_text) >= 50
          AND check_entry_completion(e.id)
          AND NOT EXISTS (
              SELECT 1
              FROM public.entry_insights ei
              WHERE ei.entry_id = e.id
                AND ei.status = 'success'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.entry_id = e.id
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_catchup AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            entry_id,
            status
            -- Removed: next_retry_at column
        )
        SELECT
            ce.user_id,
            'daily',
            ce.entry_date,
            ce.entry_id,
            'pending'
            -- Removed: ce.next_retry_at
        FROM catchup_entries ce
        RETURNING user_id
    ),
    weekly_candidates AS (
        SELECT
            uc.user_id,
            prev_week.week_start
            -- Removed: uc.next_retry_at
        FROM user_context uc
        CROSS JOIN LATERAL (
            SELECT (
                (uc.user_today - INTERVAL '7 days')::date - 
                (EXTRACT(DOW FROM (uc.user_today - INTERVAL '7 days')::timestamp)::int * INTERVAL '1 day')
            )::date AS week_start
        ) AS prev_week
        WHERE uc.user_dow = 0
          AND uc.user_hour = 0
          AND (
              SELECT COUNT(*)
              FROM public.entries e
              WHERE e.user_id = uc.user_id
                AND e.entry_date >= prev_week.week_start
                AND e.entry_date < (prev_week.week_start + INTERVAL '7 days')::date
          ) >= 3
          AND NOT EXISTS (
              SELECT 1
              FROM public.weekly_insights wi
              WHERE wi.user_id = uc.user_id
                AND wi.week_start = prev_week.week_start
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.user_id = uc.user_id
                AND aq.analysis_type = 'weekly'
                AND aq.week_start = prev_week.week_start
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_weekly AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            week_start,
            status
            -- Removed: next_retry_at column
        )
        SELECT
            wc.user_id,
            'weekly',
            wc.week_start,
            wc.week_start,
            'pending'
            -- Removed: wc.next_retry_at
        FROM weekly_candidates wc
        RETURNING user_id
    ),
    monthly_candidates AS (
        SELECT
            uc.user_id,
            prev_month.month_start
            -- Removed: uc.next_retry_at
        FROM user_context uc
        CROSS JOIN LATERAL (
            SELECT (date_trunc('month', (uc.user_today - INTERVAL '1 month')::timestamp))::date AS month_start
        ) AS prev_month
        WHERE uc.user_hour = 0
          AND EXTRACT(DAY FROM uc.user_today) = 1
          AND (
              SELECT COUNT(*)
              FROM public.entries e
              WHERE e.user_id = uc.user_id
                AND e.entry_date >= prev_month.month_start
                AND e.entry_date < (prev_month.month_start + INTERVAL '1 month')::date
          ) >= 10
          AND NOT EXISTS (
              SELECT 1
              FROM public.monthly_insights mi
              WHERE mi.user_id = uc.user_id
                AND mi.month_start = prev_month.month_start
          )
          AND NOT EXISTS (
              SELECT 1
              FROM public.analysis_queue aq
              WHERE aq.user_id = uc.user_id
                AND aq.analysis_type = 'monthly'
                AND aq.month_start = prev_month.month_start
                AND aq.status IN ('pending', 'processing')
          )
    ),
    inserted_monthly AS (
        INSERT INTO public.analysis_queue (
            user_id,
            analysis_type,
            target_date,
            month_start,
            status
            -- Removed: next_retry_at column
        )
        SELECT
            mc.user_id,
            'monthly',
            mc.month_start,
            mc.month_start,
            'pending'
            -- Removed: mc.next_retry_at
        FROM monthly_candidates mc
        RETURNING user_id
    )
    SELECT
        COALESCE((
            SELECT COUNT(DISTINCT user_id)
            FROM (
                SELECT user_id FROM inserted_daily
                UNION ALL
                SELECT user_id FROM inserted_catchup
                UNION ALL
                SELECT user_id FROM inserted_weekly
                UNION ALL
                SELECT user_id FROM inserted_monthly
            ) AS all_users
        ), 0) AS users_processed,
        COALESCE((SELECT COUNT(*) FROM inserted_daily), 0) +
        COALESCE((SELECT COUNT(*) FROM inserted_catchup), 0) AS daily_jobs_created,
        COALESCE((SELECT COUNT(*) FROM inserted_weekly), 0) AS weekly_jobs_created,
        COALESCE((SELECT COUNT(*) FROM inserted_monthly), 0) AS monthly_jobs_created
    INTO users_processed, daily_jobs_created, weekly_jobs_created, monthly_jobs_created;

    RETURN QUERY
    SELECT
        COALESCE(users_processed, 0),
        COALESCE(daily_jobs_created, 0),
        COALESCE(weekly_jobs_created, 0),
        COALESCE(monthly_jobs_created, 0);
END;
$$;

-- Add comment to function
COMMENT ON FUNCTION public.process_analysis_queue_batch IS 'Batch function to populate analysis_queue with jobs for daily, weekly, and monthly analysis. No longer sets next_retry_at - hourly cron handles job timing.';

-- Note: The next_retry_at column remains in the analysis_queue table (nullable)
-- This ensures backward compatibility. Old jobs with next_retry_at values will be ignored.
-- No data migration is needed.

