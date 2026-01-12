# **COMPREHENSIVE AI INSIGHTS SYSTEM REDESIGN**

## **1. YESTERDAY'S INSIGHT FEATURE**

### **Core Concept**
- **Complete Analysis**: Analyze user's previous full day (yesterday) for comprehensive insights
- **Batch Processing**: Run analysis overnight when the day is complete
- **Clear Labeling**: Always display as "Yesterday's Insight" to set proper expectations

### **Implementation Details**

#### **Database Changes**
**REMOVE existing 5-insight system:**
```sql
-- Remove these columns from entry_insights table:
-- Remove: insight_text, key_takeaways, action_items (if they're separate from summary)
-- Keep: summary, sentiment_label, sentiment_score, topics
```

**YESTERDAY'S INSIGHT CARD DATA STRUCTURE:**
```sql
-- Using existing entry_insights table with focus on:
- entry_id (links to specific day)
- summary (2-3 line insight)
- sentiment_label, sentiment_score
- topics
- processed_at (analysis timestamp)
```

#### **Flutter UI Changes**
**HOME SCREEN CARD:**
- **Single fixed card** (remove sliding carousel)
- **Title**: "Yesterday's Insight"
- **Content**: 2-3 line summary from `entry_insights.summary`
- **Tap Action**: Navigate to detailed "YesterdayInsightScreen"
- **Fallback**: "Your daily insight will be ready each morning" (for new users)

**YESTERDAY INSIGHT DETAIL SCREEN:**
- Full analysis from `entry_insights`
- Sentiment indicator
- Key topics detected
- Date: Clearly shows yesterday's date
- Option to view the original entry

### **Analysis Trigger System**
```sql
-- Batch job runs continuously, checks for each user:
WHERE (NOW() AT TIME ZONE users.timezone)::DATE > 
      (entries.entry_date AT TIME ZONE users.timezone)::DATE
AND entries.id NOT IN (SELECT entry_id FROM entry_insights)
AND LENGTH(entries.diary_text) > 50
```

---

## **2. WEEKLY ANALYSIS FEATURE**

### **Core Concept**
- **Fixed Weekly Schedule**: Analyze completed calendar weeks (Sunday-Saturday or Monday-Sunday)
- **Weekly Batch Processing**: Run every Sunday night/Monday morning
- **Historical Data**: Each weekly analysis is a snapshot of that specific week

### **Implementation Details**

#### **Database Structure**
**USE EXISTING `weekly_insights` TABLE:**
```sql
-- Key columns to use:
- week_start (date)
- mood_avg, cups_avg, self_care_rate
- top_topics, highlights
- mood_trend, key_insights, recommendations
- consistency_score, entries_count
```

#### **Flutter UI Implementation**
**WEEKLY ANALYSIS SCREEN STATES:**

**STATE 1: No Data Available**
```
"Your first weekly insights are brewing! ✨"
"Weekly analysis runs every Monday morning, summarizing your completed week."
"Come back next Monday to see patterns and trends from your first full week."
```

**STATE 2: Data Available**
- Display all data from `weekly_insights`
- Show week range: "Week of Jan 1-7, 2024"
- Key metrics: Mood average, consistency score, entries count
- AI-generated highlights and recommendations

#### **Analysis Schedule**
```sql
-- Run weekly analysis when:
-- It's Monday in user's timezone AND
-- Previous week has sufficient data (3+ entries) AND
-- Weekly analysis doesn't already exist for that week
```

---

## **3. MONTHLY ANALYSIS FEATURE**

### **Core Concept**
- **Fixed Monthly Schedule**: Analyze completed calendar months
- **Monthly Batch Processing**: Run on 1st of each month
- **Long-term Trends**: Focus on monthly patterns and progress

### **Implementation Details**

