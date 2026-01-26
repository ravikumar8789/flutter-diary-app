# AI FEATURE - COMPLETE DATA DOCUMENTATION

## TABLE STRUCTURES

### 1. entry_insights (Daily Analysis)
**Fields:**
- id (uuid, PK)
- entry_id (uuid, FK → entries.id, UNIQUE)
- processed_at (timestamptz, default: now())
- sentiment_label (text: 'negative'|'neutral'|'positive')
- sentiment_score (numeric)
- topics (text[], default: '{}')
- summary (text)
- embedding_json (jsonb)
- model_version (text)
- cost_tokens_prompt (integer, default: 0)
- cost_tokens_completion (integer, default: 0)
- status (text: 'pending'|'success'|'error', default: 'pending')
- error_message (text)
- ai_generated (boolean, default: false)
- analysis_type (text: 'daily'|'weekly'|'monthly')
- insight_text (text) - Main AI-generated insight (3-4 sentences)
- insight_details (jsonb) - Structured sub-points: {what_went_well, progress_area, self_care_balance, emotional_pattern}

### 2. weekly_insights (Weekly Analysis)
**Fields:**
- id (uuid, PK)
- user_id (uuid, FK → users.id)
- week_start (date, NOT NULL)
- week_end (date)
- mood_avg (numeric)
- cups_avg (numeric)
- self_care_rate (numeric)
- top_topics (text[])
- highlights (text) - 5-7 sentence paragraph
- generated_at (timestamptz, default: now())
- ai_generated (boolean, default: true)
- mood_trend (text: 'improving'|'declining'|'stable'|'volatile')
- key_insights (text[]) - Array of 5 insights
- recommendations (text[]) - Array of 3 recommendations
- habit_correlations (jsonb, default: '{}')
- consistency_score (numeric, 0.0-1.0)
- entries_count (integer, default: 0)
- word_count_total (integer, default: 0)
- model_version (text)
- cost_tokens_prompt (integer, default: 0)
- cost_tokens_completion (integer, default: 0)
- status (text: 'pending'|'success'|'error', default: 'pending')
- error_message (text)

### 3. monthly_insights (Monthly Analysis)
**Fields:**
- id (uuid, PK)
- user_id (uuid, FK → users.id)
- month_start (date, NOT NULL)
- mood_avg (numeric)
- entries_count (integer, default: 0)
- word_count_total (integer, default: 0)
- top_topics (text[], default: '{}')
- monthly_highlights (text) - 10-12 line paragraph
- growth_areas (text[], default: '{}') - 4-6 points
- achievements (text[], default: '{}') - 4-6 points
- next_month_goals (text[], default: '{}') - 4-6 points
- generated_at (timestamptz, default: now())
- consistency_score (numeric)
- habit_analysis (jsonb, default: '{}') - {mood_vs_entries, self_care_completion, consistency, analysis_points: []}
- mood_trend_monthly (text)
- model_version (text)
- cost_tokens_prompt (integer, default: 0)
- cost_tokens_completion (integer, default: 0)
- status (text: 'pending'|'success'|'error', default: 'pending')
- error_message (text)
- key_moments (text[], default: '{}')
- reflection_questions (text[], default: '{}')
- strengths (text[], default: '{}')

---

## PROMPTS

### DAILY ANALYSIS PROMPT

**System Prompt:**
```
You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide thoughtful, comprehensive insights. Always be supportive and non-judgmental. Your task is to generate a structured insight with a main 3-4 sentence insight and 4 specific sub-points that help users understand their day better.
```

