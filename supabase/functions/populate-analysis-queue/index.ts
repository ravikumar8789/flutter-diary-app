import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Calculate tomorrow midnight in user's timezone, converted to UTC for storage
 * @param supabase - Supabase client
 * @param userTimezone - IANA timezone string (e.g., 'Asia/Kolkata')
 * @returns ISO string of tomorrow midnight in user's timezone (as UTC timestamp)
 */
async function getTomorrowMidnightInUserTimezone(
  supabase: any,
  userTimezone: string
): Promise<string> {
  try {
    // Get tomorrow's date in user's timezone
    const { data: tomorrowData, error } = await supabase.rpc('get_date_in_timezone', {
      p_timezone: userTimezone,
      p_offset_days: 1  // Tomorrow
    })

    if (error || !tomorrowData) {
      return getTomorrowMidnightFallback(userTimezone)
    }

    // tomorrowData is "2025-11-22"
    const [year, month, day] = tomorrowData.split('-').map(Number)
    
    // Calculate timezone offset for this specific date
    // Use a reference time (noon) to avoid DST edge cases
    const referenceUTC = new Date(Date.UTC(year, month - 1, day, 12, 0, 0))
    
    // Get what this UTC time is in user's timezone
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: userTimezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    })
    
    const userTimeStr = formatter.format(referenceUTC)
    // Format: "11/22/2025, 17:30:00" (for IST, UTC+5:30)
    
    // Parse the formatted string
    const [datePart, timePart] = userTimeStr.split(', ')
    const [m, d, y] = datePart.split('/')
    const [h, min, sec] = timePart.split(':')
    
    // Create date object (this will be interpreted in server's local timezone)
    const userReference = new Date(parseInt(y), parseInt(m) - 1, parseInt(d), parseInt(h), parseInt(min), parseInt(sec))
    
    // Calculate offset
    const offset = referenceUTC.getTime() - userReference.getTime()
    
    // Now create midnight in user timezone
    const userMidnight = new Date(year, month - 1, day, 0, 0, 0, 0)
    
    // Convert to UTC
    const utcMidnight = new Date(userMidnight.getTime() + offset)
    
    return utcMidnight.toISOString()
    
  } catch (error) {
    console.error(`[QUEUE] Error calculating tomorrow midnight:`, error)
    return getTomorrowMidnightFallback(userTimezone)
  }
}

/**
 * Fallback function to calculate tomorrow midnight when RPC fails
 * @param userTimezone - IANA timezone string
 * @returns ISO string of tomorrow midnight in user's timezone (as UTC timestamp)
 */
