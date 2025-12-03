# Weekly AI Analysis Enhancement Plan (Premium Edition)

## 📋 Executive Summary

**Objective:** Enhance weekly AI analysis to provide **maximum depth and context** for **PREMIUM USERS ONLY** by including **complete, untruncated data** from all sources - full diary texts, complete daily insights, all structured data, and comprehensive habit details.

**IMPORTANT:** Weekly and monthly analysis are **PREMIUM-ONLY** features. Non-premium users do NOT have access to these features.

**Current Issue:** Weekly analysis only uses aggregated statistics (mood avg, counts, topics), missing rich context from daily insights and structured data (affirmations, gratitude, priorities).

**Solution:** Fetch and include **ALL data in full** - complete diary texts, full daily insights with all details, complete structured data arrays, full self-care activities, complete meal details, tomorrow notes, and shower/bath information. **NO TRUNCATION** - premium users get the best analysis possible.

**Impact:** Minimal - Only Edge Function changes, no app/database changes needed. **Premium access control must be implemented at app level.**

**Cost:** ~$0.002 per weekly analysis (0.2 cents) - Premium feature, cost justified by value.

---

## 🔍 Current State Analysis

### **Current Data Fetching:**

1. **Entries Table:**
   - Fetches: `id, diary_text, mood_score, entry_date, created_at`
   - Used for: mood_avg, entries_count, top_topics, consistency_score, mood_trend

2. **Entry Self-Care Table:**
   - Fetches: All boolean fields
   - Used for: self_care_rate

3. **Entry Meals Table:**
   - Fetches: `water_cups` only
   - Used for: cups_avg

### **Current Prompt Data:**
- Date range
- Entries count
- Average mood
- Mood scores list
- Self-care completion summary
- Key topics (keywords only)
- Limited habit correlations (mood vs entries, self-care completion)

### **Current Limitations:**
- ❌ No daily insights summaries (missing AI-generated daily insights)
- ❌ No structured data (affirmations, gratitude, priorities)
- ❌ No diary text context (only keywords extracted)
- ❌ Limited habit correlations (only 2 correlations)
- ❌ No sentiment patterns from daily insights
- ❌ No emotional pattern analysis
- ❌ No tomorrow notes context
- ❌ No shower/bath details
- ❌ No meal details (only water cups)
- ❌ No specific self-care activity details

### **Premium Access Requirement:**
- ✅ **Weekly analysis:** Premium users only
- ✅ **Monthly analysis:** Premium users only
- ✅ **Daily insights:** Available to all users (free feature)

---

## 🎯 Required Changes

### **File to Modify:**
- `supabase/functions/ai-analyze-weekly/index.ts`

### **Changes Required:**

#### **1. Additional Data Fetching:**

**a) Daily Insights (CRITICAL):**
```typescript
// Fetch daily insights for the week
const { data: dailyInsights } = await supabase
  .from('entry_insights')
  .select('entry_id, insight_text, sentiment_label, insight_details, topics')
  .in('entry_id', entryIds)
  .eq('status', 'success')
  .order('processed_at', { ascending: true })
```

**b) Affirmations:**
```typescript
const { data: affirmationsData } = await supabase
  .from('entry_affirmations')
  .select('entry_id, affirmations')
  .in('entry_id', entryIds)
```

**c) Gratitude:**
```typescript
const { data: gratitudeData } = await supabase
  .from('entry_gratitude')
  .select('entry_id, grateful_items')
  .in('entry_id', entryIds)
```

**d) Priorities:**
```typescript
const { data: prioritiesData } = await supabase
  .from('entry_priorities')
  .select('entry_id, priorities')
  .in('entry_id', entryIds)
```

**e) Meals (Full Details):**
```typescript
// Change from: .select('water_cups')
// To:
const { data: mealsData } = await supabase
  .from('entry_meals')
  .select('entry_id, water_cups, breakfast, lunch, dinner')
  .in('entry_id', entryIds)
```

**f) Tomorrow Notes:**
```typescript
const { data: tomorrowNotesData } = await supabase
  .from('entry_tomorrow_notes')
  .select('entry_id, tomorrow_notes')
  .in('entry_id', entryIds)
```

**g) Shower/Bath:**
```typescript
const { data: showerBathData } = await supabase
  .from('entry_shower_bath')
  .select('entry_id, took_shower, shower_note')
  .in('entry_id', entryIds)
```

#### **2. Enhanced Habit Correlations:**

