import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logAIError } from '../_shared/ai_error_logger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
  user_id: string
  week_start: string // YYYY-MM-DD format
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()
  let requestStatus = 'success'
  let errorMessage: string | null = null
  let tokensUsed = { prompt: 0, completion: 0, total: 0 }

  try {
    const { user_id, week_start }: RequestBody = await req.json()

    if (!user_id || !week_start) {
      throw new Error('user_id and week_start are required')
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const openaiApiKey = Deno.env.get('OPENAI_API_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    if (!openaiApiKey) {
      throw new Error('OPENAI_API_KEY not set')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Parse week_start and calculate week_end
    const weekStartDate = new Date(week_start)
    const weekEndDate = new Date(weekStartDate)
    weekEndDate.setDate(weekEndDate.getDate() + 6)
    const weekEnd = weekEndDate.toISOString().split('T')[0]

    // 1. Check if weekly insight already exists
    const { data: existingInsight } = await supabase
      .from('weekly_insights')
      .select('id, status')
      .eq('user_id', user_id)
      .eq('week_start', week_start)
      .eq('status', 'success')
      .single()

    if (existingInsight) {
      return new Response(
        JSON.stringify({ success: true, message: 'Weekly insight already exists', week_start }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Fetch all entries for the week
    const { data: entries, error: entriesError } = await supabase
      .from('entries')
      .select('id, diary_text, mood_score, entry_date, created_at')
      .eq('user_id', user_id)
      .gte('entry_date', week_start)
      .lte('entry_date', weekEnd)
      .order('entry_date', { ascending: true })

    if (entriesError) {
      throw new Error(`Failed to fetch entries: ${entriesError.message}`)
    }

    if (!entries || entries.length < 1) {
      throw new Error('No entries found for this week')
    }

    // 3. Aggregate data
    const moodScores = entries.map(e => e.mood_score).filter(Boolean) as number[]
    const avgMood = moodScores.length > 0
      ? (moodScores.reduce((a, b) => a + b, 0) / moodScores.length).toFixed(2)
      : null

    // Calculate mood trend
    const moodTrend = calculateMoodTrend(moodScores)

    // Calculate self-care rates
    const entryIds = entries.map(e => e.id)
    
    // Fetch all related data in parallel for performance
    const [
      selfCareResult,
      mealsResult,
      dailyInsightsResult,
      affirmationsResult,
      gratitudeResult,
      prioritiesResult,
      tomorrowNotesResult,
      showerBathResult
    ] = await Promise.all([
      supabase.from('entry_self_care').select('*').in('entry_id', entryIds),
      supabase.from('entry_meals').select('entry_id, water_cups, breakfast, lunch, dinner').in('entry_id', entryIds),
      supabase.from('entry_insights').select('entry_id, insight_text, sentiment_label, insight_details, topics').in('entry_id', entryIds).eq('status', 'success').order('processed_at', { ascending: true }),
      supabase.from('entry_affirmations').select('entry_id, affirmations').in('entry_id', entryIds),
      supabase.from('entry_gratitude').select('entry_id, grateful_items').in('entry_id', entryIds),
      supabase.from('entry_priorities').select('entry_id, priorities').in('entry_id', entryIds),
      supabase.from('entry_tomorrow_notes').select('entry_id, tomorrow_notes').in('entry_id', entryIds),
      supabase.from('entry_shower_bath').select('entry_id, took_shower, shower_note').in('entry_id', entryIds)
    ])

    const selfCareData = selfCareResult.data || []
    const mealsData = mealsResult.data || []
    const dailyInsights = dailyInsightsResult.data || []
    const affirmationsData = affirmationsResult.data || []
    const gratitudeData = gratitudeResult.data || []
    const prioritiesData = prioritiesResult.data || []
    const tomorrowNotesData = tomorrowNotesResult.data || []
    const showerBathData = showerBathResult.data || []

    const selfCareRates = calculateSelfCareRate(selfCareData, entries.length)

    const cupsTotal = mealsData?.reduce((sum, m) => sum + (m.water_cups || 0), 0) || 0
    const cupsAvg = entries.length > 0 ? (cupsTotal / entries.length).toFixed(1) : '0'

    // Extract topics from all entries
    const topics = extractTopics(entries)

    // Calculate consistency
    const consistencyScore = (entries.length / 7) * 100

    // Word count total
    const wordCountTotal = entries.reduce((sum, e) => sum + (e.diary_text?.split(/\s+/).length || 0), 0)

    // 4. Build enhanced habit correlations
    const gratitudeDays = gratitudeData.filter(g => 
      g.grateful_items && Array.isArray(g.grateful_items) && g.grateful_items.length > 0
    ).length

    const affirmationDays = affirmationsData.filter(a => 
      a.affirmations && Array.isArray(a.affirmations) && a.affirmations.length > 0
    ).length

    const sentimentCounts = {
      positive: dailyInsights.filter(i => i.sentiment_label === 'positive').length,
      neutral: dailyInsights.filter(i => i.sentiment_label === 'neutral').length,
      negative: dailyInsights.filter(i => i.sentiment_label === 'negative').length
    }

    const habitCorrelations = {
      mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
      self_care_completion: selfCareRates.completionRate,
      mood_vs_gratitude: gratitudeDays > 0 ? (avgMood ? parseFloat(avgMood) : null) : null,
      mood_vs_affirmations: affirmationDays > 0 ? (avgMood ? parseFloat(avgMood) : null) : null,
      sentiment_distribution: sentimentCounts,
      consistency_impact: consistencyScore > 70 ? 'high' : consistencyScore > 50 ? 'medium' : 'low'
    }

    // 5. Build full data strings (NO TRUNCATION - Premium Edition)
    
    // Build full daily insights with all details
    let dailyInsightsFull = ''
    if (dailyInsights.length > 0) {
      dailyInsightsFull = dailyInsights.map((insight, index) => {
        const entry = entries.find(e => e.id === insight.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        const sentiment = insight.sentiment_label || 'neutral'
        const text = insight.insight_text || 'No insight available'
        const details = insight.insight_details || {}
        const topics = insight.topics || []
        
        return `Day ${index + 1} (${date}, ${sentiment}):
Main Insight: ${text}
What Went Well: ${details.what_went_well || 'N/A'}
Progress Area: ${details.progress_area || 'N/A'}
Self-Care Balance: ${details.self_care_balance || 'N/A'}
Emotional Pattern: ${details.emotional_pattern || 'N/A'}
Topics: ${topics.join(', ') || 'None'}`
      }).join('\n\n---\n\n')
    } else {
      dailyInsightsFull = 'No daily insights available for this week'
    }

    // Build full affirmations (all items)
    let affirmationsFull = ''
    if (affirmationsData.length > 0) {
      affirmationsFull = affirmationsData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        const affirmations = item.affirmations || []
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}): ${affirmations.length > 0 ? affirmations.join(' | ') : 'None'}`
      }).join('\n')
    } else {
      affirmationsFull = 'No affirmations recorded this week'
    }

    // Build full gratitude (all items)
    let gratitudeFull = ''
    if (gratitudeData.length > 0) {
      gratitudeFull = gratitudeData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        const items = item.grateful_items || []
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}): ${items.length > 0 ? items.join(' | ') : 'None'}`
      }).join('\n')
    } else {
      gratitudeFull = 'No gratitude items recorded this week'
    }

    // Build full priorities (all items)
    let prioritiesFull = ''
    if (prioritiesData.length > 0) {
      prioritiesFull = prioritiesData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        const priorities = item.priorities || []
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}): ${priorities.length > 0 ? priorities.join(' | ') : 'None'}`
      }).join('\n')
    } else {
      prioritiesFull = 'No priorities recorded this week'
    }

    // Build full diary text (NO TRUNCATION)
    const diaryFull = entries.map((entry, index) => {
      const text = entry.diary_text || 'No diary text'
      return `Day ${index + 1} (${entry.entry_date}, Mood: ${entry.mood_score || 'N/A'}):
${text}`
    }).join('\n\n---\n\n')

    // Build full self-care details
    let selfCareFull = ''
    if (selfCareData.length > 0) {
      const selfCareActivities = ['exercise', 'meditation', 'reading', 'hobby', 'social', 'nature', 'music', 'rest', 'nutrition', 'hygiene']
      selfCareFull = selfCareData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        const activities = selfCareActivities.filter(activity => item[activity] === true)
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}): ${activities.length > 0 ? activities.join(', ') : 'None'}`
      }).join('\n')
    } else {
      selfCareFull = 'No self-care activities recorded this week'
    }

    // Build full meal details
    let mealsFull = ''
    if (mealsData.length > 0) {
      mealsFull = mealsData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}):
