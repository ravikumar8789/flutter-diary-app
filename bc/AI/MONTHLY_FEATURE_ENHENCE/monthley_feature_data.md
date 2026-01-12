# Monthly Insights Table Fields

- id------
- user_id----
- month_start--------
- mood_avg---------
- entries_count--------------
- word_count_total-----
- top_topics----------
- monthly_highlights-----------
- growth_areas---------------
- achievements---------------
- next_month_goals------------
- generated_at-----------
- consistency_score---------------
- habit_analysis
- mood_trend_monthly
- model_version
- cost_tokens_prompt
- cost_tokens_completion
- status
- error_message

---

## What We Are Asking AI

1. Overall month reflection (2-3 sentences)
2. Biggest growth area (1 sentence)
3. One celebration moment (1 sentence)
4. Focus for next month (1-2 sentences)

Keep it inspiring and actionable (under 200 words).

---

## System Prompt

You are a reflective AI assistant that helps users understand long-term trends in their wellness journey. Provide monthly summaries that highlight growth, patterns, and areas of focus. Be encouraging and forward-looking.

---

## User Prompt Template

Monthly Data Summary:
- Month: {month_name}
- Entries written: {entries_count}/{total_days}
- Average mood: {avg_mood}/5
- Consistency: {consistency_score}%
- Key themes: {monthly_topics}
- Mood trend: {mood_trend}

Please provide:
1. Overall month reflection (2-3 sentences)
2. Biggest growth area (1 sentence)
3. One celebration moment (1 sentence)
4. Focus for next month (1-2 sentences)

Keep it inspiring and actionable (under 200 words).

---

## What AI Gives (Response Format)

Raw text response that gets parsed into:
- highlights (string) - Overall reflection text
- growthAreas (array) - Up to 3 items
- achievements (array) - Up to 3 items
- goals (array) - Up to 3 items

Parsing logic: Searches for keywords "growth/improve", "celebration/achievement", "next month/focus/goal" to categorize sections.

---

## Migration Query - Add New Fields

```sql
ALTER TABLE public.monthly_insights
ADD COLUMN IF NOT EXISTS key_moments text[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS reflection_questions text[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS strengths text[] DEFAULT '{}'::text[];
```

---

## Impact

**Database:**
- 3 new nullable array fields added (backward compatible)

**Code Changes Needed:**
1. **Edge Function** (`ai-analyze-monthly/index.ts`):
   - Update prompt to ask for key_moments, reflection_questions, strengths
   - Update `parseMonthlyInsight()` to extract these fields
   - Update upsert to save these fields

2. **Flutter App**:
   - Update `MonthlyInsight` model to include new fields
   - Update UI to display new sections
   - Update analytics screen to show new data

**No Breaking Changes:** Existing data remains valid (new fields default to empty arrays)
