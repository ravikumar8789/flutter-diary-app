-- Change control: changes, change_reviews, change_tasks
-- Run via Supabase CLI or SQL editor after review.

CREATE SEQUENCE IF NOT EXISTS public.change_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.ctask_seq START 1;

CREATE OR REPLACE FUNCTION public.set_change_change_id()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.change_id IS NULL OR trim(NEW.change_id) = '' THEN
    NEW.change_id := 'CHG' || lpad(nextval('public.change_seq')::text, 7, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_change_task_ctask_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.ctask_number IS NULL OR trim(NEW.ctask_number) = '' THEN
    NEW.ctask_number := 'CTASK' || lpad(nextval('public.ctask_seq')::text, 7, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  change_id text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'started', 'closed', 'cancelled', 'rollbacked')),
  status_remark text,
  status_history jsonb NOT NULL DEFAULT '[]'::jsonb,
  type text NOT NULL DEFAULT 'other'
    CHECK (type IN ('fix', 'add', 'remove', 'refactor', 'other')),
  primary_feature text,
  feature_names jsonb NOT NULL DEFAULT '[]'::jsonb,
  short_description text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  rollback_plan text,
  discussed_details text,
  created_by text,
  closed_at timestamptz
);

CREATE TRIGGER trg_changes_change_id
  BEFORE INSERT ON public.changes
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_change_change_id();

CREATE TRIGGER trg_changes_updated_at
  BEFORE UPDATE ON public.changes
  FOR EACH ROW
  EXECUTE PROCEDURE public.touch_updated_at();

CREATE TABLE IF NOT EXISTS public.change_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  change_id uuid NOT NULL REFERENCES public.changes (id) ON DELETE CASCADE,
  team_key text NOT NULL,
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'implementing', 'rejected', 'approved')),
  impact_summary text,
  justification text,
  conflict boolean NOT NULL DEFAULT false,
  full_discussion text,
  doc_updates_suggested text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (change_id, team_key)
);

CREATE TRIGGER trg_change_reviews_updated_at
  BEFORE UPDATE ON public.change_reviews
  FOR EACH ROW
  EXECUTE PROCEDURE public.touch_updated_at();

CREATE TABLE IF NOT EXISTS public.change_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  change_id uuid NOT NULL REFERENCES public.changes (id) ON DELETE CASCADE,
  change_review_id uuid NOT NULL REFERENCES public.change_reviews (id) ON DELETE CASCADE,
  ctask_number text NOT NULL UNIQUE,
  motive text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'skipped')),
  status_remark text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_change_tasks_ctask_number
  BEFORE INSERT ON public.change_tasks
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_change_task_ctask_number();

CREATE TRIGGER trg_change_tasks_updated_at
  BEFORE UPDATE ON public.change_tasks
  FOR EACH ROW
  EXECUTE PROCEDURE public.touch_updated_at();

CREATE INDEX IF NOT EXISTS idx_change_reviews_change_id ON public.change_reviews (change_id);
CREATE INDEX IF NOT EXISTS idx_change_tasks_change_id ON public.change_tasks (change_id);
CREATE INDEX IF NOT EXISTS idx_change_tasks_review_id ON public.change_tasks (change_review_id);

ALTER TABLE public.changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.change_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.change_tasks ENABLE ROW LEVEL SECURITY;

-- Authenticated users: full CRUD (solo admin dashboard; tighten later if needed)
CREATE POLICY "changes_authenticated_all"
  ON public.changes FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "change_reviews_authenticated_all"
  ON public.change_reviews FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

CREATE POLICY "change_tasks_authenticated_all"
  ON public.change_tasks FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

COMMENT ON TABLE public.changes IS 'Change register (CHG*)';
COMMENT ON TABLE public.change_reviews IS 'Per-team review for a change';
COMMENT ON TABLE public.change_tasks IS 'CTASK rows linked to a change_review';
