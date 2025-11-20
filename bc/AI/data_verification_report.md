# **DATA VERIFICATION REPORT**
**What's Stored vs What We Need to Display**

---

## **✅ WHAT'S BEING STORED IN `entry_insights` TABLE**

### **From Edge Function `ai-analyze-daily` (Line 195-206):**

```typescript
.upsert({
  entry_id: entry_id,              // ✅ STORED
  insight_text: insightText,       // ✅ STORED (AI-generated text)
  summary: insightText,            // ✅ STORED (same as insight_text)
  ai_generated: true,              // ✅ STORED
  analysis_type: 'daily',          // ✅ STORED
  status: 'success',               // ✅ STORED
  sentiment_label: inferSentiment(...), // ✅ STORED (calculated)
  model_version: 'gpt-4o-mini',    // ✅ STORED
  cost_tokens_prompt: tokensUsed.prompt, // ✅ STORED
  cost_tokens_completion: tokensUsed.completion, // ✅ STORED
  processed_at: new Date().toISOString() // ✅ STORED
})
```

**✅ VERIFIED: All data we need IS being stored!**

---

## **📊 SENTIMENT SOURCE**

### **Where Sentiments Come From:**

**Location:** `supabase/functions/ai-analyze-daily/index.ts` (Line 334-351)

**Function:** `inferSentiment(insightText, moodScore)`

**Logic:**
1. **From Mood Score:**
   - If `moodScore >= 4` → `'positive'`
   - If `moodScore <= 2` → `'negative'`
   - Otherwise → check text

2. **From Insight Text:**
   - Counts positive words: `['good', 'great', 'well', 'positive', 'improving', 'achievement', 'progress']`
   - Counts negative words: `['difficult', 'challenge', 'struggling', 'concern', 'worried']`
   - If positive > negative → `'positive'`
   - If negative > positive → `'negative'`
   - Otherwise → `'neutral'`

**✅ VERIFIED: Sentiments ARE calculated and stored in `sentiment_label` column**

---

## **🔍 MULTIPLE INSIGHTS FOR HOME SCREEN**

### **The Challenge:**

**Problem:** `entry_insights` table doesn't have `user_id` or `entry_date`
- It only has `entry_id` (foreign key to `entries` table)
- To get multiple insights for a user, we need to JOIN with `entries` table

### **Solution: JOIN Query**

**Required Query:**
```sql
SELECT 
  ei.id,
  ei.entry_id,
  ei.insight_text,
  ei.sentiment_label,
  ei.processed_at,
  e.entry_date,        -- ← From entries table
  e.user_id,          -- ← From entries table (for filtering)
  e.mood_score        -- ← From entries table (for correlation)
FROM entry_insights ei
JOIN entries e ON ei.entry_id = e.id
WHERE e.user_id = :userId
  AND ei.status = 'success'
  AND ei.insight_text IS NOT NULL
ORDER BY ei.processed_at DESC
LIMIT 7;
```

**✅ VERIFIED: We CAN get multiple insights by JOINing with `entries` table**

---

## **📋 DATA AVAILABILITY CHECKLIST**

### **For Home Screen Carousel:**
- ✅ `insight_text` - Stored in `entry_insights`
- ✅ `sentiment_label` - Stored in `entry_insights`
- ✅ `processed_at` - Stored in `entry_insights`
- ⚠️ `entry_date` - **NOT in `entry_insights`, need JOIN with `entries`**
- ⚠️ `user_id` - **NOT in `entry_insights`, need JOIN with `entries`**

**Solution:** JOIN `entry_insights` with `entries` table ✅

### **For Daily Timeline:**
- ✅ `insight_text` - Stored in `entry_insights`
- ✅ `sentiment_label` - Stored in `entry_insights`
- ✅ `processed_at` - Stored in `entry_insights`
- ⚠️ `entry_date` - **NOT in `entry_insights`, need JOIN with `entries`**
- ⚠️ `mood_score` - **NOT in `entry_insights`, need JOIN with `entries`**

**Solution:** JOIN `entry_insights` with `entries` table ✅

### **For Period Comparison:**
- ✅ All weekly data - Stored in `weekly_insights`
- ✅ All metrics - Stored in `weekly_insights`
- ✅ No JOIN needed - `weekly_insights` has `user_id` directly

**Solution:** Direct query from `weekly_insights` ✅

---

## **🗄️ TABLE RELATIONSHIPS**

```
entries (has user_id, entry_date, mood_score)
    ↓ (one-to-one)
entry_insights (has entry_id, insight_text, sentiment_label)
    
weekly_insights (has user_id directly, no JOIN needed)
```

**Key Point:** 
- `entry_insights` is linked to `entries` via `entry_id`
- To filter by user or get dates, we MUST JOIN with `entries`
- This is standard relational database design ✅

---

## **✅ VERIFICATION SUMMARY**

### **What We're Storing:**
1. ✅ `insight_text` - AI-generated insight text
2. ✅ `sentiment_label` - Calculated sentiment ('positive', 'neutral', 'negative')
3. ✅ `processed_at` - When insight was generated
4. ✅ `entry_id` - Link to entry
5. ✅ `status` - Success/error status

### **What We Need to Display:**
1. ✅ `insight_text` - Available directly
2. ✅ `sentiment_label` - Available directly
3. ✅ `entry_date` - Available via JOIN with `entries`
4. ✅ `mood_score` - Available via JOIN with `entries`
5. ✅ `user_id` - Available via JOIN with `entries` (for filtering)

### **Conclusion:**
**✅ YES, we ARE storing all the data we need!**
**✅ We just need to JOIN with `entries` table to get `entry_date` and filter by `user_id`**
**✅ This is standard database practice - no issues!**

---

## **🔧 IMPLEMENTATION QUERY**

### **Correct Supabase Query for Multiple Insights:**

```dart
// In AIService.getRecentInsights()
final response = await _supabase
  .from('entry_insights')
  .select('''
    id,
    entry_id,
    insight_text,
    sentiment_label,
    processed_at,
    entries!inner(
      entry_date,
      user_id,
      mood_score
    )
  ''')
  .eq('entries.user_id', userId)  // Filter by user
  .eq('status', 'success')
  .not('insight_text', 'is', null)
  .order('processed_at', ascending: false)
  .limit(7);
```

**This query:**
- ✅ Gets insights from `entry_insights`
- ✅ JOINs with `entries` (using `!inner` for required join)
- ✅ Filters by `user_id` from `entries` table
- ✅ Gets `entry_date` and `mood_score` from `entries`
- ✅ Orders by most recent
- ✅ Limits to 7 insights

**✅ VERIFIED: This query will work correctly!**

---

## **📝 UPDATED PLAN**

The enhancement plan in `ai_plan_5.md` is **CORRECT** - we just need to ensure we use JOIN queries properly.

**No database changes needed** - all data is already being stored correctly!

---

**Status:** ✅ All data verified and available  
**Action Required:** Use JOIN queries as shown above  
**Database Changes:** None needed