**User Prompt Template:**
```
Yesterday's Complete Entry Analysis:

**Main Diary Entry:**
"{diary_text}"

**Mood:** {mood_score}/5

**Morning Ritual:**
- Affirmations: {affirmations_text}
- Priorities: {priorities_text}

**Wellness Tracking:**
- Self-care activities completed: {self_care_details}
- Meals: {meals_details}
- Shower/Bath: {shower_bath_status}

**Gratitude Practice:**
{gratitude_text}

**Tomorrow's Planning:**
{tomorrow_notes_text}

**Past 5 Days Context:**
- Mood trend: {mood_trend}
- Consistency: {consistency_score}%
- Entries completed: {entries_count}/5
- Key patterns: {key_patterns}

Please provide a structured response in JSON format:
{
  "main_insight": "3-4 sentence comprehensive insight about the day (emotional tone, key patterns, supportive observation)",
  "what_went_well": "1-1.5 lines about one specific positive thing from the data",
  "progress_area": "1-1.5 lines about what's lacking and one actionable step to improve",
  "self_care_balance": "1-1.5 lines about self-care activities and what could be added",
  "emotional_pattern": "1-1.5 lines about emotional patterns observed from diary and mood",
  "tags": ["word1", "word2", "word3", "word4"]
}

IMPORTANT for tags:
- Provide exactly 3-4 single-word tags (no phrases, no spaces)
- Tags should be the most relevant keywords/themes from the entry
- Examples: "gratitude", "exercise", "work", "family", "anxiety", "growth"
- Use lowercase, no punctuation
- Focus on main themes, emotions, activities, or topics mentioned

Keep it warm, specific, and actionable. Each point should reference actual data from the entry. Return ONLY valid JSON, no additional text.
```

**Parameters:**
- Model: gpt-4o-mini
- Temperature: 0.7
- Max Tokens: 500

---

### WEEKLY ANALYSIS PROMPT

**System Prompt:**
```
You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. You analyze weekly journal entries, daily insights, affirmations, gratitude, and priorities to provide deep, personalized insights. Focus on:

1. Emotional patterns and mood trends
2. Habit correlations and their impact on well-being
3. Recurring themes in affirmations, gratitude, and priorities
4. Actionable recommendations based on patterns
5. Celebrating progress and identifying growth areas

Be empathetic, specific, and actionable. Use the daily insights and structured data to provide context-rich analysis.

IMPORTANT: Always return your response as a valid JSON object. Do not include any markdown formatting, headers, or explanatory text outside the JSON object.
```

**User Prompt Template:**
```
WEEKLY ANALYSIS REQUEST (PREMIUM)
Date Range: {week_start} to {week_end}
Entries Written: {entries_count}/7 days

=== MOOD & SENTIMENT ANALYSIS ===
Average Mood: {avg_mood}/5
Mood Scores (Day by Day): {mood_scores}
Mood Trend: {mood_trend}
Sentiment Distribution: {sentiment_distribution}
  - Positive days: {positive_count}
  - Neutral days: {neutral_count}
  - Negative days: {negative_count}

=== COMPLETE DAILY INSIGHTS (ALL DETAILS) ===
{daily_insights_full}

=== COMPLETE DIARY ENTRIES (FULL TEXT) ===
{diary_full}

=== COMPLETE STRUCTURED DATA (ALL ITEMS) ===
AFFIRMATIONS (All Items):
{affirmations_full}

GRATITUDE (All Items):
{gratitude_full}

PRIORITIES (All Items):
{priorities_full}

=== COMPLETE SELF-CARE DETAILS ===
{self_care_full}

=== COMPLETE MEAL DETAILS ===
{meals_full}

=== TOMORROW NOTES ===
{tomorrow_notes_full}

=== SHOWER/BATH DETAILS ===
{shower_bath_full}

=== HABIT & CONSISTENCY SUMMARY ===
Self-Care Completion Rate: {self_care_summary}
Water Intake Average: {cups_avg} cups/day
Consistency Score: {consistency_score}%
Entries Count: {entries_count}/7

=== HABIT CORRELATIONS ===
{habit_correlations}

=== TOPICS MENTIONED ===
{weekly_topics}

=== ANALYSIS REQUEST ===
Based on the above COMPREHENSIVE and COMPLETE data, provide a deep, personalized weekly analysis.

Extract and discuss important points from:
- Affirmations: What themes or patterns emerge?
- Diary text: What emotional patterns, concerns, or celebrations appear?
- Tomorrow notes: What planning patterns or future focus areas exist?

Return your response as a valid JSON object with this exact structure:
{
  "highlights": "5-7 sentences covering: overall theme (1 sentence), mood journey across the week (1-2 sentences), key positive moments/achievements/breakthroughs (1-2 sentences), notable patterns/trends/shifts in behavior/emotions (1-2 sentences), and connections between different aspects like mood, habits, gratitude (1 sentence). Make it flow as one cohesive paragraph.",
  "key_insights": [
    "Deep emotional pattern or mood correlation - reference specific dates/entries when possible",
    "Habit correlation and its impact on well-being - reference specific dates/entries when possible",
    "Theme or pattern from affirmations/gratitude/priorities - reference specific dates/entries when possible",
    "Connection between self-care activities and mood/energy - reference specific dates/entries when possible",
    "Pattern in meal habits, planning (tomorrow notes), or routines - reference specific dates/entries when possible"
  ],
  "recommendations": [
    "Specific action based on strongest pattern identified - be specific and actionable, not generic",
    "Habit to strengthen or area to focus based on correlations - be specific and actionable, not generic",
    "Area for growth or improvement based on complete data analysis - be specific and actionable, not generic"
  ]
}

CRITICAL REQUIREMENTS:
- Return ONLY valid JSON. No markdown, no headers, no explanatory text.
- For each insight, reference specific dates or entries when possible (e.g., "On Day 3 (Dec 23), when you...")
- Make recommendations specific and actionable, not generic advice.
- Highlights should be 5-7 sentences, flowing as one cohesive paragraph.
- Be specific and reference actual data from the entries (dates, specific activities, patterns).
- Connect different aspects of the data (e.g., "On days when you practiced gratitude, your mood was higher").
- Be empathetic, encouraging, and actionable.
```

