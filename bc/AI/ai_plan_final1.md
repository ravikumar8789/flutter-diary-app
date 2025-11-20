# AI Feature Implementation Plan - Final Version

## **Overview**

This document outlines the complete implementation plan for the hybrid AI analysis system with enhanced insights generation.

---

## **1. SYSTEM ARCHITECTURE**

### **1.1 Hybrid Trigger Approach**

**Primary Trigger: Midnight Scheduled Analysis**
- Runs daily at midnight (user's timezone)
- Analyzes yesterday's entry if all 4 sections are complete
- Ensures complete data analysis

**Backup Trigger: Completion-Based Immediate Analysis**
- Triggers when user completes all 4 sections today
- Queued with 5-second delay to prevent race conditions
- Provides immediate feedback as bonus

**Result:**
- Complete data when possible
- Immediate analysis as bonus
- Clear user expectations

---

## **2. DATABASE CHANGES**

### **2.1 New Table: `homescreen_insights`**

**Purpose:** Store 5 concise insights (2-3 lines each) for home screen carousel display

**Schema:**
```sql
CREATE TABLE public.homescreen_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_id uuid NOT NULL REFERENCES public.entries(id),
  user_id uuid NOT NULL REFERENCES public.users(id),
  insight_1 text NOT NULL,  -- How they are improving
  insight_2 text NOT NULL,  -- How they are lacking
  insight_3 text NOT NULL,  -- What is best thing
  insight_4 text NOT NULL,  -- What can be achieved
  insight_5 text NOT NULL,  -- Why they may be lacking (if progress low)
  generated_at timestamp with time zone DEFAULT now(),
  status text DEFAULT 'success' CHECK (status IN ('pending', 'success', 'error')),
  error_message text,
  CONSTRAINT homescreen_insights_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id),
  CONSTRAINT unique_entry_insights UNIQUE (entry_id)
);

CREATE INDEX idx_homescreen_insights_user_id ON public.homescreen_insights(user_id);
CREATE INDEX idx_homescreen_insights_entry_id ON public.homescreen_insights(entry_id);
CREATE INDEX idx_homescreen_insights_generated_at ON public.homescreen_insights(generated_at DESC);
```

**Why Separate Table:**
- Optimized for home screen display (5 specific insights)
- Different from `entry_insights` (which has full analysis)
- Allows quick retrieval of last 7 insights for carousel

---

### **2.2 New Table: `ai_analysis_queue`**

**Purpose:** Queue completion-based analysis requests with delay

**Schema:**
```sql
CREATE TABLE public.ai_analysis_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_id uuid NOT NULL REFERENCES public.entries(id),
  user_id uuid NOT NULL REFERENCES public.users(id),
  created_at timestamp with time zone DEFAULT now(),
  processed boolean DEFAULT false,
  processed_at timestamp with time zone,
  retry_count integer DEFAULT 0,
  max_retries integer DEFAULT 3,
  error_message text,
  CONSTRAINT ai_analysis_queue_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.entries(id)
);

CREATE INDEX idx_ai_queue_unprocessed ON public.ai_analysis_queue(processed, created_at) WHERE processed = false;
CREATE INDEX idx_ai_queue_entry_id ON public.ai_analysis_queue(entry_id);
```

---

### **2.3 New Function: `check_entry_completion(entry_uuid)`**

**Purpose:** Check if entry has all 4 sections complete

**Logic:**
1. **Morning Ritual:** `entry_affirmations` has items OR `entry_priorities` has items
2. **Wellness:** `entry_meals` has any meal/water OR `entry_self_care` has any activity
3. **Gratitude:** `entry_gratitude` has items
4. **Diary:** `entries.diary_text` exists AND length >= 50 chars

**Returns:** `boolean` (true if all 4 complete)

---

### **2.4 New Function: `queue_ai_analysis_on_completion()`**

**Purpose:** Trigger function for database triggers

**Logic:**
1. Get `entry_id` from trigger context
2. Check completion using `check_entry_completion()`
3. If complete:
   - Check if insight already exists
   - If not, insert into `ai_analysis_queue`
   - Prevent duplicates

**Triggers on:**
- `entries` (on diary_text update)
- `entry_affirmations` (on insert/update)
- `entry_priorities` (on insert/update)
- `entry_meals` (on insert/update)
- `entry_gratitude` (on insert/update)
- `entry_self_care` (on insert/update)

---

## **3. EDGE FUNCTIONS**

### **3.1 Modify: `ai-analyze-daily/index.ts`**

**Current Behavior:**
- Accepts `entry_id` and `user_id`
- Analyzes entry and saves to `entry_insights`

**New Behavior:**
1. **Fetch Entry Data:**
   - Entry with all 4 sections
   - Past 5 days entries (if available) for context

2. **Enhanced Prompt:**
   - System prompt: Focus on generating 5 specific insights
   - User prompt: Include past 5 days data for comparison
   - Request 5 insights:
     - How they are improving
     - How they are lacking
     - What is best thing
     - What can be achieved
     - Why they may be lacking (if progress low)

3. **Save Results:**
   - Save full analysis to `entry_insights` (existing)
   - Save 5 insights to `homescreen_insights` (new)
   - Both linked to same `entry_id`

4. **Completion Check:**
   - Verify all 4 sections complete before analysis
   - Return early if incomplete

---

### **3.2 New: `process-ai-queue/index.ts`**

**Purpose:** Process queued analysis requests (backup trigger)

**Flow:**
1. Fetch entries from `ai_analysis_queue` where:
   - `processed = false`
   - `created_at < now() - 5 seconds` (delay check)
   - `retry_count < max_retries`

2. For each entry:
   - Verify completion again (double-check)
   - Check if insight already exists
   - If complete and no insight → call `ai-analyze-daily`
   - Mark as processed
   - Handle errors (increment retry_count)

3. Run every 15 seconds (scheduled)

---

### **3.3 New: `scheduled-daily-analysis/index.ts`**

**Purpose:** Midnight scheduled analysis (primary trigger)

**Flow:**
1. Get all active users (or batch process)
2. For each user:
   - Get user's timezone from `users.timezone`
   - Calculate yesterday's date in user's timezone
   - Find yesterday's entry
   - Check if all 4 sections complete
   - If complete and no insight exists:
     - Call `ai-analyze-daily` for that entry
   - If incomplete:
     - Log (optional: could notify user)

3. Scheduling:
   - Option A: Supabase pg_cron (if available)
   - Option B: External cron (GitHub Actions, etc.) → calls this function

---

## **4. PROMPT ENGINEERING**

### **4.1 Enhanced Daily Analysis Prompt**

**System Prompt:**
```
You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide helpful, actionable insights. Always be supportive and non-judgmental. 

Your task is to generate exactly 5 insights (2-3 lines each) based on the user's daily entry and their progress over the past 5 days. Each insight should be specific, actionable, and encouraging.
```

**User Prompt Template:**
```
User's Daily Entry Context:
- Current mood: {mood_score}/5
- Entry date: {entry_date}
- Today's diary text: "{diary_text}"
- Morning ritual completed: {morning_ritual_status}
- Wellness activities: {wellness_summary}
- Gratitude items: {gratitude_count}

Past 5 Days Context (if available):
- Mood trend: {mood_trend}
- Consistency: {consistency_score}%
- Entries completed: {entries_count}/5
- Key patterns: {patterns}
- Previous insights: {previous_insights_summary}

Please generate exactly 5 insights (2-3 lines each):

1. **Improvement Insight:** How is the user improving? What positive changes or growth do you notice compared to past days?

2. **Lacking Insight:** What areas is the user lacking or struggling with? Be gentle and constructive.

3. **Best Thing Insight:** What is the best thing happening in their life right now? What should they celebrate?

4. **Achievement Insight:** What can they achieve? What realistic goals or next steps can they take?

5. **Progress Insight:** If progress is low, why might they be lacking? What barriers or challenges might be preventing growth? If progress is good, what is working well?

Keep each insight:
- 2-3 lines maximum
- Specific to their data
- Actionable and encouraging
- Non-judgmental
- Based on comparison with past 5 days when available
```

**Response Format:**
```json
{
  "insight_1": "...",
  "insight_2": "...",
  "insight_3": "...",
  "insight_4": "...",
  "insight_5": "...",
  "full_analysis": "..."
}
```

---

## **5. FLUTTER IMPLEMENTATION**

### **5.1 Modify: `lib/services/entry_service.dart`**

**Change:**
- **Remove** lines 103-104 (immediate AI trigger)
- Keep all sync logic unchanged
- Database triggers handle completion-based queueing

**Before:**
```dart
if (text.trim().length >= 50) {
  _aiService.triggerDailyAnalysis(updatedEntry.id);
}
```

**After:**
```dart
// AI analysis triggered by database completion check
// No immediate trigger needed
```

---

### **5.2 Modify: `lib/services/ai_service.dart`**

**Add Methods:**

1. **`getHomescreenInsights(userId, limit = 7)`**
   - Fetches last 7 insights from `homescreen_insights` table
   - Returns list of 5-insight sets for carousel

2. **`getTodayInsightStatus(userId)`**
   - Returns status: `available`, `pending`, `incomplete`, `none`
   - Includes message for UI

3. **`checkEntryCompletion(entryId)`**
   - Calls database function to check completion
   - Returns completion status

**Modify:**
- `getDailyInsight()` - Add fallback to most recent if today's doesn't exist

---

### **5.3 New: `lib/services/homescreen_insights_service.dart`**

**Purpose:** Service for fetching and managing homescreen insights

**Methods:**
- `getRecentHomescreenInsights(userId, limit = 7)`
- `getInsightSet(entryId)` - Get 5 insights for a specific entry
- `getTodayInsightSet(userId)` - Get today's insight set if available

---

### **5.4 Modify: `lib/widgets/insight_carousel.dart`**

**Current:** Shows single insight text

**New:** Show 5 insights per entry in carousel

**Structure:**
- Each card shows one of the 5 insights
- Rotate through all 5 insights for each entry
- Show entry date and insight category (Improvement, Lacking, Best Thing, etc.)
- Total: 7 entries × 5 insights = 35 possible cards

**UI:**
- Card shows: Category badge + Insight text + Date
- Auto-rotate every 5 seconds
- Manual swipe navigation
- Dot indicators for entries (not individual insights)

---

### **5.5 Modify: `lib/screens/analytics_screen.dart`**

**Add Status Messages:**

1. **Today's Entry:**
   - "Today's insight will be generated at midnight"
   - "Analysis in progress..." (if queued)
   - "Complete all 4 sections to get today's insight" (if incomplete)

2. **Yesterday's Entry:**
   - Show analysis if available
   - "Yesterday's entry incomplete - no analysis available" (if incomplete)

3. **Most Recent Analysis:**
   - Always show most recent available insight
   - Label: "Last analysis: [date]"

---

### **5.6 Modify: `lib/widgets/daily_insights_timeline.dart`**

**Add Status Badges:**
- ✅ Complete analysis available
- ⏳ Pending (entry complete, analysis queued)
- ⚠️ Incomplete (entry missing sections)
- ❌ No entry

**Show 5 Insights:**
- Expandable card shows all 5 insights
- Categories: Improvement, Lacking, Best Thing, Achievement, Progress

---

### **5.7 Modify: `lib/models/analytics_models.dart`**

**Add Models:**

1. **`HomescreenInsightSet`**
   ```dart
   class HomescreenInsightSet {
     final String id;
     final String entryId;
     final DateTime entryDate;
     final String insight1; // Improvement
     final String insight2; // Lacking
     final String insight3; // Best Thing
     final String insight4; // Achievement
     final String insight5; // Progress
     final DateTime generatedAt;
   }
   ```

2. **`InsightStatus`**
   ```dart
   enum InsightStatus {
     available,
     pending,
     incomplete,
     none
   }
   ```

3. **`DailyInsightStatus`**
   ```dart
   class DailyInsightStatus {
     final InsightStatus status;
     final HomescreenInsightSet? insightSet;
     final DateTime? entryDate;
     final String message;
   }
   ```

---

### **5.8 Modify: `lib/providers/home_summary_provider.dart`**

**Add Providers:**

1. **`homescreenInsightsProvider`**
   - Fetches last 7 insight sets for carousel

2. **`todayInsightStatusProvider`**
   - Returns status and message for today

3. **`entryCompletionProvider`**
   - Tracks completion progress for today's entry

---

## **6. DATA FLOW**

### **6.1 User Completes All 4 Sections**

1. User saves last section → Syncs to Supabase
2. Database trigger fires → Checks completion
3. If complete → Inserts into `ai_analysis_queue`
4. Queue processor (runs every 15s) → Picks up after 5s delay
5. Calls `ai-analyze-daily` → Generates 5 insights
6. Saves to `entry_insights` + `homescreen_insights`
7. Home screen updates → Shows new insights

### **6.2 Midnight Scheduled Analysis**

1. Scheduled function runs at midnight (user timezone)
2. Gets yesterday's entry for each user
3. Checks completion
4. If complete → Calls `ai-analyze-daily`
5. Saves insights
6. User sees analysis next morning

### **6.3 Home Screen Display**

1. App loads → Fetches last 7 insight sets
2. Carousel displays → Rotates through all insights
3. Each entry shows 5 insights → User can swipe through
4. Shows status → "Today's insight available" or "Will be generated at midnight"

---

## **7. TESTING STRATEGY**

### **7.1 Database Testing**

- [ ] Completion check function works correctly
- [ ] Triggers fire on all 5 tables
- [ ] Queue prevents duplicates
- [ ] 5-second delay works
- [ ] Homescreen insights table stores correctly

### **7.2 Edge Function Testing**

- [ ] `ai-analyze-daily` generates 5 insights correctly
- [ ] Past 5 days data is included when available
- [ ] `process-ai-queue` processes queue correctly
- [ ] `scheduled-daily-analysis` runs at midnight
- [ ] Error handling works

### **7.3 Flutter Testing**

- [ ] Home screen carousel shows 5 insights per entry
- [ ] Status messages display correctly
- [ ] Analytics screen shows most recent insight
- [ ] Completion indicators work
- [ ] Timeline shows all 5 insights

---

## **8. DEPLOYMENT CHECKLIST**

### **8.1 Database Migrations**

1. Create `homescreen_insights` table
2. Create `ai_analysis_queue` table
3. Create `check_entry_completion()` function
4. Create `queue_ai_analysis_on_completion()` function
5. Create triggers on all 5 tables

### **8.2 Edge Functions**

1. Deploy modified `ai-analyze-daily`
2. Deploy new `process-ai-queue`
3. Deploy new `scheduled-daily-analysis`
4. Set up scheduled execution (cron)

### **8.3 Flutter Updates**

1. Update `entry_service.dart` (remove immediate trigger)
2. Update `ai_service.dart` (add new methods)
3. Create `homescreen_insights_service.dart`
4. Update `insight_carousel.dart` (show 5 insights)
5. Update `analytics_screen.dart` (add status messages)
6. Update models and providers

### **8.4 Testing**

1. Test completion check
2. Test queue processing
3. Test midnight scheduled analysis
4. Test home screen carousel
5. Test analytics screen

---

## **9. ROLLBACK PLAN**

If issues occur:

1. **Disable triggers:** Drop trigger functions
2. **Revert Flutter:** Restore immediate trigger in `entry_service.dart`
3. **Keep tables:** Don't delete, just stop using
4. **Monitor:** Check error logs

---

## **10. FUTURE ENHANCEMENTS**

1. **Weekly Insights:** Similar 5-insight format
2. **Monthly Insights:** Aggregate insights
3. **Insight Categories:** Filter by type (improvement, lacking, etc.)
4. **User Preferences:** Customize which insights to show
5. **Insight History:** View all insights for a specific entry

---

## **11. COST CONSIDERATIONS**

**OpenAI API Costs:**
- Daily analysis: ~1,000 tokens per entry
- 5 insights generation: ~200 tokens per insight
- Total: ~2,000 tokens per complete entry
- Estimated cost: $0.001 per entry

**Optimization:**
- Only analyze complete entries
- Cache past 5 days data
- Batch process at midnight

---

## **12. SUCCESS METRICS**

1. **Analysis Coverage:** % of complete entries analyzed
2. **User Engagement:** Time spent viewing insights
3. **Completion Rate:** % of entries with all 4 sections
4. **Error Rate:** Failed analyses / total attempts
5. **User Satisfaction:** Feedback on insight quality

---

**End of Implementation Plan**