Breakfast: ${item.breakfast || 'Not logged'}
Lunch: ${item.lunch || 'Not logged'}
Dinner: ${item.dinner || 'Not logged'}
Water: ${item.water_cups || 0} cups`
      }).join('\n\n')
    } else {
      mealsFull = 'No meal data recorded this week'
    }

    // Build tomorrow notes
    let tomorrowNotesFull = ''
    if (tomorrowNotesData.length > 0) {
      tomorrowNotesFull = tomorrowNotesData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        const notes = item.tomorrow_notes || ''
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}): ${notes || 'No notes'}`
      }).join('\n\n')
    } else {
      tomorrowNotesFull = 'No tomorrow notes recorded this week'
    }

    // Build shower/bath details
    let showerBathFull = ''
    if (showerBathData.length > 0) {
      showerBathFull = showerBathData.map((item) => {
        const entry = entries.find(e => e.id === item.entry_id)
        const date = entry ? entry.entry_date : 'Unknown'
        return `Day ${entries.findIndex(e => e.id === item.entry_id) + 1} (${date}): ${item.took_shower ? 'Yes' : 'No'}${item.shower_note ? ` - ${item.shower_note}` : ''}`
      }).join('\n')
    } else {
      showerBathFull = 'No shower/bath data recorded this week'
    }

    // 6. Get prompt template
    let template = null
    const { data: templateData } = await supabase
      .from('ai_prompt_templates')
      .select('*')
      .eq('analysis_type', 'weekly')
      .eq('is_active', true)
      .single()

    if (templateData) {
      template = templateData
    } else {
      // Fallback template (Premium Edition - Full Data)
      template = {
        system_prompt: 'You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. You analyze weekly journal entries, daily insights, affirmations, gratitude, and priorities to provide deep, personalized insights. Focus on:\n\n1. Emotional patterns and mood trends\n2. Habit correlations and their impact on well-being\n3. Recurring themes in affirmations, gratitude, and priorities\n4. Actionable recommendations based on patterns\n5. Celebrating progress and identifying growth areas\n\nBe empathetic, specific, and actionable. Use the daily insights and structured data to provide context-rich analysis.',
        user_prompt_template: `WEEKLY ANALYSIS REQUEST (PREMIUM)
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

=== COMPLETE DAILY INSIGHTS (ALL DETAILS) ===
{daily_insights_full}

=== COMPLETE DIARY ENTRIES (FULL TEXT) ===
{diary_full}

=== COMPLETE STRUCTURED DATA (ALL ITEMS) ===
AFFIRMATIONS (All Items):
{affirmations_full}

GRATITUDE (All Items):
{gratitude_full}

PRIORITIES (All Items):
{priorities_full}

=== COMPLETE SELF-CARE DETAILS ===
{self_care_full}

=== COMPLETE MEAL DETAILS ===
{meals_full}

=== TOMORROW NOTES ===
{tomorrow_notes_full}

=== SHOWER/BATH DETAILS ===
{shower_bath_full}

=== HABIT & CONSISTENCY SUMMARY ===
Self-Care Completion Rate: {self_care_summary}
Water Intake Average: {cups_avg} cups/day
Consistency Score: {consistency_score}%
Entries Count: {entries_count}/7

=== HABIT CORRELATIONS ===
{habit_correlations}

=== TOPICS MENTIONED ===
{weekly_topics}

=== ANALYSIS REQUEST ===
Based on the above COMPREHENSIVE and COMPLETE data, provide a deep, personalized weekly analysis:

1. **Weekly Highlights** (3-4 sentences):
   - Overall mood pattern and emotional journey across the week
   - Key positive moments, achievements, or breakthroughs
   - Notable patterns, trends, or shifts in behavior/emotions
   - Connection between different aspects (mood, habits, gratitude, etc.)

2. **Key Insights** (4-5 specific insights):
   - Insight 1: Deep emotional pattern or mood correlation
   - Insight 2: Habit correlation and its impact on well-being
   - Insight 3: Theme or pattern from affirmations/gratitude/priorities
   - Insight 4: Connection between self-care activities and mood/energy
   - Insight 5: Pattern in meal habits, planning (tomorrow notes), or routines

3. **Recommendations** (3 actionable items):
   - Recommendation 1: Specific action based on strongest pattern identified
   - Recommendation 2: Habit to strengthen or area to focus based on correlations
   - Recommendation 3: Area for growth or improvement based on complete data analysis

Format your response clearly with sections labeled "Highlights:", "Key Insights:", and "Recommendations:". 
- Be specific and reference actual data from the entries (dates, specific activities, patterns)
- Connect different aspects of the data (e.g., "On days when you practiced gratitude, your mood was higher")
- Be empathetic, encouraging, and actionable
- Total response should be 300-400 words (premium depth)`,
        temperature: 0.5,
        max_tokens: 800
      }
    }

    // 7. Build final prompt (Premium Edition - All Variables)
    const moodScoresStr = moodScores.length > 0 
      ? moodScores.map((m, i) => `Day ${i + 1}: ${m}`).join(', ')
      : 'No mood data'
    
    const selfCareSummary = `Completed ${selfCareRates.completedDays}/7 days with self-care activities`
    
    const userPrompt = template.user_prompt_template
      .replace('{week_start}', week_start)
      .replace('{week_end}', weekEnd)
      .replace('{entries_count}', entries.length.toString())
      .replace('{avg_mood}', avgMood || 'N/A')
      .replace('{mood_scores}', moodScoresStr)
      .replace('{mood_trend}', moodTrend)
      .replace('{sentiment_distribution}', JSON.stringify(sentimentCounts))
      .replace('{positive_count}', sentimentCounts.positive.toString())
      .replace('{neutral_count}', sentimentCounts.neutral.toString())
      .replace('{negative_count}', sentimentCounts.negative.toString())
      .replace('{daily_insights_full}', dailyInsightsFull)
      .replace('{diary_full}', diaryFull)
      .replace('{affirmations_full}', affirmationsFull)
      .replace('{gratitude_full}', gratitudeFull)
      .replace('{priorities_full}', prioritiesFull)
      .replace('{self_care_full}', selfCareFull)
      .replace('{meals_full}', mealsFull)
      .replace('{tomorrow_notes_full}', tomorrowNotesFull)
      .replace('{shower_bath_full}', showerBathFull)
      .replace('{self_care_summary}', selfCareSummary)
      .replace('{cups_avg}', cupsAvg)
      .replace('{consistency_score}', consistencyScore.toFixed(2))
      .replace('{weekly_topics}', topics.slice(0, 10).join(', ') || 'None')
      .replace('{habit_correlations}', JSON.stringify(habitCorrelations))

    // 8. Call OpenAI
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: template.system_prompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: template.temperature || 0.5,
        max_tokens: template.max_tokens || 800
      })
    })

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.json()
      throw new Error(`OpenAI API error: ${openaiResponse.status} - ${errorData.error?.message || 'Unknown error'}`)
    }

    const aiData = await openaiResponse.json()
    const insightText = aiData.choices[0]?.message?.content?.trim() || ''
    tokensUsed = {
      prompt: aiData.usage?.prompt_tokens || 0,
      completion: aiData.usage?.completion_tokens || 0,
      total: aiData.usage?.total_tokens || 0
    }

    if (!insightText) {
      throw new Error('Empty response from OpenAI')
    }

    // 9. Parse insight into structured format
    const { insights, recommendations } = parseWeeklyInsight(insightText)

    // 10. Calculate cost
    const costUsd = (tokensUsed.prompt / 1000000) * 0.15 + (tokensUsed.completion / 1000000) * 0.60

    // 11. Save to weekly_insights
    const { error: insightError } = await supabase
      .from('weekly_insights')
      .upsert({
        user_id: user_id,
        week_start: week_start,
        week_end: weekEnd,
        mood_avg: avgMood ? parseFloat(avgMood) : null,
        cups_avg: parseFloat(cupsAvg),
        self_care_rate: selfCareRates.completionRate,
        top_topics: topics.slice(0, 10),
        highlights: insightText,
        ai_generated: true,
        mood_trend: moodTrend,
        key_insights: insights,
        recommendations: recommendations,
        habit_correlations: habitCorrelations,
        consistency_score: parseFloat(consistencyScore.toFixed(2)),
        entries_count: entries.length,
        word_count_total: wordCountTotal,
        model_version: 'gpt-4o-mini',
        cost_tokens_prompt: tokensUsed.prompt,
        cost_tokens_completion: tokensUsed.completion,
        status: 'success',
        generated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,week_start'
      })

    if (insightError) {
      console.error('Error saving weekly insight:', insightError)
    }

    // 12. Log request
    const duration = Date.now() - startTime
    await supabase
      .from('ai_requests_log')
      .insert({
        user_id: user_id,
        entry_id: null,
        analysis_type: 'weekly',
        prompt_tokens: tokensUsed.prompt,
        completion_tokens: tokensUsed.completion,
        total_tokens: tokensUsed.total,
        cost_usd: costUsd,
        model_used: 'gpt-4o-mini',
        status: 'success',
        request_duration_ms: duration
      })

    return new Response(
      JSON.stringify({
        success: true,
        week_start,
        week_end: weekEnd,
        insight_text: insightText,
        tokens_used: tokensUsed.total,
        cost_usd: costUsd
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    requestStatus = 'error'
    errorMessage = error instanceof Error ? error.message : 'Unknown error'
    const duration = Date.now() - startTime

    // Try to log the error to comprehensive error table
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey)
        const body = await req.json().catch(() => ({}))
        
        // Log to comprehensive ai_errors_log table
        await logAIError(supabase, error, {
          userId: user_id || body.user_id,
          entryId: null,
          analysisType: 'weekly',
          errorCode: 'ERRAI_WEEKLY_001',
          requestBody: { user_id: user_id || body.user_id, week_start: week_start || body.week_start },
          requestDurationMs: duration,
          edgeFunctionName: 'ai-analyze-weekly',
          failedAtStep: 'unknown',
        })
        
        // Also log to ai_requests_log (existing)
        await supabase
          .from('ai_requests_log')
          .insert({
            user_id: user_id || body.user_id || 'unknown',
            entry_id: null,
            analysis_type: 'weekly',
            prompt_tokens: 0,
            completion_tokens: 0,
            total_tokens: 0,
            cost_usd: 0,
            model_used: 'gpt-4o-mini',
            status: 'error',
            error_message: errorMessage,
            request_duration_ms: duration
          })

        // Also log error to weekly_insights
        if ((week_start || body.week_start) && (user_id || body.user_id)) {
          await supabase
            .from('weekly_insights')
            .upsert({
              user_id: user_id || body.user_id,
              week_start: week_start || body.week_start,
              status: 'error',
              error_message: errorMessage
            }, {
              onConflict: 'user_id,week_start'
            })
        }
      }
    } catch (logError) {
      console.error('Failed to log error:', logError)
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage
      }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