**Parameters:**
- Model: gpt-4o-mini
- Temperature: 0.5
- Max Tokens: 1000
- Response Format: JSON object

---

### MONTHLY ANALYSIS PROMPT

**System Prompt:**
```
You are an analytical but compassionate AI assistant that analyzes monthly journal data to provide deep, personalized insights. You analyze diary entries, affirmations, gratitude, priorities, and tomorrow notes to identify authentic patterns and achievements.

Focus on:
1. Emotional patterns and mood trends over the month
2. Authentic achievements extracted from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes)
3. Habit correlations and their impact on well-being
4. Growth areas based on real patterns in the data
5. Actionable goals for next month based on entry analysis

Be specific, reference actual dates and entry content when possible. Make users feel their journey is truly understood.
```

**User Prompt Template:**
```
MONTHLY ANALYSIS REQUEST
Month: {month_name}
Date Range: {month_start} to {month_end}
Entries Written: {entries_count}/{total_days}

=== MOOD & SENTIMENT ANALYSIS ===
Average Mood: {avg_mood}/5
Mood Trend: {mood_trend}
Mood Scores (Day by Day): {mood_scores_list}

=== COMPLETE DIARY ENTRIES (FULL TEXT WITH DATES) ===
{diary_entries_full}

=== COMPLETE STRUCTURED DATA ===
AFFIRMATIONS (All Items with Dates):
{affirmations_full}

GRATITUDE (All Items with Dates):
{gratitude_full}

PRIORITIES (All Items with Dates):
{priorities_full}

TOMORROW NOTES (All Items with Dates):
{tomorrow_notes_full}

=== SELF-CARE & HABITS ===
Self-Care Completion Rate: {self_care_completion}%
Consistency Score: {consistency_score}%

=== STATISTICS ===
Word Count Total: {word_count_total}
Top Topics: {top_topics_list}

=== ANALYSIS REQUEST ===
Based on the COMPLETE data above, provide a comprehensive monthly analysis in JSON format:

{
  "highlights": "10-12 line detailed paragraph discussing how main things impacted user's mood, next day behavior, emotional patterns, and overall journey. Reference specific dates and entries when relevant.",
  "growth_areas": ["4-6 specific growth areas based on actual entry patterns", ...],
  "achievements": ["4-6 achievements extracted from diary entries, affirmations, priorities, gratitude, and tomorrow notes. Reference specific dates/content", ...],
  "next_month_goals": ["4-6 actionable goals based on entry analysis", ...],
  "habit_analysis": ["4-6 points about habit patterns and correlations", ...],
  "key_moments": ["Notable events or moments from entries", ...],
  "reflection_questions": ["3-4 questions for next month reflection", ...],
  "strengths": ["3-4 strengths identified from entries", ...]
}

IMPORTANT:
- Extract achievements from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes)
- Reference specific dates and entry content when making points
- Make insights feel authentic and personalized
- All points should relate to actual entry data
- Be empathetic, encouraging, and actionable
```

