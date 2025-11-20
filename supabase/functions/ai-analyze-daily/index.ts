import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logAIError } from '../_shared/ai_error_logger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RequestBody {
  entry_id: string
  user_id: string
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
    const { entry_id, user_id }: RequestBody = await req.json()

    if (!entry_id || !user_id) {
      throw new Error('entry_id and user_id are required')
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

    // 1. Check if insight already exists
    const { data: existingInsight } = await supabase
      .from('entry_insights')
      .select('id, status')
      .eq('entry_id', entry_id)
      .eq('status', 'success')
      .single()

    if (existingInsight) {
      return new Response(
        JSON.stringify({ success: true, message: 'Insight already exists', entry_id }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Fetch entry data
    const { data: entry, error: entryError } = await supabase
      .from('entries')
      .select('id, user_id, diary_text, mood_score, entry_date, created_at')
      .eq('id', entry_id)
      .eq('user_id', user_id)
      .single()

    if (entryError || !entry) {
      throw new Error(`Entry not found: ${entryError?.message}`)
    }

    // 3. Check completion before analysis
    const { data: isComplete, error: completionError } = await supabase.rpc(
      'check_entry_completion',
      { entry_uuid: entry_id }
    )

    if (completionError) {
      throw new Error(`Completion check failed: ${completionError.message}`)
    }

    if (!isComplete) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Entry incomplete - all 4 sections required' 
        }),
        { 
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (!entry.diary_text || entry.diary_text.trim().length < 50) {
      throw new Error('Entry text too short for analysis')
    }

    // 4. Fetch related data for today's entry
    const { data: selfCare } = await supabase
      .from('entry_self_care')
      .select('*')
      .eq('entry_id', entry_id)
      .single()

    const { data: affirmations } = await supabase
      .from('entry_affirmations')
      .select('affirmations')
      .eq('entry_id', entry_id)
      .single()

    const { data: priorities } = await supabase
      .from('entry_priorities')
      .select('priorities')
      .eq('entry_id', entry_id)
      .single()

    const { data: meals } = await supabase
      .from('entry_meals')
      .select('breakfast, lunch, dinner, water_cups')
      .eq('entry_id', entry_id)
      .single()

    const { data: gratitude } = await supabase
      .from('entry_gratitude')
      .select('grateful_items')
      .eq('entry_id', entry_id)
      .single()

    // Fetch tomorrow notes
    const { data: tomorrowNotes } = await supabase
      .from('entry_tomorrow_notes')
      .select('tomorrow_notes')
      .eq('entry_id', entry_id)
      .single()

    // Fetch shower/bath notes
    const { data: showerBath } = await supabase
      .from('entry_shower_bath')
      .select('took_shower, note')
      .eq('entry_id', entry_id)
      .single()

    // 5. Fetch past 5 days entries for context
    const fiveDaysAgo = new Date()
    fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5)
    const fiveDaysAgoStr = fiveDaysAgo.toISOString().split('T')[0]
    const entryDateStr = entry.entry_date || new Date().toISOString().split('T')[0]

    const { data: pastEntries } = await supabase
      .from('entries')
      .select('id, diary_text, mood_score, entry_date')
      .eq('user_id', user_id)
      .gte('entry_date', fiveDaysAgoStr)
      .lte('entry_date', entryDateStr)
      .neq('id', entry_id)  // Exclude current entry
      .order('entry_date', { ascending: false })
      .limit(5)

    // Fetch past insights if available
    const pastEntryIds = pastEntries?.map(e => e.id) || []
    const { data: pastInsights } = pastEntryIds.length > 0 ? await supabase
      .from('entry_insights')
      .select('insight_text, processed_at, entries!inner(entry_date)')
      .in('entry_id', pastEntryIds)
      .eq('status', 'success')
      .order('processed_at', { ascending: false })
      .limit(5) : { data: null }

    // 6. Build comprehensive context with ALL actual text content
    const affirmationsText = affirmations?.affirmations 
      ? JSON.stringify(affirmations.affirmations).replace(/[\[\]"]/g, '')
      : 'None'

    const prioritiesText = priorities?.priorities
      ? JSON.stringify(priorities.priorities).replace(/[\[\]"]/g, '')
      : 'None'

    const gratitudeText = gratitude?.grateful_items
      ? JSON.stringify(gratitude.grateful_items).replace(/[\[\]"]/g, '')
      : 'None'

    const tomorrowNotesText = tomorrowNotes?.tomorrow_notes
      ? JSON.stringify(tomorrowNotes.tomorrow_notes).replace(/[\[\]"]/g, '')
      : 'None'

    const selfCareDetails = selfCare ? Object.entries(selfCare)
      .filter(([key, value]) => value === true && key !== 'entry_id')
      .map(([key]) => key.replace(/_/g, ' '))
      .join(', ') : 'None'

    const mealsDetails = meals 
      ? `Breakfast: ${meals.breakfast || 'Not logged'}, Lunch: ${meals.lunch || 'Not logged'}, Dinner: ${meals.dinner || 'Not logged'}, Water: ${meals.water_cups || 0} cups`
      : 'No meals logged'

    const showerBathNote = showerBath?.note || 'None'

    // Calculate context metrics
    const allMoodScores = [
      ...(pastEntries?.map(e => e.mood_score).filter(Boolean) || []),
      entry.mood_score
    ].filter(Boolean) as number[]
    
    const avgMood = allMoodScores.length > 0
      ? (allMoodScores.reduce((a, b) => a + b, 0) / allMoodScores.length).toFixed(1)
      : entry.mood_score?.toString() || 'N/A'

    const moodTrend = calculateMoodTrend([...pastEntries || [], entry])
    const consistencyScore = calculateConsistencyScore(pastEntries || [], entry)
    const keyPatterns = extractPatterns(pastEntries || [])

    // 7. Build prompt with full text content
    const systemPrompt = 'You are a compassionate and insightful AI wellness assistant. Analyze diary entries with emotional intelligence and provide thoughtful, comprehensive insights. Always be supportive and non-judgmental. Your task is to generate a structured insight with a main 3-4 sentence insight and 4 specific sub-points that help users understand their day better.'

    const userPrompt = `Yesterday's Complete Entry Analysis:

**Main Diary Entry:**
"${entry.diary_text}"

**Mood:** ${entry.mood_score || 'N/A'}/5

**Morning Ritual:**
- Affirmations: ${affirmationsText}
- Priorities: ${prioritiesText}

**Wellness Tracking:**
- Self-care activities completed: ${selfCareDetails}
- Meals: ${mealsDetails}
- Shower/Bath: ${showerBath?.took_shower ? 'Yes' : 'No'}${showerBathNote !== 'None' ? ` (Note: ${showerBathNote})` : ''}

**Gratitude Practice:**
${gratitudeText}

**Tomorrow's Planning:**
${tomorrowNotesText}

**Past 5 Days Context:**
- Mood trend: ${moodTrend}
- Consistency: ${consistencyScore}%
- Entries completed: ${(pastEntries?.length || 0) + 1}/5
- Key patterns: ${keyPatterns}

Please provide a structured response in JSON format:
{
  "main_insight": "3-4 sentence comprehensive insight about the day (emotional tone, key patterns, supportive observation)",
  "what_went_well": "1-1.5 lines about one specific positive thing from the data",
  "progress_area": "1-1.5 lines about what's lacking and one actionable step to improve",
  "self_care_balance": "1-1.5 lines about self-care activities and what could be added",
  "emotional_pattern": "1-1.5 lines about emotional patterns observed from diary and mood"
}

Keep it warm, specific, and actionable. Each point should reference actual data from the entry. Return ONLY valid JSON, no additional text.`

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
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.7,
        max_tokens: 500  // Increased for structured response
      })
    })

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.json()
      throw new Error(`OpenAI API error: ${openaiResponse.status} - ${errorData.error?.message || 'Unknown error'}`)
    }

    const aiData = await openaiResponse.json()
    const responseText = aiData.choices[0]?.message?.content?.trim() || ''
    tokensUsed = {
      prompt: aiData.usage?.prompt_tokens || 0,
      completion: aiData.usage?.completion_tokens || 0,
      total: aiData.usage?.total_tokens || 0
    }

    if (!responseText) {
      throw new Error('Empty response from OpenAI')
    }

    // 9. Parse structured JSON response
    let insightData: any
    try {
      insightData = JSON.parse(responseText)
    } catch (e) {
      // Fallback: if not JSON, treat as main insight only
      console.warn('Failed to parse JSON response, using as plain text:', e)
      insightData = {
        main_insight: responseText,
        what_went_well: null,
        progress_area: null,
        self_care_balance: null,
        emotional_pattern: null
      }
    }

    const insightText = insightData.main_insight || responseText.trim()
    const insightDetails = {
      what_went_well: insightData.what_went_well || null,
      progress_area: insightData.progress_area || null,
      self_care_balance: insightData.self_care_balance || null,
      emotional_pattern: insightData.emotional_pattern || null
    }

    // 9. Calculate cost (GPT-4o-mini pricing: $0.15/1M input, $0.60/1M output)
    const costUsd = (tokensUsed.prompt / 1000000) * 0.15 + (tokensUsed.completion / 1000000) * 0.60

    // 10. Save insight to entry_insights
    const { error: insightError, data: savedInsight } = await supabase
      .from('entry_insights')
      .upsert({
        entry_id: entry_id,
        insight_text: insightText,  // Main 3-4 sentence insight
        summary: insightText,  // Keep for backward compatibility
        insight_details: insightDetails,  // NEW: Structured sub-points
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
      .select()

    if (insightError) {
      console.error('Error saving insight:', insightError)
      // Log to error table
      await logAIError(supabase, insightError, {
        userId: user_id,
        entryId: entry_id,
        analysisType: 'daily',
        errorCode: 'ERRAI_DAILY_SAVE_001',
        requestBody: { entry_id, user_id },
        requestDurationMs: Date.now() - startTime,
        edgeFunctionName: 'ai-analyze-daily',
        failedAtStep: 'save_insight',
        errorDetails: { error: insightError.message, code: insightError.code }
      })
      // Don't throw - log it but continue (request log already saved)
    } else {
      console.log('Insight saved successfully:', savedInsight)
    }

    // 11. Log request
    const duration = Date.now() - startTime
    await supabase
      .from('ai_requests_log')
      .insert({
        user_id: user_id,
        entry_id: entry_id,
        analysis_type: 'daily',
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
        entry_id,
        summary: insightText,
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
        let body: any = {}
        try {
          body = await req.json()
        } catch {
          body = {}
        }
        
        const errorUserId = (body as RequestBody)?.user_id || 'unknown'
        const errorEntryId = (body as RequestBody)?.entry_id || null
        
        // Log to comprehensive ai_errors_log table
        await logAIError(supabase, error, {
          userId: errorUserId,
          entryId: errorEntryId,
          analysisType: 'daily',
          errorCode: 'ERRAI_DAILY_001',
          requestBody: { entry_id: errorEntryId, user_id: errorUserId },
          requestDurationMs: duration,
          edgeFunctionName: 'ai-analyze-daily',
          failedAtStep: 'unknown',
        })
        
        // Also log to ai_requests_log (existing)
        await supabase
          .from('ai_requests_log')
          .insert({
            user_id: errorUserId,
            entry_id: errorEntryId,
            analysis_type: 'daily',
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
function calculateMoodTrend(entries: any[]): string {
  if (entries.length < 2) return 'insufficient data'
  
  const moods = entries.map(e => e.mood_score).filter(Boolean)
  if (moods.length < 2) return 'stable'
  
  const recent = moods.slice(0, 3)
  const older = moods.slice(3)
  
  if (older.length === 0) return 'stable'
  
  const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length
  const olderAvg = older.reduce((a, b) => a + b, 0) / older.length
  
  const diff = recentAvg - olderAvg
  if (diff > 0.5) return 'improving'
  if (diff < -0.5) return 'declining'
  return 'stable'
}

// Helper: Extract topics (simple word extraction)
function extractTopics(entries: any[]): string[] {
  const words: { [key: string]: number } = {}
  entries.forEach(entry => {
    if (entry.diary_text) {
      const text = entry.diary_text.toLowerCase()
      const commonWords = text.split(/\s+/)
        .filter(w => w.length > 4)
        .filter(w => !['today', 'yesterday', 'feeling', 'think', 'about', 'really', 'would', 'could', 'should'].includes(w))
        .slice(0, 10)
      
      commonWords.forEach(word => {
        words[word] = (words[word] || 0) + 1
      })
    }
  })
  
  return Object.entries(words)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([word]) => word)
}

// Helper: Infer sentiment from insight and mood
function inferSentiment(insightText: string, moodScore?: number | null): string {
  const text = insightText.toLowerCase()
  const positiveWords = ['good', 'great', 'well', 'positive', 'improving', 'achievement', 'progress']
  const negativeWords = ['difficult', 'challenge', 'struggling', 'concern', 'worried']
  
  const positiveCount = positiveWords.filter(w => text.includes(w)).length
  const negativeCount = negativeWords.filter(w => text.includes(w)).length
  
  if (moodScore !== null && moodScore !== undefined) {
    if (moodScore >= 4) return 'positive'
    if (moodScore <= 2) return 'negative'
  }
  
  if (positiveCount > negativeCount) return 'positive'
  if (negativeCount > positiveCount) return 'negative'
  return 'neutral'
}

// Helper: Calculate consistency score
function calculateConsistencyScore(pastEntries: any[], currentEntry: any): number {
  const totalDays = pastEntries.length + 1
  if (totalDays === 0) return 0
  
  // Simple consistency: entries with mood scores
  const entriesWithMood = [
    ...pastEntries.filter(e => e.mood_score),
    currentEntry
  ].filter(e => e.mood_score)
  
  return Math.round((entriesWithMood.length / totalDays) * 100)
}

// Helper: Extract patterns from past entries
function extractPatterns(pastEntries: any[]): string {
  if (pastEntries.length === 0) return 'No past data available'
  
  const moods = pastEntries.map(e => e.mood_score).filter(Boolean)
  if (moods.length === 0) return 'No mood patterns'
  
  const avgMood = moods.reduce((a, b) => a + b, 0) / moods.length
  const trend = moods[0] > moods[moods.length - 1] ? 'improving' : 'declining'
  
  return `Average mood: ${avgMood.toFixed(1)}, Trend: ${trend}`
}

// Helper: Summarize past insights
function summarizePastInsights(pastInsights: any[]): string {
  if (pastInsights.length === 0) return 'No previous insights'
  
  const recent = pastInsights.slice(0, 3)
  const themes = recent.map(i => i.insight_text?.substring(0, 50)).filter(Boolean)
  
  return themes.length > 0 
    ? `Recent themes: ${themes.join('; ')}`
    : 'Previous insights available'
}


