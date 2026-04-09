-- Discussion thread on changes (JSON array; dashboard prepends — newest first).

ALTER TABLE public.changes
  ADD COLUMN IF NOT EXISTS discussion_log jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.changes.discussion_log IS
  'Discussion entries: [{ at, body, author? }]. Newest first in array.';