**Parameters:**
- Model: gpt-4o-mini
- Temperature: 0.6
- Max Tokens: 1200
- Response Format: JSON object

---

## DATA FLOW

### DAILY ANALYSIS (ai-analyze-daily)

**Input Provided:**
- entry_id, user_id
- Entry data: diary_text, mood_score, entry_date
- Self-care data: all boolean fields
- Affirmations: JSON array
- Priorities: JSON array
- Gratitude: JSON array
- Meals: breakfast, lunch, dinner, water_cups
- Tomorrow notes: JSON array
- Shower/bath: took_shower, note
- Past 5 days entries: diary_text, mood_score, entry_date
- Past insights: insight_text, processed_at

**Context Built:**
- Affirmations text (stringified)
- Priorities text (stringified)
- Gratitude text (stringified)
- Tomorrow notes text (stringified)
- Self-care details (comma-separated activities)
- Meals details (formatted string)
- Mood trend (improving/declining/stable)
- Consistency score (%)
- Key patterns (mood average, trend)

**AI Response Received:**
```json
{
  "main_insight": "3-4 sentence insight",
  "what_went_well": "1-1.5 lines",
  "progress_area": "1-1.5 lines",
  "self_care_balance": "1-1.5 lines",
  "emotional_pattern": "1-1.5 lines",
  "tags": ["word1", "word2", "word3", "word4"]
}
```

**Saved to entry_insights:**
- insight_text ← main_insight
- summary ← main_insight (backward compatibility)
- insight_details ← {what_went_well, progress_area, self_care_balance, emotional_pattern}
- topics ← tags array
- ai_generated ← true
- analysis_type ← 'daily'
- status ← 'success'
- sentiment_label ← inferred from insight_text and mood_score
- model_version ← 'gpt-4o-mini'
- cost_tokens_prompt ← from OpenAI response
- cost_tokens_completion ← from OpenAI response
- processed_at ← now()

**Also Logged to ai_requests_log:**
- user_id, entry_id, analysis_type: 'daily'
- prompt_tokens, completion_tokens, total_tokens
- cost_usd (calculated)
- model_used: 'gpt-4o-mini'
- status: 'success'
- request_duration_ms

---

### WEEKLY ANALYSIS (ai-analyze-weekly)

**Input Provided:**
- user_id, week_start
- All entries for week: diary_text, mood_score, entry_date
- Self-care data: all entries
- Meals data: all entries
- Daily insights: insight_text, sentiment_label, insight_details, topics
- Affirmations: all entries
- Gratitude: all entries
- Priorities: all entries
- Tomorrow notes: all entries
- Shower/bath: all entries

**Context Built:**
- Mood scores array → avg_mood, mood_trend
- Self-care rates → completionRate, completedDays
- Water cups → cups_avg
- Consistency score (entries_count / 7)
- Word count total
- Topics extracted from all entries
- Sentiment distribution (positive/neutral/negative counts)
- Habit correlations JSON
- Daily insights full (formatted with all details)
- Diary full (all entries with dates)
- Affirmations full (all items with dates)
- Gratitude full (all items with dates)
- Priorities full (all items with dates)
- Self-care full (all activities with dates)
- Meals full (all meals with dates)
- Tomorrow notes full (all notes with dates)
- Shower/bath full (all entries with dates)

**AI Response Received:**
```json
{
  "highlights": "5-7 sentence paragraph",
  "key_insights": [
    "Insight 1 with date references",
    "Insight 2 with date references",
    "Insight 3 with date references",
    "Insight 4 with date references",
    "Insight 5 with date references"
  ],
  "recommendations": [
    "Recommendation 1 (specific and actionable)",
    "Recommendation 2 (specific and actionable)",
    "Recommendation 3 (specific and actionable)"
  ]
}
```

