# **COMPREHENSIVE AI INSIGHTS SYSTEM REDESIGN - IMPLEMENTATION PLAN**

## **OVERVIEW**
Complete redesign of AI insights system to implement:
- **Yesterday's Insight** (single card, not 5-insight carousel)
- **Batch Processing** (timezone-aware scheduled analysis)
- **Weekly Analysis** (automated Monday morning)
- **Monthly Analysis** (automated 1st of month)
- **Lightweight Architecture** (removed complexity)

---

## **PHASE 1: DATABASE CHANGES**

### **1.1 DELETE Operations**

#### **Delete `homescreen_insights` Table**
- **Reason**: No longer needed - single insight replaces 5-insight system
- **Impact**: All existing 5-insight data will be lost
- **Migration**: Not needed - new system doesn't use this data
- **SQL**: `DROP TABLE IF EXISTS public.homescreen_insights CASCADE;`

#### **Delete Old `ai_analysis_queue` Table**
- **Reason**: Replaced with new `analysis_queue` structure
- **Impact**: Pending queue items will be lost (acceptable - new system will repopulate)
- **SQL**: `DROP TABLE IF EXISTS public.ai_analysis_queue CASCADE;`

#### **Remove Columns from `entry_insights`**
- **Remove**: `key_takeaways` (jsonb)
- **Remove**: `action_items` (jsonb)
- **Reason**: Simplified to single summary field
- **SQL**: 
  ```sql
  ALTER TABLE public.entry_insights 
  DROP COLUMN IF EXISTS key_takeaways,
  DROP COLUMN IF EXISTS action_items;
  ```

---

### **1.2 CREATE Operations**

#### **Create `analysis_queue` Table**
- **Purpose**: Centralized queue for all analysis types (daily, weekly, monthly)
- **Features**: 
  - Status tracking (pending, processing, completed, failed)
  - Retry logic (max 3 attempts)
  - Timezone-aware target dates
  - Error tracking
- **Indexes**: 
  - `idx_analysis_queue_pending` on (status, next_retry_at) WHERE status IN ('pending', 'failed')
  - `idx_analysis_queue_user_type` on (user_id, analysis_type)

#### **Create `monthly_insights` Table**
- **Purpose**: Store monthly analysis results
- **Fields**: 
  - month_start (date)
  - mood_avg, entries_count, word_count_total
  - top_topics (text[])
  - monthly_highlights (text)
  - growth_areas, achievements, next_month_goals (text[])
  - consistency_score, habit_analysis (jsonb)
  - mood_trend_monthly (text)
- **Constraints**: Unique (user_id, month_start)

---

### **1.3 MODIFY Operations**

#### **Verify `users.timezone` Field**
- **Check**: Ensure `timezone` column exists (should already exist)
- **Action**: If missing, add: `ALTER TABLE public.users ADD COLUMN IF NOT EXISTS timezone text;`
- **Default**: Set default timezone for existing users (e.g., 'UTC' or 'America/New_York')

#### **Add Indexes for Performance**
- **Index 1**: `idx_users_timezone` on `users(timezone)`
- **Index 2**: `idx_entries_date_user` on `entries(user_id, entry_date)`
- **Index 3**: `idx_analysis_queue_pending` (already mentioned above)

---

## **PHASE 2: EDGE FUNCTIONS CHANGES**

### **2.1 MODIFY: `ai-analyze-daily/index.ts`**

#### **Current Behavior:**
- Generates 5 insights (insight_1 through insight_5)
- Saves to both `entry_insights` and `homescreen_insights`
- Complex prompt requesting 5 different insights
- Returns JSON with 5 insights

#### **New Behavior:**
- Generate **single 2-3 line summary**
- Save only to `entry_insights.summary` (and `insight_text`)
- Simplified prompt focused on comprehensive daily analysis
- Remove all `homescreen_insights` logic
- Remove 5-insight parsing logic

#### **Changes Required:**

**REMOVE:**
- Lines 190-225: 5-insight prompt generation
- Lines 264-277: 5-insight JSON parsing
- Lines 323-355: `homescreen_insights` save logic
- Lines 379-385: 5-insight response structure
- Function: `parseInsightsFromText()` (lines 562-578)

