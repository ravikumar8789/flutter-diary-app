# **AI FEATURE IMPLEMENTATION PLAN V2.0**
**Diary Journal App - OpenAI Integration**
*Updated based on current codebase & latest DB schema*

---

## **1. EXECUTIVE DECISION: TIERED FEATURES**

### **Q: Do we need tier system first or can we integrate AI first?**

**Answer: Integrate AI first, add tiers later.**

**Reasoning:**
- Tier system is just a simple check: `if (userHasPremium) { allowFeature }`
- AI infrastructure (DB, Edge Functions, services) is independent of tiers
- We can add tier checks as simple guards in Edge Functions and Flutter code
- Existing `subscriptions` and `plans` tables are already in place
- **Implementation**: Add a helper function `_checkUserTier(userId, requiredTier)` that we can plug in later

**Recommended Approach:**
1. Build AI features for ALL users initially (daily insights = free)
2. Add tier checks later as simple boolean flags
3. This allows faster development and easier testing

---

## **2. CURRENT STATE ANALYSIS**

### **2.1 What's Already Working**
✅ **Data Sync**: All entry data syncs to Supabase (`entries`, `entry_affirmations`, `entry_priorities`, `entry_meals`, `entry_gratitude`, `entry_self_care`)  
✅ **DB Tables**: `entry_insights` and `weekly_insights` tables exist  
✅ **Infrastructure**: `HomeSummaryService` can fetch insights  
✅ **Error Logging**: Centralized `ErrorLoggingService`  
✅ **Sync Pattern**: Non-blocking sync with offline support  

### **2.2 What Needs Building**
❌ Supabase Edge Functions for AI processing  
❌ AI service layer in Flutter  
❌ Trigger mechanism (when to analyze)  
❌ AI insight display in UI  
❌ Cost tracking and logging  
❌ Prompt templates management  

---

## **3. DATABASE SCHEMA CHANGES**

### **3.1 Update `entry_insights` Table**

**Current schema** (from `tables.md`):
```sql
CREATE TABLE public.entry_insights (
  id uuid PRIMARY KEY,
  entry_id uuid REFERENCES entries(id),
  processed_at timestamptz DEFAULT now(),
  sentiment_label text CHECK (sentiment_label IN ('negative', 'neutral', 'positive')),
  sentiment_score numeric,
  topics text[] DEFAULT '{}',
  summary text,
  embedding_json jsonb,
  model_version text,
  cost_tokens_prompt integer DEFAULT 0,
  cost_tokens_completion integer DEFAULT 0,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'error')),
  error_message text
);
```

**Required additions** (already compatible, but add for clarity):
```sql
-- Add AI-specific fields if missing
ALTER TABLE public.entry_insights 
ADD COLUMN IF NOT EXISTS ai_generated BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS analysis_type TEXT CHECK (analysis_type IN ('daily', 'weekly', 'monthly')),
ADD COLUMN IF NOT EXISTS insight_text TEXT, -- Main AI-generated insight (2-3 lines)
ADD COLUMN IF NOT EXISTS key_takeaways JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS action_items JSONB DEFAULT '[]'::jsonb;

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_entry_insights_entry_id ON public.entry_insights(entry_id);
CREATE INDEX IF NOT EXISTS idx_entry_insights_status ON public.entry_insights(status);
```

### **3.2 Update `weekly_insights` Table**

**Current schema**:
```sql
CREATE TABLE public.weekly_insights (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  week_start date NOT NULL,
  mood_avg numeric,
  cups_avg numeric,
  self_care_rate numeric,
  top_topics text[],
  highlights text,
  generated_at timestamptz DEFAULT now()
);
```

