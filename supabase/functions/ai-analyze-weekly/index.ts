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
    const { data: selfCareData } = await supabase
      .from('entry_self_care')
      .select('*')
      .in('entry_id', entryIds)

    const selfCareRates = calculateSelfCareRate(selfCareData || [], entries.length)

    // Calculate water cups average
    const { data: mealsData } = await supabase
      .from('entry_meals')
      .select('water_cups')
      .in('entry_id', entryIds)

    const cupsTotal = mealsData?.reduce((sum, m) => sum + (m.water_cups || 0), 0) || 0
    const cupsAvg = entries.length > 0 ? (cupsTotal / entries.length).toFixed(1) : '0'

    // Extract topics from all entries
    const topics = extractTopics(entries)

    // Calculate consistency
    const consistencyScore = (entries.length / 7) * 100

    // Word count total
    const wordCountTotal = entries.reduce((sum, e) => sum + (e.diary_text?.split(/\s+/).length || 0), 0)

    // 4. Build habit correlations (simple)
    const habitCorrelations = {
      mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
      self_care_completion: selfCareRates.completionRate
    }

    // 5. Get prompt template
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
      // Fallback template
      template = {
        system_prompt: 'You are an analytical but compassionate AI assistant that identifies patterns in personal journal data. Provide insightful weekly summaries that help users understand their emotional patterns and habit impacts. Focus on patterns and practical insights.',
        user_prompt_template: `Weekly Data Summary:
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

Keep it concise and actionable (under 150 words total).`,
        temperature: 0.5,
        max_tokens: 400
      }
    }

    // 6. Build final prompt
    const moodScoresStr = moodScores.length > 0 
      ? moodScores.map((m, i) => `${i + 1}: ${m}`).join(', ')
      : 'No mood data'
    
    const selfCareSummary = `Completed ${selfCareRates.completedDays}/7 days with self-care activities`
    
    const userPrompt = template.user_prompt_template
      .replace('{week_start}', week_start)
      .replace('{week_end}', weekEnd)
      .replace('{entries_count}', entries.length.toString())
      .replace('{avg_mood}', avgMood || 'N/A')
      .replace('{mood_scores}', moodScoresStr)
      .replace('{self_care_summary}', selfCareSummary)
      .replace('{weekly_topics}', topics.slice(0, 10).join(', ') || 'None')
      .replace('{habit_correlations}', JSON.stringify(habitCorrelations))

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
        temperature: template.temperature || 0.5,
        max_tokens: template.max_tokens || 400
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

    // 8. Parse insight into structured format
    const { insights, recommendations } = parseWeeklyInsight(insightText)

    // 9. Calculate cost
    const costUsd = (tokensUsed.prompt / 1000000) * 0.15 + (tokensUsed.completion / 1000000) * 0.60

    // 10. Save to weekly_insights
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

    // 11. Log request
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

// Helper: Parse weekly insight text into structured format
function parseWeeklyInsight(text: string): { insights: string[]; recommendations: string[] } {
  const insights: string[] = []
  const recommendations: string[] = []
  
  // Simple parsing - look for numbered lists or bullet points
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0)
  
  let currentSection = 'insights'
  for (const line of lines) {
    // Check if it's a recommendation section
    if (line.toLowerCase().includes('recommend') || line.toLowerCase().includes('suggest')) {
      currentSection = 'recommendations'
      continue
    }
    
    // Extract numbered or bulleted items
    const match = line.match(/^[0-9]+\.\s*(.+)|^[-•]\s*(.+)|^(.+)/)
    if (match) {
      const item = match[1] || match[2] || match[3]
      if (item && item.length > 10) {
        if (currentSection === 'recommendations') {
          recommendations.push(item)
        } else {
          insights.push(item)
        }
      }
    }
  }
  
  // Fallback: if no structured data, use first 2 sentences as insights, last 2 as recommendations
  if (insights.length === 0 && recommendations.length === 0) {
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 10)
    insights.push(...sentences.slice(0, 2))
    recommendations.push(...sentences.slice(-2))
  }
  
  return {
    insights: insights.slice(0, 3),
    recommendations: recommendations.slice(0, 2)
  }
}

