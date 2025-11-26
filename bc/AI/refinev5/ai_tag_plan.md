# **AI TAG EXTRACTION - IMPLEMENTATION PLAN**

## **📋 OVERVIEW**

**Goal:** Add AI-generated tags (3-4 relevant words) to daily analysis and store them in `entry_insights.topics` field.

**Status:** ✅ Infrastructure already exists - Flutter models, UI, and database schema support topics. Only need to modify AI prompt and extraction logic.

---

## **✅ PRE-IMPLEMENTATION CHECKLIST**

### **Existing Infrastructure (Already in Place):**
- ✅ `entry_insights.topics` field exists (ARRAY text[])
- ✅ Flutter `EntryInsights` model supports `topics` (line 8, 24, 44, 67 in `analytics_models.dart`)
- ✅ Flutter UI already displays topics (`history_screen.dart` lines 1135-1138)
- ✅ `AIService` already queries `topics` field (line 32 in `ai_service.dart`)
- ✅ Database schema ready - no migration needed

### **What Needs to Change:**
- ⚠️ Modify AI prompt to request tags in JSON response
- ⚠️ Extract tags from AI response
- ⚠️ Save tags to `entry_insights.topics` field

---

## **🔍 IMPACT ANALYSIS**

### **Files to Modify:**
1. **`supabase/functions/ai-analyze-daily/index.ts`**
   - Lines 245-252: Update prompt JSON structure
   - Lines 292-313: Extract tags from response
   - Lines 319-337: Save tags to database

### **No Impact On:**
- ✅ Flutter app (already supports topics)
- ✅ Other edge functions (weekly/monthly analysis)
- ✅ Database schema (field already exists)
- ✅ Existing insights (backward compatible - tags will be null/empty for old insights)
- ✅ User-facing functionality (tags are optional display)

### **Risk Level:** 🟢 **LOW**
- Non-breaking change
- Backward compatible
- No database migration needed
- UI already handles empty topics gracefully

---

## **📝 STEP-BY-STEP IMPLEMENTATION**

### **STEP 1: Update AI Prompt (Request Tags)**

**File:** `supabase/functions/ai-analyze-daily/index.ts`  
**Location:** Lines 245-252

**Current Prompt:**
```typescript
Please provide a structured response in JSON format:
{
  "main_insight": "...",
  "what_went_well": "...",
  "progress_area": "...",
  "self_care_balance": "...",
  "emotional_pattern": "..."
}
```

**New Prompt:**
```typescript
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
```

**Changes:**
- Add `tags` field to JSON structure
- Add clear instructions for tag format
- Specify 3-4 tags requirement
- Provide examples

---

### **STEP 2: Extract Tags from AI Response**

**File:** `supabase/functions/ai-analyze-daily/index.ts`  
**Location:** Lines 292-313 (after JSON parsing)

**Current Code:**
```typescript
const insightText = insightData.main_insight || responseText.trim()
const insightDetails = {
  what_went_well: insightData.what_went_well || null,
  progress_area: insightData.progress_area || null,
  self_care_balance: insightData.self_care_balance || null,
  emotional_pattern: insightData.emotional_pattern || null
}
```

**New Code:**
```typescript
const insightText = insightData.main_insight || responseText.trim()
const insightDetails = {
  what_went_well: insightData.what_went_well || null,
  progress_area: insightData.progress_area || null,
  self_care_balance: insightData.self_care_balance || null,
  emotional_pattern: insightData.emotional_pattern || null
}

// Extract and validate tags
let tags: string[] = []
if (insightData.tags && Array.isArray(insightData.tags)) {
  tags = insightData.tags
    .filter((tag: any) => typeof tag === 'string' && tag.trim().length > 0)
    .map((tag: string) => tag.trim().toLowerCase())
    .filter((tag: string) => tag.length <= 20) // Max 20 chars per tag
    .slice(0, 4) // Limit to 4 tags max
}

// Fallback: If AI doesn't provide tags, leave empty array (don't fail)
if (tags.length === 0) {
  console.warn('No tags provided by AI, continuing without tags')
}
```