// Helper: Calculate mood trend
function calculateMoodTrend(moodScores: number[]): string {
  if (moodScores.length < 2) return 'stable'
  
  const firstHalf = moodScores.slice(0, Math.ceil(moodScores.length / 2))
  const secondHalf = moodScores.slice(Math.ceil(moodScores.length / 2))
  
  const firstAvg = firstHalf.reduce((a, b) => a + b, 0) / firstHalf.length
  const secondAvg = secondHalf.reduce((a, b) => a + b, 0) / secondHalf.length
  
  const diff = secondAvg - firstAvg
  if (diff > 0.3) return 'improving'
  if (diff < -0.3) return 'declining'
  if (Math.abs(secondAvg - firstAvg) < 0.5 && Math.max(...secondHalf) - Math.min(...secondHalf) > 1.5) {
    return 'volatile'
  }
  return 'stable'
}

// Helper: Calculate self-care completion rate
function calculateSelfCareRate(selfCareData: any[], totalDays: number): { completedDays: number; completionRate: number } {
  const completedDays = selfCareData.filter(sc => {
    const values = Object.values(sc).filter(v => v === true)
    return values.length > 0
  }).length
  
  return {
    completedDays,
    completionRate: totalDays > 0 ? parseFloat(((completedDays / totalDays) * 100).toFixed(2)) : 0
  }
}

