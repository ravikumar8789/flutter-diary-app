# Dashboard status control — database change (commands & SQL)

Spec for richer **change / change_review / change_task** lifecycles, required remarks, terminal notes, and guards. Apply via Supabase CLI or SQL Editor.

---

## 1. Commands (Supabase CLI)

From the **diaryapp repo root** (where `supabase/` lives):

```bash
# Optional: confirm project link
supabase projects list
supabase link --project-ref YOUR_PROJECT_REF
```

**Option A — new migration file (recommended)**  
Copy the SQL in §3 into a new file, then push:

```bash
# Create empty migration (or paste SQL into the file it opens)
supabase migration new dashboard_status_control

# After saving SQL under supabase/migrations/<timestamp>_dashboard_status_control.sql:
supabase db push
```

**Option B — run SQL manually**  
Paste §3 into **Supabase Dashboard → SQL → New query** → Run (review in staging first).

**Option C — local reset (destructive; dev only)**

```bash
supabase db reset
```

---

## 2. Verification queries (after apply)

```sql
-- changes.status allowed values (spot-check constraint)
SELECT DISTINCT status FROM public.changes;

-- CR / CTASK vocab
SELECT DISTINCT status FROM public.change_reviews ORDER BY 1;
SELECT DISTINCT status FROM public.change_tasks ORDER BY 1;

-- Terminal rows must have final_state_note
SELECT id, change_id, status, final_state_note
FROM public.changes
WHERE status IN ('closed', 'rollbacked', 'cancelled', 'rejected')
  AND (final_state_note IS NULL OR trim(final_state_note) = '');
```

---

## 3. Reference migration SQL (`011_dashboard_status_control.sql`)

Save as `supabase/migrations/011_dashboard_status_control.sql` (adjust filename if your sequence differs).

```sql
-- 011: Dashboard status control — enums, audit columns, terminal note, data backfill.
-- Depends on 008, 009, 010.

-- ---------------------------------------------------------------------------
-- 1) changes: terminal note + rejected status
-- ---------------------------------------------------------------------------
ALTER TABLE public.changes
  ADD COLUMN IF NOT EXISTS final_state_note text;

COMMENT ON COLUMN public.changes.final_state_note IS
  'Long-form note required when status is closed, rollbacked, cancelled, or rejected.';

-- Backfill existing terminal rows so new CHECK passes
UPDATE public.changes
SET final_state_note = COALESCE(
  NULLIF(trim(status_remark), ''),
  'Migrated: no final_state_note; see status_history.'
)
WHERE status IN ('closed', 'rollbacked', 'cancelled')
  AND (final_state_note IS NULL OR trim(final_state_note) = '');

ALTER TABLE public.changes DROP CONSTRAINT IF EXISTS changes_status_check;
ALTER TABLE public.changes ADD CONSTRAINT changes_status_check
  CHECK (status IN ('new', 'started', 'closed', 'cancelled', 'rollbacked', 'rejected'));

ALTER TABLE public.changes DROP CONSTRAINT IF EXISTS changes_final_note_when_terminal;
ALTER TABLE public.changes ADD CONSTRAINT changes_final_note_when_terminal
  CHECK (
    status NOT IN ('closed', 'rollbacked', 'cancelled', 'rejected')
    OR (final_state_note IS NOT NULL AND length(trim(final_state_note)) > 0)
  );

-- ---------------------------------------------------------------------------
-- 2) change_reviews: rejection remark, status_history, new status vocabulary
-- ---------------------------------------------------------------------------
ALTER TABLE public.change_reviews
  ADD COLUMN IF NOT EXISTS rejection_remark text;

COMMENT ON COLUMN public.change_reviews.rejection_remark IS
  'Remark when CR is rejected (e.g. propagated from CTASK reject).';

ALTER TABLE public.change_reviews
  ADD COLUMN IF NOT EXISTS status_history jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.change_reviews.status_history IS
  'Append-only audit: transitions with from, to, remark, at, ref.';

-- Map old label to new
UPDATE public.change_reviews SET status = 'open' WHERE status = 'requested';

ALTER TABLE public.change_reviews DROP CONSTRAINT IF EXISTS change_reviews_status_check;
ALTER TABLE public.change_reviews ADD CONSTRAINT change_reviews_status_check
  CHECK (status IN ('new', 'open', 'implementing', 'approved', 'rejected', 'cancelled'));

-- ---------------------------------------------------------------------------
-- 3) change_tasks: status_history + new status vocabulary
-- ---------------------------------------------------------------------------
ALTER TABLE public.change_tasks
  ADD COLUMN IF NOT EXISTS status_history jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.change_tasks.status_history IS
  'Append-only audit: transitions with from, to, remark, at, ref.';

UPDATE public.change_tasks SET status = 'open' WHERE status = 'pending';

ALTER TABLE public.change_tasks DROP CONSTRAINT IF EXISTS change_tasks_status_check;
ALTER TABLE public.change_tasks ADD CONSTRAINT change_tasks_status_check
  CHECK (status IN ('new', 'open', 'implementing', 'closed', 'rejected', 'skipped', 'cancelled'));

-- ---------------------------------------------------------------------------
-- 4) Optional: remark required when status changes (stub — tighten in app or extend)
-- Dashboard should append status_history and set status_remark on every save.
-- ---------------------------------------------------------------------------
-- Example pattern (uncomment and customize if you want DB-enforced remarks):
--
-- CREATE OR REPLACE FUNCTION public.require_status_remark_on_change_tasks()
-- RETURNS TRIGGER LANGUAGE plpgsql AS $$
-- BEGIN
--   IF NEW.status IS DISTINCT FROM OLD.status THEN
--     IF NEW.status_remark IS NULL OR trim(NEW.status_remark) = '' THEN
--       RAISE EXCEPTION 'status_remark required when change_tasks.status changes';
--     END IF;
--   END IF;
--   RETURN NEW;
-- END;
-- $$;
-- DROP TRIGGER IF EXISTS trg_change_tasks_status_remark ON public.change_tasks;
-- CREATE TRIGGER trg_change_tasks_status_remark
--   BEFORE UPDATE OF status ON public.change_tasks
--   FOR EACH ROW EXECUTE FUNCTION public.require_status_remark_on_change_tasks();
```

**Guards** (change → `started` only if all CR `approved`; `new` → `rollbacked`/`cancelled` only if not all CR `approved`; `closed` only if all CR `approved`) are best implemented as **RPCs** or **dashboard transactions** so you can return clear errors; add triggers later if you want hard DB enforcement.

---

## 4. Follow-up (not in SQL above)

| Item | Where |
|------|--------|
| TypeScript enums | `change-dashboard/src/lib/types.ts` |
| Flutter / app | Any Dart models mirroring these tables |
| RLS | Re-check policies if you add RPCs with `SECURITY DEFINER` |
| CTASK reject → CR reject + change `rejected` | App layer or dedicated migration with triggers |

---

## 5. Status reference (post-migration)

| Entity | Values |
|--------|--------|
| **changes.status** | `new`, `started`, `closed`, `cancelled`, `rollbacked`, `rejected` |
| **change_reviews.status** | `new`, `open`, `implementing`, `approved`, `rejected`, `cancelled` |
| **change_tasks.status** | `new`, `open`, `implementing`, `closed`, `rejected`, `skipped`, `cancelled` |

**Maps:** `requested` → `open`; `pending` → `open`.
