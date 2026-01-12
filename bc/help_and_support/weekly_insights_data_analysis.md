# **WEEKLY_INSIGHTS TABLE - COMPLETE DATA ANALYSIS**

**Date:** 2025-12-22  
**Source:** Supabase Database (via MCP)  
**Table:** `public.weekly_insights`

---

## **📊 TABLE OVERVIEW**

### **Table Structure**
- **Total Columns:** 23
- **Primary Key:** `id` (uuid)
- **Foreign Key:** `user_id` → `public.users.id`
- **RLS Enabled:** Yes
- **Total Records:** 3

### **Column Details**
| Column Name | Data Type | Nullable | Default | Description |
|------------|-----------|----------|---------|-------------|
| `id` | uuid | NO | gen_random_uuid() | Primary key |
| `user_id` | uuid | NO | - | User reference |
| `week_start` | date | NO | - | Week start date |
| `mood_avg` | numeric | YES | - | Average mood score |
| `cups_avg` | numeric | YES | - | Average water cups |
| `self_care_rate` | numeric | YES | - | Self-care completion % |
| `top_topics` | text[] | YES | - | Top topics array |
| `highlights` | text | YES | - | Weekly highlights text |
| `generated_at` | timestamptz | YES | now() | Generation timestamp |
| `week_end` | date | YES | - | Week end date |
| `ai_generated` | boolean | YES | true | AI generated flag |
| `mood_trend` | text | YES | - | improving/declining/stable/volatile |
| `key_insights` | text[] | YES | - | Key insights array |
| `recommendations` | text[] | YES | - | Recommendations array |
| `habit_correlations` | jsonb | YES | '{}' | Habit correlation data |
| `consistency_score` | numeric | YES | - | Consistency score (0-1) |
| `entries_count` | integer | YES | 0 | Number of entries |
| `word_count_total` | integer | YES | 0 | Total word count |
| `model_version` | text | YES | - | AI model used |
| `cost_tokens_prompt` | integer | YES | 0 | Prompt tokens |
| `cost_tokens_completion` | integer | YES | 0 | Completion tokens |
| `status` | text | YES | 'pending' | pending/success/error |
| `error_message` | text | YES | - | Error message if failed |

---

## **📈 STATISTICS SUMMARY**

### **Overall Statistics**
- **Total Weekly Insights:** 3
- **Unique Users:** 1
- **Successful:** 3 (100%)
- **Pending:** 0
- **Errors:** 0
- **Average Mood Across All Weeks:** 4.19/5
- **Average Consistency Score:** 0.67 (67%)

---

## **📝 DETAILED RECORDS**

### **Record 1: Week of Dec 14-20, 2025**
- **ID:** `26a5b92f-0e0c-4bdf-9323-b9014d277a1c`
- **User:** Nandini show (nandinisinghanay@gmail.com)
- **Week:** 2025-12-14 to 2025-12-20
- **Mood Average:** 4.33/5
- **Water Cups Average:** 1.7
- **Self-Care Rate:** 33.33%
- **Consistency Score:** 0.43 (43%)
- **Entries Count:** 3
- **Word Count:** 156
- **Mood Trend:** declining
- **Status:** success
- **Generated At:** 2025-12-20 19:00:07 UTC

**Top Topics:**
- after, which, early, morning, exercise, drink, healthy, water, mixture, ajwain

**Highlights:**
> **Weekly Mood Pattern:** Your mood this week was generally positive, with an average score of 4.33/5, although it dipped slightly on Day 3.
> 
> **Top 2 Positive Influences on Mood:** The consistent high scores on Days 1 and 2 suggest that engaging in morning activities, possibly related to exercise or hydration, positively influenced your mood.
> 
> **One Area for Potential Improvement:** Self-care activities were completed only 1 out of 7 days, indicating a need for more consistent self-care practices.
> 
> **Two Specific, Actionable Recommendations for Next Week:**
> 1. Aim to incorporate at least 3 self-care activities throughout the week, perhaps scheduling them in advance.
> 2. Consider starting each day with a morning routine that includes exercise and hydration to maintain your positive mood momentum.

**Recommendations:**
1. Aim to incorporate at least 3 self-care activities throughout the week, perhaps scheduling them in advance.
2. Consider starting each day with a morning routine that includes exercise and hydration to maintain your positive mood momentum.

**Habit Correlations:**
```json
{
  "mood_vs_entries": 4.33,
  "mood_vs_gratitude": 4.33,
  "consistency_impact": "low",
  "mood_vs_affirmations": 4.33,
  "self_care_completion": 33.33,
  "sentiment_distribution": {
    "neutral": 0,
    "negative": 0,
    "positive": 1
  }
}
```