**Saved to weekly_insights:**
- user_id, week_start, week_end
- mood_avg ← calculated average
- cups_avg ← calculated average
- self_care_rate ← completionRate
- top_topics ← extracted topics (top 10)
- highlights ← AI highlights
- ai_generated ← true
- mood_trend ← calculated (improving/declining/stable/volatile)
- key_insights ← AI key_insights array (5 items)
- recommendations ← AI recommendations array (3 items)
- habit_correlations ← calculated JSON
- consistency_score ← entries_count / 7 (0.0-1.0)
- entries_count ← actual count
- word_count_total ← calculated
- model_version ← 'gpt-4o-mini'
- cost_tokens_prompt ← from OpenAI response
- cost_tokens_completion ← from OpenAI response
- status ← 'success'
- generated_at ← now()

**Also Logged to ai_requests_log:**
- user_id, entry_id: null, analysis_type: 'weekly'
- prompt_tokens, completion_tokens, total_tokens
- cost_usd (calculated)
- model_used: 'gpt-4o-mini'
- status: 'success'
- request_duration_ms

---

### MONTHLY ANALYSIS (ai-analyze-monthly)

**Input Provided:**
- user_id, month_start
- All entries for month: diary_text, mood_score, entry_date
- Self-care data: all entries
- Affirmations: all entries
- Gratitude: all entries
- Priorities: all entries
- Tomorrow notes: all entries

**Context Built:**
- Month name, month_end, total_days_in_month
- Mood scores array → avg_mood, mood_trend
- Self-care rates → completionRate
- Consistency score (entries_count / total_days * 100)
- Word count total
- Topics extracted (top 7)
- Habit analysis numeric (mood_vs_entries, self_care_completion, consistency)
- Diary entries full (formatted with dates)
- Affirmations full (formatted with dates)
- Gratitude full (formatted with dates)
- Priorities full (formatted with dates)
- Tomorrow notes full (formatted with dates)

**AI Response Received:**
```json
{
  "highlights": "10-12 line detailed paragraph",
  "growth_areas": ["4-6 specific growth areas", ...],
  "achievements": ["4-6 achievements with date references", ...],
  "next_month_goals": ["4-6 actionable goals", ...],
  "habit_analysis": ["4-6 points about habits", ...],
  "key_moments": ["Notable moments", ...],
  "reflection_questions": ["3-4 questions", ...],
  "strengths": ["3-4 strengths", ...]
}
```

**Saved to monthly_insights:**
- user_id, month_start
- mood_avg ← calculated average
- entries_count ← actual count
- word_count_total ← calculated
- top_topics ← extracted topics (top 7)
- monthly_highlights ← AI highlights
- growth_areas ← AI growth_areas array (4-6 items)
- achievements ← AI achievements array (4-6 items)
- next_month_goals ← AI next_month_goals array (4-6 items)
- consistency_score ← calculated percentage
- habit_analysis ← {numeric_data, analysis_points: AI habit_analysis array}
- mood_trend_monthly ← calculated trend
- key_moments ← AI key_moments array
- reflection_questions ← AI reflection_questions array
- strengths ← AI strengths array
- model_version ← 'gpt-4o-mini'
- cost_tokens_prompt ← from OpenAI response
- cost_tokens_completion ← from OpenAI response
- status ← 'success'
- generated_at ← now()

**Also Logged to ai_requests_log:**
- user_id, entry_id: null, analysis_type: 'monthly'
- prompt_tokens, completion_tokens, total_tokens
- cost_usd (calculated)
- model_used: 'gpt-4o-mini'
- status: 'success'
- request_duration_ms

---

## COST CALCULATION

**Model:** gpt-4o-mini
**Pricing:**
- Input: $0.15 per 1M tokens
- Output: $0.60 per 1M tokens

**Formula:**
```
cost_usd = (prompt_tokens / 1000000) * 0.15 + (completion_tokens / 1000000) * 0.60
```

---

## NOTES

- All prompts stored in `ai_prompt_templates` table (can be updated without code changes)
- Fallback prompts hardcoded in edge functions if DB template not found
- All functions use JSON response format for structured parsing
- Error handling logs to both `ai_requests_log` and `ai_errors_log` tables
- Deduplication: checks if insight already exists before processing
- Entry completion check: daily analysis requires all 4 sections complete
- Minimum requirements: daily (50 chars), weekly (1 entry), monthly (10 entries)
