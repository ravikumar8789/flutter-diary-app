# AI Feature Deployment Guide

## Prerequisites Checklist

- [ ] All SQL migrations run successfully (see `supabase/migrations/001_ai_feature_setup.sql`)
- [ ] Supabase CLI installed and logged in
- [ ] Project linked to Supabase
- [ ] OpenAI API key obtained

---

## Step 1: Run Database Migrations

1. Open Supabase Dashboard → SQL Editor
2. Copy and paste the contents of `supabase/migrations/001_ai_feature_setup.sql`
3. Run the SQL script
4. Verify no errors

---

## Step 2: Set OpenAI API Key Secret

1. Go to Supabase Dashboard
2. Navigate to: **Project Settings → Edge Functions → Secrets**
3. Click "Add New Secret"
4. Add:
   - **Key**: `OPENAI_API_KEY`
   - **Value**: Your OpenAI API key (get from https://platform.openai.com/api-keys)
5. Click "Save"

---

## Step 3: Install & Link Supabase CLI

```bash
# Install Supabase CLI (if not installed)
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
# Get project ref from: Supabase Dashboard → Settings → General → Reference ID
supabase link --project-ref YOUR_PROJECT_REF
```

---

## Step 4: Deploy Edge Functions

```bash
# Deploy daily analysis function
supabase functions deploy ai-analyze-daily

# Deploy weekly analysis function
supabase functions deploy ai-analyze-weekly
```

**Expected output**: Both functions should deploy successfully.

---

## Step 5: Verify Deployment

1. Go to Supabase Dashboard → Edge Functions
2. You should see both functions:
   - `ai-analyze-daily`
   - `ai-analyze-weekly`
3. Both should show "Active" status

---

## Step 6: Test in App

1. Open the Flutter app
2. Write a diary entry (at least 50 characters)
3. Wait a few seconds for sync
4. Go to Home screen
5. Check the AI Insight card - it should show an insight after processing (may take 10-30 seconds)

---

## Troubleshooting

### Edge Function deployment fails
- Check you're logged in: `supabase projects list`
- Verify project is linked: `supabase status`
- Check function files exist in `supabase/functions/`

### AI insights not appearing
- Check `ai_requests_log` table for errors
- Verify OpenAI API key is set correctly
- Check Edge Function logs in Supabase Dashboard

### SQL errors
- Make sure you're running as database owner or have proper permissions
- Check if tables already exist (use `IF NOT EXISTS` clauses)

---

## Verification Queries

Run these in Supabase SQL Editor to verify setup:

```sql
-- Check entry_insights columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'entry_insights' 
AND column_name IN ('ai_generated', 'insight_text', 'analysis_type');

-- Check weekly_insights columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'weekly_insights' 
AND column_name IN ('ai_generated', 'mood_trend', 'key_insights');

-- Check ai_requests_log exists
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_name = 'ai_requests_log';

-- Check ai_prompt_templates exists and has data
SELECT template_name, analysis_type, is_active 
FROM ai_prompt_templates;
```

All should return results if setup is correct.

