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
  streak_compassion_enabled boolean DEFAULT true,
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
  freeze_credits integer DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT streaks_pkey PRIMARY KEY (user_id),
  CONSTRAINT streaks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

-- Daily habits
CREATE TABLE public.habits_daily (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  wrote_entry boolean DEFAULT false,
  filled_affirmations boolean DEFAULT false,
  filled_gratitude boolean DEFAULT false,
  self_care_completed_count smallint DEFAULT 0,
  CONSTRAINT habits_daily_pkey PRIMARY KEY (id),
  CONSTRAINT habits_daily_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

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
-- END OF SCHEMA
-- =============================