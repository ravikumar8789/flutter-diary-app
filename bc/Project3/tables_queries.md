-- Project 3 — Supabase DDL (ACTUAL SCHEMA FROM SUPABASE)
-- IMPORTANT: This is the real schema from the live database
-- Last updated: Current production schema

-- Extensions
create extension if not exists pgcrypto; -- for gen_random_uuid()

-- =============================
-- 1) USERS & ACCOUNTS
-- =============================

-- Main users table (mirrors auth.users)
CREATE TABLE public.users (
  id uuid NOT NULL,
  email text,
  email_verified boolean DEFAULT false,
  display_name text,
  avatar_url text,
  locale text,
  timezone text,
  marketing_opt_in boolean DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);

-- User profiles (additional profile data)
CREATE TABLE public.user_profiles (
  user_id uuid NOT NULL,
  bio text,
  onboarding_complete boolean DEFAULT false,
  theme_preference text DEFAULT 'system'::text CHECK (theme_preference = ANY (ARRAY['system'::text, 'light'::text, 'dark'::text])),
  diary_font text,
  font_size integer,
  paper_style text DEFAULT 'ruled'::text CHECK (paper_style = ANY (ARRAY['plain'::text, 'ruled'::text, 'grid'::text])),
  gender text DEFAULT 'unspecified'::text CHECK (gender = ANY (ARRAY['unspecified'::text, 'male'::text, 'female'::text, 'other'::text])),
  CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Auth providers
CREATE TABLE public.auth_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider text NOT NULL,
  provider_uid text,
  linked_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT auth_providers_pkey PRIMARY KEY (id),
  CONSTRAINT auth_providers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- =============================
-- 2) SETTINGS & PREFERENCES
-- =============================

-- User settings
CREATE TABLE public.user_settings (
  user_id uuid NOT NULL,
  reminder_enabled boolean DEFAULT true,
  reminder_time_local time without time zone,
  reminder_days ARRAY DEFAULT '{1,2,3,4,5,6,7}'::smallint[],
  grace_system_enabled boolean DEFAULT true,
  privacy_lock_enabled boolean DEFAULT false,
  region_preference text,
  export_format_default text DEFAULT 'json'::text CHECK (export_format_default = ANY (ARRAY['pdf'::text, 'csv'::text, 'json'::text])),
  CONSTRAINT user_settings_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Notification tokens
CREATE TABLE public.notification_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  platform text CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text, 'web'::text])),
  fcm_token text NOT NULL,
  last_seen_at timestamp with time zone,
  CONSTRAINT notification_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT notification_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- =============================
-- 3) DIARY & ENTRIES
-- =============================

-- Main diary entries
CREATE TABLE public.entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  entry_date date NOT NULL DEFAULT (CURRENT_DATE AT TIME ZONE 'utc'::text),
  diary_text text,
  mood_score smallint CHECK (mood_score >= 1 AND mood_score <= 5),
  tags ARRAY DEFAULT '{}'::text[],
  source text DEFAULT 'mobile'::text CHECK (source = ANY (ARRAY['mobile'::text, 'web'::text, 'import'::text])),
  is_backdated boolean DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT entries_pkey PRIMARY KEY (id),
  CONSTRAINT entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Entry affirmations
