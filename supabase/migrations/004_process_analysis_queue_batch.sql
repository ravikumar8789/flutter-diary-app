-- Helper to calculate the next midnight in a user's timezone and convert to UTC
CREATE OR REPLACE FUNCTION public.calculate_next_midnight_utc(
    p_timezone text,
    p_user_today date
) RETURNS timestamptz
LANGUAGE plpgsql
AS $$
DECLARE
    next_day date := (p_user_today + INTERVAL '1 day')::date;
BEGIN
    RETURN make_timestamptz(
        EXTRACT(YEAR FROM next_day)::int,
        EXTRACT(MONTH FROM next_day)::int,
        EXTRACT(DAY FROM next_day)::int,
        0,
        0,
        0,
        p_timezone
    );
END;
$$;

-- Batch queue population function described in refine_mixed_cursor_deepseek.md
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
            EXTRACT(DOW FROM (current_utc_time AT TIME ZONE u.timezone))::int AS user_dow,
            calculate_next_midnight_utc(u.timezone, (current_utc_time AT TIME ZONE u.timezone)::date) AS next_retry_at
        FROM public.users u
        WHERE u.timezone IS NOT NULL
    ),
    daily_candidates AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            e.id AS entry_id,
            e.entry_date
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
            next_retry_at
        )
        SELECT
            dc.user_id,
            'daily',
            dc.entry_date,
            dc.entry_id,
            'pending',
            dc.next_retry_at
        FROM daily_candidates dc
        RETURNING user_id
    ),
    catchup_entries AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            e.id AS entry_id,
            e.entry_date
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
            ce.next_retry_at
        FROM catchup_entries ce
        RETURNING user_id
    ),
    weekly_candidates AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            prev_week.week_start
        FROM user_context uc
        CROSS JOIN LATERAL (
            SELECT (date_trunc('week', (uc.user_today - INTERVAL '7 days')::timestamp))::date AS week_start
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
            wc.next_retry_at
        FROM weekly_candidates wc
        RETURNING user_id
    ),
    monthly_candidates AS (
        SELECT
            uc.user_id,
            uc.next_retry_at,
            prev_month.month_start
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
            mc.next_retry_at
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

