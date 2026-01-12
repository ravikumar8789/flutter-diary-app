# Weekly Analysis Prompt Enhancement - Implementation Plan

## 📋 Overview

**Goal:** Switch from free-form text parsing to JSON format for weekly AI analysis to:
- Fix root cause of duplication issue (format mismatch)
- Improve content quality (5-7 sentence highlights, better insights)
- Eliminate complex parsing logic (150+ lines → simple JSON.parse)
- Ensure reliable data extraction

**Change Type:** Backward compatible (fallback exists)

---

## 🗄️ Database Level Changes

### **Status: NO CHANGES REQUIRED**

**Reason:**
- Table schema already supports the fields we need
- `highlights` (text) - stores paragraph
- `key_insights` (text[]) - stores array
- `recommendations` (text[]) - stores array

**Existing Records:**
- Old records will continue to work (already stored)
- New records will have improved format
- No migration needed

---

## ⚙️ Edge Function Changes

### **File:** `supabase/functions/ai-analyze-weekly/index.ts`

### **1. Update System Prompt** (Line ~306)

**Current:**
```typescript
system_prompt: 'You are an analytical but compassionate AI assistant...'
```

**New:**
```typescript
system_prompt: 'You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. You analyze weekly journal entries, daily insights, affirmations, gratitude, and priorities to provide deep, personalized insights. Focus on:\n\n1. Emotional patterns and mood trends\n2. Habit correlations and their impact on well-being\n3. Recurring themes in affirmations, gratitude, and priorities\n4. Actionable recommendations based on patterns\n5. Celebrating progress and identifying growth areas\n\nBe empathetic, specific, and actionable. Use the daily insights and structured data to provide context-rich analysis.\n\nIMPORTANT: Always return your response as a valid JSON object. Do not include any markdown formatting, headers, or explanatory text outside the JSON object.'
```

### **2. Update User Prompt Template** (Lines 360-385)

**Replace Analysis Request Section:**

**Current:**
```
1. **Weekly Highlights** (3-4 sentences):...
2. **Key Insights** (4-5 specific insights):...
3. **Recommendations** (3 actionable items):...
Format your response clearly with sections labeled "Highlights:", "Key Insights:", and "Recommendations:".
```

**New:**
```
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

### **3. Update API Call** (Line ~431)

**Current:**
```typescript
body: JSON.stringify({
  model: 'gpt-4o-mini',
  messages: [
    { role: 'system', content: template.system_prompt },
    { role: 'user', content: userPrompt }
  ],
  temperature: template.temperature || 0.5,
  max_tokens: template.max_tokens || 800
})
```

**New:**
```typescript
body: JSON.stringify({
  model: 'gpt-4o-mini',
  messages: [
    { role: 'system', content: template.system_prompt },
    { role: 'user', content: userPrompt }
  ],
  temperature: template.temperature || 0.5,
  max_tokens: template.max_tokens || 800,
  response_format: { type: "json_object" }  // ADD THIS LINE
})
```

### **4. Replace Parsing Logic** (Lines 448-460)

**Current:**
```typescript
const aiData = await openaiResponse.json()
const insightText = aiData.choices[0]?.message?.content?.trim() || ''

if (!insightText) {
  throw new Error('Empty response from OpenAI')
}

// 9. Parse insight into structured format
const { highlights, insights, recommendations } = parseWeeklyInsight(insightText)
```

**New:**
```typescript
const aiData = await openaiResponse.json()
const insightText = aiData.choices[0]?.message?.content?.trim() || ''

if (!insightText) {
  throw new Error('Empty response from OpenAI')
}

// 9. Parse JSON response
let highlights = ''
let insights: string[] = []
let recommendations: string[] = []

try {
  const parsed = JSON.parse(insightText)
  highlights = parsed.highlights || ''
  insights = Array.isArray(parsed.key_insights) ? parsed.key_insights : []
  recommendations = Array.isArray(parsed.recommendations) ? parsed.recommendations : []
  
  // Validate we got the data
  if (!highlights || insights.length === 0 || recommendations.length === 0) {
    throw new Error('Invalid JSON structure from AI')
  }
} catch (parseError) {
  // Fallback: Try old parsing method if JSON fails
  console.warn('JSON parsing failed, falling back to text parsing:', parseError)
  const parsed = parseWeeklyInsight(insightText)
  highlights = parsed.highlights || insightText
  insights = parsed.insights
  recommendations = parsed.recommendations
}
```

### **5. Remove/Deprecate parseWeeklyInsight Function** (Lines 706-847)

**Action:** Keep function for fallback but mark as deprecated:
```typescript
/**
 * @deprecated This function is kept only for fallback compatibility.
 * New implementations should use JSON format with response_format: { type: "json_object" }
 */
