# weekly_insights Table Fields

id
user_id
week_start
mood_avg
cups_avg
self_care_rate
top_topics
highlights
generated_at
week_end
ai_generated
mood_trend
key_insights
recommendations
habit_correlations
consistency_score
entries_count
word_count_total
model_version
cost_tokens_prompt
cost_tokens_completion
status
error_message

---

# What We Give to AI

- Date Range (week_start to week_end)
- Entries Count
- Average Mood Score
- Day-by-Day Mood Scores
- Mood Trend (improving/declining/stable/volatile)
- Sentiment Distribution (positive/neutral/negative counts)
- Complete Daily Insights (all details: insight_text, what_went_well, progress_area, self_care_balance, emotional_pattern, topics)
- Complete Diary Entries (full text with dates and mood scores)
- Affirmations (all items per day)
- Gratitude (all items per day)
- Priorities (all items per day)
- Self-Care Details (activities per day)
- Meal Details (breakfast, lunch, dinner, water cups per day)
- Tomorrow Notes (all notes per day)
- Shower/Bath Details (per day)
- Self-Care Completion Rate
- Water Intake Average
- Consistency Score
- Habit Correlations (mood_vs_entries, self_care_completion, mood_vs_gratitude, mood_vs_affirmations, sentiment_distribution, consistency_impact)
- Topics Mentioned (top 10)

---

# What We Ask AI

Provide a deep, personalized weekly analysis with:

1. **Weekly Highlights** (3-4 sentences):
   - Overall mood pattern and emotional journey
   - Key positive moments, achievements, breakthroughs
   - Notable patterns, trends, shifts in behavior/emotions
   - Connection between different aspects (mood, habits, gratitude, etc.)

2. **Key Insights** (4-5 specific insights):
   - Deep emotional pattern or mood correlation
   - Habit correlation and impact on well-being
   - Theme or pattern from affirmations/gratitude/priorities
   - Connection between self-care activities and mood/energy
   - Pattern in meal habits, planning, or routines

3. **Recommendations** (3 actionable items):
   - Specific action based on strongest pattern
   - Habit to strengthen or area to focus
   - Area for growth or improvement

**Format Requirements:**
- Sections labeled "Highlights:", "Key Insights:", and "Recommendations:"
- Be specific, reference actual data (dates, activities, patterns)
- Connect different aspects of data
- Be empathetic, encouraging, actionable
- Total response: 300-400 words

---

# What AI Gives

Full text response containing:
- Highlights section (3-4 sentences)
- Key Insights section (4-5 numbered insights)
- Recommendations section (3 numbered recommendations)

**Actual AI Response Format:**
AI generates free-form text with sections like:
- "**Weekly Mood Pattern:**" or "**Highlights:**"
- "**Key Insights:**" with numbered list
- "**Two Specific, Actionable Recommendations for Next Week:**" or "**Recommendations:**"

---

# Exact Prompt

## System Prompt
```
You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. You analyze weekly journal entries, daily insights, affirmations, gratitude, and priorities to provide deep, personalized insights. Focus on:

1. Emotional patterns and mood trends
2. Habit correlations and their impact on well-being
3. Recurring themes in affirmations, gratitude, and priorities
4. Actionable recommendations based on patterns
5. Celebrating progress and identifying growth areas

Be empathetic, specific, and actionable. Use the daily insights and structured data to provide context-rich analysis.
```

## User Prompt Template
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
Based on the above COMPREHENSIVE and COMPLETE data, provide a deep, personalized weekly analysis:

1. **Weekly Highlights** (3-4 sentences):
   - Overall mood pattern and emotional journey across the week
   - Key positive moments, achievements, or breakthroughs
   - Notable patterns, trends, or shifts in behavior/emotions
   - Connection between different aspects (mood, habits, gratitude, etc.)

2. **Key Insights** (4-5 specific insights):
   - Insight 1: Deep emotional pattern or mood correlation
   - Insight 2: Habit correlation and its impact on well-being
   - Insight 3: Theme or pattern from affirmations/gratitude/priorities
   - Insight 4: Connection between self-care activities and mood/energy
   - Insight 5: Pattern in meal habits, planning (tomorrow notes), or routines

3. **Recommendations** (3 actionable items):
   - Recommendation 1: Specific action based on strongest pattern identified
   - Recommendation 2: Habit to strengthen or area to focus based on correlations
   - Recommendation 3: Area for growth or improvement based on complete data analysis

Format your response clearly with sections labeled "Highlights:", "Key Insights:", and "Recommendations:". 
- Be specific and reference actual data from the entries (dates, specific activities, patterns)
- Connect different aspects of the data (e.g., "On days when you practiced gratitude, your mood was higher")
- Be empathetic, encouraging, and actionable
- Total response should be 300-400 words (premium depth)
```

## API Parameters
- Model: gpt-4o-mini
- Temperature: 0.5
- Max Tokens: 800