**MODIFY:**
- **Prompt** (lines 191-226): Change to single comprehensive insight
  ```typescript
  const systemPrompt = 'You are a compassionate AI wellness assistant. Analyze the user\'s complete day and provide a thoughtful 2-3 sentence insight that captures the emotional tone, key patterns, and one supportive observation. Be warm and encouraging.';
  
  const userPrompt = `Yesterday's Entry Analysis:
  - Date: ${entry.entry_date}
  - Mood: ${entry.mood_score || 'N/A'}/5
  - Diary: "${entry.diary_text.substring(0, 1000)}"
  - Self-care: ${selfCareSummary}
  - Wellness: ${wellnessSummary}
  - Gratitude items: ${gratitudeCount}
  
  Past 5 Days Context:
  - Mood trend: ${moodTrend}
  - Consistency: ${consistencyScore}%
  
  Provide a 2-3 sentence insight that:
  1. Acknowledges the emotional tone of the day
  2. Highlights one key pattern or positive observation
  3. Offers gentle encouragement or a supportive note
  
  Keep it warm, specific, and under 100 words.`;
  ```

- **Save Logic** (lines 285-301): Simplify to single summary
  ```typescript
  await supabase
    .from('entry_insights')
    .upsert({
      entry_id: entry_id,
      insight_text: insightText,  // Full analysis
      summary: insightText,        // Same for card display
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
  ```

- **Response** (lines 374-390): Return single insight
  ```typescript
  return new Response(
    JSON.stringify({
      success: true,
      entry_id,
      summary: insightText,
      tokens_used: tokensUsed.total,
      cost_usd: costUsd
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
  ```

---

### **2.2 CREATE: `ai-analyze-monthly/index.ts`**

#### **Purpose:**
Generate monthly insights for completed calendar months

#### **Structure:**
- Similar to `ai-analyze-weekly` but for monthly data
- Aggregates all entries in a month
- Calculates monthly metrics (mood avg, consistency, topics)
- Generates monthly highlights, growth areas, achievements, goals
- Saves to `monthly_insights` table

#### **Key Features:**
- Timezone-aware month calculation
- Minimum 10 entries required
- Deduplication (check if monthly_insight exists)
- Error handling with retry logic
- Cost tracking

#### **Prompt Template:**
```typescript
const systemPrompt = 'You are a reflective AI assistant that helps users understand long-term trends in their wellness journey. Provide monthly summaries that highlight growth, patterns, and areas of focus. Be encouraging and forward-looking.';

const userPrompt = `Monthly Data Summary:
- Month: ${monthStart} (${monthName})
- Entries written: ${entriesCount}/${totalDaysInMonth}
- Average mood: ${avgMood}/5
- Consistency: ${consistencyScore}%
- Key themes: ${monthlyTopics.join(', ')}
- Mood trend: ${moodTrend}

Please provide:
1. Overall month reflection (2-3 sentences)
2. Biggest growth area (1 sentence)
3. One celebration moment (1 sentence)
4. Focus for next month (1-2 sentences)

Keep it inspiring and actionable (under 200 words).`;
```

---

### **2.3 REPLACE: `process-ai-queue/index.ts`**

#### **Current Behavior:**
- Processes old `ai_analysis_queue` table
- Only handles daily analysis
- Calls `ai-analyze-daily` function

#### **New Behavior:**
- Process new `analysis_queue` table
- Handle all analysis types: `daily`, `weekly`, `monthly`
- Route to appropriate function based on `analysis_type`
- Process 5-10 jobs per run
- Handle retries with exponential backoff

