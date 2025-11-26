## AI Queue Optimization Plan (DeepSeek × Cursor)

### Objective
Implement the DB-first batching logic from `refine_logic1.md` **inside our current Supabase project** without regressing any AI feature. This document is the single source of truth for the rollout order, guardrails, and validation steps.

---

### Step 0 · Ground Checks (must pass before touching code)
1. **Inventory current behavior**
   - `populate-analysis-queue` (edge function) + cron every 5 min.
   - `process-ai-queue` hourly with timezone filtering, retries, `target_date <= yesterday`.
   - `check_entry_completion` RPC enforces 4 mandatory sections.
2. **Confirm metadata**
   - Note DB schema versions, existing indexes (`entries.user_id`, `entry_insights.entry_id`, `analysis_queue.entry_id`), and cron job IDs.
   - Snapshot Supabase logs (`db_function_log.md`) to compare request counts later.

**Readiness status (2025-11-26)**
- Verified current JS implementation in `supabase/functions/populate-analysis-queue/index.ts` and `process-ai-queue/index.ts`; behavior matches the baseline described above.
- Confirmed schema + indexes from `supabase/migrations/001_ai_feature_setup.sql` (`idx_entry_insights_entry_id`, `idx_entry_insights_status`, etc.) and `bc/Project3/tables_queries.md`; no conflicting constraints.
- `check_entry_completion` RPC already exists (referenced by multiple edge functions) and returns a boolean, so we can call it directly from SQL.
- Cron metadata + Supabase log snapshot referenced in `bc/AI/refinev4/db_function_log.md`; nothing else blocks SQL work.

---

### Step 1 · Design the SQL Batch Function
Target: `process_analysis_queue_batch()` described in `refine_logic1.md` but aligned with our data rules.

Specs to bake in:
1. **Completion gate**  
   - For every candidate entry call `check_entry_completion(entry_uuid)` (or inline the same checks) before inserting.
2. **Daily scheduling**  
   - `target_date` = entry’s date.  
   - `next_retry_at` = tomorrow midnight in user timezone converted to UTC (reuse existing timezone RPC logic but in SQL).
3. **Catch-up logic (30 days)**  
   - Scan `entries` within `[user_today-30, user_today)` that still lack insights/queue rows.  
   - Same completion + scheduling rules as “today”.
4. **Weekly block**  
   - Trigger only when user timezone is Sunday 00:00.  
   - Require ≥3 entries in the previous week.  
   - Ensure no existing weekly insight or queued job (`analysis_queue`).
5. **Monthly block**  
   - Trigger when user timezone is 1st-of-month 00:00.  
   - Require ≥10 entries in the previous month.  
   - Same dedupe rules as weekly.
6. **Result payload**  
   - Return `users_processed`, `daily_jobs_created`, `weekly_jobs_created`, `monthly_jobs_created`.  
   - Wrap counts with `COALESCE` to avoid nulls.

Deliverable: reviewed SQL spec inside this doc before coding.

**Implementation blueprint**
- `calculate_next_midnight_utc(p_timezone text, p_user_today date)` helper returns the next-day midnight converted to UTC via `make_timestamptz`; reused for all inserted jobs.
- Primary function builds a `user_context` CTE (`user_id`, timezone, `user_today`, `user_hour`, `user_dow`) derived from `NOW()` with `AT TIME ZONE`.
- `daily_candidates` joins `entries` for `user_today`, filters with `check_entry_completion(entry_uuid => entry_id)`, `length(diary_text) >= 50`, and ensures no `entry_insights` success row or pending queue record. Catch-up logic lives in `catchup_entries` scanning `[user_today-30, user_today)` per user.
- `weekly_candidates` evaluate only when `user_dow = 0` and `user_hour = 0`, compute `week_start = date_trunc('week', user_today - interval '7 days')`, require ≥3 entries in that previous week, and ensure neither `weekly_insights` nor `analysis_queue` has a record for that `week_start`.
- `monthly_candidates` trigger when `user_today` is the 1st and `user_hour = 0`, compute `month_start = date_trunc('month', user_today - interval '1 month')`, require ≥10 entries across that month, and dedupe against `monthly_insights` + queue rows.
- Insert statements run in one transaction via `INSERT ... SELECT` CTEs, returning counts per block. All counts roll up into `RETURN QUERY SELECT processed_users, daily_jobs, weekly_jobs, monthly_jobs` with `COALESCE`.

