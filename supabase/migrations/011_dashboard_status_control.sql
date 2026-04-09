-- Dashboard status control — enums, audit columns, terminal note, data backfill.
-- Depends on 008, 009, 010.

ALTER TABLE public.changes
  ADD COLUMN IF NOT EXISTS final_state_note text;

COMMENT ON COLUMN public.changes.final_state_note IS
  'Long-form note required when status is closed, rollbacked, cancelled, or rejected.';

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

ALTER TABLE public.change_reviews
  ADD COLUMN IF NOT EXISTS rejection_remark text;

COMMENT ON COLUMN public.change_reviews.rejection_remark IS
  'Remark when CR is rejected (e.g. propagated from CTASK reject).';

ALTER TABLE public.change_reviews
  ADD COLUMN IF NOT EXISTS status_history jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.change_reviews.status_history IS
  'Append-only audit: transitions with from, to, remark, at, ref.';

UPDATE public.change_reviews SET status = 'open' WHERE status = 'requested';

ALTER TABLE public.change_reviews DROP CONSTRAINT IF EXISTS change_reviews_status_check;
ALTER TABLE public.change_reviews ADD CONSTRAINT change_reviews_status_check
  CHECK (status IN ('new', 'open', 'implementing', 'approved', 'rejected', 'cancelled'));

ALTER TABLE public.change_tasks
  ADD COLUMN IF NOT EXISTS status_history jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.change_tasks.status_history IS
  'Append-only audit: transitions with from, to, remark, at, ref.';

UPDATE public.change_tasks SET status = 'open' WHERE status = 'pending';

ALTER TABLE public.change_tasks DROP CONSTRAINT IF EXISTS change_tasks_status_check;
ALTER TABLE public.change_tasks ADD CONSTRAINT change_tasks_status_check
  CHECK (status IN ('new', 'open', 'implementing', 'closed', 'rejected', 'skipped', 'cancelled'));