#### **New Logic:**
```typescript
// 1. Fetch pending jobs
const { data: queueItems } = await supabase
  .from('analysis_queue')
  .select('*')
  .eq('status', 'pending')
  .lt('next_retry_at', new Date().toISOString())
  .limit(10);

// 2. For each job, route by type
for (const job of queueItems) {
  // Update status to processing
  await supabase
    .from('analysis_queue')
    .update({ status: 'processing' })
    .eq('id', job.id);

  try {
    let result;
    switch (job.analysis_type) {
      case 'daily':
        result = await supabase.functions.invoke('ai-analyze-daily', {
          body: { entry_id: job.entry_id, user_id: job.user_id }
        });
        break;
      case 'weekly':
        result = await supabase.functions.invoke('ai-analyze-weekly', {
          body: { user_id: job.user_id, week_start: job.week_start }
        });
        break;
      case 'monthly':
        result = await supabase.functions.invoke('ai-analyze-monthly', {
          body: { user_id: job.user_id, month_start: job.month_start }
        });
        break;
    }

    // Mark as completed
    await supabase
      .from('analysis_queue')
      .update({ 
        status: 'completed',
        processed_at: new Date().toISOString()
      })
      .eq('id', job.id);
  } catch (error) {
    // Handle retry logic
    const newAttempts = job.attempts + 1;
    if (newAttempts >= job.max_attempts) {
      await supabase
        .from('analysis_queue')
        .update({ 
          status: 'failed',
          error_message: error.message,
          processed_at: new Date().toISOString()
        })
        .eq('id', job.id);
    } else {
      // Exponential backoff
      const nextRetry = new Date(Date.now() + Math.pow(2, newAttempts) * 60000);
      await supabase
        .from('analysis_queue')
        .update({ 
          status: 'pending',
          attempts: newAttempts,
          next_retry_at: nextRetry.toISOString(),
          error_message: error.message
        })
        .eq('id', job.id);
    }
  }
}
```

---

### **2.4 CREATE: `populate-analysis-queue/index.ts`**

#### **Purpose:**
Continuously populate `analysis_queue` with jobs based on timezone-aware scheduling

#### **Logic:**
```typescript
// Run every 5 minutes
// For each user:
//   1. Check if yesterday (their timezone) needs daily analysis
//   2. Check if Monday (their timezone) needs weekly analysis
//   3. Check if 1st of month (their timezone) needs monthly analysis

// Get all users with timezone
const { data: users } = await supabase
  .from('users')
  .select('id, timezone')
  .not('timezone', 'is', null);

for (const user of users) {
  const userTimezone = user.timezone || 'UTC';
  
  // Calculate current date in user's timezone
  const nowInTz = new Date(new Date().toLocaleString('en-US', { timeZone: userTimezone }));
  const todayInTz = new Date(nowInTz.getFullYear(), nowInTz.getMonth(), nowInTz.getDate());
  
  // 1. DAILY: Check yesterday
  const yesterday = new Date(todayInTz);
  yesterday.setDate(yesterday.getDate() - 1);
  
  // Find entry from yesterday
  const { data: yesterdayEntry } = await supabase
    .from('entries')
    .select('id')
    .eq('user_id', user.id)
    .eq('entry_date', yesterday.toISOString().split('T')[0])
    .single();
  
  if (yesterdayEntry) {
    // Check if insight exists
    const { data: existingInsight } = await supabase
      .from('entry_insights')
      .select('id')
      .eq('entry_id', yesterdayEntry.id)
      .eq('status', 'success')
      .single();
    
    // Check if already queued
    const { data: queued } = await supabase
      .from('analysis_queue')
      .select('id')
      .eq('user_id', user.id)
      .eq('analysis_type', 'daily')
      .eq('target_date', yesterday.toISOString().split('T')[0])
      .in('status', ['pending', 'processing'])
      .single();
    
    if (!existingInsight && !queued && yesterdayEntry.diary_text?.length >= 50) {
      // Queue daily analysis
      await supabase
        .from('analysis_queue')
        .insert({
          user_id: user.id,
          analysis_type: 'daily',
          target_date: yesterday.toISOString().split('T')[0],
          entry_id: yesterdayEntry.id,
          status: 'pending',
          next_retry_at: new Date().toISOString()
        });
    }
  }
  
  // 2. WEEKLY: Check if Monday and previous week needs analysis
  if (nowInTz.getDay() === 1) { // Monday
    const lastWeekStart = new Date(todayInTz);
    lastWeekStart.setDate(lastWeekStart.getDate() - 7);
    // Set to Monday of last week
    lastWeekStart.setDate(lastWeekStart.getDate() - lastWeekStart.getDay() + 1);
    
    // Check if weekly insight exists
    const { data: existingWeekly } = await supabase
      .from('weekly_insights')
      .select('id')
      .eq('user_id', user.id)
      .eq('week_start', lastWeekStart.toISOString().split('T')[0])
      .single();
    
    // Check if queued
    const { data: queuedWeekly } = await supabase
      .from('analysis_queue')
      .select('id')
      .eq('user_id', user.id)
      .eq('analysis_type', 'weekly')
      .eq('week_start', lastWeekStart.toISOString().split('T')[0])
      .in('status', ['pending', 'processing'])
      .single();
    
    // Check if sufficient entries (3+)
    const { count } = await supabase
      .from('entries')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('entry_date', lastWeekStart.toISOString().split('T')[0])
      .lt('entry_date', new Date(lastWeekStart.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]);
    
    if (!existingWeekly && !queuedWeekly && (count || 0) >= 3) {
      await supabase
        .from('analysis_queue')
        .insert({
          user_id: user.id,
          analysis_type: 'weekly',
          target_date: lastWeekStart.toISOString().split('T')[0],
          week_start: lastWeekStart.toISOString().split('T')[0],
          status: 'pending',
          next_retry_at: new Date().toISOString()
        });
    }
  }
  
  // 3. MONTHLY: Check if 1st of month and previous month needs analysis
  if (nowInTz.getDate() === 1) {
    const lastMonth = new Date(todayInTz.getFullYear(), todayInTz.getMonth() - 1, 1);
    
    // Check if monthly insight exists
    const { data: existingMonthly } = await supabase
      .from('monthly_insights')
      .select('id')
      .eq('user_id', user.id)
      .eq('month_start', lastMonth.toISOString().split('T')[0])
      .single();
    
    // Check if queued
    const { data: queuedMonthly } = await supabase
      .from('analysis_queue')
      .select('id')
      .eq('user_id', user.id)
      .eq('analysis_type', 'monthly')
      .eq('month_start', lastMonth.toISOString().split('T')[0])
      .in('status', ['pending', 'processing'])
      .single();
    
    // Check if sufficient entries (10+)
    const firstDayOfMonth = new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 1);
    const lastDayOfMonth = new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 0);
    
    const { count } = await supabase
      .from('entries')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('entry_date', firstDayOfMonth.toISOString().split('T')[0])
      .lte('entry_date', lastDayOfMonth.toISOString().split('T')[0]);
    
    if (!existingMonthly && !queuedMonthly && (count || 0) >= 10) {
      await supabase
        .from('analysis_queue')
        .insert({
          user_id: user.id,
          analysis_type: 'monthly',
          target_date: lastMonth.toISOString().split('T')[0],
          month_start: lastMonth.toISOString().split('T')[0],
          status: 'pending',
          next_retry_at: new Date().toISOString()
        });
    }
  }
}
```