CREATE TABLE public.entry_affirmations (
  entry_id uuid NOT NULL,
  affirmations jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_affirmations_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_affirmations_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Entry priorities
CREATE TABLE public.entry_priorities (
  entry_id uuid NOT NULL,
  priorities jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_priorities_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_priorities_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Entry meals
CREATE TABLE public.entry_meals (
  entry_id uuid NOT NULL,
  breakfast text,
  lunch text,
  dinner text,
  water_cups smallint DEFAULT 0 CHECK (water_cups >= 0 AND water_cups <= 8),
  CONSTRAINT entry_meals_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_meals_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Entry gratitude
CREATE TABLE public.entry_gratitude (
  entry_id uuid NOT NULL,
  grateful_items jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_gratitude_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_gratitude_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Entry self care
CREATE TABLE public.entry_self_care (
  entry_id uuid NOT NULL,
  sleep boolean,
  get_up_early boolean,
  fresh_air boolean,
  learn_new boolean,
  balanced_diet boolean,
  podcast boolean,
  me_moment boolean,
  hydrated boolean,
  read_book boolean,
  exercise boolean,
  CONSTRAINT entry_self_care_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_self_care_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Entry shower/bath
CREATE TABLE public.entry_shower_bath (
  entry_id uuid NOT NULL,
  took_shower boolean DEFAULT false,
  note text,
  CONSTRAINT entry_shower_bath_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_shower_bath_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Entry tomorrow notes
CREATE TABLE public.entry_tomorrow_notes (
  entry_id uuid NOT NULL,
  tomorrow_notes jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_tomorrow_notes_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_tomorrow_notes_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- =============================
-- 4) INSIGHTS & ANALYTICS
-- =============================

-- Entry insights
CREATE TABLE public.entry_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL,
  processed_at timestamp with time zone DEFAULT now(),
  sentiment_label text CHECK (sentiment_label = ANY (ARRAY['negative'::text, 'neutral'::text, 'positive'::text])),
  sentiment_score numeric,
  topics ARRAY DEFAULT '{}'::text[],
  summary text,
  embedding_json jsonb,
  model_version text,
  cost_tokens_prompt integer DEFAULT 0,
  cost_tokens_completion integer DEFAULT 0,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'success'::text, 'error'::text])),
  error_message text,
  CONSTRAINT entry_insights_pkey PRIMARY KEY (id),
  CONSTRAINT entry_insights_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- Weekly insights
CREATE TABLE public.weekly_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  week_start date NOT NULL,
  mood_avg numeric,
  cups_avg numeric,
  self_care_rate numeric,
  top_topics ARRAY,
  highlights text,
  generated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT weekly_insights_pkey PRIMARY KEY (id),
  CONSTRAINT weekly_insights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Analytics events
CREATE TABLE public.analytics_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  event_type text NOT NULL,
  event_at timestamp with time zone NOT NULL DEFAULT now(),
  props jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT analytics_events_pkey PRIMARY KEY (id),
  CONSTRAINT analytics_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- =============================
-- 5) PROMPTS & CONTENT
-- =============================

-- Prompts
CREATE TABLE public.prompts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  text text NOT NULL,
  category text,
  locale text,
  active boolean DEFAULT true,
  CONSTRAINT prompts_pkey PRIMARY KEY (id)
);

-- Prompt assignments
CREATE TABLE public.prompt_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  prompt_id uuid NOT NULL,
  assigned_for_date date NOT NULL,
  completed boolean DEFAULT false,
  CONSTRAINT prompt_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT prompt_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT prompt_assignments_prompt_id_fkey FOREIGN KEY (prompt_id) REFERENCES public.prompts(id)
);

-- =============================
-- 6) STREAKS & HABITS
-- =============================

-- User streaks
CREATE TABLE public.streaks (
  user_id uuid NOT NULL,
  current integer DEFAULT 0,
  longest integer DEFAULT 0,
  last_entry_date date,
  freeze_credits integer DEFAULT 0, -- Now represents grace days available (0-5)
  grace_pieces_total numeric(5,1) DEFAULT 0.0, -- Total grace pieces earned
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT streaks_pkey PRIMARY KEY (user_id),
  CONSTRAINT streaks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Streak freeze usage tracking
CREATE TABLE public.streak_freeze_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  used_at timestamp with time zone DEFAULT now(),
  reason text NOT NULL CHECK (reason = ANY (ARRAY['missed_day', 'manual_use', 'recovery', 'grace_day_used'])),
  streak_maintained integer NOT NULL,
  grace_period_days integer NOT NULL DEFAULT 1,
  grace_day_used boolean DEFAULT false, -- Track if this was a grace day usage
  created_at timestamp with time zone DEFAULT now()
);

-- Indexes for streak_freeze_usage
CREATE INDEX idx_streak_freeze_usage_user_id ON public.streak_freeze_usage(user_id);
CREATE INDEX idx_streak_freeze_usage_used_at ON public.streak_freeze_usage(used_at);

-- Daily habits
CREATE TABLE public.habits_daily (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  wrote_entry boolean DEFAULT false,
  filled_affirmations boolean DEFAULT false,
  filled_gratitude boolean DEFAULT false,
  self_care_completed_count smallint DEFAULT 0,
  grace_pieces_earned numeric(3,1) DEFAULT 0.0, -- Grace pieces earned for this day (0.5 per task)
  CONSTRAINT habits_daily_pkey PRIMARY KEY (id),
  CONSTRAINT habits_daily_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Index for grace pieces performance
CREATE INDEX idx_habits_daily_grace_pieces ON public.habits_daily(user_id, date) WHERE grace_pieces_earned > 0;

-- =============================
-- 7) FILES & STORAGE
-- =============================