**Required additions**:
```sql
-- Add AI-specific fields
ALTER TABLE public.weekly_insights 
ADD COLUMN IF NOT EXISTS week_end date,
ADD COLUMN IF NOT EXISTS ai_generated BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS mood_trend text CHECK (mood_trend IN ('improving', 'declining', 'stable', 'volatile')),
ADD COLUMN IF NOT EXISTS key_insights text[], -- AI-generated insights array
ADD COLUMN IF NOT EXISTS recommendations text[], -- AI recommendations
ADD COLUMN IF NOT EXISTS habit_correlations jsonb DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS consistency_score numeric(3,2),
ADD COLUMN IF NOT EXISTS entries_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS word_count_total integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS model_version text,
ADD COLUMN IF NOT EXISTS cost_tokens_prompt integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS cost_tokens_completion integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'error')),
ADD COLUMN IF NOT EXISTS error_message text;

-- Add unique constraint
ALTER TABLE public.weekly_insights 
ADD CONSTRAINT IF NOT EXISTS unique_user_week UNIQUE (user_id, week_start);

-- Index
CREATE INDEX IF NOT EXISTS idx_weekly_insights_user_week ON public.weekly_insights(user_id, week_start);
```

### **3.3 New Table: `ai_requests_log`**

**Purpose**: Track all AI API calls for cost monitoring and debugging

```sql
CREATE TABLE public.ai_requests_log (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  entry_id uuid REFERENCES public.entries(id), -- NULL for weekly/monthly
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  prompt_tokens integer NOT NULL DEFAULT 0,
  completion_tokens integer NOT NULL DEFAULT 0,
  total_tokens integer NOT NULL DEFAULT 0,
  cost_usd numeric(10,6) NOT NULL DEFAULT 0, -- Cost in USD
  model_used text DEFAULT 'gpt-4o-mini',
  status text DEFAULT 'success' CHECK (status IN ('success', 'error', 'rate_limited', 'timeout')),
  error_message text,
  request_duration_ms integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_ai_requests_user_id ON public.ai_requests_log(user_id);
CREATE INDEX idx_ai_requests_created_at ON public.ai_requests_log(created_at);
CREATE INDEX idx_ai_requests_analysis_type ON public.ai_requests_log(analysis_type);
CREATE INDEX idx_ai_requests_entry_id ON public.ai_requests_log(entry_id);
```

### **3.4 New Table: `ai_prompt_templates` (Optional but Recommended)**

**Purpose**: Store prompt templates for easy updates without code changes

```sql
CREATE TABLE public.ai_prompt_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  template_name text UNIQUE NOT NULL,
  system_prompt text NOT NULL,
  user_prompt_template text NOT NULL, -- With {placeholders}
  temperature numeric(3,2) DEFAULT 0.7,
  max_tokens integer DEFAULT 500,
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  version integer DEFAULT 1,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Insert default templates (see section 4.2)
```

### **3.5 Optional: `user_ai_preferences` Table**

**Purpose**: User controls for AI features (can be added later)

```sql
CREATE TABLE public.user_ai_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.users(id),
  daily_analysis_enabled boolean DEFAULT true,
  weekly_analysis_enabled boolean DEFAULT false, -- Premium feature
  monthly_analysis_enabled boolean DEFAULT false, -- Premium feature
  ai_tone_preference text DEFAULT 'supportive' CHECK (ai_tone_preference IN ('supportive', 'motivational', 'analytical')),
  max_daily_ai_requests integer DEFAULT 5,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

**Note**: This can be added later. For MVP, we can enable AI for all users by default.

---

## **4. PROMPT ENGINEERING**

### **4.1 Daily Analysis Prompt Template**

**System Prompt**:
```
You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide helpful, actionable insights. Always be supportive and non-judgmental. Keep responses concise (2-3 sentences maximum).
```

**User Prompt Template** (with placeholders):
```
User's Recent Context:
- Current mood: {mood_score}/5
- Recent topics: {recent_topics}
- Self-care completion: {self_care_summary}
- Last 3 days mood trend: {mood_trend}

Today's Entry: "{diary_text}"

Please provide a brief insight (2-3 sentences) that:
1. Acknowledges the emotional tone
2. Offers one supportive observation
3. Gently suggests one actionable next step (if applicable)

