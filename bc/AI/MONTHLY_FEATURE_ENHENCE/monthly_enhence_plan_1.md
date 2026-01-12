# Monthly Feature Enhancement Plan

## Overview
Enhance monthly analysis to provide deeper, more engaging insights with structured JSON format (like weekly feature). Focus on authentic, entry-based insights that reference actual user data.

---

## Phase 1: Edge Function Updates (`supabase/functions/ai-analyze-monthly/index.ts`)

### 1.1 Fetch All Entry-Related Data

**Current:** Only fetches basic entry data
**New:** Fetch complete entry ecosystem

```typescript
// After fetching entries (line ~70), add:

// Fetch affirmations
const { data: affirmationsData } = await supabase
  .from('entry_affirmations')
  .select('entry_id, affirmations')
  .in('entry_id', entryIds)

// Fetch priorities
const { data: prioritiesData } = await supabase
  .from('entry_priorities')
  .select('entry_id, priorities')
  .in('entry_id', entryIds)

// Fetch gratitude
const { data: gratitudeData } = await supabase
  .from('entry_gratitude')
  .select('entry_id, grateful_items')
  .in('entry_id', entryIds)

// Fetch tomorrow notes
const { data: tomorrowNotesData } = await supabase
  .from('entry_tomorrow_notes')
  .select('entry_id, tomorrow_notes')
  .in('entry_id', entryIds)

// Fetch self-care data (already done, but keep it)
// Fetch meals data (if needed for habit analysis)
```

### 1.2 Update System Prompt

**Current:**
```
You are a reflective AI assistant that helps users understand long-term trends in their wellness journey. Provide monthly summaries that highlight growth, patterns, and areas of focus. Be encouraging and forward-looking.
```

**New:**
```
You are an analytical but compassionate AI assistant that analyzes monthly journal data to provide deep, personalized insights. You analyze diary entries, affirmations, gratitude, priorities, and tomorrow notes to identify authentic patterns and achievements. 

Focus on:
1. Emotional patterns and mood trends over the month
2. Authentic achievements extracted from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes)
3. Habit correlations and their impact on well-being
4. Growth areas based on real patterns in the data
5. Actionable goals for next month based on entry analysis

Be specific, reference actual dates and entry content when possible. Make users feel their journey is truly understood.
```

### 1.3 Update User Prompt Template

**New Structure:**
```
MONTHLY ANALYSIS REQUEST
Month: {month_name}
Date Range: {month_start} to {month_end}
Entries Written: {entries_count}/{total_days}

=== MOOD & SENTIMENT ANALYSIS ===
Average Mood: {avg_mood}/5
Mood Trend: {mood_trend}
Mood Scores (Day by Day): {mood_scores_list}

=== COMPLETE DIARY ENTRIES (FULL TEXT WITH DATES) ===
{diary_entries_full_with_dates}

=== COMPLETE STRUCTURED DATA ===
AFFIRMATIONS (All Items with Dates):
{affirmations_full_with_dates}

GRATITUDE (All Items with Dates):
{gratitude_full_with_dates}

PRIORITIES (All Items with Dates):
{priorities_full_with_dates}

TOMORROW NOTES (All Items with Dates):
{tomorrow_notes_full_with_dates}

=== SELF-CARE & HABITS ===
{self_care_summary}
{habit_analysis_data}

=== STATISTICS ===
Consistency Score: {consistency_score}%
Word Count Total: {word_count_total}
Top Topics: {top_topics_list}

=== ANALYSIS REQUEST ===
Based on the COMPLETE data above, provide a comprehensive monthly analysis in JSON format:

{
  "highlights": "10-12 line detailed paragraph discussing how main things impacted user's mood, next day behavior, emotional patterns, and overall journey. Reference specific dates and entries when relevant.",
  "growth_areas": ["4-6 specific growth areas based on actual entry patterns", ...],
  "achievements": ["4-6 achievements extracted from diary entries, affirmations, priorities, gratitude, and tomorrow notes. Reference specific dates/content", ...],
  "next_month_goals": ["4-6 actionable goals based on entry analysis", ...],
  "habit_analysis": ["4-6 points about habit patterns and correlations", ...],
  "key_moments": ["Notable events or moments from entries", ...],
  "reflection_questions": ["3-4 questions for next month reflection", ...],
  "strengths": ["3-4 strengths identified from entries", ...]
}

IMPORTANT:
- Extract achievements from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes)
- Reference specific dates and entry content when making points
- Make insights feel authentic and personalized
- All points should relate to actual entry data
- Be empathetic, encouraging, and actionable
```

