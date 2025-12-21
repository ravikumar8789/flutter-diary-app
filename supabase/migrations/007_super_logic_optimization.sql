-- ============================================================================
-- SUPER LOGIC: Scalable & Reliable Queue Processing
-- ============================================================================
-- 
-- Design Philosophy:
-- 1. Calculate process_after ONCE at queue creation (no runtime calculations)
-- 2. Simple filter: process_after <= NOW() (database handles everything)
-- 3. Reuse next_retry_at column as process_after (no schema changes)
-- 4. Efficient index on (status, process_after) for fast filtering
-- 5. Works for 1000+ users, scales automatically
--
-- Benefits:
-- - No timezone calculations during processing
-- - No complex filtering logic
-- - Database-level filtering (fastest)
-- - Perfect timing (exact timestamp)
-- - No unnecessary delays
-- ============================================================================

-- Step 1: Update process_analysis_queue_batch to calculate process_after
-- This replaces target_date logic with a simple timestamp

CREATE OR REPLACE FUNCTION public.process_analysis_queue_batch()
RETURNS TABLE(users_processed bigint, daily_jobs_created bigint, weekly_jobs_created bigint, monthly_jobs_created bigint)
LANGUAGE plpgsql
AS $function$
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
        FROM public.users u
        WHERE u.timezone IS NOT NULL
          AND (u.timezone = 'UTC' OR u.timezone ~ '^[A-Za-z_]+/[A-Za-z_]+$')
    ),
    daily_candidates AS (
        SELECT
            uc.user_id,
            uc.timezone,
            e.id AS entry_id,
            e.entry_date,
            -- Calculate process_after: tomorrow midnight in user timezone → UTC timestamp
            -- This is when the job becomes eligible for processing
            make_timestamptz(
                EXTRACT(YEAR FROM (e.entry_date + INTERVAL '1 day'))::int,
                EXTRACT(MONTH FROM (e.entry_date + INTERVAL '1 day'))::int,
                EXTRACT(DAY FROM (e.entry_date + INTERVAL '1 day'))::int,
                0, 0, 0,
                uc.timezone
            ) AS process_after
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
            status,
            next_retry_at  -- Used as process_after (when job becomes eligible)
        )
        SELECT
            dc.user_id,
            'daily',
            dc.entry_date,  -- Keep for reference, but not used for filtering
            dc.entry_id,
            'pending',
            dc.process_after  -- Store exact UTC timestamp when job becomes eligible
        FROM daily_candidates dc
        RETURNING user_id
    ),
    catchup_entries AS (
        SELECT
            uc.user_id,
            uc.timezone,
            e.id AS entry_id,
            e.entry_date,
            -- Same calculation for catchup entries
            make_timestamptz(
                EXTRACT(YEAR FROM (e.entry_date + INTERVAL '1 day'))::int,
                EXTRACT(MONTH FROM (e.entry_date + INTERVAL '1 day'))::int,
                EXTRACT(DAY FROM (e.entry_date + INTERVAL '1 day'))::int,
                0, 0, 0,
                uc.timezone
            ) AS process_after
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
            status,
            next_retry_at
        )
        SELECT
            ce.user_id,
            'daily',
            ce.entry_date,
            ce.entry_id,
            'pending',
            ce.process_after
        FROM catchup_entries ce
        RETURNING user_id
    ),
    weekly_candidates AS (
        SELECT
            uc.user_id,
            prev_week.week_start,
            -- For weekly: process immediately when queued (past date)
            current_utc_time AS process_after
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
            status,
            next_retry_at
        )
        SELECT
            wc.user_id,
            'weekly',
            wc.week_start,
            wc.week_start,
            'pending',
            wc.process_after
        FROM weekly_candidates wc
        RETURNING user_id
    ),
    monthly_candidates AS (
        SELECT
            uc.user_id,
            prev_month.month_start,
            -- For monthly: process immediately when queued (past date)
            current_utc_time AS process_after
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
            status,
            next_retry_at
        )
        SELECT
            mc.user_id,
            'monthly',
            mc.month_start,
            mc.month_start,
            'pending',
            mc.process_after
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
$function$;

-- Step 2: Update claim_pending_jobs with super simple filter
-- Just check: process_after <= NOW() (that's it!)

CREATE OR REPLACE FUNCTION public.claim_pending_jobs(
    p_batch_size integer DEFAULT 20,
    p_max_retry_at timestamp with time zone DEFAULT now()
)
RETURNS TABLE(
    id uuid,
    user_id uuid,
    analysis_type text,
    target_date date,
    entry_id uuid,
    week_start date,
    month_start date,
    attempts integer,
    max_attempts integer,
    next_retry_at timestamp with time zone,
    created_at timestamp with time zone
)
LANGUAGE plpgsql
AS $function$
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
          -- SUPER SIMPLE: Just check if process_after time has arrived
          -- next_retry_at is used as process_after (when job becomes eligible)
          AND (aq.next_retry_at IS NULL OR aq.next_retry_at <= NOW())
        ORDER BY aq.next_retry_at ASC NULLS LAST, aq.created_at ASC
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
$function$;

-- Step 3: Create optimized index for super fast filtering
-- Index on (status, next_retry_at) where status = 'pending'
-- This makes the filter lightning fast

DROP INDEX IF EXISTS idx_analysis_queue_process_after;
CREATE INDEX idx_analysis_queue_process_after 
ON public.analysis_queue (status, next_retry_at) 
WHERE status = 'pending';

-- Step 4: Update function comments
COMMENT ON FUNCTION public.process_analysis_queue_batch IS 'Creates analysis queue jobs with process_after timestamp (stored in next_retry_at). Calculates exact UTC timestamp when job becomes eligible (tomorrow midnight in user timezone for daily, immediate for weekly/monthly).';

COMMENT ON FUNCTION public.claim_pending_jobs IS 'Atomically claims eligible pending jobs. Simple filter: next_retry_at (process_after) <= NOW(). Uses FOR UPDATE SKIP LOCKED for concurrency. Optimized index makes this super fast for 1000+ users.';