**Current:**
```typescript
const habitCorrelations = {
  mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
  self_care_completion: selfCareRates.completionRate
}
```

**Enhanced:**
```typescript
// Calculate gratitude impact
const gratitudeDays = gratitudeData?.filter(g => 
  g.grateful_items && Array.isArray(g.grateful_items) && g.grateful_items.length > 0
).length || 0

// Calculate affirmations impact
const affirmationDays = affirmationsData?.filter(a => 
  a.affirmations && Array.isArray(a.affirmations) && a.affirmations.length > 0
).length || 0

// Calculate sentiment distribution
const sentimentCounts = {
  positive: dailyInsights?.filter(i => i.sentiment_label === 'positive').length || 0,
  neutral: dailyInsights?.filter(i => i.sentiment_label === 'neutral').length || 0,
  negative: dailyInsights?.filter(i => i.sentiment_label === 'negative').length || 0
}

// Enhanced habit correlations
const habitCorrelations = {
  mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
  self_care_completion: selfCareRates.completionRate,
  mood_vs_gratitude: gratitudeDays > 0 ? (avgMood ? parseFloat(avgMood) : null) : null,
  mood_vs_affirmations: affirmationDays > 0 ? (avgMood ? parseFloat(avgMood) : null) : null,
  sentiment_distribution: sentimentCounts,
  consistency_impact: consistencyScore > 70 ? 'high' : consistencyScore > 50 ? 'medium' : 'low'
}
```

#### **3. Enhanced Prompt Building (FULL DATA - NO TRUNCATION):**

**Build Full Daily Insights (Complete):**
```typescript
// Build complete daily insights with all details
let dailyInsightsFull = ''
if (dailyInsights && dailyInsights.length > 0) {
  dailyInsightsFull = dailyInsights.map((insight, index) => {
    const entry = entries.find(e => e.id === insight.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const sentiment = insight.sentiment_label || 'neutral'
    const text = insight.insight_text || 'No insight available'
    const details = insight.insight_details || {}
    const topics = insight.topics || []
    
    return `Day ${index + 1} (${date}, ${sentiment}):
Main Insight: ${text}
What Went Well: ${details.what_went_well || 'N/A'}
Progress Area: ${details.progress_area || 'N/A'}
Self-Care Balance: ${details.self_care_balance || 'N/A'}
Emotional Pattern: ${details.emotional_pattern || 'N/A'}
Topics: ${topics.join(', ') || 'None'}`
  }).join('\n\n---\n\n')
} else {
  dailyInsightsFull = 'No daily insights available for this week'
}
```

**Build Full Structured Data (Complete Arrays):**
```typescript
// Build complete affirmations (all items, not just themes)
let affirmationsFull = ''
if (affirmationsData && affirmationsData.length > 0) {
  affirmationsFull = affirmationsData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const affirmations = item.affirmations || []
    return `Day ${index + 1} (${date}): ${affirmations.length > 0 ? affirmations.join(' | ') : 'None'}`
  }).join('\n')
} else {
  affirmationsFull = 'No affirmations recorded this week'
}

// Build complete gratitude (all items)
let gratitudeFull = ''
if (gratitudeData && gratitudeData.length > 0) {
  gratitudeFull = gratitudeData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const items = item.grateful_items || []
    return `Day ${index + 1} (${date}): ${items.length > 0 ? items.join(' | ') : 'None'}`
  }).join('\n')
} else {
  gratitudeFull = 'No gratitude items recorded this week'
}

// Build complete priorities (all items)
let prioritiesFull = ''
if (prioritiesData && prioritiesData.length > 0) {
  prioritiesFull = prioritiesData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const priorities = item.priorities || []
    return `Day ${index + 1} (${date}): ${priorities.length > 0 ? priorities.join(' | ') : 'None'}`
  }).join('\n')
} else {
  prioritiesFull = 'No priorities recorded this week'
}
```

**Build Full Diary Text (NO TRUNCATION):**
```typescript
// Build complete diary entries (full text, no truncation)
const diaryFull = entries.map((entry, index) => {
  const text = entry.diary_text || 'No diary text'
  return `Day ${index + 1} (${entry.entry_date}, Mood: ${entry.mood_score || 'N/A'}):
${text}`
}).join('\n\n---\n\n')
```

