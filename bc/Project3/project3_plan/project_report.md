# Project 3 — AI-Powered Journaling App (End-to-End Plan)

## Vision
An AI-assisted, privacy-first journaling app that helps people build a daily writing habit, understand mood trends, and track personal growth with compassionate nudges and clear progress.

## Objectives
- Deliver a delightful, low-friction journaling experience.
- Encourage habit consistency through gentle streaks, prompts, and reminders.
- Provide meaningful insights (sentiment, themes, trends) with cost-aware AI.
- Preserve user trust via robust privacy, security, and data control.
- Validate monetization with a freemium model and premium AI insights.

## Target Users
- Self-improvement seekers and students building reflective habits.
- Therapy/coaching companions who want a private space with insights.
- Busy professionals needing lightweight reflection and mood tracking.

---

## Product Scope

### Core MVP (v0.1)
- Daily journal entry (rich text), mood scale (1–5), and optional tags.
- Local-first editor: offline write, later sync; conflict policy: last-writer-wins with diff preview.
- Basic charts: 7-day streak, 14-day mood trend.
- Smart reminders: time-based with snooze; anti-fatigue rules.
- Account auth with email/password + magic link.

### AI (v0.2)
- Nightly processing for each entry:
  - Sentiment classification (pos/neu/neg) and score.
  - Topics/tags suggestions.
  - 3-bullet reflective summary (token-capped).
- Caching and batching to control API spend.

### Insights & Analytics (v0.3)
- Weekly recap with highlights (streak, mood changes, themes).
- Trend comparisons over custom ranges.
- Export PDF/CSV of entries and insights.

### Nice-to-Haves (later)
- Prompt packs, custom templates.
- Anonymous sharing of generic learnings (privacy-first).
- Institutional plans (schools/clinics) after PMF.

---

## Non-Goals (for MVP)
- Public social feeds.
- Complex multi-user collaboration.
- Heavy on-device models.

---

## Monetization Strategy
- Freemium: core journaling free.
- Premium: AI weekly insights, deep trends, custom prompts.
- Pricing target: $4.99/mo or $49.99/yr; 7-day trial; early-bird coupon.
- Guardrails: token budgets, per-user daily cap, fallback summaries if API unavailable.

---

## Success Metrics
- D1/D7/D30 retention; weekly active writers (WAW).
- Median entries/week; average streak length.
- Premium conversion rate; churn reasons.
- AI cost per active user; API error rate/latency.

---

## Architecture Overview
- Frontend: Flutter (Dart) for iOS/Android.
- Backend: Supabase (Auth, Postgres, Storage, Analytics).
- AI: OpenAI API (sentiment, tags, summaries) with batching/caching.
- Notifications: Firebase Cloud Messaging.
- State management: Riverpod/Provider.

### Data Model (initial)
- users
- entries(id, user_id, content, mood, tags[], created_at)
- entry_insights(id, entry_id, sentiment_label, sentiment_score, topics[], summary, processed_at)
- streaks(user_id, current, longest, updated_at)
- prompts(id, text, category)
- settings(user_id, reminder_prefs, privacy_prefs)

### Security & Privacy
- TLS in transit; field-level encryption for `entries.content` at rest.
- Supabase RLS on all user-scoped tables.
- Data controls: export (JSON/CSV/PDF), delete, region preference.
- Minimal logging of PII; redact in traces.

---

## Project Plan & Timeline

### Phase 1: Foundation (Weeks 1–2)
- Project setup, repo standards, CI.
- Flutter init with clean folders; theming and design tokens.
- Supabase project + Postgres schema + RLS; Auth setup.

### Phase 2: Core Features (Weeks 3–6)
- Journal editor (offline-first) with mood scale and tags.
- Local cache + sync engine; conflict resolution UX.
- Basic charts (streak, mood trend) and reminders (FCM).

### Phase 3: AI Integration (Weeks 7–10)
- Nightly batch worker to process entries → insights.
- Token budgeting, retries, error audits; caching embeddings.
- Display per-entry insights; start weekly recap.

### Phase 4: Analytics & Reports (Weeks 11–13)
- Trends dashboard, export to PDF/CSV.
- Weekly/monthly reports; growth comparisons.

### Phase 5: Polish & Launch (Weeks 14–15)
- UX refinement, a11y, perf; beta and feedback.
- Store assets, review, and rollout.

---

## Implementation Details

### Flutter Modules
- features/journal
- features/insights
- features/analytics
- features/auth
- core/network, core/storage, core/ui, core/state

### Key Screens
- Onboarding & privacy explainer
- Home (streak, quick add)
- Editor (entry, mood, tags)
- Timeline (entries list)
- Insights (per-entry + weekly)
- Settings (reminders, privacy, export/delete)

### Supabase Schema (DDL sketch)
```sql
create table entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  mood int2 check (mood between 1 and 5),
  tags text[] default '{}',
  created_at timestamptz not null default now()
);

create table entry_insights (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references entries(id) on delete cascade,
  sentiment_label text check (sentiment_label in ('negative','neutral','positive')),
  sentiment_score numeric,
  topics text[] default '{}',
  summary text,
  processed_at timestamptz default now()
);

alter table entries enable row level security;
alter table entry_insights enable row level security;

create policy "owner-can-read-write-entries" on entries
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner-can-read-write-insights" on entry_insights
for all using (
  exists (select 1 from entries e where e.id = entry_id and e.user_id = auth.uid())
) with check (
  exists (select 1 from entries e where e.id = entry_id and e.user_id = auth.uid())
);
```

### AI Processing Flow
- Trigger: nightly cron or queue on new entry.
- Steps: fetch unprocessed entries → run sentiment/topics/summary → write `entry_insights` → mark processed.
- Cost controls: batch by user/day, token caps, retries with backoff, cache embeddings.
- Failure paths: store error reason; show fallback “insight pending”.

### Notifications
- Daily reminder window; snooze; auto-dampen if ignored 3×.
- Weekly recap notification linking to insights.

### Testing & QA
- Unit tests for sync engine, RLS policies, and reducers.
- Golden tests for UI; integration tests for editor and auth.
- Load test AI worker with synthetic entries.

### Observability
- Track: write latency, sync conflicts, AI failure rate, token spend, WAW, streak length.
- Dashboards and alerts; privacy-safe logs.

---

## Risks & Mitigations
- AI cost spikes → batching, caching, caps, summaries delayed to next day.
- Privacy concerns → encryption, RLS, transparent controls, minimal PII.
- Engagement drop → compassionate streaks, prompt rotation, weekly highlights.
- Scope creep → defer social/corporate; stick to MVP KPIs.

---

## Operational Runbook
- Secrets via environment (Supabase keys, OpenAI keys).
- Rollbacks: feature flags for AI; dark launch weekly recap.
- Backups: daily DB snapshots; client-side export.
- Incident playbook: AI outage → fallback summaries; notify users if prolonged.

---

## Road to PMF
- Dogfood internally; 50–100 early users.
- Iterate on prompts and insights based on retention and qualitative feedback.
- Expand once D30 retention and premium conversion cross targets.