### 1.4 Update API Call to Use JSON Format

**Current (line ~166):**
```typescript
body: JSON.stringify({
  model: 'gpt-4o-mini',
  messages: [
    { role: 'system', content: template.system_prompt },
    { role: 'user', content: userPrompt }
  ],
  temperature: template.temperature || 0.6,
  max_tokens: template.max_tokens || 500
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
  temperature: template.temperature || 0.6,
  max_tokens: template.max_tokens || 1200, // Increased for longer highlights
  response_format: { type: "json_object" }  // ADD THIS
})
```

### 1.5 Replace Parsing Logic

**Current (line ~200):**
```typescript
const { highlights, growthAreas, achievements, goals } = parseMonthlyInsight(insightText)
```

**New:**
```typescript
let highlights = ''
let growthAreas: string[] = []
let achievements: string[] = []
let goals: string[] = []
let habitAnalysis: string[] = []
let keyMoments: string[] = []
let reflectionQuestions: string[] = []
let strengths: string[] = []

try {
  const parsed = JSON.parse(insightText)
  highlights = parsed.highlights || ''
  growthAreas = Array.isArray(parsed.growth_areas) ? parsed.growth_areas : []
  achievements = Array.isArray(parsed.achievements) ? parsed.achievements : []
  goals = Array.isArray(parsed.next_month_goals) ? parsed.next_month_goals : []
  habitAnalysis = Array.isArray(parsed.habit_analysis) ? parsed.habit_analysis : []
  keyMoments = Array.isArray(parsed.key_moments) ? parsed.key_moments : []
  reflectionQuestions = Array.isArray(parsed.reflection_questions) ? parsed.reflection_questions : []
  strengths = Array.isArray(parsed.strengths) ? parsed.strengths : []
  
  // Validate required fields
  if (!highlights || growthAreas.length === 0) {
    throw new Error('Invalid JSON structure from AI')
  }
} catch (parseError) {
  // Fallback: Try old parsing method if JSON fails
  console.warn('JSON parsing failed, falling back to text parsing:', parseError)
  const parsed = parseMonthlyInsight(insightText)
  highlights = parsed.highlights || insightText
  growthAreas = parsed.growthAreas
  achievements = parsed.achievements
  goals = parsed.goals
  // Set defaults for new fields
  habitAnalysis = []
  keyMoments = []
  reflectionQuestions = []
  strengths = []
}
```

### 1.6 Update Habit Analysis Structure

**Current (line ~114):**
```typescript
const habitAnalysis = {
  mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
  self_care_completion: selfCareRates.completionRate,
  consistency: parseFloat(consistencyScore.toFixed(2))
}
```

**New:** Keep numeric data, but AI will provide text analysis points
```typescript
// Keep numeric data for calculations
const habitAnalysisNumeric = {
  mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
  self_care_completion: selfCareRates.completionRate,
  consistency: parseFloat(consistencyScore.toFixed(2))
}

// AI will provide habitAnalysis array (text points) in JSON response
// Store both: numeric in habit_analysis jsonb, text points in separate field or within jsonb
```

**Update upsert (line ~207):**
```typescript
habit_analysis: {
  ...habitAnalysisNumeric,
  analysis_points: habitAnalysis // Add AI-generated text points
}
```

### 1.7 Update Upsert to Save All Fields

**Current upsert (line ~207):**
```typescript
.upsert({
  user_id: user_id,
  month_start: month_start,
  mood_avg: avgMood ? parseFloat(avgMood) : null,
  entries_count: entries.length,
  word_count_total: wordCountTotal,
  top_topics: topics.slice(0, 10),
  monthly_highlights: highlights,
  growth_areas: growthAreas,
  achievements: achievements,
  next_month_goals: goals,
  consistency_score: parseFloat(consistencyScore.toFixed(2)),
  habit_analysis: habitAnalysis,
  mood_trend_monthly: moodTrend,
  model_version: 'gpt-4o-mini',
  cost_tokens_prompt: tokensUsed.prompt,
  cost_tokens_completion: tokensUsed.completion,
  status: 'success',
  generated_at: new Date().toISOString()
})
```

