-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.ai_errors_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  user_id uuid,
  entry_id uuid,
  analysis_type text NOT NULL CHECK (analysis_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'affirmation'::text])),
  error_code text NOT NULL,
  error_message text NOT NULL,
  error_type text NOT NULL CHECK (error_type = ANY (ARRAY['openai_api_error'::text, 'supabase_error'::text, 'validation_error'::text, 'network_error'::text, 'timeout_error'::text, 'rate_limit_error'::text, 'data_error'::text, 'unknown_error'::text])),
  error_severity text NOT NULL CHECK (error_severity = ANY (ARRAY['CRITICAL'::text, 'HIGH'::text, 'MEDIUM'::text, 'LOW'::text])),
  request_body jsonb,
  request_duration_ms integer,
  retry_attempt integer DEFAULT 0,
  edge_function_name text NOT NULL,
  environment text DEFAULT 'production'::text,
  deno_version text,
  stack_trace text,
  error_details jsonb DEFAULT '{}'::jsonb,
  failed_at_step text,
  auto_retry_attempted boolean DEFAULT false,
  manual_retry_required boolean DEFAULT false,
  resolved_at timestamp with time zone,
  resolution_notes text,
  related_request_id uuid,
  cost_impact_usd numeric DEFAULT 0,
  CONSTRAINT ai_errors_log_pkey PRIMARY KEY (id),
  CONSTRAINT ai_errors_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT ai_errors_log_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id),
  CONSTRAINT ai_errors_log_related_request_id_fkey FOREIGN KEY (related_request_id) REFERENCES public.ai_requests_log(id)
);
CREATE TABLE public.ai_prompt_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  template_name text NOT NULL UNIQUE,
  system_prompt text NOT NULL,
  user_prompt_template text NOT NULL,
  temperature numeric DEFAULT 0.7,
  max_tokens integer DEFAULT 500,
  analysis_type text NOT NULL CHECK (analysis_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'affirmation'::text])),
  version integer DEFAULT 1,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ai_prompt_templates_pkey PRIMARY KEY (id)
);
CREATE TABLE public.ai_requests_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  entry_id uuid,
  analysis_type text NOT NULL CHECK (analysis_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'affirmation'::text])),
  prompt_tokens integer NOT NULL DEFAULT 0,
  completion_tokens integer NOT NULL DEFAULT 0,
  total_tokens integer NOT NULL DEFAULT 0,
  cost_usd numeric NOT NULL DEFAULT 0,
  model_used text DEFAULT 'gpt-4o-mini'::text,
  status text DEFAULT 'success'::text CHECK (status = ANY (ARRAY['success'::text, 'error'::text, 'rate_limited'::text, 'timeout'::text])),
  error_message text,
  request_duration_ms integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_requests_log_pkey PRIMARY KEY (id),
  CONSTRAINT ai_requests_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT ai_requests_log_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.analysis_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  analysis_type text NOT NULL CHECK (analysis_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text])),
  target_date date NOT NULL,
  entry_id uuid,
  week_start date,
  month_start date,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text])),
  attempts integer DEFAULT 0,
  max_attempts integer DEFAULT 3,
  next_retry_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  processed_at timestamp with time zone,
  CONSTRAINT analysis_queue_pkey PRIMARY KEY (id),
  CONSTRAINT analysis_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.analytics_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  event_type text NOT NULL,
  event_at timestamp with time zone NOT NULL DEFAULT now(),
  props jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT analytics_events_pkey PRIMARY KEY (id),
  CONSTRAINT analytics_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
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
CREATE TABLE public.auth_providers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider text NOT NULL,
  provider_uid text,
  linked_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT auth_providers_pkey PRIMARY KEY (id),
  CONSTRAINT auth_providers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
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
CREATE TABLE public.data_deletions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  requested_at timestamp with time zone NOT NULL DEFAULT now(),
  processed_at timestamp with time zone,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text])),
  CONSTRAINT data_deletions_pkey PRIMARY KEY (id),
  CONSTRAINT data_deletions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
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
CREATE TABLE public.entry_affirmations (
  entry_id uuid NOT NULL,
  affirmations jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_affirmations_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_affirmations_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.entry_gratitude (
  entry_id uuid NOT NULL,
  grateful_items jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_gratitude_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_gratitude_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.entry_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL UNIQUE,
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
  ai_generated boolean DEFAULT false,
  analysis_type text CHECK (analysis_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text])),
  insight_text text,
  insight_details jsonb,
  CONSTRAINT entry_insights_pkey PRIMARY KEY (id),
  CONSTRAINT entry_insights_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.entry_meals (
  entry_id uuid NOT NULL,
  breakfast text,
  lunch text,
  dinner text,
  water_cups smallint DEFAULT 0 CHECK (water_cups >= 0 AND water_cups <= 8),
  CONSTRAINT entry_meals_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_meals_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.entry_priorities (
  entry_id uuid NOT NULL,
  priorities jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_priorities_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_priorities_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
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
CREATE TABLE public.entry_shower_bath (
  entry_id uuid NOT NULL,
  took_shower boolean DEFAULT false,
  note text,
  CONSTRAINT entry_shower_bath_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_shower_bath_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.entry_tomorrow_notes (
  entry_id uuid NOT NULL,
  tomorrow_notes jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT entry_tomorrow_notes_pkey PRIMARY KEY (entry_id),
  CONSTRAINT entry_tomorrow_notes_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);
CREATE TABLE public.error_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  error_code text NOT NULL,
  error_message text NOT NULL,
  stack_trace text,
  error_severity text NOT NULL CHECK (error_severity = ANY (ARRAY['CRITICAL'::text, 'HIGH'::text, 'MEDIUM'::text, 'LOW'::text])),
  user_id uuid,
  session_id text,
  screen_stack jsonb,
  error_context jsonb,
  retry_count integer DEFAULT 0,
  sync_status text,
  resolved_at timestamp with time zone,
  resolution_notes text,
  auto_resolved boolean DEFAULT false,
  CONSTRAINT error_logs_pkey PRIMARY KEY (id),
  CONSTRAINT error_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.feature_flags (
  key text NOT NULL,
  enabled boolean DEFAULT false,
  notes text,
  CONSTRAINT feature_flags_pkey PRIMARY KEY (key)
);
CREATE TABLE public.habits_daily (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  wrote_entry boolean DEFAULT false,
  filled_affirmations boolean DEFAULT false,
  filled_gratitude boolean DEFAULT false,
  self_care_completed_count smallint DEFAULT 0,
  grace_pieces_earned numeric DEFAULT 0.0,
  CONSTRAINT habits_daily_pkey PRIMARY KEY (id),
  CONSTRAINT habits_daily_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
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
CREATE TABLE public.monthly_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  month_start date NOT NULL,
  mood_avg numeric,
  entries_count integer DEFAULT 0,
  word_count_total integer DEFAULT 0,
  top_topics ARRAY DEFAULT '{}'::text[],
  monthly_highlights text,
  growth_areas ARRAY DEFAULT '{}'::text[],
  achievements ARRAY DEFAULT '{}'::text[],
  next_month_goals ARRAY DEFAULT '{}'::text[],
  generated_at timestamp with time zone DEFAULT now(),
  consistency_score numeric,
  habit_analysis jsonb DEFAULT '{}'::jsonb,
  mood_trend_monthly text,
  model_version text,
  cost_tokens_prompt integer DEFAULT 0,
  cost_tokens_completion integer DEFAULT 0,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'success'::text, 'error'::text])),
  error_message text,
  CONSTRAINT monthly_insights_pkey PRIMARY KEY (id),
  CONSTRAINT monthly_insights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.notification_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  platform text CHECK (platform = ANY (ARRAY['ios'::text, 'android'::text, 'web'::text])),
  fcm_token text NOT NULL,
  last_seen_at timestamp with time zone,
  CONSTRAINT notification_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT notification_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
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
CREATE TABLE public.prompts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  text text NOT NULL,
  category text,
  locale text,
  active boolean DEFAULT true,
  CONSTRAINT prompts_pkey PRIMARY KEY (id)
);
CREATE TABLE public.streak_freeze_usage (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  used_at timestamp with time zone DEFAULT now(),
  reason text NOT NULL CHECK (reason = ANY (ARRAY['missed_day'::text, 'manual_use'::text, 'recovery'::text, 'grace_day_used'::text])),
  streak_maintained integer NOT NULL,
  grace_period_days integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  grace_day_used boolean DEFAULT false,
  CONSTRAINT streak_freeze_usage_pkey PRIMARY KEY (id),
  CONSTRAINT streak_freeze_usage_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.streaks (
  user_id uuid NOT NULL,
  current integer DEFAULT 0,
  longest integer DEFAULT 0,
  last_entry_date date,
  freeze_credits integer DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  grace_pieces_total numeric DEFAULT 0.0,
  CONSTRAINT streaks_pkey PRIMARY KEY (user_id),
  CONSTRAINT streaks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
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
  week_end date,
  ai_generated boolean DEFAULT true,
  mood_trend text CHECK (mood_trend = ANY (ARRAY['improving'::text, 'declining'::text, 'stable'::text, 'volatile'::text])),
  key_insights ARRAY,
  recommendations ARRAY,
  habit_correlations jsonb DEFAULT '{}'::jsonb,
  consistency_score numeric,
  entries_count integer DEFAULT 0,
  word_count_total integer DEFAULT 0,
  model_version text,
  cost_tokens_prompt integer DEFAULT 0,
  cost_tokens_completion integer DEFAULT 0,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'success'::text, 'error'::text])),
  error_message text,
  CONSTRAINT weekly_insights_pkey PRIMARY KEY (id),
  CONSTRAINT weekly_insights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);