// Helper: Extract topics from entries
function extractTopics(entries: any[]): string[] {
  const words: { [key: string]: number } = {}
  
  entries.forEach(entry => {
    if (entry.diary_text) {
      const text = entry.diary_text.toLowerCase()
      const wordList = text.split(/\s+/)
        .filter(w => w.length > 4)
        .filter(w => !['today', 'yesterday', 'feeling', 'think', 'about', 'really', 'would', 'could', 'should', 'things', 'going', 'something', 'nothing'].includes(w))
        .slice(0, 20)
      
      wordList.forEach(word => {
        words[word] = (words[word] || 0) + 1
      })
    }
  })
  
  return Object.entries(words)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([word]) => word)
}

// Helper: Parse weekly insight text into structured format (Premium Edition - 4-5 insights, 3 recommendations)
function parseWeeklyInsight(text: string): { insights: string[]; recommendations: string[] } {
  const insights: string[] = []
  const recommendations: string[] = []
  
  // Look for section headers
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0)
  
  let currentSection = 'highlights'
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    
    // Detect section headers
    if (line.toLowerCase().includes('highlights:')) {
      currentSection = 'highlights'
      continue
    }
    if (line.toLowerCase().includes('key insights:') || line.toLowerCase().includes('insights:')) {
      currentSection = 'insights'
      continue
    }
    if (line.toLowerCase().includes('recommendations:') || line.toLowerCase().includes('recommend')) {
      currentSection = 'recommendations'
      continue
    }
    
    // Extract numbered or bulleted items
    const match = line.match(/^[0-9]+\.\s*(.+)|^[-•]\s*(.+)|^Insight\s+[0-9]+:\s*(.+)|^Recommendation\s+[0-9]+:\s*(.+)|^(.+)/)
    if (match) {
      const item = match[1] || match[2] || match[3] || match[4] || match[5]
      if (item && item.length > 10) {
        if (currentSection === 'recommendations') {
          recommendations.push(item)
        } else if (currentSection === 'insights') {
          insights.push(item)
        }
        // Skip highlights section items
      }
    }
  }
  
  // Fallback: if no structured data, try to extract from paragraphs
  if (insights.length === 0 && recommendations.length === 0) {
    const paragraphs = text.split(/\n\n+/).filter(p => p.trim().length > 20)
    // First few paragraphs as insights, last as recommendations
    insights.push(...paragraphs.slice(0, 4).map(p => p.trim()))
    if (paragraphs.length > 4) {
      recommendations.push(...paragraphs.slice(-3).map(p => p.trim()))
    }
  }
  
  return {
    insights: insights.slice(0, 5), // Premium: up to 5 insights
    recommendations: recommendations.slice(0, 3) // Premium: up to 3 recommendations
  }
}