function parseWeeklyInsight(text: string): { highlights: string; insights: string[]; recommendations: string[] } {
  // ... existing code ...
}
```

### **6. Update Max Tokens** (Line ~387)

**Current:** `max_tokens: 800`

**New:** `max_tokens: 1000` (to accommodate 5-7 sentence highlights)

---

## 📱 App Level Changes

### **Status: NO CHANGES REQUIRED**

**Reason:**
- Flutter code already expects:
  - `highlights` as String
  - `key_insights` as List<String>
  - `recommendations` as List<String>
- Data structure remains the same
- Only the source format changes (JSON vs text parsing)

**Files That Work As-Is:**
- `lib/services/analytics_service.dart` (line 240) - reads `weeklyInsight.highlights`
- `lib/services/ai_service.dart` (line 178) - reads `highlights` from DB
- `lib/screens/analytics_screen.dart` (line 1010) - displays `data.highlights!`
- `lib/models/analytics_models.dart` - models already support the structure

---

## 📊 Impact Analysis

### **✅ Positive Impacts**

1. **Fixes Root Cause**
   - Eliminates format mismatch issues
   - No more "**Weekly Mood Pattern:**" vs "Highlights:" confusion
   - 100% reliable parsing

2. **Code Simplification**
   - Removes 150+ lines of complex parsing logic
   - Replaces with simple `JSON.parse()`
   - Easier to maintain and debug

3. **Improved Content Quality**
   - 5-7 sentence highlights (vs 3-4)
   - Better structure and flow
   - Specific date/entry references
   - More actionable recommendations

4. **Performance**
   - Faster parsing (JSON.parse vs regex matching)
   - Lower CPU usage
   - More predictable execution time

5. **Reliability**
   - Guaranteed structure from OpenAI
   - No parsing failures
   - Consistent data format

### **⚠️ Potential Risks**

1. **OpenAI API Changes**
   - Risk: Low - JSON mode is stable feature
   - Mitigation: Fallback to old parsing exists

2. **Invalid JSON Responses**
   - Risk: Low - OpenAI JSON mode guarantees valid JSON
   - Mitigation: Try-catch with fallback to old parsing

3. **Token Usage**
   - Risk: Low - JSON format may use slightly more tokens
   - Impact: ~50-100 tokens increase (negligible cost)
   - Mitigation: Increased max_tokens to 1000

4. **Existing Records**
   - Risk: None - Old records remain unchanged
   - Impact: Only new records use new format

### **📈 Expected Improvements**

1. **Parsing Success Rate**
   - Current: ~85-90% (fails on format mismatches)
   - Expected: 99%+ (JSON guaranteed structure)

2. **Content Quality**
   - Highlights: 3-4 → 5-7 sentences
   - Insights: More specific with date references
   - Recommendations: More actionable

3. **Code Maintainability**
   - Parsing logic: 150+ lines → ~20 lines
   - Complexity: High → Low
   - Debugging: Difficult → Easy

---

## 🧪 Testing Plan

### **1. Unit Tests**

**Test Cases:**
- ✅ Valid JSON response parsing
- ✅ Invalid JSON fallback to old parsing
- ✅ Missing fields handling
- ✅ Empty arrays handling
- ✅ Malformed JSON handling

### **2. Integration Tests**

**Test Scenarios:**
- ✅ Generate new weekly insight with JSON format
- ✅ Verify highlights are 5-7 sentences
- ✅ Verify insights have date references
- ✅ Verify recommendations are actionable
- ✅ Verify data saves correctly to DB
- ✅ Verify Flutter app displays correctly

### **3. Edge Cases**

**Test Cases:**
- ✅ AI returns empty highlights
- ✅ AI returns only 2 insights (should handle gracefully)
- ✅ AI returns extra fields (should ignore)
- ✅ AI returns malformed JSON (fallback works)
- ✅ Network timeout during API call

### **4. Backward Compatibility**

**Test Cases:**
- ✅ Old records still display correctly
- ✅ Mixed old/new records work
- ✅ Fallback parsing works if JSON fails

---

## 🚀 Rollout Strategy

### **Phase 1: Development & Testing** (1-2 days)
1. Update Edge Function code
2. Test locally with sample data
3. Verify JSON parsing works
4. Test fallback mechanism

### **Phase 2: Staging Deployment** (1 day)
1. Deploy to staging environment
2. Generate test weekly insights
3. Verify data quality
4. Test Flutter app display

### **Phase 3: Production Deployment** (1 day)
1. Deploy Edge Function
2. Monitor first few generations
3. Verify no errors
4. Monitor token usage

### **Phase 4: Monitoring** (1 week)
1. Monitor parsing success rate
2. Monitor content quality
3. Monitor error rates
4. Collect user feedback

---

## 📝 Implementation Checklist

### **Edge Function**
- [ ] Update system prompt with JSON requirement
- [ ] Update user prompt template with JSON schema
- [ ] Add `response_format: { type: "json_object" }` to API call
- [ ] Replace parsing logic with JSON.parse
- [ ] Add try-catch with fallback
- [ ] Update max_tokens to 1000
- [ ] Mark old parsing function as deprecated
- [ ] Test with sample data
- [ ] Deploy to staging
- [ ] Test in staging
- [ ] Deploy to production

### **Documentation**
- [ ] Update prompt template in database (if stored)
- [ ] Update code comments
- [ ] Document JSON schema
- [ ] Update API documentation

### **Testing**
- [ ] Unit tests for JSON parsing
- [ ] Integration tests
- [ ] Edge case tests
- [ ] Backward compatibility tests

---

## 🔄 Rollback Plan

**If Issues Occur:**
1. Remove `response_format: { type: "json_object" }` from API call
2. Revert to old parsing logic
3. Keep enhanced prompt (still works with text)
4. No database changes needed

**Rollback Time:** < 5 minutes

---

## 📊 Success Metrics

**Track These Metrics:**
1. Parsing success rate (target: 99%+)
2. Average highlights length (target: 5-7 sentences)
3. Insights with date references (target: 80%+)
4. Error rate (target: <1%)
5. Token usage per request (baseline vs new)
6. User engagement with insights (if tracked)

---

## 🎯 Summary

**Changes Required:**
- ✅ Edge Function: Update prompt + API call + parsing
- ❌ Database: No changes
- ❌ Flutter App: No changes

**Risk Level:** LOW
- Backward compatible
- Fallback exists
- No breaking changes

**Effort:** Medium (2-3 days)
- Code changes: 1 day
- Testing: 1 day
- Deployment: 0.5 day

**Benefits:**
- Fixes duplication issue
- Improves content quality
- Simplifies code
- Increases reliability