---

### Step 2 · Build & Test the SQL Function
1. Create the function in Supabase SQL editor / migration:
   - Use CTEs (`daily_candidates`, `catchup_entries`, `weekly_candidates`, `monthly_candidates`).  
   - Exclude rows where `entry_id IS NULL`.  
   - Use `AT TIME ZONE` to derive user-local dates.
2. Add helper functions if needed:
   - e.g., `calculate_next_midnight_utc(user_timezone, base_date)` returning timestamp.
3. Unit tests:
   - Manual `SELECT process_analysis_queue_batch();` on staging data.  
   - Verify counts and inserted rows in `analysis_queue`.  
   - Confirm no job is inserted when completion fails or insight already exists.

Rollback plan: `DROP FUNCTION process_analysis_queue_batch;`

---

### Step 3 · Update Edge Function
1. Replace `populate-analysis-queue/index.ts` body with a simple RPC call:
   ```ts
   const { data, error } = await supabase.rpc('process_analysis_queue_batch');
   ```
2. Keep logging for observability (log payload + error).  
3. Remove redundant REST calls, caches, etc.—logic now lives in SQL.

---

### Step 4 · Cron & Runtime Adjustments
1. Unschedule the old 5-min cron (already paused).  
2. Create a new cron job (or pg_cron entry) to run every 30 minutes:
   - `SELECT cron.schedule('populate-analysis-queue-batch', '*/30 * * * *', $$ ... $$);`
   - Payload hits the edge function (which now calls the RPC).
3. Keep `process-ai-queue` hourly as-is.  
4. Monitor queue length—adjust frequency if backlog occurs (function is efficient enough for 15-min if required).

---

### Step 5 · Validation Checklist
1. **DB assertions**
   - `SELECT COUNT(*) FROM analysis_queue WHERE created_at > NOW() - INTERVAL '1 hour';` (ensure jobs exist).  
   - Inspect `analysis_queue` rows for correct `next_retry_at` (UTC midnight).
2. **Edge logs**
   - `console.log` output from edge function should show counts without errors.
3. **REST usage**
   - Compare new logs with baseline (expect <10 REST calls/hour).
4. **End-to-end**
   - Manually trigger `process-ai-queue` and confirm insights are generated as before.  
   - QA: create partial entry → ensure NOT queued; create full entry → queued next day.

---

### Risks & Mitigations

| Risk | Mitigation |
| --- | --- |
| SQL function bug queues wrong jobs | Use staging project first, run diff queries (`EXCEPT`) against old queue output. |
| Completion logic diverges | Reuse `check_entry_completion` RPC within SQL to ensure consistency. |
| Timezone miscalc | Cross-check with existing `get_date_in_timezone` results; add unit tests with sample timezones (UTC, IST, PST). |
| Cron misfire | Keep manual “Run Now” button via Supabase dashboard during rollout. |

---

### Timeline (single-track)
1. Step 0–1 (design) — 0.5 day  
2. Step 2 (SQL build + tests) — 1 day  
3. Step 3 (edge refactor) — 0.5 day  
4. Step 4–5 (cron + validation) — 0.5 day  
**Total:** ~2.5 days with buffer.

---

### Key References
- `refine_logic1.md` – original DeepSeek batch SQL draft.  
- `populate-analysis-queue/index.ts` – current logic to retire.  
- `process-ai-queue/index.ts` – remains unchanged.  
- `check_entry_completion` RPC – completion contract.

---

**Next action:** green-light Step 0 readiness check, then proceed sequentially. Once Step 2 SQL passes tests, we can deploy the edge refactor + cron updates confidently.*** End Patch
