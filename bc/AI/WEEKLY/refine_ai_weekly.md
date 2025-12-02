# Weekly AI Analysis Enhancement Plan

## 📋 Executive Summary

**Objective:** Enhance weekly AI analysis to provide deeper, more engaging insights by including daily insights, structured user data, and better habit correlations.

**Current Issue:** Weekly analysis only uses aggregated statistics (mood avg, counts, topics), missing rich context from daily insights and structured data (affirmations, gratitude, priorities).

**Solution:** Fetch and include daily insights summaries, structured data, and enhanced habit correlations in the AI prompt for better analysis.

**Impact:** Minimal - Only Edge Function changes, no app/database changes needed.

**Cost:** ~$0.0005 per weekly analysis (0.05 cents) - Very affordable.

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
- Basic habit correlations (mood vs entries, self-care completion)

### **Current Limitations:**
- ❌ No daily insights summaries (missing AI-generated daily insights)
- ❌ No structured data (affirmations, gratitude, priorities)
- ❌ No diary text context (only keywords extracted)
- ❌ Limited habit correlations (only 2 basic correlations)
- ❌ No sentiment patterns from daily insights
- ❌ No emotional pattern analysis

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

**e) Meals (Expand):**
```typescript
// Change from: .select('water_cups')
// To:
const { data: mealsData } = await supabase
  .from('entry_meals')
  .select('entry_id, water_cups, breakfast, lunch, dinner')
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

#### **3. Enhanced Prompt Building:**

**Build Daily Insights Summary:**
```typescript
// Build daily insights summary
let dailyInsightsSummary = ''
if (dailyInsights && dailyInsights.length > 0) {
  dailyInsightsSummary = dailyInsights.map((insight, index) => {
    const entry = entries.find(e => e.id === insight.entry_id)
    const date = entry ? entry.entry_date : 'Unknown'
    const sentiment = insight.sentiment_label || 'neutral'
    const text = insight.insight_text || 'No insight available'
    return `Day ${index + 1} (${date}, ${sentiment}): ${text.substring(0, 100)}${text.length > 100 ? '...' : ''}`
  }).join('\n')
} else {
  dailyInsightsSummary = 'No daily insights available for this week'
}
```

**Build Structured Data Summary:**
```typescript
// Extract common themes from affirmations
const affirmationThemes = extractThemes(affirmationsData, 'affirmations')
// Extract common themes from gratitude
const gratitudeThemes = extractThemes(gratitudeData, 'grateful_items')
// Extract common priorities
const priorityThemes = extractThemes(prioritiesData, 'priorities')
```

**Build Diary Excerpts (Truncated):**
```typescript
// Build diary excerpts (first 100 words per entry)
const diaryExcerpts = entries.map((entry, index) => {
  const text = entry.diary_text || 'No diary text'
  const truncated = text.split(/\s+/).slice(0, 100).join(' ')
  return `Day ${index + 1} (${entry.entry_date}, Mood: ${entry.mood_score || 'N/A'}): ${truncated}${text.split(/\s+/).length > 100 ? '...' : ''}`
}).join('\n\n')
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

