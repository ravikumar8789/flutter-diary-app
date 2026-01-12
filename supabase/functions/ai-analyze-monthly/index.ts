import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logAIError } from '../_shared/ai_error_logger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
  user_id: string
  month_start: string // YYYY-MM-DD format (first day of month)
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()
  let requestStatus = 'success'
  let errorMessage: string | null = null
  let tokensUsed = { prompt: 0, completion: 0, total: 0 }
  let user_id: string | undefined = undefined
  let month_start: string | undefined = undefined

  try {
    const bodyData: RequestBody = await req.json()
    user_id = bodyData.user_id
    month_start = bodyData.month_start

    if (!user_id || !month_start) {
      throw new Error('user_id and month_start are required')
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

    // Parse month_start and calculate month_end
    const monthStartDate = new Date(month_start)
    const monthEndDate = new Date(monthStartDate.getFullYear(), monthStartDate.getMonth() + 1, 0)
    const monthEnd = monthEndDate.toISOString().split('T')[0]
    const monthName = monthStartDate.toLocaleString('default', { month: 'long', year: 'numeric' })
    const totalDaysInMonth = monthEndDate.getDate()

    // 1. Check if monthly insight already exists
    const { data: existingInsight } = await supabase
      .from('monthly_insights')
      .select('id, status')
      .eq('user_id', user_id)
      .eq('month_start', month_start)
      .eq('status', 'success')
      .single()

    if (existingInsight) {
      return new Response(
        JSON.stringify({ success: true, message: 'Monthly insight already exists', month_start }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Fetch all entries for the month
    const { data: entries, error: entriesError } = await supabase
      .from('entries')
      .select('id, diary_text, mood_score, entry_date, created_at')
      .eq('user_id', user_id)
      .gte('entry_date', month_start)
      .lte('entry_date', monthEnd)
      .order('entry_date', { ascending: true })

    if (entriesError) {
      throw new Error(`Failed to fetch entries: ${entriesError.message}`)
    }

    if (!entries || entries.length < 10) {
      throw new Error(`Insufficient entries for monthly analysis. Found ${entries.length}, need at least 10.`)
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
    const { data: selfCareData } = await supabase
      .from('entry_self_care')
      .select('*')
      .in('entry_id', entryIds)

    const selfCareRates = calculateSelfCareRate(selfCareData || [], entries.length)

    // Fetch all entry-related data for comprehensive analysis
    const { data: affirmationsData } = await supabase
      .from('entry_affirmations')
      .select('entry_id, affirmations')
      .in('entry_id', entryIds)

    const { data: prioritiesData } = await supabase
      .from('entry_priorities')
      .select('entry_id, priorities')
      .in('entry_id', entryIds)

    const { data: gratitudeData } = await supabase
      .from('entry_gratitude')
      .select('entry_id, grateful_items')
      .in('entry_id', entryIds)

    const { data: tomorrowNotesData } = await supabase
      .from('entry_tomorrow_notes')
      .select('entry_id, tomorrow_notes')
      .in('entry_id', entryIds)

    // Extract topics from all entries (limit to 5-7)
    const topics = extractTopics(entries).slice(0, 7)

    // Calculate consistency
    const consistencyScore = (entries.length / totalDaysInMonth) * 100

    // Word count total
    const wordCountTotal = entries.reduce((sum, e) => sum + (e.diary_text?.split(/\s+/).length || 0), 0)

    // 4. Build habit analysis (numeric data - AI will provide text points)
    const habitAnalysisNumeric = {
      mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
      self_care_completion: selfCareRates.completionRate,
      consistency: parseFloat(consistencyScore.toFixed(2))
    }

    // Format mood scores for prompt
    const moodScoresList = moodScores.length > 0 
      ? moodScores.map((score, idx) => {
          const entry = entries[idx]
          const date = entry ? new Date(entry.entry_date).toLocaleDateString() : 'Unknown'
          return `${date}: ${score}/5`
        }).join(', ')
      : 'No mood data'

    // Format data for prompt
    const diaryEntriesFull = formatDiaryEntries(entries)
    const affirmationsFull = formatStructuredData(affirmationsData || [], entries, 'affirmations')
    const prioritiesFull = formatStructuredData(prioritiesData || [], entries, 'priorities')
    const gratitudeFull = formatStructuredData(gratitudeData || [], entries, 'gratitude')
    const tomorrowNotesFull = formatStructuredData(tomorrowNotesData || [], entries, 'tomorrow_notes')

    // 5. Get prompt template
    let template = null
    const { data: templateData } = await supabase
      .from('ai_prompt_templates')
      .select('*')
      .eq('analysis_type', 'monthly')
      .eq('is_active', true)
      .single()

    if (templateData) {
      template = templateData
    } else {
      // Fallback template
      template = {
        system_prompt: `You are an analytical but compassionate AI assistant that analyzes monthly journal data to provide deep, personalized insights. You analyze diary entries, affirmations, gratitude, priorities, and tomorrow notes to identify authentic patterns and achievements.

Focus on:
1. Emotional patterns and mood trends over the month
2. Authentic achievements extracted from actual entries (diary, affirmations, priorities, gratitude, tomorrow notes)
3. Habit correlations and their impact on well-being
4. Growth areas based on real patterns in the data
5. Actionable goals for next month based on entry analysis

Be specific, reference actual dates and entry content when possible. Make users feel their journey is truly understood.`,
        user_prompt_template: `MONTHLY ANALYSIS REQUEST
Month: {month_name}
Date Range: {month_start} to {month_end}
Entries Written: {entries_count}/{total_days}

=== MOOD & SENTIMENT ANALYSIS ===
Average Mood: {avg_mood}/5
Mood Trend: {mood_trend}
Mood Scores (Day by Day): {mood_scores_list}

=== COMPLETE DIARY ENTRIES (FULL TEXT WITH DATES) ===
{diary_entries_full}

=== COMPLETE STRUCTURED DATA ===
AFFIRMATIONS (All Items with Dates):
{affirmations_full}

GRATITUDE (All Items with Dates):
{gratitude_full}

PRIORITIES (All Items with Dates):
{priorities_full}

TOMORROW NOTES (All Items with Dates):
{tomorrow_notes_full}

=== SELF-CARE & HABITS ===
Self-Care Completion Rate: {self_care_completion}%
Consistency Score: {consistency_score}%

=== STATISTICS ===
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
- Be empathetic, encouraging, and actionable`,
        temperature: 0.6,
        max_tokens: 1200
      }
    }

    // 6. Build final prompt
    const userPrompt = template.user_prompt_template
      .replace('{month_name}', monthName)
      .replace('{month_start}', month_start)
      .replace('{month_end}', monthEnd)
      .replace('{entries_count}', entries.length.toString())
      .replace('{total_days}', totalDaysInMonth.toString())
      .replace('{avg_mood}', avgMood || 'N/A')
      .replace('{mood_trend}', moodTrend)
      .replace('{mood_scores_list}', moodScoresList)
      .replace('{diary_entries_full}', diaryEntriesFull)
      .replace('{affirmations_full}', affirmationsFull)
      .replace('{gratitude_full}', gratitudeFull)
      .replace('{priorities_full}', prioritiesFull)
      .replace('{tomorrow_notes_full}', tomorrowNotesFull)
      .replace('{self_care_completion}', selfCareRates.completionRate.toFixed(1))
      .replace('{consistency_score}', consistencyScore.toFixed(1))
      .replace('{word_count_total}', wordCountTotal.toString())
      .replace('{top_topics_list}', topics.join(', ') || 'None')

    // 7. Call OpenAI
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
        temperature: template.temperature || 0.6,
        max_tokens: template.max_tokens || 1200,
        response_format: { type: "json_object" }
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

    // 8. Parse JSON response
    let highlights = ''
    let growthAreas: string[] = []
    let achievements: string[] = []
    let goals: string[] = []
    let habitAnalysisPoints: string[] = []
    let keyMoments: string[] = []
    let reflectionQuestions: string[] = []
    let strengths: string[] = []

    try {
      const parsed = JSON.parse(insightText)
      highlights = parsed.highlights || ''
      growthAreas = Array.isArray(parsed.growth_areas) ? parsed.growth_areas : []
      achievements = Array.isArray(parsed.achievements) ? parsed.achievements : []
      goals = Array.isArray(parsed.next_month_goals) ? parsed.next_month_goals : []
      habitAnalysisPoints = Array.isArray(parsed.habit_analysis) ? parsed.habit_analysis : []
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
      habitAnalysisPoints = []
      keyMoments = []
      reflectionQuestions = []
      strengths = []
    }

    // 9. Calculate cost
    const costUsd = (tokensUsed.prompt / 1000000) * 0.15 + (tokensUsed.completion / 1000000) * 0.60

    // 10. Save to monthly_insights
    const { error: insightError } = await supabase
      .from('monthly_insights')
      .upsert({
        user_id: user_id,
        month_start: month_start,
        mood_avg: avgMood ? parseFloat(avgMood) : null,
        entries_count: entries.length,
        word_count_total: wordCountTotal,
        top_topics: topics.slice(0, 7), // 5-7 topics
        monthly_highlights: highlights,
        growth_areas: growthAreas.slice(0, 6), // 4-6 points
        achievements: achievements.slice(0, 6), // 4-6 points
        next_month_goals: goals.slice(0, 6), // 4-6 points
        consistency_score: parseFloat(consistencyScore.toFixed(2)),
        habit_analysis: {
          ...habitAnalysisNumeric,
          analysis_points: habitAnalysisPoints.slice(0, 6) // 4-6 points
        },
        mood_trend_monthly: moodTrend,
        key_moments: keyMoments,
        reflection_questions: reflectionQuestions,
        strengths: strengths,
        model_version: 'gpt-4o-mini',
        cost_tokens_prompt: tokensUsed.prompt,
        cost_tokens_completion: tokensUsed.completion,
        status: 'success',
        generated_at: new Date().toISOString()
      }, {
        onConflict: 'user_id,month_start'
      })

    if (insightError) {
      console.error('Error saving monthly insight:', insightError)
      await logAIError(supabase, insightError, {
        userId: user_id,
        entryId: null,
        analysisType: 'monthly',
        errorCode: 'ERRAI_MONTHLY_SAVE_001',
        requestBody: { user_id, month_start },
        requestDurationMs: Date.now() - startTime,
        edgeFunctionName: 'ai-analyze-monthly',
        failedAtStep: 'save_insight',
        errorDetails: { error: insightError.message, code: insightError.code }
      })
    }

    // 11. Log request
    const duration = Date.now() - startTime
    await supabase
      .from('ai_requests_log')
      .insert({
        user_id: user_id,
        entry_id: null,
        analysis_type: 'monthly',
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
        month_start,
        month_name: monthName,
        highlights: highlights,
        tokens_used: tokensUsed.total,
        cost_usd: costUsd
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    requestStatus = 'error'
    errorMessage = error instanceof Error ? error.message : 'Unknown error'
    const duration = Date.now() - startTime

    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey)
        
        // Try to get request body, but handle case where req.json() was already called
        let body: any = {}
        try {
          // Clone request if possible, otherwise use stored values
          if (user_id && month_start) {
            body = { user_id, month_start }
          } else {
            // Try to read from request if not already consumed
            const reqClone = req.clone()
            body = await reqClone.json().catch(() => ({}))
          }
        } catch {
          // If we can't read body, use stored values or empty object
          body = user_id && month_start ? { user_id, month_start } : {}
        }
        
        // Determine failed step from error message
        const errorMsg = errorMessage.toLowerCase()
        let failedStep = 'unknown'
        if (errorMsg.includes('save') || errorMsg.includes('upsert') || errorMsg.includes('insert') || errorMsg.includes('database') || errorMsg.includes('numeric field overflow')) {
          failedStep = 'save_insight'
        } else if (errorMsg.includes('openai') || errorMsg.includes('api')) {
          failedStep = 'call_openai'
        } else if (errorMsg.includes('fetch') || errorMsg.includes('entries')) {
          failedStep = 'fetch_data'
        } else if (errorMsg.includes('parse') || errorMsg.includes('json') || errorMsg.includes('insight')) {
          failedStep = 'parse_response'
        }
        
        await logAIError(supabase, error, {
          userId: user_id || body.user_id || 'unknown',
          entryId: null,
          analysisType: 'monthly',
          errorCode: 'ERRAI_MONTHLY_001',
          requestBody: { user_id: user_id || body.user_id, month_start: month_start || body.month_start },
          requestDurationMs: duration,
          edgeFunctionName: 'ai-analyze-monthly',
          failedAtStep: failedStep,
          errorDetails: {
            error_message: errorMessage,
            error_type: error instanceof Error ? error.constructor.name : typeof error
          }
        })
        
        await supabase
          .from('ai_requests_log')
          .insert({
            user_id: user_id || body.user_id || 'unknown',
            entry_id: null,
            analysis_type: 'monthly',
            prompt_tokens: 0,
            completion_tokens: 0,
            total_tokens: 0,
            cost_usd: 0,
            model_used: 'gpt-4o-mini',
            status: 'error',
            error_message: errorMessage,
            request_duration_ms: duration
          })
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
  
  const firstThird = moodScores.slice(0, Math.ceil(moodScores.length / 3))
  const lastThird = moodScores.slice(-Math.ceil(moodScores.length / 3))
  
  const firstAvg = firstThird.reduce((a, b) => a + b, 0) / firstThird.length
  const lastAvg = lastThird.reduce((a, b) => a + b, 0) / lastThird.length
  
  const diff = lastAvg - firstAvg
  if (diff > 0.3) return 'improving'
  if (diff < -0.3) return 'declining'
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
    .slice(0, 7) // 5-7 topics
    .map(([word]) => word)
}

// Helper: Format diary entries with dates
function formatDiaryEntries(entries: any[]): string {
  if (!entries || entries.length === 0) return 'No diary entries available.'
  
  return entries.map(e => {
    const date = new Date(e.entry_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    return `[${date}] ${e.diary_text || 'No text'} (Mood: ${e.mood_score || 'N/A'}/5)`
  }).join('\n\n')
}

// Helper: Format structured data (affirmations, priorities, gratitude, tomorrow notes)
function formatStructuredData(data: any[], entries: any[], type: string): string {
  if (!data || data.length === 0) return `No ${type} data available.`
  
  return data.map(item => {
    const entry = entries.find((e: any) => e.id === item.entry_id)
    const date = entry ? new Date(entry.entry_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Unknown date'
    const items = item.affirmations || item.priorities || item.grateful_items || item.tomorrow_notes || []
    const itemsList = Array.isArray(items) ? items.join(', ') : JSON.stringify(items)
    return `[${date}]: ${itemsList}`
  }).join('\n')
}

// Helper: Parse monthly insight text into structured format
function parseMonthlyInsight(text: string): { highlights: string; growthAreas: string[]; achievements: string[]; goals: string[] } {
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0)
  
  let highlights = ''
  const growthAreas: string[] = []
  const achievements: string[] = []
  const goals: string[] = []
  
  let currentSection = 'highlights'
  
  for (const line of lines) {
    const lowerLine = line.toLowerCase()
    
    if (lowerLine.includes('growth') || lowerLine.includes('improve')) {
      currentSection = 'growth'
      continue
    }
    if (lowerLine.includes('celebration') || lowerLine.includes('achievement') || lowerLine.includes('celebrate')) {
      currentSection = 'achievement'
      continue
    }
    if (lowerLine.includes('next month') || lowerLine.includes('focus') || lowerLine.includes('goal')) {
      currentSection = 'goal'
      continue
    }
    
    const match = line.match(/^[0-9]+\.\s*(.+)|^[-•]\s*(.+)|^(.+)/)
    if (match) {
      const item = match[1] || match[2] || match[3]
      if (item && item.length > 10) {
        switch (currentSection) {
          case 'growth':
            growthAreas.push(item)
            break
          case 'achievement':
            achievements.push(item)
            break
          case 'goal':
            goals.push(item)
            break
          default:
            if (!highlights) highlights = item
            else highlights += ' ' + item
        }
      }
    } else if (line.length > 20 && !highlights) {
      highlights = line
    }
  }
  
  // Fallback: use first 2 sentences as highlights if not parsed
  if (!highlights) {
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 10)
    highlights = sentences.slice(0, 2).join('. ')
  }
  
  return {
    highlights: highlights || text.substring(0, 200),
    growthAreas: growthAreas.slice(0, 3),
    achievements: achievements.slice(0, 3),
    goals: goals.slice(0, 3)
  }
}

