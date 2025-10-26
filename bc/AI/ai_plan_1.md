# **COMPREHENSIVE AI FEATURE IMPLEMENTATION REPORT**
**For Diary Journal App - OpenAI Integration**
*Complete Technical Specification for Development Team*

---

## **1. EXECUTIVE SUMMARY & ARCHITECTURE DECISIONS**

### **1.1 Core AI Strategy**
We're implementing a **tiered AI analysis system** using **OpenAI GPT-4o mini** with **context-aware prompts** and **cost-optimized** execution.

### **1.2 Key Decisions Made**
- **Model**: GPT-4o mini (best balance of cost & quality for emotional analysis)
- **Architecture**: Stateless API calls with managed context
- **Cost Control**: Tiered features + local preprocessing
- **Integration**: Supabase Edge Functions as secure proxy
- **Data Flow**: Local-first with intelligent background sync

### **1.3 AI Feature Tiers**
| Tier | Features | Cost/User | Target Users |
|------|----------|-----------|-------------|
| **Free** | Basic daily insights | ₹0.03-0.05 | All users |
| **Premium** | Daily + Weekly analysis | ₹0.20-0.30/week | Paying users |
| **Premium+** | All + Monthly + WhatsApp | ₹1.00-1.50/month | Power users |

---

## **2. DATABASE SCHEMA ENHANCEMENTS**

### **2.1 New Tables Required**

#### **Table: `ai_requests_log`**
```sql
CREATE TABLE ai_requests_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  entry_id UUID REFERENCES entries(id),
  analysis_type TEXT NOT NULL CHECK (analysis_type IN ('daily', 'weekly', 'monthly', 'affirmation')),
  prompt_tokens INTEGER NOT NULL,
  completion_tokens INTEGER NOT NULL,
  total_tokens INTEGER NOT NULL,
  cost NUMERIC(10,6) NOT NULL,
  model_used TEXT DEFAULT 'gpt-4o-mini',
  status TEXT DEFAULT 'success' CHECK (status IN ('success', 'error', 'retry')),
  error_message TEXT,
  request_duration_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_ai_requests_user_id ON ai_requests_log(user_id);
CREATE INDEX idx_ai_requests_created_at ON ai_requests_log(created_at);
```