---

### **2.5 MODIFY: `ai-analyze-weekly/index.ts`**

#### **Changes:**
- **Minimal changes** - function already works well
- **Add**: Timezone-aware week calculation (if needed)
- **Ensure**: Idempotency (already has deduplication)
- **Keep**: All existing logic

---

## **PHASE 3: FLUTTER UI CHANGES**

### **3.1 DELETE Files**

#### **Delete `lib/widgets/insight_carousel.dart`**
- **Reason**: Replaced with single card
- **Impact**: Home screen will need new widget

#### **Delete `lib/services/homescreen_insights_service.dart`**
- **Reason**: No longer using `homescreen_insights` table
- **Impact**: Need new service method for yesterday's insight

---

### **3.2 MODIFY: Home Screen**

#### **Current:**
- Shows `InsightCarousel` with 5 insights
- Fetches from `homescreen_insights` table
- Auto-rotates through insights

#### **New:**
- Show single `YesterdayInsightCard` widget
- Fetch from `entry_insights` where `entry_date = yesterday`
- Tap to navigate to `YesterdayInsightScreen`

#### **Implementation:**
```dart
// In home_screen.dart
// REMOVE: InsightCarousel widget
// ADD: YesterdayInsightCard widget

Widget _buildYesterdayInsightCard() {
  return Consumer(
    builder: (context, ref, child) {
      final yesterdayInsight = ref.watch(yesterdayInsightProvider);
      
      return yesterdayInsight.when(
        data: (insight) {
          if (insight == null) {
            return _buildEmptyInsightState();
          }
          return YesterdayInsightCard(
            insight: insight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => YesterdayInsightScreen(insight: insight)
              )
            ),
          );
        },
        loading: () => _buildLoadingInsightState(),
        error: (err, stack) => _buildErrorInsightState(),
      );
    },
  );
}

Widget _buildEmptyInsightState() {
  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.insights, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            "Your daily insights will be ready each morning",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

---

### **3.3 CREATE: New Widgets & Screens**

#### **Create `lib/widgets/yesterday_insight_card.dart`**
- **Purpose**: Display single yesterday's insight card
- **Features**:
  - Title: "Yesterday's Insight"
  - Content: 2-3 line summary from `entry_insights.summary`
  - Date: Shows yesterday's date
  - Sentiment indicator (color-coded)
  - Tap to view full details

#### **Create `lib/screens/yesterday_insight_screen.dart`**
- **Purpose**: Full screen view of yesterday's insight
- **Features**:
  - Full analysis text
  - Sentiment label and score
  - Topics detected
  - Date clearly displayed
  - Link to view original entry
  - Back button

#### **Create `lib/screens/monthly_insight_screen.dart`**
- **Purpose**: Display monthly analysis
- **Features**:
  - Month header (e.g., "January 2024 Review")
  - Monthly highlights
  - Growth areas
  - Achievements
  - Next month goals
  - Empty state if no data

---

### **3.4 MODIFY: Services**

#### **Modify `lib/services/ai_service.dart`**

**REMOVE:**
- `triggerDailyAnalysis()` method
- `getTodayInsightWithFallback()` method

**ADD:**
- `getYesterdayInsight(String userId)` - Fetch yesterday's insight
- `getWeeklyInsight(String userId, DateTime weekStart)` - Fetch from DB
- `getMonthlyInsight(String userId, DateTime monthStart)` - Fetch from DB

**Implementation:**
```dart
/// Fetch yesterday's insight for user
Future<DailyInsight?> getYesterdayInsight(String userId) async {
  try {
    // Calculate yesterday in user's timezone (or UTC if not set)
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    
    final response = await _supabase
        .from('entry_insights')
        .select('''
          id, 
          entry_id,
          summary, 
          insight_text,
          sentiment_label, 
          sentiment_score,
          topics,
          processed_at, 
          status,
          entries!inner(entry_date)
        ''')
        .eq('entries.user_id', userId)
        .eq('entries.entry_date', yesterdayStr)
        .eq('status', 'success')
        .maybeSingle();
    
    if (response == null) return null;
    
    return DailyInsight(
      id: response['id'] as String,
      entryId: response['entry_id'] as String,
      summary: response['summary'] as String? ?? response['insight_text'] as String?,
      sentimentLabel: response['sentiment_label'] as String?,
      sentimentScore: (response['sentiment_score'] as num?)?.toDouble(),
      topics: (response['topics'] as List<dynamic>?)?.cast<String>() ?? [],
      processedAt: DateTime.parse(response['processed_at'] as String),
    );
  } catch (e) {
    ErrorLoggingService.logLowError(
      errorCode: 'ERRAI005',
      errorMessage: 'Failed to fetch yesterday insight: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
    );
    return null;
  }
}
```

#### **Modify `lib/services/entry_service.dart`**

**REMOVE:**
- Line 104: `triggerDailyAnalysis()` call
- All AI trigger logic after entry sync

**KEEP:**
- Entry sync logic only
- No AI triggering from Flutter side

---

### **3.5 MODIFY: Analytics Screens**

#### **Weekly Analysis Screen**
- **Remove**: Manual trigger button
- **Change**: Fetch existing `weekly_insights` records
- **Add**: Empty state with message: "Your first weekly insights are brewing! ✨ Weekly analysis runs every Monday morning."

#### **Monthly Analysis Screen** (if exists)
- **Add**: Fetch from `monthly_insights` table
- **Add**: Empty state with message: "Monthly insights are on the way! 📈 At the start of each month, you'll receive a comprehensive review."

---

## **PHASE 4: PROVIDER CHANGES**

### **4.1 MODIFY: `lib/providers/home_summary_provider.dart`**

#### **Remove:**
- `homescreenInsightsProvider` (fetches 5 insights)

#### **Add:**
- `yesterdayInsightProvider` (fetches single yesterday insight)

```dart
final yesterdayInsightProvider = FutureProvider.autoDispose<DailyInsight?>((ref) async {
  final userId = ref.watch(authProvider).user?.id;
  if (userId == null) return null;
  
  final aiService = ref.watch(aiServiceProvider);
  return await aiService.getYesterdayInsight(userId);
});
```

---

## **PHASE 5: TIMEZONE HANDLING**

### **5.1 Flutter: Timezone Acquisition**

#### **During Onboarding:**
```dart
// Get user's timezone
final timeZoneName = DateTime.now().timeZoneName;
// Examples: "America/New_York", "Europe/London", "Asia/Kolkata"

