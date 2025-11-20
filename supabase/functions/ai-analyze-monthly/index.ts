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

  try {
    const { user_id, month_start }: RequestBody = await req.json()

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

    // Extract topics from all entries
    const topics = extractTopics(entries)

    // Calculate consistency
    const consistencyScore = (entries.length / totalDaysInMonth) * 100

    // Word count total
    const wordCountTotal = entries.reduce((sum, e) => sum + (e.diary_text?.split(/\s+/).length || 0), 0)

    // 4. Build habit analysis
    const habitAnalysis = {
      mood_vs_entries: avgMood ? parseFloat(avgMood) : null,
      self_care_completion: selfCareRates.completionRate,
      consistency: parseFloat(consistencyScore.toFixed(2))
    }

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
        system_prompt: 'You are a reflective AI assistant that helps users understand long-term trends in their wellness journey. Provide monthly summaries that highlight growth, patterns, and areas of focus. Be encouraging and forward-looking.',
        user_prompt_template: `Monthly Data Summary:
- Month: {month_name}
- Entries written: {entries_count}/{total_days}
- Average mood: {avg_mood}/5
- Consistency: {consistency_score}%
- Key themes: {monthly_topics}
- Mood trend: {mood_trend}

Please provide:
1. Overall month reflection (2-3 sentences)
2. Biggest growth area (1 sentence)
3. One celebration moment (1 sentence)
4. Focus for next month (1-2 sentences)

Keep it inspiring and actionable (under 200 words).`,
        temperature: 0.6,
        max_tokens: 500
      }
    }

    // 6. Build final prompt
    const userPrompt = template.user_prompt_template
      .replace('{month_name}', monthName)
      .replace('{entries_count}', entries.length.toString())
      .replace('{total_days}', totalDaysInMonth.toString())
      .replace('{avg_mood}', avgMood || 'N/A')
      .replace('{consistency_score}', consistencyScore.toFixed(1))
      .replace('{monthly_topics}', topics.slice(0, 10).join(', ') || 'None')
      .replace('{mood_trend}', moodTrend)

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
        max_tokens: template.max_tokens || 500
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
    const { highlights, growthAreas, achievements, goals } = parseMonthlyInsight(insightText)

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
        const body = await req.json().catch(() => ({}))
        
        await logAIError(supabase, error, {
          userId: (body as RequestBody)?.user_id || 'unknown',
          entryId: null,
          analysisType: 'monthly',
          errorCode: 'ERRAI_MONTHLY_001',
          requestBody: body,
          requestDurationMs: duration,
          edgeFunctionName: 'ai-analyze-monthly',
          failedAtStep: 'unknown',
        })
        
        await supabase
          .from('ai_requests_log')
          .insert({
            user_id: (body as RequestBody)?.user_id || 'unknown',
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
    .slice(0, 10)
    .map(([word]) => word)
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