#### **Table: `ai_prompt_templates`**
```sql
CREATE TABLE ai_prompt_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  template_name TEXT UNIQUE NOT NULL,
  system_prompt TEXT NOT NULL,
  user_prompt_template TEXT NOT NULL,
  temperature NUMERIC(3,2) DEFAULT 0.7,
  max_tokens INTEGER DEFAULT 500,
  analysis_type TEXT NOT NULL,
  version INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### **Table: `user_ai_preferences`**
```sql
CREATE TABLE user_ai_preferences (
  user_id UUID REFERENCES users(id) PRIMARY KEY,
  ai_insights_enabled BOOLEAN DEFAULT true,
  ai_affirmations_enabled BOOLEAN DEFAULT true,
  ai_tone_preference TEXT DEFAULT 'supportive' CHECK (ai_tone_preference IN ('supportive', 'motivational', 'analytical')),
  daily_analysis_enabled BOOLEAN DEFAULT true,
  weekly_summary_enabled BOOLEAN DEFAULT false,
  monthly_insights_enabled BOOLEAN DEFAULT false,
  whatsapp_insights_enabled BOOLEAN DEFAULT false,
  max_daily_ai_requests INTEGER DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### **2.2 Existing Table Modifications**

#### **Enhanced `entry_insights` Table:**
```sql
-- Add new columns to existing table
ALTER TABLE entry_insights 
ADD COLUMN ai_generated BOOLEAN DEFAULT false,
ADD COLUMN analysis_type TEXT CHECK (analysis_type IN ('daily', 'weekly', 'monthly')),
ADD COLUMN confidence_score NUMERIC(3,2),
ADD COLUMN key_takeaways JSONB DEFAULT '[]'::jsonb,
ADD COLUMN action_items JSONB DEFAULT '[]'::jsonb;
```

#### **New `weekly_insights` Table:**
```sql
CREATE TABLE weekly_insights (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  mood_avg NUMERIC(3,2),
  mood_trend TEXT CHECK (mood_trend IN ('improving', 'declining', 'stable', 'volatile')),
  top_positive_topics TEXT[],
  top_concern_topics TEXT[],
  habit_correlations JSONB DEFAULT '{}'::jsonb,
  key_insights TEXT[],
  recommendations TEXT[],
  ai_generated BOOLEAN DEFAULT true,
  word_count_total INTEGER,
  entries_count INTEGER,
  consistency_score NUMERIC(3,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, week_start)
);
```

---

## **3. PROMPT ENGINEERING SPECIFICATION**

### **3.1 Core Prompt Templates**

#### **Daily Analysis Prompt:**
```sql
INSERT INTO ai_prompt_templates (template_name, system_prompt, user_prompt_template, analysis_type, temperature, max_tokens) VALUES
(
  'daily_analysis_v1',
  'You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide helpful, actionable insights. Always be supportive and non-judgmental.',
  
  'User''s Recent Context:
  - Current mood: {mood_score}/5
  - Recent topics: {recent_topics}
  - Self-care completion: {self_care_summary}
  - Last 3 days mood trend: {mood_trend}
  
  Today''s Entry: "{diary_text}"
  
  Please provide:
  1. Emotional tone analysis (1 sentence)
  2. One key insight about today''s entry
  3. One supportive affirmation based on today''s content
  4. One gentle suggestion if any concerns are detected
  
  Keep it concise and warm.',
  
  'daily',
  0.7,
  300
);
```

#### **Weekly Analysis Prompt:**
```sql
INSERT INTO ai_prompt_templates (template_name, system_prompt, user_prompt_template, analysis_type, temperature, max_tokens) VALUES
(
  'weekly_analysis_v1',
  'You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. Provide insightful weekly summaries that help users understand their emotional patterns and habit impacts.',
  
  'Weekly Data Summary:
  - Date range: {week_start} to {week_end}
  - Mood scores: {mood_scores}
  - Average mood: {avg_mood}
  - Entries written: {entries_count}/7
  - Self-care completion: {self_care_summary}
  - Key topics mentioned: {weekly_topics}
  
  Habit Analysis:
  {habit_correlations}
  
  Please provide:
  1. Weekly mood pattern (1-2 sentences)
  2. Top 2 positive influences on mood
  3. One area for potential improvement
  4. Two specific, actionable recommendations for next week
  
  Focus on patterns and practical insights.',
  
  'weekly',
  0.5,
  400
);
```

#### **Affirmation Generation Prompt:**
```sql
INSERT INTO ai_prompt_templates (template_name, system_prompt, user_prompt_template, analysis_type, temperature, max_tokens) VALUES
(
  'affirmation_generation_v1',
  'You are a motivational AI that creates personalized, empowering affirmations based on user context and challenges. Make them specific, believable, and emotionally resonant.',
  
  'User Context:
  - Current challenges: {current_challenges}
  - Recent achievements: {recent_achievements}
  - Personal goals: {user_goals}
  - Preferred tone: {tone_preference}
  
  Generate 3 personalized affirmations that:
  1. Address their current context
  2. Are specific and actionable
  3. Use empowering language
  4. Are under 15 words each
  
  Return as a JSON array of strings.',
  
  'affirmation',
  0.8,
  200
);
```

---

## **4. SUPABASE EDGE FUNCTIONS IMPLEMENTATION**

### **4.1 Core AI Service Edge Function**

#### **File: `supabase/functions/ai-analysis/index.ts`**
```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, analysis_type, entry_data, context_data } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Get user AI preferences
    const { data: preferences, error: prefError } = await supabase
      .from('user_ai_preferences')
      .select('*')
      .eq('user_id', user_id)
      .single()

    if (prefError || !preferences?.[`${analysis_type}_analysis_enabled`]) {
      throw new Error('AI analysis not enabled for user')
    }

    // 2. Get prompt template
    const { data: template, error: templateError } = await supabase
      .from('ai_prompt_templates')
      .select('*')
      .eq('analysis_type', analysis_type)
      .eq('is_active', true)
      .single()

    if (templateError) throw templateError

    // 3. Build final prompt
    const finalPrompt = buildPrompt(template, entry_data, context_data)

    // 4. Call OpenAI
    const startTime = Date.now()
    const aiResponse = await callOpenAI(finalPrompt, template)
    const duration = Date.now() - startTime

    // 5. Log the request
    await supabase
      .from('ai_requests_log')
      .insert({
        user_id,
        analysis_type,
        prompt_tokens: aiResponse.usage.prompt_tokens,
        completion_tokens: aiResponse.usage.completion_tokens,
        total_tokens: aiResponse.usage.total_tokens,
        cost: calculateCost(aiResponse.usage),
        request_duration_ms: duration,
        status: 'success'
      })

    // 6. Save insights to appropriate table
    await saveInsights(supabase, user_id, analysis_type, aiResponse.choices[0].message.content, entry_data)

    return new Response(
      JSON.stringify({ 
        success: true, 
        insights: aiResponse.choices[0].message.content,
        tokens_used: aiResponse.usage.total_tokens
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    // Log error
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    await supabase
      .from('ai_requests_log')
      .insert({
        user_id: req.json().user_id,
        analysis_type: req.json().analysis_type,
        status: 'error',
        error_message: error.message,
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0,
        cost: 0
      })

    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Helper functions
function buildPrompt(template: any, entryData: any, contextData: any): string {
  let prompt = template.user_prompt_template
  const placeholders = prompt.match(/{[^}]+}/g) || []
  
  placeholders.forEach(placeholder => {
    const key = placeholder.slice(1, -1)
    const value = contextData[key] || entryData[key] || ''
    prompt = prompt.replace(placeholder, value)
  })
  
  return prompt
}

async function callOpenAI(prompt: string, template: any) {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: template.system_prompt },
        { role: 'user', content: prompt }
      ],
      temperature: template.temperature,
      max_tokens: template.max_tokens
    })
  })

  if (!response.ok) {
    throw new Error(`OpenAI API error: ${response.statusText}`)
  }

  return await response.json()
}

function calculateCost(usage: any): number {
  const inputCost = (usage.prompt_tokens / 1000) * 0.15  // $0.15 per 1K tokens
  const outputCost = (usage.completion_tokens / 1000) * 0.60  // $0.60 per 1K tokens
  return inputCost + outputCost
}

async function saveInsights(supabase: any, userId: string, analysisType: string, insights: string, entryData: any) {
  if (analysisType === 'daily') {
    await supabase
      .from('entry_insights')
      .insert({
        entry_id: entryData.entry_id,
        sentiment_label: extractSentiment(insights),
        summary: insights,
        ai_generated: true,
        analysis_type: 'daily'
      })
  } else if (analysisType === 'weekly') {
    await supabase
      .from('weekly_insights')
      .insert({
        user_id: userId,
        week_start: entryData.week_start,
        week_end: entryData.week_end,
        key_insights: extractArray(insights, 'insights'),
        recommendations: extractArray(insights, 'recommendations'),
        ai_generated: true
      })
  }
}
```

### **4.2 Affirmation Generation Edge Function**

#### **File: `supabase/functions/generate-affirmations/index.ts`**
```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, context } = await req.json()
    
    // Similar structure to main AI function
    // Specialized for affirmation generation
    // Returns JSON array of 3 personalized affirmations
    
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), 
      { status: 400, headers: corsHeaders })
  }
})
```

---

## **5. FLUTTER INTEGRATION SPECIFICATION**

### **5.1 AI Service Class**

#### **File: `lib/services/ai_service.dart`**
```dart
class AIService {
  final SupabaseClient _supabase;
  final LocalStorageService _localStorage;
  
  AIService(this._supabase, this._localStorage);
  
  // Daily Analysis
  Future<AIAnalysisResult> analyzeDailyEntry(Entry entry) async {
    try {
      // Build context from recent data
      final context = await _buildDailyContext(entry);
      
      final response = await _supabase.functions.invoke('ai-analysis', {
        body: {
          'user_id': _supabase.auth.currentUser?.id,
          'analysis_type': 'daily',
          'entry_data': _formatEntryData(entry),
          'context_data': context
        }
      });
      
      return AIAnalysisResult.fromJson(response.data);
    } catch (e) {
      // Fallback to local basic analysis
      return _fallbackLocalAnalysis(entry);
    }
  }
  
  // Weekly Analysis
  Future<WeeklyInsights> generateWeeklyInsights(DateTime weekStart) async {
    if (!await _hasPremiumAccess()) {
      throw AIFeatureNotAvailableException('Weekly insights require premium');
    }
    
    final weekData = await _fetchWeekData(weekStart);
    final response = await _supabase.functions.invoke('ai-analysis', {
      body: {
        'user_id': _supabase.auth.currentUser?.id,
        'analysis_type': 'weekly',
        'entry_data': _formatWeekData(weekData),
        'context_data': await _buildWeeklyContext(weekData)
      }
    });
    
    return WeeklyInsights.fromJson(response.data);
  }
  
  // Affirmation Generation
  Future<List<String>> generatePersonalizedAffirmations() async {
    final context = await _buildAffirmationContext();
    final response = await _supabase.functions.invoke('generate-affirmations', {
      body: {
        'user_id': _supabase.auth.currentUser?.id,
        'context': context
      }
    });
    
    return List<String>.from(response.data['affirmations']);
  }
  
  // Context Building Helpers
  Future<Map<String, dynamic>> _buildDailyContext(Entry entry) async {
    final recentEntries = await _supabase
        .from('entries')
        .select('mood_score, diary_text, created_at')
        .eq('user_id', _supabase.auth.currentUser?.id)
        .gte('created_at', DateTime.now().subtract(Duration(days: 3)))
        .order('created_at', ascending: false);
    
    final selfCareData = await _supabase
        .from('entry_self_care')
        .select('*')
        .eq('entry_id', entry.id)
        .single();
    
    return {
      'mood_score': entry.moodScore,
      'recent_topics': _extractTopics(recentEntries),
      'self_care_summary': _summarizeSelfCare(selfCareData),
      'mood_trend': _calculateMoodTrend(recentEntries),
      'diary_text': entry.diaryText
    };
  }
  
  // Cost tracking
  Future<double> getMonthlyAICost(String userId) async {
    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    
    final response = await _supabase
        .from('ai_requests_log')
        .select('cost')
        .eq('user_id', userId)
        .gte('created_at', startOfMonth);
    
    return response.fold(0.0, (sum, record) => sum + record['cost']);
  }
}
```

### **5.2 AI Models and Data Classes**

#### **File: `lib/models/ai_models.dart`**
```dart
class AIAnalysisResult {
  final String insights;
  final String summary;
  final List<String> keyTakeaways;
  final List<String> actionItems;
  final double confidenceScore;
  final int tokensUsed;
  final String analysisType;
  
  AIAnalysisResult({
    required this.insights,
    required this.summary,
    required this.keyTakeaways,
    required this.actionItems,
    required this.confidenceScore,
    required this.tokensUsed,
    required this.analysisType,
  });
  
  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      insights: json['insights'] ?? '',
      summary: json['summary'] ?? '',
      keyTakeaways: List<String>.from(json['key_takeaways'] ?? []),
      actionItems: List<String>.from(json['action_items'] ?? []),
      confidenceScore: (json['confidence_score'] ?? 0.0).toDouble(),
      tokensUsed: json['tokens_used'] ?? 0,
      analysisType: json['analysis_type'] ?? 'daily',
    );
  }
}

class WeeklyInsights {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double averageMood;
  final String moodTrend;
  final List<String> keyInsights;
  final List<String> recommendations;
  final Map<String, dynamic> habitCorrelations;
  final int entriesCount;
  final int totalWordCount;
  
  WeeklyInsights({
    required this.weekStart,
    required this.weekEnd,
    required this.averageMood,
    required this.moodTrend,
    required this.keyInsights,
    required this.recommendations,
    required this.habitCorrelations,
    required this.entriesCount,
    required this.totalWordCount,
  });
}

class AIPreferences {
  final bool dailyAnalysisEnabled;
  final bool weeklySummaryEnabled;
  final bool monthlyInsightsEnabled;
  final bool whatsappInsightsEnabled;
  final String tonePreference;
  final int maxDailyRequests;
  
  AIPreferences({
    required this.dailyAnalysisEnabled,
    required this.weeklySummaryEnabled,
    required this.monthlyInsightsEnabled,
    required this.whatsappInsightsEnabled,
    required this.tonePreference,
    required this.maxDailyRequests,
  });
}
```

---

## **6. TRIGGER SYSTEM & SCHEDULING**

### **6.1 Automatic Analysis Triggers**

#### **File: `lib/services/ai_trigger_service.dart`**
```dart
class AITriggerService {
  final AIService _aiService;
  final SupabaseClient _supabase;
  final LocalStorageService _storage;
  
  AITriggerService(this._aiService, this._supabase, this._storage);
  
  // Trigger daily analysis when entry is completed
  Future<void> triggerDailyAnalysis(String entryId) async {
    final preferences = await _getUserAIPreferences();
    
    if (!preferences.dailyAnalysisEnabled) return;
    
    // Check rate limiting
    if (await _hasExceededDailyLimit()) return;
    
    final entry = await _fetchEntry(entryId);
    if (_isEntrySubstantial(entry)) {
      await _aiService.analyzeDailyEntry(entry);
    }
  }
  
  // Weekly analysis - triggered on Sunday night
  Future<void> triggerWeeklyAnalysis() async {
    final preferences = await _getUserAIPreferences();
    
    if (!preferences.weeklySummaryEnabled) return;
    
    final weekStart = _getStartOfWeek();
    final weekData = await _fetchWeekData(weekStart);
    
    if (_hasSufficientData(weekData)) {
      await _aiService.generateWeeklyInsights(weekStart);
    }
  }
  
  // Manual triggers for user-requested analysis
  Future<void> manualAnalysisRequest(String type) async {
    switch (type) {
      case 'daily':
        final latestEntry = await _getLatestEntry();
        await _aiService.analyzeDailyEntry(latestEntry);
        break;
      case 'weekly':
        await _aiService.generateWeeklyInsights(_getStartOfWeek());
        break;
      case 'affirmations':
        final affirmations = await _aiService.generatePersonalizedAffirmations();
        await _saveAffirmations(affirmations);
        break;
    }
  }
  
  bool _isEntrySubstantial(Entry entry) {
    return (entry.diaryText?.length ?? 0) > 50 && 
           entry.moodScore != null;
  }
  
  bool _hasSufficientData(WeekData weekData) {
    return weekData.entries.length >= 3;
  }
  
  Future<bool> _hasExceededDailyLimit() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final response = await _supabase
        .from('ai_requests_log')
        .select('id')
        .eq('user_id', _supabase.auth.currentUser?.id)
        .gte('created_at', startOfDay);
    
    final preferences = await _getUserAIPreferences();
    return response.length >= preferences.maxDailyRequests;
  }
}
```

---

## **7. COST MANAGEMENT & MONITORING**

### **7.1 Cost Tracking System**

#### **File: `lib/services/ai_cost_service.dart`**
```dart
class AICostService {
  final SupabaseClient _supabase;
  
  AICostService(this._supabase);
  
  Future<AICostSummary> getCostSummary(String userId, {DateTimeRange? range}) async {
    final query = _supabase
        .from('ai_requests_log')
        .select('cost, analysis_type, created_at')
        .eq('user_id', userId);
    
    if (range != null) {
      query.gte('created_at', range.start)
           .lte('created_at', range.end);
    }
    
    final records = await query;
    
    double totalCost = 0;
    final costByType = <String, double>{};
    final dailyCosts = <DateTime, double>{};
    
    for (final record in records) {
      totalCost += record['cost'];
      
      final type = record['analysis_type'];
      costByType[type] = (costByType[type] ?? 0) + record['cost'];
      
      final date = DateTime.parse(record['created_at']).toLocal();
      final dateOnly = DateTime(date.year, date.month, date.day);
      dailyCosts[dateOnly] = (dailyCosts[dateOnly] ?? 0) + record['cost'];
    }
    
    return AICostSummary(
      totalCost: totalCost,
      costByType: costByType,
      dailyCosts: dailyCosts,
      totalRequests: records.length,
    );
  }
  
  Future<bool> isUserWithinBudget(String userId) async {
    final monthlyCost = await getMonthlyCost(userId);
    final userPlan = await _getUserPlan(userId);
    
    return monthlyCost <= userPlan.monthlyAIBudget;
  }
  
  Future<double> predictMonthlyCost(String userId) async {
    final currentCost = await getMonthlyCost(userId);
    final daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    final currentDay = DateTime.now().day;
    
    return (currentCost / currentDay) * daysInMonth;
  }
}
```

### **7.2 Usage Analytics Dashboard**

#### **SQL View for Cost Analytics:**
```sql
CREATE VIEW ai_usage_analytics AS
SELECT 
  user_id,
  DATE(created_at) as usage_date,
  analysis_type,
  COUNT(*) as request_count,
  SUM(total_tokens) as total_tokens,
  SUM(cost) as total_cost,
  AVG(request_duration_ms) as avg_duration_ms
FROM ai_requests_log 
GROUP BY user_id, DATE(created_at), analysis_type;
```

---

## **8. ERROR HANDLING & FALLBACKS**

### **8.1 Comprehensive Error Handling**

#### **File: `lib/services/ai_error_handler.dart`**
```dart
class AIErrorHandler {
  static Future<AIAnalysisResult> handleAIFailure(
    Object error, 
    StackTrace stackTrace, 
    String analysisType,
    dynamic context
  ) async {
    // Log error for monitoring
    await _logAIFailure(error, stackTrace, analysisType, context);
    
    switch (analysisType) {
      case 'daily':
        return _fallbackDailyAnalysis(context);
      case 'weekly':
        return _fallbackWeeklyAnalysis(context);
      case 'affirmation':
        return _fallbackAffirmations(context);
      default:
        return _genericFallback();
    }
  }
  
  static Future<AIAnalysisResult> _fallbackDailyAnalysis(dynamic context) async {
    // Basic local sentiment analysis
    final entry = context['entry'];
    final sentiment = _basicSentimentAnalysis(entry.diaryText);
    final mood = entry.moodScore;
    
    return AIAnalysisResult(
      insights: _generateBasicInsight(sentiment, mood),
      summary: 'Basic analysis: ${_getSentimentDescription(sentiment)}',
      keyTakeaways: [_getBasicTakeaway(sentiment)],
      actionItems: [_getBasicActionItem(sentiment)],
      confidenceScore: 0.5,
      tokensUsed: 0,
      analysisType: 'daily',
    );
  }
  
  static String _basicSentimentAnalysis(String? text) {
    if (text == null) return 'neutral';
    final positiveWords = ['happy', 'good', 'great', 'excited', 'love', 'amazing'];
    final negativeWords = ['sad', 'bad', 'angry', 'hate', 'terrible', 'worried'];
    
    final words = text.toLowerCase().split(' ');
    final positiveCount = words.where((w) => positiveWords.contains(w)).length;
    final negativeCount = words.where((w) => negativeWords.contains(w)).length;
    
    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }
}
```

---

## **9. IMPLEMENTATION ROADMAP**

### **Phase 1: Foundation (Week 1-2)**
- [ ] Create new database tables
- [ ] Set up Supabase Edge Functions
- [ ] Implement basic AI service in Flutter
- [ ] Create prompt templates
- [ ] Set up cost tracking

### **Phase 2: Core Features (Week 3-4)**
- [ ] Daily analysis automation
- [ ] Affirmation generation
- [ ] Basic error handling and fallbacks
- [ ] User preference management
- [ ] Cost monitoring dashboard

### **Phase 3: Advanced Features (Week 5-6)**
- [ ] Weekly analysis automation
- [ ] Progress tracking integration
- [ ] WhatsApp integration
- [ ] Advanced prompt optimization
- [ ] A/B testing framework

### **Phase 4: Optimization (Week 7-8)**
- [ ] Performance optimization
- [ ] Cost reduction strategies
- [ ] User feedback integration
- [ ] Quality improvement iterations

---

## **10. MONITORING & QUALITY ASSURANCE**

### **10.1 Key Performance Indicators**
- AI request success rate (>95%)
- Average response time (<3 seconds)
- Cost per user per month (<₹10 for premium)
- User engagement with AI features
- Insight quality scores (user ratings)

### **10.2 Alert Thresholds**
- Error rate > 5% for 1 hour
- Average cost per user > ₹15/month
- Response time > 5 seconds consistently
- OpenAI API downtime

### **10.3 Quality Monitoring**
```sql
-- Quality monitoring query
SELECT 
  analysis_type,
  AVG(request_duration_ms) as avg_response_time,
  COUNT(*) as total_requests,
  SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END) as error_count,
  AVG(cost) as avg_cost_per_request
FROM ai_requests_log 
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY analysis_type;
```

---

## **11. SECURITY & PRIVACY**

### **11.1 Data Protection**
- All AI calls through secure Edge Functions
- No user data stored by OpenAI beyond individual requests
- User opt-in required for each AI feature
- Right to disable AI features at any time
- Data anonymization for prompt context

### **11.2 Compliance Measures**
- Clear privacy policy about AI data usage
- User controls for data sharing preferences
- Regular security audits of AI infrastructure
- Data encryption in transit and at rest

---

## **CONCLUSION**

This comprehensive implementation plan provides everything needed to build a **robust, cost-effective, and user-friendly AI feature set** for your diary app. The architecture is designed to **scale efficiently** while maintaining **excellent user experience** and **manageable costs**.

**Key Success Factors:**
1. **Start simple** with daily analysis and expand gradually
2. **Monitor costs closely** especially during initial rollout
3. **Gather user feedback** continuously to improve prompt quality
4. **Maintain fallback options** for when AI services are unavailable

**The system is ready for implementation** and should deliver **significant value to users** while operating within reasonable cost constraints.

--- 
*Implementation Guide Version: 1.0 | Last Updated: [Current Date] | For Development Team Use*