Keep it warm, specific, and under 100 words.
```

**Parameters**:
- Temperature: 0.7
- Max tokens: 200
- Model: gpt-4o-mini

### **4.2 Weekly Analysis Prompt Template**

**System Prompt**:
```
You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. Provide insightful weekly summaries that help users understand their emotional patterns and habit impacts. Focus on patterns and practical insights.
```

**User Prompt Template**:
```
Weekly Data Summary:
- Date range: {week_start} to {week_end}
- Entries written: {entries_count}/7
- Average mood: {avg_mood}/5
- Mood scores: {mood_scores}
- Self-care completion: {self_care_summary}
- Key topics mentioned: {weekly_topics}

Habit Analysis:
{habit_correlations}

Please provide:
1. Weekly mood pattern (1-2 sentences)
2. Top 2 positive influences on mood
3. One area for potential improvement
4. Two specific, actionable recommendations for next week

Keep it concise and actionable (under 150 words total).
```

**Parameters**:
- Temperature: 0.5 (more deterministic for patterns)
- Max tokens: 400
- Model: gpt-4o-mini

### **4.3 Monthly Analysis Prompt Template**

**System Prompt**:
```
You are a reflective AI assistant that helps users understand long-term trends in their wellness journey. Provide monthly summaries that highlight growth, patterns, and areas of focus. Be encouraging and forward-looking.
```

**User Prompt Template**:
```
Monthly Data Summary:
- Month: {month}
- Entries written: {entries_count}/{total_days}
- Mood trends: {mood_trends}
- Consistency: {consistency_score}%
- Key themes: {monthly_themes}

Please provide:
1. Overall month reflection (2-3 sentences)
2. Biggest growth area
3. One celebration moment
4. Focus for next month

Keep it inspiring and actionable (under 200 words).
```

---

## **5. SUPABASE EDGE FUNCTIONS**

### **5.1 Function: `ai-analyze-daily`**

**File**: `supabase/functions/ai-analyze-daily/index.ts`

**Purpose**: Analyze a single diary entry using OpenAI

**Flow**:
1. Receive: `{ entry_id, user_id }`
2. Fetch entry data from Supabase (entry + related tables)
3. Build context (recent entries, mood trends, self-care)
4. Get prompt template from DB (or use hardcoded fallback)
5. Call OpenAI API
6. Parse response and save to `entry_insights`
7. Log request to `ai_requests_log`
8. Return success/error

**Key Features**:
- Non-blocking (fire-and-forget from app)
- Error handling with retry logic
- Cost tracking
- Rate limiting (check user's daily requests)

**Authentication**: Uses Supabase service role key (secured)

### **5.2 Function: `ai-analyze-weekly`**

**File**: `supabase/functions/ai-analyze-weekly/index.ts`

**Purpose**: Generate weekly insights for a user

**Flow**:
1. Receive: `{ user_id, week_start }`
2. Fetch all entries for that week
3. Aggregate data (mood avg, topics, habits)
4. Build context from week data
5. Call OpenAI with weekly prompt
6. Parse and save to `weekly_insights`
7. Log request
8. Return success/error

**Scheduling**: Can be triggered manually or via cron (Sunday night)

### **5.3 Function: `ai-analyze-monthly`** (Future)

Similar structure to weekly, but for monthly data.

---

## **6. FLUTTER INTEGRATION**

### **6.1 New Service: `ai_service.dart`**

**Location**: `lib/services/ai_service.dart`

**Responsibilities**:
- Trigger AI analysis after entry saves
- Fetch AI insights for display
- Handle errors and fallbacks
- Check user permissions (tiers - can be added later)

**Key Methods**:
```dart
class AIService {
  final SupabaseClient _supabase;
  
  // Trigger daily analysis (non-blocking)
  Future<void> triggerDailyAnalysis(String entryId);
  
  // Fetch daily insight for entry
  Future<EntryInsight?> getDailyInsight(String entryId);
  
  // Trigger weekly analysis
  Future<void> triggerWeeklyAnalysis(String userId, DateTime weekStart);
  
  // Fetch weekly insight
  Future<WeeklyInsight?> getWeeklyInsight(String userId, DateTime weekStart);
  