-- Attachments
CREATE TABLE public.attachments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  entry_id uuid,
  file_url text NOT NULL,
  kind text CHECK (kind = ANY (ARRAY['image'::text, 'audio'::text, 'pdf'::text])),
  bytes integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT attachments_pkey PRIMARY KEY (id),
  CONSTRAINT attachments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT attachments_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

-- =============================
-- 8) NOTIFICATIONS & SCHEDULING
-- =============================

-- Notifications
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind = ANY (ARRAY['reminder'::text, 'weekly_recap'::text, 'system'::text])),
  scheduled_for timestamp with time zone,
  sent_at timestamp with time zone,
  status text DEFAULT 'scheduled'::text CHECK (status = ANY (ARRAY['scheduled'::text, 'sent'::text, 'canceled'::text, 'failed'::text])),
  meta jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Cron jobs
CREATE TABLE public.cron_jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_type text NOT NULL,
  scheduled_at timestamp with time zone,
  started_at timestamp with time zone,
  finished_at timestamp with time zone,
  status text DEFAULT 'scheduled'::text CHECK (status = ANY (ARRAY['scheduled'::text, 'running'::text, 'success'::text, 'error'::text])),
  result jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT cron_jobs_pkey PRIMARY KEY (id)
);

-- =============================
-- 9) MONETIZATION
-- =============================

-- Plans
CREATE TABLE public.plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text UNIQUE,
  name text,
  price_month numeric,
  price_year numeric,
  features ARRAY,
  active boolean DEFAULT true,
  CONSTRAINT plans_pkey PRIMARY KEY (id)
);

-- Subscriptions
CREATE TABLE public.subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  plan_id uuid,
  status text DEFAULT 'trialing'::text CHECK (status = ANY (ARRAY['trialing'::text, 'active'::text, 'paused'::text, 'canceled'::text, 'past_due'::text])),
  trial_end timestamp with time zone,
  renews_at timestamp with time zone,
  canceled_at timestamp with time zone,
  CONSTRAINT subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id)
);

-- Invoices
CREATE TABLE public.invoices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount_cents integer NOT NULL,
  currency text DEFAULT 'USD'::text,
  period_start timestamp with time zone,
  period_end timestamp with time zone,
  payment_status text DEFAULT 'paid'::text CHECK (payment_status = ANY (ARRAY['paid'::text, 'refunded'::text, 'failed'::text])),
  provider_invoice_id text,
  CONSTRAINT invoices_pkey PRIMARY KEY (id),
  CONSTRAINT invoices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- =============================
-- 10) PRIVACY & COMPLIANCE
-- =============================

-- Data exports
CREATE TABLE public.data_exports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  requested_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  download_url text,
  format text DEFAULT 'json'::text CHECK (format = ANY (ARRAY['json'::text, 'csv'::text, 'pdf'::text])),
  CONSTRAINT data_exports_pkey PRIMARY KEY (id),
  CONSTRAINT data_exports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Data deletions
CREATE TABLE public.data_deletions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  requested_at timestamp with time zone NOT NULL DEFAULT now(),
  processed_at timestamp with time zone,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text])),
  CONSTRAINT data_deletions_pkey PRIMARY KEY (id),
  CONSTRAINT data_deletions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- =============================
-- 11) ADMIN & SUPPORT
-- =============================

-- Feature flags
CREATE TABLE public.feature_flags (
  key text NOT NULL,
  enabled boolean DEFAULT false,
  notes text,
  CONSTRAINT feature_flags_pkey PRIMARY KEY (key)
);

-- Support tickets
CREATE TABLE public.support_tickets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  subject text,
  message text,
  status text DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'closed'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  closed_at timestamp with time zone,
  CONSTRAINT support_tickets_pkey PRIMARY KEY (id),
  CONSTRAINT support_tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- =============================
-- 12) ERROR LOGGING & ANALYTICS
-- =============================

-- Error logs table for comprehensive error tracking
CREATE TABLE public.error_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  
  -- Basic Error Data
  error_code text NOT NULL,
  error_message text NOT NULL,
  stack_trace text,
  error_severity text NOT NULL CHECK (error_severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
  
  -- User Data
  user_id uuid REFERENCES public.users(id),
  session_id text,
  
  -- Context Data
  screen_stack jsonb,           -- Navigation stack when error occurred
  error_context jsonb,          -- Additional context data
  retry_count integer DEFAULT 0,
  sync_status text,             -- Local/cloud sync status
  
  -- Resolution Data
  resolved_at timestamp with time zone,
  resolution_notes text,
  auto_resolved boolean DEFAULT false,
  
  CONSTRAINT error_logs_pkey PRIMARY KEY (id)
);