**Build Full Self-Care Details:**
```typescript
// Build detailed self-care activities per day
let selfCareFull = ''
if (selfCareData && selfCareData.length > 0) {
  const selfCareActivities = ['exercise', 'meditation', 'reading', 'hobby', 'social', 'nature', 'music', 'rest', 'nutrition', 'hygiene']
  selfCareFull = selfCareData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const activities = selfCareActivities.filter(activity => item[activity] === true)
    return `Day ${index + 1} (${date}): ${activities.length > 0 ? activities.join(', ') : 'None'}`
  }).join('\n')
} else {
  selfCareFull = 'No self-care activities recorded this week'
}
```

**Build Full Meals Details:**
```typescript
// Build complete meal details
let mealsFull = ''
if (mealsData && mealsData.length > 0) {
  mealsFull = mealsData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    return `Day ${index + 1} (${date}):
Breakfast: ${item.breakfast || 'Not logged'}
Lunch: ${item.lunch || 'Not logged'}
Dinner: ${item.dinner || 'Not logged'}
Water: ${item.water_cups || 0} cups`
  }).join('\n\n')
} else {
  mealsFull = 'No meal data recorded this week'
}
```

**Build Tomorrow Notes:**
```typescript
// Build tomorrow notes
let tomorrowNotesFull = ''
if (tomorrowNotesData && tomorrowNotesData.length > 0) {
  tomorrowNotesFull = tomorrowNotesData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const notes = item.tomorrow_notes || ''
    return `Day ${index + 1} (${date}): ${notes || 'No notes'}`
  }).join('\n\n')
} else {
  tomorrowNotesFull = 'No tomorrow notes recorded this week'
}
```

**Build Shower/Bath Details:**
```typescript
// Build shower/bath details
let showerBathFull = ''
if (showerBathData && showerBathData.length > 0) {
  showerBathFull = showerBathData.map((item, index) => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    return `Day ${index + 1} (${date}): ${item.took_shower ? 'Yes' : 'No'}${item.shower_note ? ` - ${item.shower_note}` : ''}`
  }).join('\n')
} else {
  showerBathFull = 'No shower/bath data recorded this week'
}
```

---

## 📝 Enhanced Prompt Template

### **System Prompt:**
```
You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. You analyze weekly journal entries, daily insights, affirmations, gratitude, and priorities to provide deep, personalized insights. Focus on:

1. Emotional patterns and mood trends
2. Habit correlations and their impact on well-being
3. Recurring themes in affirmations, gratitude, and priorities
4. Actionable recommendations based on patterns
5. Celebrating progress and identifying growth areas

Be empathetic, specific, and actionable. Use the daily insights and structured data to provide context-rich analysis.
```

### **User Prompt Template (PREMIUM - FULL DATA):**
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

### **Prompt Variables to Replace:**
- `{week_start}` - Week start date
- `{week_end}` - Week end date
- `{entries_count}` - Number of entries (0-7)
- `{avg_mood}` - Average mood score
- `{mood_scores}` - Day-by-day mood scores
- `{mood_trend}` - improving/declining/stable/volatile
- `{sentiment_distribution}` - JSON with positive/neutral/negative counts
- `{positive_count}`, `{neutral_count}`, `{negative_count}` - Sentiment counts
- `{daily_insights_full}` - **COMPLETE** daily insights with all details (full text, insight_details, topics)
- `{diary_full}` - **COMPLETE** diary entries (full text, NO truncation)
- `{affirmations_full}` - **COMPLETE** affirmations (all items, day by day)
- `{gratitude_full}` - **COMPLETE** gratitude items (all items, day by day)
- `{priorities_full}` - **COMPLETE** priorities (all items, day by day)
- `{self_care_full}` - **COMPLETE** self-care details (specific activities per day)
- `{meals_full}` - **COMPLETE** meal details (breakfast, lunch, dinner, water per day)
- `{tomorrow_notes_full}` - **COMPLETE** tomorrow notes (all notes, day by day)
- `{shower_bath_full}` - **COMPLETE** shower/bath details (per day)
- `{self_care_summary}` - Self-care completion summary
- `{cups_avg}` - Average water cups
- `{consistency_score}` - Consistency percentage
- `{habit_correlations}` - Enhanced habit correlations JSON
- `{weekly_topics}` - Top 10 topics

---

## 🔧 Implementation Plan

### **Phase 1: Data Fetching (Lines 69-126)**

**Step 1.1: Add Daily Insights Fetch**
- Location: After `entryIds` is created (line 96)
- Add fetch for `entry_insights` table
- Filter by `entry_id` in `entryIds`
- Select: `entry_id, insight_text, sentiment_label, insight_details, topics`