  // Build context for AI (helper)
  Future<Map<String, dynamic>> _buildDailyContext(Entry entry);
}
```

### **6.2 Integration Points**

#### **A. Entry Save Trigger**
**Location**: `lib/services/entry_service.dart`

After entry sync succeeds:
```dart
// In syncEntry or saveDiaryText (after successful sync)
if (entry.diaryText != null && entry.diaryText!.trim().length > 50) {
  // Trigger AI analysis (non-blocking, deduplicated)
  _aiService.triggerDailyAnalysis(entry.id).catchError((e) {
    // Log but don't block user
    ErrorLoggingService.logLowError(...);
  });
}
```

#### **B. Home Screen AI Insight Card**
**Location**: `lib/screens/home_screen.dart`

Use the fallback ladder from `ai_plan_1.md`:
1. Today's `entry_insights.insight_text`
2. Yesterday's insight
3. This week's闭上眼睛 `weekly_insights.highlights`
4. Habit-based nudge
5. Streak-based nudge
6. Static "start" tip

**Integration**: Add `_fetchAiInsight()` to `HomeSummaryService`

#### **C. Entry Detail Screen**
**Location**: `lib/screens/[entry_detail_screen]` (if exists)

Show AI insight below entry content (if available).

---

## **7. DATA FLOW ARCHITECTURE**

### **7.1 Daily Analysis Flow**

```
User writes entry
    ↓
Entry saved to local DB
    ↓
Sync to Supabase (non-blocking)
    ↓
[After sync success]
    ↓
Flutter: triggerDailyAnalysis(entryId)
    ↓
Supabase Edge Function: ai-analyze-daily
    ↓
Edge Function fetches entry + context from DB
    ↓
Edge Function calls OpenAI API
    ↓
Edge Function parses response
    ↓
Edge Function saves to entry_insights table
    ↓
Edge Function logs to ai_requests_log
    ↓
[Done - user sees insight on next screen load]
```

### **7.2 Weekly Analysis Flow**

```
Sunday 11 PM (or manual trigger)
    ↓
Supabase Cron Job (or Flutter trigger)
    ↓
Edge Function: ai-analyze-weekly
    ↓
Edge Function fetches week's entries
    ↓
Edge Function aggregates data
    ↓
Edge Function calls OpenAI
    ↓
Edge Function saves to weekly_insights
    ↓
