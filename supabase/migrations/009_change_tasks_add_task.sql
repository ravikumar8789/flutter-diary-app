-- Detailed instructions for performing a CTASK (separate from short `motive`).
ALTER TABLE public.change_tasks
  ADD COLUMN IF NOT EXISTS task text;

COMMENT ON COLUMN public.change_tasks.task IS 'Detailed instructions to perform this CTASK';