**Step 1.2: Add Structured Data Fetches**
- Add `entry_affirmations` fetch
- Add `entry_gratitude` fetch
- Add `entry_priorities` fetch
- All use `.in('entry_id', entryIds)`

**Step 1.3: Expand Meals Fetch**
- Change from `.select('water_cups')` to `.select('entry_id, water_cups, breakfast, lunch, dinner')`
- Update variable name from `mealsData` to maintain consistency

**Step 1.4: Add Tomorrow Notes Fetch**
- Add fetch for `entry_tomorrow_notes` table
- Select: `entry_id, tomorrow_notes`
- Use `.in('entry_id', entryIds)`

**Step 1.5: Add Shower/Bath Fetch**
- Add fetch for `entry_shower_bath` table
- Select: `entry_id, took_shower, shower_note`
- Use `.in('entry_id', entryIds)`

### **Phase 2: Data Processing (Lines 86-126)**

**Step 2.1: Build Full Daily Insights (NO TRUNCATION)**
- Create helper function or inline code
- Format: "Day X (date, sentiment): FULL insight_text + ALL insight_details"
- Include: main insight, what_went_well, progress_area, self_care_balance, emotional_pattern, topics
- Handle missing insights gracefully

**Step 2.2: Build Full Structured Data (ALL ITEMS)**
- Build complete affirmations list (all items, day by day)
- Build complete gratitude list (all items, day by day)
- Build complete priorities list (all items, day by day)
- NO theme extraction - include ALL items

**Step 2.3: Build Full Diary Text (NO TRUNCATION)**
- Include COMPLETE diary text for each entry
- Format: "Day X (date, Mood: X): FULL TEXT"
- Handle empty diary text gracefully

**Step 2.4: Build Full Self-Care Details**
- List specific activities per day (exercise, meditation, reading, etc.)
- Format: "Day X (date): activity1, activity2, activity3"
- Show which activities were done each day

**Step 2.5: Build Full Meals Details**
- Include breakfast, lunch, dinner text for each day
- Include water cups per day
- Format: "Day X (date): Breakfast: ..., Lunch: ..., Dinner: ..., Water: X cups"

**Step 2.6: Build Tomorrow Notes**
- Include complete tomorrow_notes text for each day
- Format: "Day X (date): [full notes text]"

**Step 2.7: Build Shower/Bath Details**
- Include took_shower boolean and shower_note text
- Format: "Day X (date): Yes/No [note if available]"

**Step 2.8: Enhanced Habit Correlations**
- Calculate gratitude days count
- Calculate affirmations days count
- Calculate sentiment distribution
- Build enhanced correlations object

### **Phase 3: Prompt Enhancement (Lines 128-181)**

**Step 3.1: Update Fallback Template**
- Replace current `user_prompt_template` with enhanced version
- Add all new variables to template

**Step 3.2: Update Prompt Building**
- Add replacements for all new variables:
  - `{daily_insights_full}` - Complete daily insights with all details
  - `{diary_full}` - Complete diary text (no truncation)
  - `{affirmations_full}` - Complete affirmations (all items)
  - `{gratitude_full}` - Complete gratitude (all items)
  - `{priorities_full}` - Complete priorities (all items)
  - `{self_care_full}` - Complete self-care details (specific activities)
  - `{meals_full}` - Complete meal details (breakfast, lunch, dinner, water)
  - `{tomorrow_notes_full}` - Complete tomorrow notes
  - `{shower_bath_full}` - Complete shower/bath details
  - `{sentiment_distribution}`
  - `{positive_count}`, `{neutral_count}`, `{negative_count}`
- Update `habit_correlations` with enhanced version

**Step 3.3: Update System Prompt**
- Enhance system prompt for premium analysis depth
- Emphasize connecting all data points for comprehensive insights

**Step 3.4: Update Max Tokens**
- Increase `max_tokens` from 400 to 600-800 (for premium-depth response)

### **Phase 4: Helper Functions (After line 413)**

**Step 4.1: Remove `extractThemes()` Function**
- **NOT NEEDED** - We're using full data, not themes
- All structured data will be included in full

**Step 4.2: Update `parseWeeklyInsight()` Function**
- May need minor updates if response format changes
- Should handle new structure with "Highlights:", "Key Insights:", "Recommendations:" sections
- Handle 4-5 insights instead of 3
- Handle 3 recommendations instead of 2

---

## 📊 Impact Analysis

### **✅ No Impact Areas:**