User sees weekly summary on Home screen
```

---

## **8. COST ESTIMATION & MONITORING**

### **8.1 Cost Per Request (GPT-4o-mini)**
- Input: $0.15 per 1M tokens
- Output: $0.60 per 1M tokens
- Daily insight: ~500 tokens input, ~100 tokens output = **$0.00009 per request**
- Weekly insight: ~2000 tokens input, ~300 tokens output = **$0.00048 per request**

### **8.2 Monthly Cost Estimate**
- **Free tier**: 1 daily insight/day = 30 × $0.00009 = **$0.0027/month per user**
- **Premium**: + 1 weekly insight/week = 4 × $0.00048 = **$0.00192/month extra**
- **1000 users**: ~$2.70/month (free) + ~$1.92/month (premium users)

### **8.3 Cost Tracking**
- All requests logged in `ai_requests_log`
- Monthly cost view: `SELECT SUM(cost_usd) FROM ai_requests_log WHERE user_id = ? AND created_at >= ?`
- Alert threshold: Set up monitoring for unexpected spikes

---

## **9. IMPLEMENTATION PHASES**

### **Phase 1: Foundation (Week 1)**
1. ✅ Update DB schema (add missing columns)
2. ✅ Create `ai_requests_log` table
3. ✅ Create `ai_prompt_templates` table + insert defaults
4. ✅ Set up Supabase Edge Functions project structure

### **Phase 2: Daily Analysis (Week 2)**
1. ✅ Implement `ai-analyze-daily` Edge Function
2. ✅ Test OpenAI integration
3. ✅ Create `AIService` in Flutter
4. ✅ Integrate trigger after entry save
5. ✅ Update Home screen to show daily insights

### **Phase 3: Weekly Analysis (Week 3)**
1. ✅ Update `weekly_insights` schema
2. ✅ Implement `ai-analyze-weekly` Edge Function
3. ✅ Add weekly analysis trigger (manual first, cron later)
4. ✅ Update Home screen AI insight card with fallback ladder

### **Phase 4: Polish & Monitoring (Week 4)**
1. ✅ Error handling & fallbacks
2. ✅ Cost monitoring dashboard
3. ✅ User preferences (optional)
4. ✅ Performance optimization

### **Phase 5: Tiers (Later)**
1. ✅ Add tier checks in Edge Functions
2. ✅ Add tier checks in Flutter
3. ✅ Update UI to show premium badges

---

## **10. ERROR HANDLING & FALLBACKS**

### **10.1 When AI Fails**
- **Network error**: Retry 3 times with exponential backoff
- **API error**: Log to `ai_requests_log` with error status
- **Timeout**: Use fallback (basic sentiment analysis or show static message)
- **Rate limit**: Queue request, process later

### **10.2 Fallback Strategy**
If AI analysis fails:
1. Show "Insight coming soon" message
2. Use basic sentiment (positive/negative word count)
3. Show habit-based nudge instead
4. Never block user from using the app

---

## **11. SECURITY & PRIVACY**

### **11.1 Data Protection**
- ✅ All AI calls via Edge Functions (API key secured on server)
- ✅ No user data sent to OpenAI beyond what's needed
- ✅ User can opt-out via preferences
- ✅ Data encrypted in transit (HTTPS)

### **11.2 Compliance**
- ✅ Clear privacy policy about AI usage
- ✅ User controls (can disable AI features)
- ✅ No persistent storage by OpenAI (stateless requests)

---

## **12. TESTING STRATEGY**

### **12.1 Edge Function Testing**
- Unit tests for prompt building
- Integration tests with mock OpenAI responses
- Test error scenarios (API down, rate limit, etc.)

### **12.2 Flutter Testing**
- Test AI service methods
- Test Home screen insight display
- Test error handling and fallbacks

### **12.3 Cost Testing**
- Monitor actual costs in staging
- Set up alerts for unexpected spikes
- Test rate limiting

---

## **13. MONITORING & ALERTS**

### **13.1 Key Metrics**
- AI request success rate (target: >95%)
- Average response time (target: <3 seconds)
- Cost per user per month (target: <$0.01)
- Error rate (target: <5%)

### **13.2 Alerts**
- Error rate > 10% for 1 hour
- Cost spike > 2x average
- OpenAI API downtime
- Edge Function timeout > 10 seconds

---

## **14. OPEN QUESTIONS & DECISIONS NEEDED**

1. **When to trigger daily analysis?**
   - Immediately after entry save? ✅ (Recommended - non-blocking)
   - On-demand when user views entry?
   - Scheduled batch at night?

2. **Rate limiting?**
   - Per user per day? (Recommended: 5 daily, 1 weekly)
   - Global API rate limits?

3. **Weekly analysis timing?**
   - Sunday 11 PM automatic?
   - Manual trigger only?
   - Both?

4. **User preferences?**
   - Build now or later?
   - MVP: All users get AI (can add preferences later)

---

## **15. FILES TO CREATE/MODIFY**

### **New Files**:
1. `supabase/functions/ai-analyze-daily/index.ts`
2. `supabase/functions/ai-analyze-weekly/index.ts`
3. `lib/services/ai_service.dart`
4. `lib/models/ai_models.dart` (if needed, or extend existing)

### **Modified Files**:
1. `lib/services/entry_service.dart` (add AI trigger)
2. `lib/services/home_summary_service.dart` (add AI insight fetch)
3. `lib/screens/home_screen.dart` (update AI insight card)
4. DB schema (SQL migrations)

---

## **16. NEXT STEPS**

1. **Review this plan** with team
2. **Decide on open questions** (section 14)
3. **Set up Supabase Edge Functions** project
4. **Create DB migrations** for schema changes
5. **Start Phase 1** implementation

---

**Last Updated**: [Current Date]  
**Status**: Ready for Implementation  
**Estimated Timeline**: 4 weeks for full MVP