**Changes:**
- Extract `tags` array from AI response
- Validate tags (must be strings, non-empty, max 20 chars)
- Normalize to lowercase
- Limit to 4 tags maximum
- Graceful fallback if tags missing (don't break existing flow)

---

### **STEP 3: Save Tags to Database**

**File:** `supabase/functions/ai-analyze-daily/index.ts`  
**Location:** Lines 319-337 (upsert operation)

**Current Code:**
```typescript
const { error: insightError, data: savedInsight } = await supabase
  .from('entry_insights')
  .upsert({
    entry_id: entry_id,
    insight_text: insightText,
    summary: insightText,
    insight_details: insightDetails,
    ai_generated: true,
    analysis_type: 'daily',
    status: 'success',
    sentiment_label: inferSentiment(insightText, entry.mood_score),
    model_version: 'gpt-4o-mini',
    cost_tokens_prompt: tokensUsed.prompt,
    cost_tokens_completion: tokensUsed.completion,
    processed_at: new Date().toISOString()
  }, {
    onConflict: 'entry_id'
  })
  .select()
```

**New Code:**
```typescript
const { error: insightError, data: savedInsight } = await supabase
  .from('entry_insights')
  .upsert({
    entry_id: entry_id,
    insight_text: insightText,
    summary: insightText,
    insight_details: insightDetails,
    topics: tags, // NEW: Save AI-generated tags
    ai_generated: true,
    analysis_type: 'daily',
    status: 'success',
    sentiment_label: inferSentiment(insightText, entry.mood_score),
    model_version: 'gpt-4o-mini',
    cost_tokens_prompt: tokensUsed.prompt,
    cost_tokens_completion: tokensUsed.completion,
    processed_at: new Date().toISOString()
  }, {
    onConflict: 'entry_id'
  })
  .select()
```

**Changes:**
- Add `topics: tags` to upsert payload
- No other changes needed

---

### **STEP 4: Update Fallback Handling**

**File:** `supabase/functions/ai-analyze-daily/index.ts`  
**Location:** Lines 296-304 (fallback when JSON parsing fails)

**Current Code:**
```typescript
insightData = {
  main_insight: responseText,
  what_went_well: null,
  progress_area: null,
  self_care_balance: null,
  emotional_pattern: null
}
```

**New Code:**
```typescript
insightData = {
  main_insight: responseText,
  what_went_well: null,
  progress_area: null,
  self_care_balance: null,
  emotional_pattern: null,
  tags: [] // Empty array if parsing fails
}
```

**Changes:**
- Add empty `tags: []` to fallback object
- Ensures tags field is always defined

---

## **🧪 TESTING PLAN**

### **Test Case 1: Normal Flow (AI Returns Tags)**
1. Create test entry with diary text
2. Trigger daily analysis
3. **Expected:** 
   - AI response includes `tags` array with 3-4 words
   - Tags saved to `entry_insights.topics`
   - Tags visible in Flutter app

### **Test Case 2: AI Doesn't Return Tags (Backward Compatibility)**
1. Simulate AI response without tags field
2. **Expected:**
   - Function doesn't crash
   - `topics` field saved as empty array `[]`
   - Existing functionality continues to work

### **Test Case 3: Invalid Tags Format**
1. Simulate AI response with invalid tags (non-array, non-strings)
2. **Expected:**
   - Invalid tags filtered out
   - Valid tags saved, invalid ones ignored
   - Function completes successfully

### **Test Case 4: Too Many Tags**
1. Simulate AI response with 10 tags
2. **Expected:**
   - Only first 4 tags saved
   - Function completes successfully

### **Test Case 5: JSON Parsing Failure**
1. Simulate malformed JSON response
2. **Expected:**
   - Falls back to plain text insight
   - Tags saved as empty array
   - Function doesn't crash

### **Test Case 6: Existing Insights (No Re-analysis)**
1. Check existing insights before deployment
2. **Expected:**
   - Old insights remain unchanged
   - New insights include tags
   - No data corruption

---

## **📊 COST IMPACT**

### **Token Usage:**
- **Current:** ~500 tokens per daily analysis
- **After Change:** ~520-540 tokens (adds ~20-40 tokens for tags)
- **Cost Increase:** ~$0.00001 per analysis (negligible)

### **API Call Impact:**
- No additional API calls
- Same model (gpt-4o-mini)
- Same temperature (0.7)
- Slight increase in max_tokens not needed (tags are short)

---

## **🚀 DEPLOYMENT STEPS**

### **Pre-Deployment:**
1. ✅ Review code changes
2. ✅ Test locally (if possible) or in staging
3. ✅ Backup current function code
4. ✅ Verify database field exists: `SELECT column_name FROM information_schema.columns WHERE table_name = 'entry_insights' AND column_name = 'topics';`

### **Deployment:**
```bash
# 1. Deploy updated edge function
supabase functions deploy ai-analyze-daily

# 2. Verify deployment
supabase functions list

# 3. Test with a sample entry
# (Use Supabase dashboard or test script)
```

### **Post-Deployment:**
1. Monitor logs for first few analyses:
   ```bash
   supabase functions logs ai-analyze-daily --limit 20
   ```
2. Check database for tags:
   ```sql
   SELECT entry_id, topics, insight_text 
   FROM entry_insights 
   WHERE ai_generated = true 
   AND analysis_type = 'daily'
   ORDER BY processed_at DESC 
   LIMIT 5;
   ```
3. Verify Flutter app displays tags correctly

---

## **🔄 ROLLBACK PLAN**

If issues occur:

1. **Quick Rollback:**
   ```bash
   # Revert to previous version
   git checkout HEAD~1 supabase/functions/ai-analyze-daily/index.ts
   supabase functions deploy ai-analyze-daily
   ```

2. **Data Impact:**
   - No data loss (tags are additive)
   - Old insights remain unchanged
   - New insights will have empty tags after rollback

3. **No Database Changes Needed:**
   - `topics` field remains in schema
   - Just won't be populated until fix deployed

---

## **✅ SUCCESS CRITERIA**

- [ ] AI returns tags in 95%+ of responses
- [ ] Tags saved to `entry_insights.topics` field
- [ ] Tags visible in Flutter app (history screen)
- [ ] No errors in edge function logs
- [ ] No impact on existing insights
- [ ] Cost increase < $0.0001 per analysis
- [ ] Backward compatibility maintained

---

## **📝 IMPLEMENTATION NOTES**

### **Tag Format Guidelines:**
- **Single words only** (no phrases like "work stress" → use "work" or "stress")
- **Lowercase** (normalized in code)
- **Max 20 characters** per tag
- **3-4 tags** per entry
- **Relevant themes** from the entry content

### **Why `entry_insights.topics` and not `entries.tags`?**
- ✅ Semantically correct (tags are part of AI analysis)
- ✅ Consistent with weekly insights (`top_topics`)
- ✅ Keeps AI data separate from user data
- ✅ `entries.tags` can be for user-editable tags later

### **Error Handling:**
- If tags missing → empty array (don't fail)
- If tags invalid → filter and use valid ones
- If JSON parsing fails → empty array in fallback
- Log warnings but don't throw errors

---

## **🔗 RELATED FILES**

- **Edge Function:** `supabase/functions/ai-analyze-daily/index.ts`
- **Flutter Model:** `lib/models/analytics_models.dart` (already supports topics)
- **Flutter Service:** `lib/services/ai_service.dart` (already queries topics)
- **Flutter UI:** `lib/screens/history_screen.dart` (already displays topics)
- **Database Schema:** `bc/Project3/tables_queries.md` (topics field exists)

---

## **📅 IMPLEMENTATION TIMELINE**

- **Step 1-3:** Code changes (~15 minutes)
- **Step 4:** Testing (~30 minutes)
- **Deployment:** ~5 minutes
- **Verification:** ~15 minutes
- **Total:** ~1 hour

---

## **🎯 NEXT STEPS**

1. Review this plan
2. Implement code changes (Steps 1-4)
3. Test locally/staging
4. Deploy to production
5. Monitor and verify

---

**Status:** Ready for implementation ✅  
**Risk:** Low 🟢  
**Impact:** Additive only (no breaking changes) ✅