-- Indexes for better query performance
CREATE INDEX idx_error_logs_user_id ON public.error_logs(user_id);
CREATE INDEX idx_error_logs_error_code ON public.error_logs(error_code);
CREATE INDEX idx_error_logs_created_at ON public.error_logs(created_at);
CREATE INDEX idx_error_logs_severity ON public.error_logs(error_severity);
CREATE INDEX idx_error_logs_resolved ON public.error_logs(resolved_at) WHERE resolved_at IS NOT NULL;

-- =============================
-- 13) GRACE SYSTEM FEATURE
-- =============================

-- RLS Policies for streak_freeze_usage
ALTER TABLE public.streak_freeze_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own freeze usage" ON public.streak_freeze_usage
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own freeze usage" ON public.streak_freeze_usage
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own freeze usage" ON public.streak_freeze_usage
  FOR UPDATE USING (auth.uid() = user_id);

-- Function to calculate grace days from habits
CREATE OR REPLACE FUNCTION calculate_grace_days_from_habits(p_user_id uuid)
RETURNS TABLE(
  grace_days_available integer,
  grace_pieces_total numeric(5,1),
  pieces_today numeric(3,1),
  tasks_completed_today integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  total_pieces numeric(5,1) := 0;
  grace_days integer := 0;
  today_pieces numeric(3,1) := 0;
  today_tasks integer := 0;
  today_record RECORD;
BEGIN
  -- Get today's habits record
  SELECT * INTO today_record 
  FROM public.habits_daily 
  WHERE user_id = p_user_id AND date = CURRENT_DATE;
  
  -- Calculate today's pieces and tasks
  IF today_record.id IS NOT NULL THEN
    today_pieces := COALESCE(today_record.grace_pieces_earned, 0);
    today_tasks := (
      CASE WHEN today_record.filled_affirmations THEN 1 ELSE 0 END +
      CASE WHEN today_record.filled_gratitude THEN 1 ELSE 0 END +
      CASE WHEN today_record.wrote_entry THEN 1 ELSE 0 END +
      CASE WHEN today_record.self_care_completed_count > 0 THEN 1 ELSE 0 END
    );
  END IF;
  
  -- Calculate total pieces from all time
  SELECT COALESCE(SUM(grace_pieces_earned), 0) INTO total_pieces
  FROM public.habits_daily
  WHERE user_id = p_user_id;
  
  -- Calculate grace days (10 pieces = 1 grace day, max 5)
  grace_days := LEAST(FLOOR(total_pieces / 10), 5);
  
  RETURN QUERY SELECT grace_days, total_pieces, today_pieces, today_tasks;
END;
$$;

-- Function to update grace pieces when tasks complete
CREATE OR REPLACE FUNCTION update_grace_pieces_on_task_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  new_pieces numeric(3,1) := 0;
  total_pieces numeric(5,1) := 0;
  grace_days integer := 0;
BEGIN
  -- Calculate pieces based on completed tasks (0.5 per task)
  new_pieces := (
    CASE WHEN NEW.filled_affirmations THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.filled_gratitude THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.wrote_entry THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.self_care_completed_count > 0 THEN 0.5 ELSE 0 END
  );
  
  -- Update the grace_pieces_earned for this record
  NEW.grace_pieces_earned := new_pieces;
  
  -- Calculate total pieces and grace days
  SELECT COALESCE(SUM(grace_pieces_earned), 0) INTO total_pieces
  FROM public.habits_daily
  WHERE user_id = NEW.user_id;
  
  grace_days := LEAST(FLOOR(total_pieces / 10), 5);
  
  -- Update streaks table
  UPDATE public.streaks 
  SET 
    freeze_credits = grace_days,
    grace_pieces_total = total_pieces,
    updated_at = now()
  WHERE user_id = NEW.user_id;
  
  RETURN NEW;
END;
$$;

-- Create trigger for automatic grace pieces calculation
CREATE TRIGGER trigger_update_grace_pieces
  BEFORE INSERT OR UPDATE ON public.habits_daily
  FOR EACH ROW
  EXECUTE FUNCTION update_grace_pieces_on_task_completion();

-- =============================
-- END OF SCHEMA
-- =============================