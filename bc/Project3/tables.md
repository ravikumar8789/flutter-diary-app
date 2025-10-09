# Tables — Project 3 (Comprehensive)

Note: Conceptual data model listing all entities and fields for the journaling app. No SQL yet; names are indicative and can be refined during schema design.

## 1) Users & Accounts
- users
  - id (uuid)
  - email (text)
  - email_verified (bool)
  - display_name (text)
  - avatar_url (text)
  - created_at (timestamptz)
  - updated_at (timestamptz)
  - locale (text)
  - timezone (text)
  - marketing_opt_in (bool)

- user_profiles
  - user_id (uuid, pk, fk → users)
  - bio (text)
  - onboarding_complete (bool)
  - theme_preference (enum: system/light/dark)
  - diary_font (text)
  - font_size (int)
  - paper_style (enum: plain/ruled/grid)

- auth_providers
  - id (uuid)
  - user_id (uuid)
  - provider (text: password, magic_link, google, apple, etc.)
  - provider_uid (text)
  - linked_at (timestamptz)

## 2) Settings & Preferences
- user_settings
  - user_id (uuid, pk)
  - reminder_enabled (bool)
  - reminder_time_local (time)
  - reminder_days (int2[] 1–7)
  - streak_compassion_enabled (bool)
  - privacy_lock_enabled (bool)
  - region_preference (text)
  - export_format_default (enum: pdf/csv/json)

- notification_tokens
  - id (uuid)
  - user_id (uuid)
  - platform (text: ios/android/web)
  - fcm_token (text)
  - last_seen_at (timestamptz)

## 3) Diary & Affirmations (Fixed Inputs)
- entries
  - id (uuid)
  - user_id (uuid)
  - entry_date (date)  // allows one per day but not enforced here
  - diary_text (text)
  - mood_score (int2 1–5)
  - tags (text[] from fixed set)
  - created_at (timestamptz)
  - updated_at (timestamptz)
  - source (enum: mobile/web/import)
  - is_backdated (bool)

- entry_affirmations
  - entry_id (uuid, pk, fk → entries)
  - a1 (text, 80c)
  - a2 (text)
  - a3 (text)
  - a4 (text)
  - a5 (text)

- entry_priorities
  - entry_id (uuid, pk)
  - p1 (text)
  - p2 (text)
  - p3 (text)
  - p4 (text)
  - p5 (text)
  - p6 (text)

- entry_meals
  - entry_id (uuid, pk)
  - breakfast (text)
  - lunch (text)
  - dinner (text)
  - water_cups (int2 0–8)

- entry_gratitude
  - entry_id (uuid, pk)
  - g1 (text)
  - g2 (text)
  - g3 (text)
  - g4 (text)
  - g5 (text)
  - g6 (text)

- entry_self_care
  - entry_id (uuid, pk)
  - sleep (bool)
  - get_up_early (bool)
  - fresh_air (bool)
  - learn_new (bool)
  - balanced_diet (bool)
  - podcast (bool)
  - me_moment (bool)
  - hydrated (bool)
  - read_book (bool)
  - exercise (bool)

- entry_shower_bath
  - entry_id (uuid, pk)
  - took_shower (bool)
  - note (text)

- entry_tomorrow_notes
  - entry_id (uuid, pk)
  - n1 (text)
  - n2 (text)
  - n3 (text)
  - n4 (text)

## 4) Insights & Analytics
- entry_insights
  - id (uuid)
  - entry_id (uuid)
  - processed_at (timestamptz)
  - sentiment_label (enum: negative/neutral/positive)
  - sentiment_score (numeric)
  - topics (text[])
  - summary (text)
  - embedding_vector (vector | jsonb) // optional for semantic search later
  - model_version (text)
  - cost_tokens_prompt (int)
  - cost_tokens_completion (int)
  - status (enum: pending/success/error)
  - error_message (text)

- weekly_insights
  - id (uuid)
  - user_id (uuid)
  - week_start (date)
  - mood_avg (numeric)
  - cups_avg (numeric)
  - self_care_rate (numeric)
  - top_topics (text[])
  - highlights (text)
  - generated_at (timestamptz)

- analytics_events (privacy-safe)
  - id (uuid)
  - user_id (uuid)
  - event_type (text)
  - event_at (timestamptz)
  - props (jsonb)

## 5) Prompts & Content
- prompts
  - id (uuid)
  - text (text)
  - category (text)
  - locale (text)
  - active (bool)

- prompt_assignments
  - id (uuid)
  - user_id (uuid)
  - prompt_id (uuid)
  - assigned_for_date (date)
  - completed (bool)

## 6) Streaks & Habits
- streaks
  - user_id (uuid, pk)
  - current (int)
  - longest (int)
  - last_entry_date (date)
  - freeze_credits (int)
  - updated_at (timestamptz)

- habits_daily
  - id (uuid)
  - user_id (uuid)
  - date (date)
  - wrote_entry (bool)
  - filled_affirmations (bool)
  - filled_gratitude (bool)
  - self_care_completed_count (int2)

## 7) Files & Storage
- attachments
  - id (uuid)
  - user_id (uuid)
  - entry_id (uuid)
  - file_url (text)
  - kind (enum: image/audio/pdf)
  - bytes (int)
  - created_at (timestamptz)

## 8) Notifications & Scheduling
- notifications
  - id (uuid)
  - user_id (uuid)
  - kind (enum: reminder/weekly_recap/system)
  - scheduled_for (timestamptz)
  - sent_at (timestamptz)
  - status (enum: scheduled/sent/canceled/failed)
  - meta (jsonb)

- cron_jobs (for workers)
  - id (uuid)
  - job_type (text: nightly_insights, weekly_recap)
  - scheduled_at (timestamptz)
  - started_at (timestamptz)
  - finished_at (timestamptz)
  - status (enum: scheduled/running/success/error)
  - result (jsonb)

## 9) Monetization (Optional, if/when enabled)
- plans
  - id (uuid)
  - code (text)
  - name (text)
  - price_month (numeric)
  - price_year (numeric)
  - features (text[])
  - active (bool)

- subscriptions
  - id (uuid)
  - user_id (uuid)
  - plan_id (uuid)
  - status (enum: trialing/active/paused/canceled/past_due)
  - trial_end (timestamptz)
  - renews_at (timestamptz)
  - canceled_at (timestamptz)

- invoices
  - id (uuid)
  - user_id (uuid)
  - amount_cents (int)
  - currency (text)
  - period_start (timestamptz)
  - period_end (timestamptz)
  - payment_status (enum: paid/refunded/failed)
  - provider_invoice_id (text)

## 10) Privacy & Compliance
- data_exports
  - id (uuid)
  - user_id (uuid)
  - requested_at (timestamptz)
  - completed_at (timestamptz)
  - download_url (text)
  - format (enum: json/csv/pdf)

- data_deletions
  - id (uuid)
  - user_id (uuid)
  - requested_at (timestamptz)
  - processed_at (timestamptz)
  - status (enum: pending/completed/failed)

## 11) Admin & Support
- feature_flags
  - key (text, pk)
  - enabled (bool)
  - notes (text)

- support_tickets
  - id (uuid)
  - user_id (uuid)
  - subject (text)
  - message (text)
  - status (enum: open/closed)
  - created_at (timestamptz)
  - closed_at (timestamptz)

---

This list is intentionally exhaustive to cover MVP and near-future needs. We can trim for the first schema migration and incrementally add tables as features ship.