**New:**
```typescript
.upsert({
  user_id: user_id,
  month_start: month_start,
  mood_avg: avgMood ? parseFloat(avgMood) : null,
  entries_count: entries.length,
  word_count_total: wordCountTotal,
  top_topics: topics.slice(0, 7), // 5-7 topics as requested
  monthly_highlights: highlights,
  growth_areas: growthAreas.slice(0, 6), // 4-6 points
  achievements: achievements.slice(0, 6), // 4-6 points
  next_month_goals: goals.slice(0, 6), // 4-6 points
  consistency_score: parseFloat(consistencyScore.toFixed(2)),
  habit_analysis: {
    ...habitAnalysisNumeric,
    analysis_points: habitAnalysis.slice(0, 6) // 4-6 points
  },
  mood_trend_monthly: moodTrend,
  key_moments: keyMoments, // NEW
  reflection_questions: reflectionQuestions, // NEW
  strengths: strengths, // NEW
  model_version: 'gpt-4o-mini',
  cost_tokens_prompt: tokensUsed.prompt,
  cost_tokens_completion: tokensUsed.completion,
  status: 'success',
  generated_at: new Date().toISOString()
})
```

### 1.8 Build Data Strings for Prompt

Add helper functions to format data for prompt:

```typescript
// Format diary entries with dates
function formatDiaryEntries(entries: any[]): string {
  return entries.map(e => {
    const date = new Date(e.entry_date).toLocaleDateString()
    return `[${date}] ${e.diary_text || 'No text'} (Mood: ${e.mood_score || 'N/A'}/5)`
  }).join('\n\n')
}

// Format structured data (affirmations, gratitude, etc.)
function formatStructuredData(data: any[], type: string): string {
  if (!data || data.length === 0) return `No ${type} data available.`
  
  return data.map(item => {
    const entry = entries.find(e => e.id === item.entry_id)
    const date = entry ? new Date(entry.entry_date).toLocaleDateString() : 'Unknown date'
    const items = item.affirmations || item.priorities || item.grateful_items || item.tomorrow_notes || []
    return `[${date}]: ${Array.isArray(items) ? items.join(', ') : JSON.stringify(items)}`
  }).join('\n')
}
```

---

## Phase 2: Flutter Model Updates

### 2.1 Update MonthlyInsight Model (`lib/services/ai_service.dart`)

**Current (line ~468):**
```dart
class MonthlyInsight {
  final String id;
  final String userId;
  final DateTime monthStart;
  final double? moodAvg;
  final int entriesCount;
  final int wordCountTotal;
  final List<String> topTopics;
  final String monthlyHighlights;
  final List<String> growthAreas;
  final List<String> achievements;
  final List<String> nextMonthGoals;
  final double? consistencyScore;
  final String? moodTrendMonthly;
  final DateTime generatedAt;
  // ...
}
```

**New:**
```dart
class MonthlyInsight {
  final String id;
  final String userId;
  final DateTime monthStart;
  final double? moodAvg;
  final int entriesCount;
  final int wordCountTotal;
  final List<String> topTopics;
  final String monthlyHighlights; // Now 10-12 lines
  final List<String> growthAreas; // 4-6 points
  final List<String> achievements; // 4-6 points
  final List<String> nextMonthGoals; // 4-6 points
  final double? consistencyScore;
  final String? moodTrendMonthly;
  final Map<String, dynamic>? habitAnalysis; // Contains numeric + analysis_points
  final List<String> keyMoments; // NEW
  final List<String> reflectionQuestions; // NEW
  final List<String> strengths; // NEW
  final DateTime generatedAt;
  // ...
}
```

### 2.2 Update fromJson in getMonthlyInsight

**Current (line ~395):**
```dart
return MonthlyInsight(
  id: response['id'] as String,
  userId: userId,
  monthStart: monthStart,
  moodAvg: (response['mood_avg'] as num?)?.toDouble(),
  entriesCount: response['entries_count'] as int? ?? 0,
  wordCountTotal: response['word_count_total'] as int? ?? 0,
  topTopics: (response['top_topics'] as List<dynamic>?)?.cast<String>() ?? [],
  monthlyHighlights: response['monthly_highlights'] as String? ?? '',
  growthAreas: (response['growth_areas'] as List<dynamic>?)?.cast<String>() ?? [],
  achievements: (response['achievements'] as List<dynamic>?)?.cast<String>() ?? [],
  nextMonthGoals: (response['next_month_goals'] as List<dynamic>?)?.cast<String>() ?? [],
  consistencyScore: (response['consistency_score'] as num?)?.toDouble(),
  moodTrendMonthly: response['mood_trend_monthly'] as String?,
  generatedAt: DateTime.parse(response['generated_at'] as String),
);
```