function getTomorrowMidnightFallback(userTimezone: string): string {
  const now = new Date()
  
  // Get current date/time in user timezone
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: userTimezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  })
  
  const userNowStr = formatter.format(now)
  const [datePart, timePart] = userNowStr.split(', ')
  const [m, d, y] = datePart.split('/')
  const [h, min, sec] = timePart.split(':')
  
  const userNow = new Date(parseInt(y), parseInt(m) - 1, parseInt(d), parseInt(h), parseInt(min), parseInt(sec))
  const offset = now.getTime() - userNow.getTime()
  
  // Calculate tomorrow
  const tomorrow = new Date(userNow)
  tomorrow.setDate(tomorrow.getDate() + 1)
  tomorrow.setHours(0, 0, 0, 0)
  
  // Convert to UTC
  const utcMidnight = new Date(tomorrow.getTime() + offset)
  
  return utcMidnight.toISOString()
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all users with timezone set
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, timezone')
      .not('timezone', 'is', null)

    if (usersError) throw usersError

    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No users with timezone found', queued: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[QUEUE] Starting queue population at ${new Date().toISOString()}`)
    let dailyQueued = 0
    let weeklyQueued = 0
    let monthlyQueued = 0

    for (const user of users) {
      const userTimezone = user.timezone || 'UTC'

      try {
        console.log(`[QUEUE] Processing user ${user.id} (timezone: ${userTimezone})`)
        
        // Calculate current date in user's timezone using SQL
        // We'll use a query to get the date in user's timezone
        const { data: nowData, error: nowError } = await supabase.rpc('get_date_in_timezone', {
          p_timezone: userTimezone,
          p_offset_days: 0
        })

        // Fallback: use JavaScript timezone calculation if function doesn't exist
        let todayInTz: Date
        if (nowError || !nowData) {
          // JavaScript fallback
          const now = new Date()
          const tzDate = new Date(now.toLocaleString('en-US', { timeZone: userTimezone }))
          todayInTz = new Date(tzDate.getFullYear(), tzDate.getMonth(), tzDate.getDate())
        } else {
          todayInTz = new Date(nowData)
        }

        const todayStr = todayInTz.toISOString().split('T')[0]
        const currentHour = todayInTz.getHours()

        // 1. DAILY: Queue TODAY's entry
        const { data: todayEntry } = await supabase
          .from('entries')
          .select('id, diary_text, entry_date')
          .eq('user_id', user.id)
          .eq('entry_date', todayStr)
          .single()

        if (todayEntry) {
          // Check entry completion BEFORE queuing
          const { data: isComplete, error: completionError } = await supabase.rpc(
            'check_entry_completion',
            { entry_uuid: todayEntry.id }
          )

          if (completionError) {
            console.error(`[QUEUE] Completion check failed for entry ${todayEntry.id}:`, completionError)
          } else if (isComplete && (todayEntry.diary_text?.length || 0) >= 50) {
            // Check if insight already exists
            const { data: existingInsight } = await supabase
              .from('entry_insights')
              .select('id')
              .eq('entry_id', todayEntry.id)
              .eq('status', 'success')
              .single()

            // Check if already queued
            const { data: queued } = await supabase
              .from('analysis_queue')
              .select('id')
              .eq('user_id', user.id)
              .eq('analysis_type', 'daily')
              .eq('target_date', todayStr)
              .in('status', ['pending', 'processing'])
              .single()

            if (!existingInsight && !queued) {
              const tomorrowMidnight = await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
              await supabase
                .from('analysis_queue')
                .insert({
                  user_id: user.id,
                  analysis_type: 'daily',
                  target_date: todayStr,  // TODAY's date
                  entry_id: todayEntry.id,
                  status: 'pending',
                  next_retry_at: tomorrowMidnight
                })
              console.log(`[QUEUE] ✅ Queued today's entry: user=${user.id}, date=${todayStr}, entry_id=${todayEntry.id}`)
              dailyQueued++
            } else if (queued) {
              console.log(`[QUEUE] ⏭️ Skipped (already queued): user=${user.id}, date=${todayStr}`)
            } else if (existingInsight) {
              console.log(`[QUEUE] ⏭️ Skipped (insight exists): user=${user.id}, entry_id=${todayEntry.id}`)
            }
          } else if (!isComplete) {
            console.log(`[QUEUE] ⏭️ Skipped (incomplete entry): user=${user.id}, entry_id=${todayEntry.id}`)
          }
        }

        // 1.2 DAILY: Catch-up analysis - Find ALL entries from previous dates (before today) that don't have insights
        // Limit to last 30 days to avoid processing very old entries
        const thirtyDaysAgo = new Date(todayInTz)
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
        const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0]

        // Find entries without insights
        const { data: unanalyzedEntries } = await supabase
          .from('entries')
          .select('id, entry_date, diary_text')
          .eq('user_id', user.id)
          .lt('entry_date', todayStr)  // Before today
          .gte('entry_date', thirtyDaysAgoStr)  // Within last 30 days
          .not('diary_text', 'is', null)
          .not('diary_text', 'eq', '')

        if (unanalyzedEntries && unanalyzedEntries.length > 0) {
          for (const entry of unanalyzedEntries) {
            // Check if insight exists
            const { data: existingInsight } = await supabase
              .from('entry_insights')
              .select('id')
              .eq('entry_id', entry.id)
              .eq('status', 'success')
              .single()

            // Check if already queued
            const { data: queued } = await supabase
              .from('analysis_queue')
              .select('id')
              .eq('user_id', user.id)
              .eq('analysis_type', 'daily')
              .eq('target_date', entry.entry_date)
              .in('status', ['pending', 'processing'])
              .single()

            // Check entry completion
            const { data: isComplete } = await supabase.rpc(
              'check_entry_completion',
              { entry_uuid: entry.id }
            )

            if (!existingInsight && !queued && isComplete && (entry.diary_text?.length || 0) >= 50) {
              const tomorrowMidnight = await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
              await supabase.from('analysis_queue').insert({
                user_id: user.id,
                analysis_type: 'daily',
                target_date: entry.entry_date,  // Previous date
                entry_id: entry.id,
                status: 'pending',
                next_retry_at: tomorrowMidnight
              })
              console.log(`[QUEUE] ✅ Queued catch-up entry: user=${user.id}, date=${entry.entry_date}, entry_id=${entry.id}`)
              dailyQueued++
            }
          }
        }

        // 2. WEEKLY: Check if Sunday at midnight and previous week needs analysis
        const dayOfWeek = todayInTz.getDay() // 0 = Sunday, 1 = Monday
        if (dayOfWeek === 0 && currentHour === 0) { // Sunday at midnight
          const lastWeekStart = new Date(todayInTz)
          lastWeekStart.setDate(lastWeekStart.getDate() - 7)
          // Set to Monday of last week
          const dayOffset = lastWeekStart.getDay() === 0 ? 6 : lastWeekStart.getDay() - 1
          lastWeekStart.setDate(lastWeekStart.getDate() - dayOffset)
          const lastWeekStartStr = lastWeekStart.toISOString().split('T')[0]

          // Check if weekly insight exists
          const { data: existingWeekly } = await supabase
            .from('weekly_insights')
            .select('id')
            .eq('user_id', user.id)
            .eq('week_start', lastWeekStartStr)
            .single()

          // Check if queued
          const { data: queuedWeekly } = await supabase
            .from('analysis_queue')
            .select('id')
            .eq('user_id', user.id)
            .eq('analysis_type', 'weekly')
            .eq('week_start', lastWeekStartStr)
            .in('status', ['pending', 'processing'])
            .single()

          // Check if sufficient entries (3+)
          const weekEnd = new Date(lastWeekStart)
          weekEnd.setDate(weekEnd.getDate() + 6)
          const weekEndStr = weekEnd.toISOString().split('T')[0]

          const { count } = await supabase
            .from('entries')
            .select('id', { count: 'exact', head: true })
            .eq('user_id', user.id)
            .gte('entry_date', lastWeekStartStr)
            .lte('entry_date', weekEndStr)

          if (!existingWeekly && !queuedWeekly && (count || 0) >= 3) {
            const tomorrowMidnight = await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
            await supabase
              .from('analysis_queue')
              .insert({
                user_id: user.id,
                analysis_type: 'weekly',
                target_date: lastWeekStartStr,
                week_start: lastWeekStartStr,
                status: 'pending',
                next_retry_at: tomorrowMidnight
              })
            console.log(`[QUEUE] ✅ Queued weekly analysis: user=${user.id}, week_start=${lastWeekStartStr}`)
            weeklyQueued++
          }
        }

        // 3. MONTHLY: Check if 1st of month at midnight and previous month needs analysis
        if (todayInTz.getDate() === 1 && currentHour === 0) {
          const lastMonth = new Date(todayInTz.getFullYear(), todayInTz.getMonth() - 1, 1)
          const lastMonthStr = lastMonth.toISOString().split('T')[0]

          // Check if monthly insight exists
          const { data: existingMonthly } = await supabase
            .from('monthly_insights')
            .select('id')
            .eq('user_id', user.id)
            .eq('month_start', lastMonthStr)
            .single()

          // Check if queued
          const { data: queuedMonthly } = await supabase
            .from('analysis_queue')
            .select('id')
            .eq('user_id', user.id)
            .eq('analysis_type', 'monthly')
            .eq('month_start', lastMonthStr)
            .in('status', ['pending', 'processing'])
            .single()

          // Check if sufficient entries (10+)
          const firstDayOfMonth = new Date(lastMonth.getFullYear(), lastMonth.getMonth(), 1)
          const lastDayOfMonth = new Date(lastMonth.getFullYear(), lastMonth.getMonth() + 1, 0)
          const firstDayStr = firstDayOfMonth.toISOString().split('T')[0]
          const lastDayStr = lastDayOfMonth.toISOString().split('T')[0]

          const { count } = await supabase
            .from('entries')
            .select('id', { count: 'exact', head: true })
            .eq('user_id', user.id)
            .gte('entry_date', firstDayStr)
            .lte('entry_date', lastDayStr)

          if (!existingMonthly && !queuedMonthly && (count || 0) >= 10) {
            const tomorrowMidnight = await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
            await supabase
              .from('analysis_queue')
              .insert({
                user_id: user.id,
                analysis_type: 'monthly',
                target_date: lastMonthStr,
                month_start: lastMonthStr,
                status: 'pending',
                next_retry_at: tomorrowMidnight
              })
            console.log(`[QUEUE] ✅ Queued monthly analysis: user=${user.id}, month_start=${lastMonthStr}`)
            monthlyQueued++
          }
        }

      } catch (userError) {
        console.error(`[QUEUE] Error processing user ${user.id}:`, userError)
        // Continue with next user
        continue
      }
    }

    console.log(`[QUEUE] Summary: Users=${users.length}, Daily=${dailyQueued}, Weekly=${weeklyQueued}, Monthly=${monthlyQueued}, Total=${dailyQueued + weeklyQueued + monthlyQueued}`)

    return new Response(
      JSON.stringify({
        success: true,
        users_processed: users.length,
        daily_queued: dailyQueued,
        weekly_queued: weeklyQueued,
        monthly_queued: monthlyQueued,
        total_queued: dailyQueued + weeklyQueued + monthlyQueued
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