// Save to Supabase
await supabase
  .from('users')
  .update({ 'timezone': timeZoneName })
  .eq('id', userId);
```

#### **Default Timezone:**
- If user doesn't have timezone set, default to 'UTC'
- Edge functions will handle UTC as fallback

### **5.2 Edge Functions: Timezone Calculations**

#### **Key Functions:**
- Always use `users.timezone` for date calculations
- Convert UTC `NOW()` to user's timezone: `(NOW() AT TIME ZONE users.timezone)::DATE`
- Calculate "yesterday" in user's timezone
- Calculate "Monday" in user's timezone
- Calculate "1st of month" in user's timezone

#### **Example:**
```typescript
// Get user's timezone
const { data: user } = await supabase
  .from('users')
  .select('timezone')
  .eq('id', user_id)
  .single();

const userTimezone = user?.timezone || 'UTC';

// Calculate yesterday in user's timezone
const { data: yesterdayDate } = await supabase.rpc('get_date_in_timezone', {
  p_timezone: userTimezone,
  p_offset_days: -1
});
```

---

## **PHASE 6: TESTING & VALIDATION**

### **6.1 Database Tests**
- [ ] Verify `analysis_queue` table created
- [ ] Verify `monthly_insights` table created
- [ ] Verify `homescreen_insights` dropped
- [ ] Verify `entry_insights` columns removed
- [ ] Test timezone calculations

### **6.2 Edge Function Tests**
- [ ] Test `ai-analyze-daily` with single insight
- [ ] Test `ai-analyze-monthly` creation
- [ ] Test `populate-analysis-queue` logic
- [ ] Test `process-ai-queue` routing
- [ ] Test timezone-aware scheduling

### **6.3 Flutter Tests**
- [ ] Test yesterday insight card display
- [ ] Test empty states
- [ ] Test navigation to detail screen
- [ ] Test weekly/monthly screens
- [ ] Test timezone acquisition

---

## **PHASE 7: DEPLOYMENT**

### **7.1 Database Migration Order**
1. Create new tables (`analysis_queue`, `monthly_insights`)
2. Add indexes
3. Remove columns from `entry_insights`
4. Drop old tables (`homescreen_insights`, old `ai_analysis_queue`)

### **7.2 Edge Function Deployment**
1. Deploy `ai-analyze-daily` (modified)
2. Deploy `ai-analyze-monthly` (new)
3. Deploy `process-ai-queue` (replaced)
4. Deploy `populate-analysis-queue` (new)
5. Set up cron/scheduler for `populate-analysis-queue` (every 5 min)
6. Set up cron/scheduler for `process-ai-queue` (every 1 min)

### **7.3 Flutter Deployment**
1. Remove old widgets/services
2. Add new widgets/screens
3. Update providers
4. Test thoroughly
5. Deploy to app stores

---

## **CRITICAL NOTES**

### **Timezone Handling:**
- **Always** use `users.timezone` for date calculations
- **Default** to 'UTC' if timezone not set
- **Test** with multiple timezones (EST, PST, IST, etc.)

### **Data Migration:**
- **No data migration needed** - new system starts fresh
- Existing `entry_insights` remain (but won't have 5 insights)
- Users will see new format going forward

### **Backward Compatibility:**
- Old insights remain in database
- New system only generates new format
- Flutter app only displays new format

### **Error Handling:**
- All edge functions log to `ai_errors_log`
- Queue retry logic handles failures
- Empty states guide users

---

## **SUCCESS CRITERIA**

✅ Single "Yesterday's Insight" card on home screen  
✅ Batch processing runs automatically  
✅ Weekly analysis on Monday mornings  
✅ Monthly analysis on 1st of month  
✅ Timezone-aware scheduling  
✅ Lightweight, simplified codebase  
✅ No 5-insight carousel  
✅ Clear empty states for users  

---

## **ESTIMATED TIMELINE**

- **Phase 1 (Database)**: 1-2 hours
- **Phase 2 (Edge Functions)**: 4-6 hours
- **Phase 3 (Flutter UI)**: 6-8 hours
- **Phase 4 (Providers)**: 1-2 hours
- **Phase 5 (Timezone)**: 2-3 hours
- **Phase 6 (Testing)**: 4-6 hours
- **Phase 7 (Deployment)**: 2-3 hours

**Total**: ~20-30 hours

---

**END OF IMPLEMENTATION PLAN**