1. **Database Schema:**
   - ✅ No schema changes needed
   - ✅ All required fields exist
   - ✅ No migrations required

2. **App-Level Code:**
   - ⚠️ **Premium access control required** - Verify user has premium subscription before allowing weekly/monthly analysis
   - ✅ `WeeklyInsight` model already has all fields
   - ✅ Analytics screen already displays all outputs
   - ⚠️ **UI changes:** Show premium upgrade prompt for non-premium users trying to access weekly/monthly analysis

3. **Other Services:**
   - ✅ No changes to `AIService`
   - ✅ No changes to `AnalyticsService`
   - ✅ No changes to `HistoryService`
   - ✅ No changes to providers

4. **Other Edge Functions:**
   - ✅ No changes to `ai-analyze-daily`
   - ✅ No changes to `ai-analyze-monthly`
   - ✅ No changes to `process-ai-queue`

5. **Data Models:**
   - ✅ No changes to models
   - ✅ No changes to serialization

### **⚠️ Areas Requiring Attention:**

1. **Edge Function Performance:**
   - **Impact:** Additional queries (4-5 more queries)
   - **Mitigation:** All queries run in parallel using `Promise.all()`
   - **Risk:** Low - queries are fast, data is small

2. **Token Usage:**
   - **Impact:** Increased from ~350 to ~8,000-10,000 input tokens (full data)
   - **Cost Impact:** From $0.0002 to ~$0.002 per analysis (premium feature)
   - **Risk:** Low - cost justified for premium users, still very affordable

3. **Response Parsing:**
   - **Impact:** May need to update `parseWeeklyInsight()` if AI response format changes
   - **Mitigation:** Enhanced prompt asks for clear section labels
   - **Risk:** Low - parsing function is flexible

4. **Error Handling:**
   - **Impact:** More data sources = more potential failure points
   - **Mitigation:** Graceful fallbacks for missing data
   - **Risk:** Low - all fetches have try-catch

### **🔒 Safety Measures:**

1. **Graceful Degradation:**
   - If daily insights missing → Continue with aggregated data
   - If structured data missing → Continue without that data (show "None" or empty)
   - If any fetch fails → Log error but continue with available data

2. **Backward Compatibility:**
   - Enhanced prompt is backward compatible
   - Old responses still parse correctly
   - No breaking changes to response structure

3. **Error Logging:**
   - All new fetches wrapped in try-catch
   - Errors logged to `ai_errors_log`
   - Function continues even if some data missing

---

## 💰 Cost Analysis (Premium Edition)

### **Current Implementation (Before Enhancement):**
- Input tokens: ~350
- Output tokens: ~300
- Cost: **$0.0002 per week**
- **Note:** This is the current basic implementation that will be replaced with premium-only full analysis

### **Premium Implementation (FULL DATA - PREMIUM ONLY):**
- Input tokens: ~8,000-10,000
- Output tokens: ~600-800
- Cost: **~$0.002 per week**
- **Access:** Premium users only

### **Cost Breakdown (7 days of entries - FULL DATA):**

**Input Tokens (Complete Data):**
- System prompt: 80 tokens
- **Daily insights (7 × full insight + details):** ~2,100 tokens
  - Full insight_text: ~200 tokens each = 1,400 tokens
  - insight_details (what_went_well, progress_area, etc.): ~100 tokens each = 700 tokens
- **Diary entries (7 × full text):** ~4,500 tokens
  - Average 500 words per entry = ~650 tokens each
  - 7 entries = ~4,550 tokens
- **Structured data (full arrays):** ~1,400 tokens
  - Affirmations (all items): ~400 tokens
  - Gratitude (all items): ~400 tokens
  - Priorities (all items): ~400 tokens
  - Tomorrow notes: ~200 tokens
- **Self-care details:** ~300 tokens
  - Specific activities per day: ~40 tokens each
- **Meal details:** ~500 tokens
  - Breakfast, lunch, dinner text per day: ~70 tokens each
- **Shower/bath:** ~100 tokens
- Aggregated stats: 200 tokens
- Habit correlations: 100 tokens
- Topics: 100 tokens
- **Total Input: ~9,180 tokens**

**Output Tokens (Premium Depth):**
- Highlights (3-4 sentences): ~120 tokens
- Key Insights (4-5 insights): ~200 tokens
- Recommendations (3 items): ~150 tokens
- Formatting: ~30 tokens
- **Total Output: ~500 tokens**