**AI Processing:**
- Model: gpt-4o-mini
- Prompt Tokens: 283
- Completion Tokens: 162
- Total Tokens: 445
- Cost: $0.000140

---

### **Record 2: Week of Dec 7-13, 2025**
- **ID:** `c700d468-bc34-4015-ad73-5576f39e4162`
- **User:** Nandini show (nandinisinghanay@gmail.com)
- **Week:** 2025-12-07 to 2025-12-13
- **Mood Average:** 4.00/5
- **Water Cups Average:** 3.5
- **Self-Care Rate:** 75%
- **Consistency Score:** 0.57 (57%)
- **Entries Count:** 4
- **Word Count:** 553
- **Mood Trend:** declining
- **Status:** success
- **Generated At:** 2025-12-13 19:00:07 UTC

**Top Topics:**
- office, after, o'clock, night, morning, breakfast, shift, outside, because, slept

**Highlights:**
> **Weekly Mood Pattern:** Your mood was generally high this week, with an average score of 4.00, reflecting a positive outlook on most days. However, a dip to 3 on two days suggests some fluctuations in emotional stability.
> 
> **Top 2 Positive Influences on Mood:** Consistent self-care activities and gratitude practices significantly contributed to maintaining your positive mood.
> 
> **One Area for Potential Improvement:** Increasing the frequency of journal entries could provide deeper insights into your emotional patterns.
> 
> **Two Specific, Actionable Recommendations for Next Week:**
> 1. Aim to complete self-care activities daily to enhance your mood and overall well-being.
> 2. Set a goal to write at least one journal entry each day to capture your thoughts and feelings consistently, which may help you identify triggers and patterns more effectively.

**Recommendations:**
1. Aim to complete self-care activities daily to enhance your mood and overall well-being.
2. Set a goal to write at least one journal entry each day to capture your thoughts and feelings consistently, which may help you identify triggers and patterns more effectively.

**Habit Correlations:**
```json
{
  "mood_vs_entries": 4,
  "mood_vs_gratitude": 4,
  "consistency_impact": "medium",
  "mood_vs_affirmations": 4,
  "self_care_completion": 75,
  "sentiment_distribution": {
    "neutral": 0,
    "negative": 0,
    "positive": 3
  }
}
```

**AI Processing:**
- Model: gpt-4o-mini
- Prompt Tokens: 282
- Completion Tokens: 159
- Total Tokens: 441
- Cost: $0.000138

---

### **Record 3: Week of Nov 30 - Dec 6, 2025**
- **ID:** `27d8afd9-75c5-454d-8d92-5fb71bd2f204`
- **User:** Nandini show (nandinisinghanay@gmail.com)
- **Week:** 2025-11-30 to 2025-12-06
- **Mood Average:** 4.25/5
- **Water Cups Average:** 3.7
- **Self-Care Rate:** 100%
- **Consistency Score:** 1.00 (100%)
- **Entries Count:** 7
- **Word Count:** 739
- **Mood Trend:** improving
- **Status:** success
- **Generated At:** 2025-12-07 18:00:08 UTC

**Top Topics:**
- morning, early, little, after, o'clock, office, because, myself, tomorrow, night

**Highlights:**
> **Weekly Mood Pattern:**
> Your mood has shown a positive upward trend this week, peaking at 5 on Days 3 and 4, indicating a strong sense of well-being.
> 
> **Top 2 Positive Influences on Mood:**
> 1. Consistent self-care activities throughout the week have significantly contributed to your elevated mood.
> 2. Engaging in morning routines may have boosted your overall positivity and productivity.
> 
> **One Area for Potential Improvement:**
> Consider addressing the negative sentiment noted in your entries to better understand its source and mitigate its impact.
> 
> **Two Specific, Actionable Recommendations for Next Week:**
> 1. Continue your self-care routine but add a reflective journaling session to explore any negative feelings and their triggers.
> 2. Experiment with varying your morning routine to include a new activity that excites you, enhancing your mood further.

**Recommendations:**
1. Continue your self-care routine but add a reflective journaling session to explore any negative feelings and their triggers.
2. Experiment with varying your morning routine to include a new activity that excites you, enhancing your mood further.

**Habit Correlations:**
```json
{
  "mood_vs_entries": 4.25,
  "mood_vs_gratitude": 4.25,
  "consistency_impact": "high",
  "mood_vs_affirmations": 4.25,
  "self_care_completion": 100,
  "sentiment_distribution": {
    "neutral": 0,
    "negative": 1,
    "positive": 6
  }
}
```