#### **Database Structure**
**CREATE NEW `monthly_insights` TABLE:**
```sql
CREATE TABLE public.monthly_insights (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  month_start date NOT NULL,  -- First day of month
  mood_avg numeric,
  entries_count integer DEFAULT 0,
  word_count_total integer DEFAULT 0,
  top_topics ARRAY,
  monthly_highlights text,
  growth_areas ARRAY,
  achievements ARRAY,
  next_month_goals ARRAY,
  generated_at timestamp with time zone DEFAULT now(),
  consistency_score numeric,
  habit_analysis jsonb DEFAULT '{}'::jsonb,
  mood_trend_monthly text,
  CONSTRAINT monthly_insights_pkey PRIMARY KEY (id),
  CONSTRAINT monthly_insights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
```

#### **Flutter UI Implementation**
**MONTHLY ANALYSIS SCREEN STATES:**

**STATE 1: No Data Available**
```
"Monthly insights are on the way! 📈"
"At the start of each month, you'll receive a comprehensive review of your previous month's journey."
"Your first monthly report will be available on [calculate 1st of next month]."
```

**STATE 2: Data Available**
- Display data from `monthly_insights`
- Show month: "January 2024 Review"
- Monthly highlights and achievements
- Growth areas and next month's goals

---

## **4. TIMEZONE HANDLING SYSTEM**

### **Implementation Strategy**

#### **Timezone Acquisition**
```dart
// During onboarding in Flutter:
final String userTimezone = DateTime.now().timeZoneName;
// Examples: "America/New_York", "Europe/London", "Asia/Kolkata"

// Send to Supabase users.timezone field
```

#### **Batch Processing Logic**
```sql
-- For daily analysis: Check if it's past midnight in user's timezone
SELECT u.id as user_id, e.id as entry_id
FROM users u
JOIN entries e ON u.id = e.user_id
WHERE (NOW() AT TIME ZONE u.timezone)::DATE = (e.entry_date AT TIME ZONE u.timezone)::DATE + INTERVAL '1 day'
AND e.id NOT IN (SELECT entry_id FROM entry_insights)

-- For weekly analysis: Check if it's Monday in user's timezone
WHERE EXTRACT(DOW FROM (NOW() AT TIME ZONE u.timezone)) = 1  -- 1 = Monday

-- For monthly analysis: Check if it's 1st of month in user's timezone
WHERE EXTRACT(DAY FROM (NOW() AT TIME ZONE u.timezone)) = 1
```

#### **Timezone Change Policy**
- **Initial Implementation**: Fixed timezone set during onboarding
- **Future Enhancement**: Allow changes with clear data boundary explanations
- **Data Integrity**: Existing analyses remain in original timezone context

---

## **5. AI ANALYSIS QUEUE SYSTEM**

### **Scalable Processing Architecture**

#### **Queue Table Creation**
```sql
CREATE TABLE public.analysis_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  analysis_type text NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly')),
  target_date date NOT NULL,  -- The date/week/month being analyzed
  entry_id uuid,  -- For daily analysis
  week_start date,  -- For weekly analysis  
  month_start date,  -- For monthly analysis
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  attempts integer DEFAULT 0,
  max_attempts integer DEFAULT 3,
  next_retry_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  processed_at timestamp with time zone,
  CONSTRAINT analysis_queue_pkey PRIMARY KEY (id),
  CONSTRAINT analysis_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
```

#### **Queue Processing Logic**
```sql
-- Step 1: Queue Population (runs continuously)
-- Identify users needing daily analysis (past midnight their time)
-- Identify users needing weekly analysis (Monday their time)  
-- Identify users needing monthly analysis (1st of month their time)

-- Step 2: Worker Process (runs every minute)
-- Process 5-10 jobs per minute
-- Update status to 'processing'
-- Call OpenAI API with appropriate prompt template
-- Store results in respective tables (entry_insights, weekly_insights, monthly_insights)
-- Update queue status to 'completed' or 'failed'
```

---

## **6. PROMPT TEMPLATES & AI CONFIGURATION**