**Cost Calculation:**
- Input: 9,180 × $0.15/1M = **$0.001377**
- Output: 500 × $0.60/1M = **$0.0003**
- **Total: $0.001677 ≈ $0.002 per week**

**Monthly Cost:** ~$0.008 per premium user  
**Annual Cost:** ~$0.10 per premium user

**Conclusion:** 
- **Premium-only feature** - Weekly and monthly analysis are exclusively for premium users
- **Extremely affordable** ($0.002/week) for the depth of analysis provided
- **Justified for premium users** who get maximum depth and context
- **No cost concerns** - premium feature with premium value
- **GPT-4o-mini supports up to 128k tokens** - we're well within limits (~9k tokens)

---

## 🧪 Testing Plan

### **Test Cases:**

1. **Full Week (7 entries):**
   - ✅ All data available
   - ✅ Verify all insights generated
   - ✅ Verify habit correlations calculated
   - ✅ Verify all data included (no truncation)

2. **Partial Week (3-4 entries):**
   - ✅ Some data missing
   - ✅ Verify graceful handling
   - ✅ Verify insights still generated

3. **Missing Daily Insights:**
   - ✅ Some entries have insights, some don't
   - ✅ Verify function continues
   - ✅ Verify prompt includes available insights only

4. **Missing Structured Data:**
   - ✅ No affirmations/gratitude/priorities
   - ✅ Verify themes show "None" or empty
   - ✅ Verify function doesn't fail

5. **Empty Diary Text:**
   - ✅ Some entries have no diary text
   - ✅ Verify excerpts handle gracefully
   - ✅ Verify topics still extracted from available text

6. **Error Scenarios:**
   - ✅ Database query fails
   - ✅ Verify error logged
   - ✅ Verify function continues or fails gracefully

7. **Response Parsing:**
   - ✅ Verify insights extracted correctly
   - ✅ Verify recommendations extracted correctly
   - ✅ Verify highlights saved correctly

---

## 📋 Implementation Checklist

### **Pre-Implementation:**
- [x] Plan created
- [x] Impact analyzed
- [x] Cost calculated
- [x] Prompt template designed

### **Implementation:**
- [ ] Add daily insights fetch (full data)
- [ ] Add affirmations fetch
- [ ] Add gratitude fetch
- [ ] Add priorities fetch
- [ ] Expand meals fetch (breakfast, lunch, dinner)
- [ ] Add tomorrow notes fetch
- [ ] Add shower/bath fetch
- [ ] Build full daily insights (no truncation)
- [ ] Build full structured data (all items)
- [ ] Build full diary text (no truncation)
- [ ] Build full self-care details (specific activities)
- [ ] Build full meal details
- [ ] Build tomorrow notes
- [ ] Build shower/bath details
- [ ] Enhance habit correlations
- [ ] Update prompt template (premium version)
- [ ] Update prompt building logic (all new variables)
- [ ] Update max_tokens (600-800)
- [ ] Add error handling
- [ ] Test with sample data

### **Post-Implementation:**
- [ ] Deploy edge function
- [ ] Test with real user data
- [ ] Monitor error logs
- [ ] Verify insights quality
- [ ] Monitor token usage
- [ ] Monitor costs

---

## 🎯 Expected Outcomes

### **User Experience:**
- ✅ **Maximum depth** - Full context from all data sources
- ✅ **Complete pattern recognition** - AI sees everything, not summaries
- ✅ **Highly personalized** - Based on complete diary texts, all insights, all structured data
- ✅ **Comprehensive correlations** - Can connect any aspect (mood, habits, meals, planning, etc.)
- ✅ **Premium value** - Users get the absolute best analysis possible
- ✅ **Actionable insights** - Based on complete picture, not partial data

### **Technical:**
- ✅ Richer data for AI analysis
- ✅ Better prompt context
- ✅ More accurate insights
- ✅ Better user engagement

### **Business:**
- ✅ **Premium feature** - Justifies premium subscription
- ✅ **Maximum value** - Users get best possible analysis
- ✅ **Higher engagement** - Deeper insights = more engagement
- ✅ **Better retention** - Premium users see clear value
- ✅ **Competitive advantage** - Most comprehensive weekly analysis available
- ✅ **Cost justified** - $0.002/week is negligible for premium feature value

---

## 🔄 Rollback Plan

**If Issues Arise:**
1. Revert Edge Function to previous version
2. No database changes to rollback
3. No app changes to rollback
4. Users see previous format (still works)