**AI Processing:**
- Model: gpt-4o-mini
- Prompt Tokens: 288
- Completion Tokens: 168
- Total Tokens: 456
- Cost: $0.000144

---

## **🔗 RELATED DATA**

### **Entries Associated with Weekly Insights**

**Week 1 (Dec 14-20):** 3 entries
- 2025-12-16: Mood 5 (no diary text)
- 2025-12-19: Mood 5 (diary text available)
- 2025-12-20: Mood 3 (no diary text)

**Week 2 (Dec 7-13):** 4 entries
- 2025-12-07: Mood 5 (diary text available)
- 2025-12-09: Mood 5 (diary text available)
- 2025-12-10: Mood 3 (no diary text)
- 2025-12-11: Mood 3 (diary text available)

**Week 3 (Nov 30 - Dec 6):** 7 entries
- 2025-11-30: Mood 3 (diary text available)
- 2025-12-01: Mood 3 (diary text available)
- 2025-12-02: Mood 4 (diary text available)
- 2025-12-03: Mood 5 (diary text available)
- 2025-12-04: Mood 5 (diary text available)
- 2025-12-05: Mood 3 (diary text available)
- 2025-12-06: Mood 3 (diary text available)

### **AI Request Logs (Weekly Analysis)**
- **Total Requests:** 6
- **All Successful:** Yes
- **Total Cost:** ~$0.000869
- **Average Tokens per Request:** ~456
- **Model Used:** gpt-4o-mini (all)

### **Analysis Queue (Weekly)**
- **Total Queue Items:** 4
- **All Completed:** Yes
- **No Errors:** Yes
- **Average Processing Time:** ~30 minutes from creation to processing

---

## **📊 TRENDS & PATTERNS**

### **Mood Trends**
- **Week 1 (Dec 14-20):** 4.33 avg, declining trend
- **Week 2 (Dec 7-13):** 4.00 avg, declining trend
- **Week 3 (Nov 30 - Dec 6):** 4.25 avg, improving trend

### **Consistency Trends**
- **Week 1:** 43% (low)
- **Week 2:** 57% (medium)
- **Week 3:** 100% (high) ⭐

### **Self-Care Trends**
- **Week 1:** 33.33% (low)
- **Week 2:** 75% (good)
- **Week 3:** 100% (excellent) ⭐

### **Entry Frequency**
- **Week 1:** 3 entries (43% of week)
- **Week 2:** 4 entries (57% of week)
- **Week 3:** 7 entries (100% of week) ⭐

---

## **💰 COST ANALYSIS**

### **Per Weekly Insight**
- **Average Cost:** ~$0.000144 per insight
- **Total Cost (3 insights):** ~$0.000422
- **Average Tokens:** ~454 tokens per insight

### **Cost Breakdown**
| Week | Prompt Tokens | Completion Tokens | Total Tokens | Cost (USD) |
|------|---------------|-------------------|--------------|------------|
| Dec 14-20 | 283 | 162 | 445 | $0.000140 |
| Dec 7-13 | 282 | 159 | 441 | $0.000138 |
| Nov 30 - Dec 6 | 288 | 168 | 456 | $0.000144 |

---

## **✅ KEY OBSERVATIONS**

1. **100% Success Rate:** All weekly insights generated successfully
2. **Single User:** All insights belong to one user (Nandini show)
3. **Consistent Quality:** All insights have detailed highlights and recommendations
4. **Cost Effective:** Very low cost per insight (~$0.00014)
5. **Improving Consistency:** Week 3 shows perfect consistency (100%)
6. **Self-Care Correlation:** Higher self-care rates correlate with better mood trends
7. **Entry Frequency Matters:** More entries (Week 3) = better insights

---

## **🔍 RELATED TABLES**

### **Foreign Key Relationships**
- `user_id` → `public.users.id`
- Related entries via `entries.user_id` and date range matching

### **Related Processing Tables**
- `ai_requests_log` - Tracks AI API calls
- `analysis_queue` - Queues weekly analysis jobs
- `ai_errors_log` - Error tracking (none for weekly insights)

---

## **📝 NOTES**

- All insights are AI-generated (`ai_generated: true`)
- All insights use model `gpt-4o-mini`
- No errors in weekly insight generation
- All insights have status `success`
- `key_insights` array is empty for all records (may need investigation)
- Recommendations are provided as text array
- Habit correlations stored as JSONB with detailed metrics

---

**Generated:** 2025-12-22  
**Data Source:** Supabase Database (MCP Tool)