### **Daily Analysis Prompt**
```sql
-- Use ai_prompt_templates with analysis_type = 'daily'
-- Focus on: emotional patterns, key events, sentiment analysis
-- Output: 2-3 line summary for card + detailed analysis for full screen
```

### **Weekly Analysis Prompt**  
```sql
-- analysis_type = 'weekly'
-- Focus on: weekly patterns, progress tracking, habit correlations
-- Output: Weekly highlights, trends, recommendations
```

### **Monthly Analysis Prompt**
```sql
-- analysis_type = 'monthly'  
-- Focus on: monthly trends, growth areas, achievements, future goals
-- Output: Monthly review with actionable insights
```

---

## **7. USER EXPERIENCE FLOW**

### **New User Journey**
**DAY 1:**
- Home screen: "Your daily insights will be ready each morning"
- Weekly screen: "First weekly analysis available next Monday"
- Monthly screen: "First monthly report available on [1st of next month]"

**DAY 2:**
- Home screen: "Yesterday's Insight" card appears
- Tap to view detailed analysis

**END OF WEEK 1:**
- Weekly screen: First weekly analysis available
- Shows patterns from first complete week

**START OF NEXT MONTH:**
- Monthly screen: First monthly report available
- Comprehensive monthly review

---

## **8. ERROR HANDLING & EDGE CASES**

### **Insufficient Data Handling**
```sql
-- Skip analysis if:
-- Daily: entry character count < 50
-- Weekly: less than 3 entries in the week
-- Monthly: less than 10 entries in the month
```

### **Queue Retry Logic**
- Maximum 3 attempts per analysis job
- Exponential backoff between retries
- Failed jobs logged in `ai_errors_log` for manual review

### **User Communication**
- Clear messaging when data is insufficient
- Progress indicators when analysis is pending
- Error states with helpful guidance

---

## **9. MIGRATION INSTRUCTIONS**

### **Immediate Actions**
1. **Remove 5-insight carousel** from Flutter home screen
2. **Create single yesterday insight card** with tap navigation
3. **Implement analysis queue system** in Supabase
4. **Add monthly_insights table**
5. **Update batch processing** to use timezone-aware scheduling

### **Data Migration**
- Existing insights can be converted to new format
- Historical weekly/monthly analyses can be backfilled gradually
- No user data loss during transition

---

## **10. PERFORMANCE CONSIDERATIONS**

### **Database Indexing**
```sql
CREATE INDEX CONCURRENTLY idx_analysis_queue_pending 
ON analysis_queue (status, next_retry_at) 
WHERE status IN ('pending', 'failed');

CREATE INDEX CONCURRENTLY idx_users_timezone 
ON users (timezone);

CREATE INDEX CONCURRENTLY idx_entries_date_user 
ON entries (user_id, entry_date);
```

### **Cost Optimization**
- Queue processing limits API calls to 5-10 per minute
- Skip analysis on insufficient data to avoid wasted calls
- Cache frequent prompt templates
- Monitor costs via `ai_requests_log`

---

## **SPECIAL NOTE FOR CURSOR IDE:**

**CRITICAL IMPLEMENTATION RULES:**
1. **NO CLIENT-SIDE CALCULATIONS** for weekly/monthly insights
2. **FETCH DIRECTLY FROM DATABASE** tables: `entry_insights`, `weekly_insights`, `monthly_insights`
3. **USE EXISTING AI GENERATED DATA** - do not recalculate or derive insights in Flutter
4. **RESPECT TIMEZONE BOUNDARIES** in all date calculations
5. **MAINTAIN CLEAR LABELING**: "Yesterday's Insight", "Weekly Analysis", "Monthly Report"
6. **IMPLEMENT GRACEFUL EMPTY STATES** with educational messaging

This system provides a scalable, timezone-aware AI insights platform that grows with your user base while maintaining clear user expectations and valuable, actionable insights.