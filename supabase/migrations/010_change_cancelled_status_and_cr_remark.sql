-- CTASK + approver (CR): cancelled status; optional audit column on CR for status transitions.

ALTER TABLE public.change_reviews
  ADD COLUMN IF NOT EXISTS status_remark text;

COMMENT ON COLUMN public.change_reviews.status_remark IS 'Remark for the latest approver status transition (dashboard)';

ALTER TABLE public.change_tasks DROP CONSTRAINT IF EXISTS change_tasks_status_check;
ALTER TABLE public.change_tasks ADD CONSTRAINT change_tasks_status_check
  CHECK (status IN ('pending', 'approved', 'rejected', 'skipped', 'cancelled'));

ALTER TABLE public.change_reviews DROP CONSTRAINT IF EXISTS change_reviews_status_check;
ALTER TABLE public.change_reviews ADD CONSTRAINT change_reviews_status_check
  CHECK (status IN ('requested', 'implementing', 'rejected', 'approved', 'cancelled'));