**Risk Level:** ⭐ Very Low (isolated change, easy rollback)

---

## 📝 Final Conclusion

**Changes Required:**
- ✅ **1 file:** `supabase/functions/ai-analyze-weekly/index.ts` (Edge Function)
- ⚠️ **App-level:** Premium access control required (verify user has premium subscription before allowing weekly/monthly analysis)
- ✅ **No database changes**
- ✅ **No other functionality impact**

**Benefits:**
- ✅ **Premium-only feature** - Exclusive value for premium users
- ✅ Significantly better AI insights (maximum depth)
- ✅ More engaging user experience
- ✅ Better pattern recognition (complete data context)
- ✅ Premium value proposition

**Risk:**
- ⭐ Very Low (isolated, backward compatible, graceful degradation)
- ⚠️ **Premium access control** must be implemented at app level

**Status:** Ready for Implementation ✅

**IMPORTANT REMINDER:**
- Weekly and monthly analysis are **PREMIUM-ONLY** features
- Non-premium users should NOT have access
- App must verify premium status before allowing access
- Edge Function can optionally verify premium status as well (defense in depth)

---

## 📌 Notes

- **PREMIUM-ONLY FEATURE:** Weekly and monthly analysis are exclusively for premium users
- **Access Control:** App must verify premium subscription before allowing access
- **Full Data:** NO truncation - send complete data for best analysis
- **All new data fetches** should be wrapped in try-catch
- **Missing data** should not break the function (graceful degradation)
- **Enhanced prompt** should maintain clear structure for parsing
- **Token limit:** GPT-4o-mini supports 128k tokens - we're using ~9k (safe margin)
- **Cost:** $0.002/week is extremely affordable for premium feature
- **No breaking changes** to existing functionality
- **Parallel queries:** All data fetches should run in parallel for performance
- **Error handling:** Log errors but continue with available data
- **Daily insights:** Remain available to all users (free feature)
- **Weekly/Monthly:** Premium users only

---

## 📦 Complete Data Fetching Summary

### **All Data Sources (7 Additional Fetches):**

1. **Daily Insights** (`entry_insights`)
   - Fields: `entry_id, insight_text, sentiment_label, insight_details, topics`
   - Purpose: Complete AI-generated insights with all details

2. **Affirmations** (`entry_affirmations`)
   - Fields: `entry_id, affirmations` (JSONB array)
   - Purpose: All affirmation items per day

3. **Gratitude** (`entry_gratitude`)
   - Fields: `entry_id, grateful_items` (JSONB array)
   - Purpose: All gratitude items per day

4. **Priorities** (`entry_priorities`)
   - Fields: `entry_id, priorities` (JSONB array)
   - Purpose: All priority items per day

5. **Meals** (`entry_meals`) - **EXPANDED**
   - Fields: `entry_id, water_cups, breakfast, lunch, dinner`
   - Purpose: Complete meal details per day

6. **Tomorrow Notes** (`entry_tomorrow_notes`) - **NEW**
   - Fields: `entry_id, tomorrow_notes`
   - Purpose: Planning and forward-looking notes

7. **Shower/Bath** (`entry_shower_bath`) - **NEW**
   - Fields: `entry_id, took_shower, shower_note`
   - Purpose: Hygiene routine details

### **Existing Data (Already Fetched):**
- **Entries:** `id, diary_text, mood_score, entry_date, created_at` (FULL TEXT - no truncation)
- **Self-Care:** All boolean fields (exercise, meditation, reading, hobby, social, nature, music, rest, nutrition, hygiene)

### **Parallel Query Execution:**
```typescript
// Execute all fetches in parallel for performance
const [
  dailyInsights,
  affirmationsData,
  gratitudeData,
  prioritiesData,
  mealsData,
  tomorrowNotesData,
  showerBathData
] = await Promise.all([
  supabase.from('entry_insights').select('...').in('entry_id', entryIds),
  supabase.from('entry_affirmations').select('...').in('entry_id', entryIds),
  supabase.from('entry_gratitude').select('...').in('entry_id', entryIds),
  supabase.from('entry_priorities').select('...').in('entry_id', entryIds),
  supabase.from('entry_meals').select('...').in('entry_id', entryIds),
  supabase.from('entry_tomorrow_notes').select('...').in('entry_id', entryIds),
  supabase.from('entry_shower_bath').select('...').in('entry_id', entryIds)
])
```

---

## ✅ Final Implementation Checklist

