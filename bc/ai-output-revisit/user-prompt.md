# Daily

TODAY'S ENTRY CONTEXT

Date: {entry_date}
Mood: {mood_score}/5

Today's diary:
"{diary_text}"

Affirmations: {affirmations_text}
Priorities: {priorities_text}
Gratitude: {gratitude_text}

Self-care: {self_care_details}
Meals: {meals_details}
Shower/Bath: {shower_bath_status}
Tomorrow notes: {tomorrow_notes_text}

Recent days:
- Mood trend: {mood_trend}
- Consistency: {consistency_score}%
- Entries completed (recent window): {entries_count}
- Key patterns: {key_patterns}

Using ONLY the information above, return a JSON object that matches exactly this schema:

{
  "main_insight": "3-4 sentence summary that acknowledges the user's feelings, mentions at least 2-3 specific details from today (and recent days if helpful), and offers a gentle, supportive perspective.",
  "what_went_well": "1 short line highlighting one concrete positive thing from today or the last few days.",
  "progress_area": "1 short line about one area that could improve, with a small, realistic next step.",
  "self_care_balance": "1 short line about self-care today versus recent days (e.g., more/less balanced, one small suggestion).",
  "emotional_pattern": "1 short line comparing today's mood/feelings to recent days, describing any emerging pattern carefully (use words like 'may', 'seems', 'could').",
  "tags": ["word1", "word2", "word3"]
}

Return ONLY this JSON object, nothing else.

# Weekly

WEEKLY ANALYSIS
Week: {week_start} to {week_end}
Entries written: {entries_count}/7

MOOD & SENTIMENT
- Average mood: {avg_mood}/5
- Mood scores by day: {mood_scores}
- Mood trend: {mood_trend}
- Sentiment: {sentiment_distribution} (Positive: {positive_count}, Neutral: {neutral_count}, Negative: {negative_count})

DAILY INSIGHTS (from each day):
{daily_insights_full}

DIARY & STRUCTURED DATA
- Diary entries (full): {diary_full}
- Affirmations: {affirmations_full}
- Gratitude: {gratitude_full}
- Priorities: {priorities_full}
- Self-care: {self_care_full}
- Meals: {meals_full}
- Tomorrow notes: {tomorrow_notes_full}
- Shower/Bath: {shower_bath_full}

HABITS & CONSISTENCY
- Self-care completion: {self_care_summary}
- Water intake average: {cups_avg} cups/day
- Consistency score: {consistency_score}%
- Habit correlations (numeric and categorical): {habit_correlations}

TOPICS
- Main topics mentioned this week: {weekly_topics}