### **User Prompt Template:**
```
WEEKLY ANALYSIS REQUEST
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

=== DAILY INSIGHTS SUMMARY ===
{daily_insights_summary}

=== DIARY ENTRIES EXCERPTS ===
{diary_excerpts}

=== STRUCTURED DATA PATTERNS ===
Affirmations Themes: {affirmation_themes}
Gratitude Focus: {gratitude_themes}
Recurring Priorities: {priority_themes}

=== HABIT & CONSISTENCY ===
Self-Care Completion: {self_care_summary}
Water Intake: {cups_avg} cups/day average
Consistency Score: {consistency_score}%
Entries Count: {entries_count}/7

=== HABIT CORRELATIONS ===
{habit_correlations}

=== TOPICS MENTIONED ===
{weekly_topics}

=== ANALYSIS REQUEST ===
Based on the above comprehensive data, provide:

1. **Weekly Highlights** (2-3 sentences):
   - Overall mood pattern and emotional journey
   - Key positive moments or achievements
   - Notable patterns or trends

2. **Key Insights** (3 specific insights):
   - Insight 1: Pattern related to mood/emotions
   - Insight 2: Habit correlation or impact
   - Insight 3: Theme from affirmations/gratitude/priorities

3. **Recommendations** (2 actionable items):
   - Recommendation 1: Specific action based on patterns
   - Recommendation 2: Habit to strengthen or area to focus

Format your response clearly with sections labeled "Highlights:", "Key Insights:", and "Recommendations:". Keep insights specific and recommendations actionable. Total response should be 200-250 words.
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
- `{daily_insights_summary}` - Formatted daily insights (7 insights)
- `{diary_excerpts}` - Truncated diary text excerpts (7 entries)
- `{affirmation_themes}` - Common themes from affirmations
- `{gratitude_themes}` - Common themes from gratitude
- `{priority_themes}` - Common priorities mentioned
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

### **Phase 2: Data Processing (Lines 86-126)**

**Step 2.1: Build Daily Insights Summary**
- Create helper function or inline code
- Format: "Day X (date, sentiment): insight_text (truncated to 100 chars)"
- Handle missing insights gracefully

**Step 2.2: Extract Themes from Structured Data**
- Create `extractThemes()` helper function
- Extract common words/phrases from affirmations, gratitude, priorities
- Return top 3-5 themes per category

**Step 2.3: Build Diary Excerpts**
- Truncate each diary text to 100 words
- Format: "Day X (date, Mood: X): text..."
- Handle empty diary text

**Step 2.4: Enhanced Habit Correlations**
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
  - `{daily_insights_summary}`
  - `{diary_excerpts}`
  - `{affirmation_themes}`
  - `{gratitude_themes}`
  - `{priority_themes}`
  - `{sentiment_distribution}`
  - `{positive_count}`, `{neutral_count}`, `{negative_count}`
- Update `habit_correlations` with enhanced version

**Step 3.3: Update System Prompt**
- Enhance system prompt for better context understanding

**Step 3.4: Update Max Tokens**
- Increase `max_tokens` from 400 to 500-600 (for longer, detailed response)

### **Phase 4: Helper Functions (After line 413)**

**Step 4.1: Add `extractThemes()` Function**
```typescript
function extractThemes(data: any[], fieldName: string): string[] {
  const themes: { [key: string]: number } = {}
  
  data.forEach(item => {
    const items = item[fieldName]
    if (Array.isArray(items)) {
      items.forEach((text: string) => {
        if (text && typeof text === 'string') {
          const words = text.toLowerCase().split(/\s+/)
            .filter(w => w.length > 3)
            .filter(w => !['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her', 'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how', 'its', 'may', 'new', 'now', 'old', 'see', 'two', 'way', 'who', 'boy', 'did', 'its', 'let', 'put', 'say', 'she', 'too', 'use'].includes(w))
          
          words.forEach(word => {
            themes[word] = (themes[word] || 0) + 1
          })
        }
      })
    }
  })
  
  return Object.entries(themes)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([word]) => word)
}
```

**Step 4.2: Update `parseWeeklyInsight()` Function**
- May need minor updates if response format changes
- Should handle new structure with "Highlights:", "Key Insights:", "Recommendations:" sections

---

## 📊 Impact Analysis

### **✅ No Impact Areas:**

1. **Database Schema:**
   - ✅ No schema changes needed
   - ✅ All required fields exist
   - ✅ No migrations required

2. **App-Level Code:**
   - ✅ No changes to Flutter app
   - ✅ `WeeklyInsight` model already has all fields
   - ✅ Analytics screen already displays all outputs
   - ✅ No UI changes needed

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
   - **Impact:** Increased from ~350 to ~1,500 input tokens
   - **Cost Impact:** From $0.0002 to $0.0005 per analysis (still very low)
   - **Risk:** Low - cost is negligible

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
   - If structured data missing → Continue without themes
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

## 💰 Cost Analysis

### **Current Implementation:**
- Input tokens: ~350
- Output tokens: ~300
- Cost: **$0.0002 per week**

### **Enhanced Implementation:**
- Input tokens: ~1,500
- Output tokens: ~400
- Cost: **$0.0005 per week**

### **Cost Breakdown (7 days of entries):**

**Input Tokens:**
- System prompt: 50 tokens
- Daily insights (7 × 50 words): 350 tokens
- Diary excerpts (7 × 100 words): 700 tokens
- Structured data themes: 150 tokens
- Aggregated stats: 200 tokens
- Habit correlations: 50 tokens
- **Total Input: ~1,500 tokens**

**Output Tokens:**
- Highlights: ~80 tokens
- Key Insights (3): ~120 tokens
- Recommendations (2): ~80 tokens
- Formatting: ~20 tokens
- **Total Output: ~400 tokens**

**Cost Calculation:**
- Input: 1,500 × $0.15/1M = **$0.000225**
- Output: 400 × $0.60/1M = **$0.00024**
- **Total: $0.000465 ≈ $0.0005 per week**

**Monthly Cost:** ~$0.002 per user  
**Annual Cost:** ~$0.025 per user

**Conclusion:** Cost increase is minimal and acceptable for significantly better insights.

---

## 🧪 Testing Plan

### **Test Cases:**

1. **Full Week (7 entries):**
   - ✅ All data available
   - ✅ Verify all insights generated
   - ✅ Verify habit correlations calculated
   - ✅ Verify themes extracted

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
- [ ] Add daily insights fetch
- [ ] Add affirmations fetch
- [ ] Add gratitude fetch
- [ ] Add priorities fetch
- [ ] Expand meals fetch
- [ ] Build daily insights summary
- [ ] Create `extractThemes()` helper
- [ ] Build diary excerpts
- [ ] Enhance habit correlations
- [ ] Update prompt template
- [ ] Update prompt building logic
- [ ] Update max_tokens
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
- ✅ More personalized insights (based on actual diary content)
- ✅ Better pattern recognition (from daily insights)
- ✅ More relevant recommendations (based on affirmations/gratitude/priorities)
- ✅ Deeper emotional analysis (sentiment patterns)
- ✅ Better habit correlations (mood vs gratitude, affirmations, etc.)

### **Technical:**
- ✅ Richer data for AI analysis
- ✅ Better prompt context
- ✅ More accurate insights
- ✅ Better user engagement

### **Business:**
- ✅ Higher user engagement
- ✅ Better retention (users see value)
- ✅ Minimal cost increase ($0.0003 per week)
- ✅ Competitive advantage (deeper insights)

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
- ✅ **1 file:** `supabase/functions/ai-analyze-weekly/index.ts`
- ✅ **No app changes**
- ✅ **No database changes**
- ✅ **No other functionality impact**

**Benefits:**
- ✅ Significantly better AI insights
- ✅ More engaging user experience
- ✅ Better pattern recognition
- ✅ Minimal cost increase

**Risk:**
- ⭐ Very Low (isolated, backward compatible, graceful degradation)

**Status:** Ready for Implementation ✅

---

## 📌 Notes

- All new data fetches should be wrapped in try-catch
- Missing data should not break the function
- Enhanced prompt should maintain clear structure for parsing
- Cost increase is acceptable for quality improvement
- No breaking changes to existing functionality