**New:**
```dart
// Parse habit_analysis
final habitAnalysisRaw = response['habit_analysis'];
Map<String, dynamic>? habitAnalysisMap;
if (habitAnalysisRaw != null) {
  if (habitAnalysisRaw is Map) {
    habitAnalysisMap = Map<String, dynamic>.from(habitAnalysisRaw);
  } else if (habitAnalysisRaw is String) {
    try {
      habitAnalysisMap = Map<String, dynamic>.from(jsonDecode(habitAnalysisRaw));
    } catch (e) {
      habitAnalysisMap = null;
    }
  }
}

return MonthlyInsight(
  id: response['id'] as String,
  userId: userId,
  monthStart: monthStart,
  moodAvg: (response['mood_avg'] as num?)?.toDouble(),
  entriesCount: response['entries_count'] as int? ?? 0,
  wordCountTotal: response['word_count_total'] as int? ?? 0,
  topTopics: (response['top_topics'] as List<dynamic>?)?.cast<String>() ?? [],
  monthlyHighlights: response['monthly_highlights'] as String? ?? '',
  growthAreas: (response['growth_areas'] as List<dynamic>?)?.cast<String>() ?? [],
  achievements: (response['achievements'] as List<dynamic>?)?.cast<String>() ?? [],
  nextMonthGoals: (response['next_month_goals'] as List<dynamic>?)?.cast<String>() ?? [],
  consistencyScore: (response['consistency_score'] as num?)?.toDouble(),
  moodTrendMonthly: response['mood_trend_monthly'] as String?,
  habitAnalysis: habitAnalysisMap,
  keyMoments: (response['key_moments'] as List<dynamic>?)?.cast<String>() ?? [],
  reflectionQuestions: (response['reflection_questions'] as List<dynamic>?)?.cast<String>() ?? [],
  strengths: (response['strengths'] as List<dynamic>?)?.cast<String>() ?? [],
  generatedAt: DateTime.parse(response['generated_at'] as String),
);
```

---

## Phase 3: UI Updates (`lib/screens/analytics_screen.dart`)

### 3.1 Update Monthly Section Display

**Current:** Basic display of highlights, growth areas, achievements, goals

**New Structure:**
1. **Motivational Message** (if no data): Already exists, keep as is
2. **10-12 Line Highlight** (detailed paragraph): Display in expanded card
3. **Stats Row**: Mood avg, Entries count, Word count, Consistency score
4. **Top Topics** (5-7): Display as chips/tags
5. **Strengths** (3-4): New section
6. **Achievements** (4-6): Enhanced with entry references
7. **Growth Areas** (4-6): Enhanced display
8. **Habit Analysis** (4-6 points): Extract from habit_analysis.analysis_points
9. **Key Moments** (notable events): New section
10. **Next Month Goals** (4-6): Enhanced display
11. **Reflection Questions** (3-4): New section
12. **Mood Trend**: Visual indicator

### 3.2 Create Monthly Insight Widgets

Create reusable widgets:
- `MonthlyHighlightCard` - For 10-12 line highlight
- `MonthlyStatsRow` - For mood, entries, words, consistency
- `MonthlySectionCard` - Generic card for sections (achievements, growth, etc.)
- `MonthlyTopicChips` - For top topics display
- `MonthlyHabitAnalysisCard` - For habit analysis points

---

## Phase 4: Testing Checklist

- [ ] Edge function generates JSON response
- [ ] All entry types (affirmations, priorities, gratitude, tomorrow notes) are fetched
- [ ] AI references actual entry dates/content in insights
- [ ] All new fields (key_moments, reflection_questions, strengths) are saved
- [ ] Habit analysis contains both numeric and text points
- [ ] Flutter model parses all fields correctly
- [ ] UI displays all sections properly
- [ ] Motivational message shows when no data
- [ ] 10-12 line highlight displays correctly
- [ ] Top topics limited to 5-7
- [ ] All arrays limited to specified counts (4-6 points)

---

## Phase 5: Prompt Template in Database

Update `ai_prompt_templates` table for monthly analysis:

```sql
UPDATE ai_prompt_templates
SET 
  system_prompt = 'New system prompt...',
  user_prompt_template = 'New user prompt template...',
  max_tokens = 1200,
  temperature = 0.6
WHERE analysis_type = 'monthly' AND is_active = true;
```

Or insert new template if doesn't exist.

---

## Notes

- **Authenticity**: AI must reference actual entry dates and content
- **Entry-based**: All achievements must come from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes)
- **JSON Format**: Use JSON for reliable parsing (like weekly)
- **Backward Compatible**: Fallback to text parsing if JSON fails
- **UI Later**: Past month navigation and other UI features to be added later