ANALYSIS REQUEST
Using ONLY the information above, analyze the full week as a whole. Focus on:
- How habits and routines (self-care, gratitude, affirmations, meals, planning, etc.) are connected to mood and energy.
- Weekly patterns (for example, differences between early and late week, or between days when you practiced self-care vs when you didn't).
- Explain these as patterns using day names (Sunday, Monday, etc.), not "Day 3".

Return a JSON object matching EXACTLY this schema:

{
  "highlights": "4-6 sentence single paragraph: overall weekly theme, mood journey, key positive or meaningful moments, and at least one sentence that clearly connects habits/routines to how the week felt.",
  "key_insights": [
    "1-1.5 lines max. Pattern -> Evidence (with day names) -> Likely reason (because of habit pattern).",
    "1-1.5 lines max. Different pattern with day names and reason.",
    "1-1.5 lines max. Another clear pattern and explanation.",
    "Optional: 1-1.5 lines max. Extra pattern if clearly useful.",
    "Optional: 1-1.5 lines max. Extra pattern if clearly useful."
  ],
  "recommendations": [
    "1-1.5 lines max. Specific action based on the strongest positive pattern (what to keep doing and why).",
    "1-1.5 lines max. Specific habit to strengthen or adjust based on a pattern that seems to lower mood or energy.",
    "1-1.5 lines max. Gentle focus area or experiment for next week, directly tied to the data."
  ]
}

CRITICAL:
- Return ONLY this JSON object, nothing else.
- Use day names (Sunday, Monday, etc.) instead of "Day 3 (Dec 23)".
- Each key_insight and recommendation must be short (about 1-1.5 lines).
- Always connect patterns to habits or routines so the user understands why things may be happening, not just what happened.

# Monthly

MONTHLY ANALYSIS
Month: {month_name}
Date Range: {month_start} to {month_end}
Entries Written: {entries_count}/{total_days}

MOOD & SENTIMENT
- Average mood: {avg_mood}/5
- Mood trend: {mood_trend}
- Mood scores by date: {mood_scores_list}

DIARY & STRUCTURED DATA
- Diary entries (full with dates): {diary_entries_full}
- Affirmations (with dates): {affirmations_full}
- Gratitude (with dates): {gratitude_full}
- Priorities (with dates): {priorities_full}
- Tomorrow notes (with dates): {tomorrow_notes_full}

HABITS & STATISTICS
- Self-care completion: {self_care_completion}%
- Consistency score: {consistency_score}%
- Word count total: {word_count_total}
- Top topics: {top_topics_list}

ANALYSIS REQUEST
Using ONLY the information above, analyze the full month as a whole. Focus on:
- Long-term patterns and trends (how habits, routines, and emotional patterns evolved over the month).
- Why certain behaviors occurred (habit causality: "because when you did X consistently, Y improved").
- Authentic achievements extracted from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes).
- Growth areas based on real patterns (where habits or routines could be adjusted for better outcomes).

Return a JSON object matching EXACTLY this schema:

{
  "highlights": "5-6 sentence single paragraph: overall month theme, mood journey over the month, key patterns or shifts, notable achievements or growth moments, and at least one sentence connecting long-term habits to outcomes.",
  "growth_areas": [
    "1-1.5 lines max. First growth area with brief context.",
    "1-1.5 lines max. Second growth area with brief context.",
    "1-1.5 lines max. Third growth area with brief context."
  ],
  "achievements": [
    "1 line max. Achievement extracted from entries, with date/pattern reference if helpful.",
    "1 line max. Another achievement.",
    "1 line max. Another achievement.",
    "Optional: 1 line max. Extra achievement if clearly meaningful.",
    "Optional: 1 line max. Extra achievement if clearly meaningful.",
    "Optional: 1 line max. Extra achievement if clearly meaningful."
  ],
  "next_month_goals": [],
  "habit_analysis": [
    "1-1.5 lines max. Habit pattern and correlation to mood/energy (explain why: 'because when you did X, Y happened').",
    "1-1.5 lines max. Another habit pattern with causality.",
    "1-1.5 lines max. Another habit pattern with causality.",
    "Optional: 1-1.5 lines max. Extra pattern if clearly useful.",
    "Optional: 1-1.5 lines max. Extra pattern if clearly useful.",
    "Optional: 1-1.5 lines max. Extra pattern if clearly useful."
  ],
  "key_moments": [
    "1-1.5 lines max. Notable moment or event with date/period reference.",
    "1-1.5 lines max. Another key moment.",
    "Optional: More moments if clearly meaningful, each 1-1.5 lines max."
  ],
  "reflection_questions": [
    "Question 1 for next month reflection.",
    "Question 2 for next month reflection.",
    "Question 3 for next month reflection.",
    "Optional: Question 4 if helpful."
  ],
  "strengths": [
    "Less than 1 line. Brief strength statement.",
    "Less than 1 line. Another strength.",
    "Less than 1 line. Another strength.",
    "Optional: Less than 1 line. Extra strength if clearly meaningful."
  ]
}

CRITICAL:
- Return ONLY this JSON object, nothing else.
- next_month_goals MUST be an empty array []. Do not populate it.
- All array items must be short (1-1.5 lines max, except achievements and strengths which are even shorter).
- Always connect patterns to habits or routines so the user understands why things may be happening over the month, not just what happened.
- Reference specific dates or time periods (early/mid/late month) when helpful.
- Make the user feel their journey is truly understood through specific, authentic references to their entries.