### **Data Fetching (7 new fetches):**
- [ ] Fetch daily insights (full data)
- [ ] Fetch affirmations
- [ ] Fetch gratitude
- [ ] Fetch priorities
- [ ] Expand meals fetch (breakfast, lunch, dinner)
- [ ] Fetch tomorrow notes
- [ ] Fetch shower/bath
- [ ] Execute all fetches in parallel

### **Data Processing (Full Data Building):**
- [ ] Build full daily insights (no truncation, all details)
- [ ] Build full affirmations (all items, day by day)
- [ ] Build full gratitude (all items, day by day)
- [ ] Build full priorities (all items, day by day)
- [ ] Build full diary text (no truncation)
- [ ] Build full self-care details (specific activities)
- [ ] Build full meal details (breakfast, lunch, dinner, water)
- [ ] Build tomorrow notes (full text)
- [ ] Build shower/bath details
- [ ] Calculate enhanced habit correlations

### **Prompt Enhancement:**
- [ ] Update system prompt (premium depth)
- [ ] Update user prompt template (all new variables)
- [ ] Add all variable replacements:
  - `{daily_insights_full}`
  - `{diary_full}`
  - `{affirmations_full}`
  - `{gratitude_full}`
  - `{priorities_full}`
  - `{self_care_full}`
  - `{meals_full}`
  - `{tomorrow_notes_full}`
  - `{shower_bath_full}`
- [ ] Update max_tokens to 600-800

### **Error Handling:**
- [ ] Wrap all new fetches in try-catch
- [ ] Graceful degradation for missing data
- [ ] Error logging for all failures
- [ ] Continue with available data if some fails

### **Testing:**
- [ ] Test with full week (7 entries, all data)
- [ ] Test with partial week (3-4 entries)
- [ ] Test with missing daily insights
- [ ] Test with missing structured data
- [ ] Test with empty diary text
- [ ] Test error scenarios
- [ ] Verify response parsing
- [ ] Verify token usage
- [ ] Verify cost calculation

### **Deployment:**
- [ ] Deploy edge function
- [ ] Test with real user data
- [ ] Monitor error logs
- [ ] Monitor token usage
- [ ] Monitor costs
- [ ] Verify insights quality

---

## 🎯 Premium Feature Specifications

**IMPORTANT:** Weekly and monthly analysis are **PREMIUM-ONLY** features. Non-premium users do NOT have access to these features.

### **Premium Weekly Analysis Features:**

| Feature | Specification |
|--------|--------------|
| **Diary Text** | **Full text (no limit, no truncation)** |
| **Daily Insights** | **Full insight + all details** (what_went_well, progress_area, self_care_balance, emotional_pattern, topics) |
| **Structured Data** | **All items (complete arrays)** - affirmations, gratitude, priorities |
| **Self-Care** | **Specific activities per day** (exercise, meditation, reading, hobby, social, nature, music, rest, nutrition, hygiene) |
| **Meals** | **Breakfast, lunch, dinner, water** (full details per day) |
| **Tomorrow Notes** | **Full notes included** (planning and forward-looking context) |
| **Shower/Bath** | **Full details included** (hygiene routine context) |
| **Input Tokens** | **~9,000 tokens** (comprehensive data) |
| **Output Depth** | **4-5 insights, 3 recommendations** (premium depth) |
| **Cost** | **$0.002/week** (extremely affordable) |
| **Value** | **Maximum depth & context** - best analysis possible |

### **Access Control:**
- ✅ **Premium users only** - Weekly and monthly analysis
- ❌ **Non-premium users** - No access to weekly/monthly analysis
- ✅ **Daily insights** - Available to all users (free feature)

### **Premium Access Control Implementation:**

**App-Level (Required):**
1. **Before triggering weekly/monthly analysis:**
   - Verify user has active premium subscription
   - If not premium → Show upgrade prompt / block access
   - If premium → Allow access to weekly/monthly analysis

2. **UI/UX:**
   - Analytics screen: Show premium badge/lock icon for weekly/monthly sections
   - If non-premium user tries to access → Show upgrade modal
   - Clearly indicate premium-only features

**Edge Function Level (Optional - Defense in Depth):**
- Can optionally verify premium status in Edge Function
- Return error if non-premium user tries to access
- This provides server-side validation (additional security)

**Database Consideration:**
- Store premium status in `users` table or subscription service
- Check premium status before allowing weekly/monthly analysis triggers

---

**Status:** ✅ **Complete Premium Plan Ready for Implementation**

