-- Add unique constraint on entry_id for entry_insights table
-- This allows ON CONFLICT to work in upsert operations

-- Check if constraint already exists, if not add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_entry_insight_entry_id' 
        AND conrelid = 'public.entry_insights'::regclass
    ) THEN
        ALTER TABLE public.entry_insights 
        ADD CONSTRAINT unique_entry_insight_entry_id UNIQUE (entry_id);
    END IF;
END $$;

