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
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const now = new Date()
    console.log(`[PROCESS] Starting queue processing at ${now.toISOString()}`)

    // Fetch ALL pending jobs that are ready to process (not filtered by date yet)
    const { data: allPendingJobs, error: queueError } = await supabase
      .from('analysis_queue')
      .select('*')
      .eq('status', 'pending')
      .lte('next_retry_at', now.toISOString())
      .limit(50)  // Process up to 50 jobs per run (increased from 10)

    if (queueError) throw queueError

    if (!allPendingJobs || allPendingJobs.length === 0) {
      console.log(`[PROCESS] No pending jobs ready to process`)
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No pending jobs ready to process', 
          processed: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get unique user IDs and fetch their timezones
    const userIds = [...new Set(allPendingJobs.map((job: any) => job.user_id))]
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, timezone')
      .in('id', userIds)

    if (usersError) {
      console.error(`[PROCESS] Error fetching user timezones:`, usersError)
      throw usersError
    }

    // Create a map of user_id -> timezone
    const userTimezoneMap = new Map<string, string>()
    users?.forEach((user: any) => {
      userTimezoneMap.set(user.id, user.timezone || 'UTC')
    })

    // Filter jobs where target_date is "yesterday" in user's timezone
    const queueItems: any[] = []
    for (const job of allPendingJobs) {
      const userTimezone = userTimezoneMap.get(job.user_id) || 'UTC'
      
      try {
        // Calculate yesterday in user's timezone
        const { data: yesterdayData, error: tzError } = await supabase.rpc('get_date_in_timezone', {
          p_timezone: userTimezone,
          p_offset_days: -1  // Yesterday
        })

        let yesterdayInUserTz: string
        if (tzError || !yesterdayData) {
          // Fallback: JavaScript calculation
          const now = new Date()
          const tzDate = new Date(now.toLocaleString('en-US', { timeZone: userTimezone }))
          const yesterday = new Date(tzDate)
          yesterday.setDate(yesterday.getDate() - 1)
          yesterdayInUserTz = yesterday.toISOString().split('T')[0]
        } else {
          yesterdayInUserTz = new Date(yesterdayData).toISOString().split('T')[0]
        }

        // Only process if target_date matches yesterday in user's timezone
        if (job.target_date === yesterdayInUserTz) {
          queueItems.push(job)
        } else {
          console.log(`[PROCESS] ⏭️ Skipping job ${job.id}: target_date=${job.target_date}, user_yesterday=${yesterdayInUserTz}, timezone=${userTimezone}`)
        }
      } catch (error) {
        console.error(`[PROCESS] Error checking timezone for job ${job.id}:`, error)
        // Skip this job on error
      }
    }

    if (queueItems.length === 0) {
      console.log(`[PROCESS] No jobs to process after timezone filtering (checked ${allPendingJobs.length} pending jobs)`)
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No jobs to process after timezone filtering', 
          processed: 0,
          checked: allPendingJobs.length
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[PROCESS] Found ${queueItems.length} jobs to process (filtered from ${allPendingJobs.length} pending jobs)`)

    let processed = 0
    let failed = 0
    const results: any[] = []

    for (const job of queueItems) {
      try {
        console.log(`[PROCESS] Processing job ${job.id}: type=${job.analysis_type}, user=${job.user_id}, target_date=${job.target_date}, entry_id=${job.entry_id || 'N/A'}`)
        
        // Update status to processing
        await supabase
          .from('analysis_queue')
          .update({ status: 'processing' })
          .eq('id', job.id)

        let result: any
        let functionName = ''

        // Route to appropriate analysis function based on type
        let response: any
        try {
          switch (job.analysis_type) {
            case 'daily':
              if (!job.entry_id || !job.user_id) {
                throw new Error('Missing entry_id or user_id for daily analysis')
              }
              functionName = 'ai-analyze-daily'
              response = await supabase.functions.invoke('ai-analyze-daily', {
                body: {
                  entry_id: job.entry_id,
                  user_id: job.user_id
                }
              })
              break

            case 'weekly':
              if (!job.week_start || !job.user_id) {
                throw new Error('Missing week_start or user_id for weekly analysis')
              }
              functionName = 'ai-analyze-weekly'
              response = await supabase.functions.invoke('ai-analyze-weekly', {
                body: {
                  user_id: job.user_id,
                  week_start: job.week_start
                }
              })
              break

            case 'monthly':
              if (!job.month_start || !job.user_id) {
                throw new Error('Missing month_start or user_id for monthly analysis')
              }
              functionName = 'ai-analyze-monthly'
              response = await supabase.functions.invoke('ai-analyze-monthly', {
                body: {
                  user_id: job.user_id,
                  month_start: job.month_start
                }
              })
              break

            default:
              throw new Error(`Unknown analysis type: ${job.analysis_type}`)
          }
        } catch (invokeError) {
          // If invoke itself throws, rethrow with context
          throw new Error(`Failed to invoke ${functionName}: ${invokeError instanceof Error ? invokeError.message : String(invokeError)}`)
        }

        // Check for invocation errors in response
        if (response.error) {
          throw new Error(`Function invocation error: ${response.error.message || JSON.stringify(response.error)}`)
        }

        // Get result from data
        result = response.data

        // If data is null/undefined, try to parse error from response
        if (!result) {
          // Check if there's error info in the response
          if (response.error) {
            throw new Error(`Function error: ${response.error.message || JSON.stringify(response.error)}`)
          }
          // If no data and no error, might be a 400 response - log for debugging
          console.error(`Function ${functionName} returned null data for job ${job.id}. Response:`, JSON.stringify(response))
          throw new Error(`Function ${functionName} returned empty response`)
        }

        // Check if function call was successful
        if (result && result.success !== false) {
          // Mark as completed
          await supabase
            .from('analysis_queue')
            .update({
              status: 'completed',
              processed_at: new Date().toISOString()
            })
            .eq('id', job.id)

          console.log(`[PROCESS] ✅ Job ${job.id} completed: ${job.analysis_type} for user ${job.user_id}`)
          processed++
          results.push({ id: job.id, status: 'completed', type: job.analysis_type })
        } else {
          // Check if it's a validation error (like incomplete entry) that shouldn't be retried
          const errorMsg = result?.error || result?.message || 'Function returned unsuccessful result'
          const isValidationError = errorMsg.includes('incomplete') || 
                                   errorMsg.includes('Entry incomplete') ||
                                   errorMsg.includes('already exists') ||
                                   errorMsg.includes('too short')

          if (isValidationError) {
            // Mark as completed (skipped) for validation errors - don't retry
            await supabase
              .from('analysis_queue')
              .update({
                status: 'completed',
                processed_at: new Date().toISOString(),
                error_message: errorMsg
              })
              .eq('id', job.id)

            console.log(`[PROCESS] ⏭️ Job ${job.id} skipped (validation error): ${errorMsg}`)
            processed++
            results.push({ id: job.id, status: 'skipped', type: job.analysis_type, reason: errorMsg })
          } else {
            // Other errors should be retried
            throw new Error(errorMsg)
          }
        }

      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error'
        console.log(`[PROCESS] ❌ Job ${job.id} failed: ${errorMessage}`)
        const newAttempts = job.attempts + 1

        if (newAttempts >= job.max_attempts) {
          // Max retries reached, mark as failed
          await supabase
            .from('analysis_queue')
            .update({
              status: 'failed',
              error_message: errorMessage,
              processed_at: new Date().toISOString()
            })
            .eq('id', job.id)

          failed++
          results.push({ id: job.id, status: 'failed', type: job.analysis_type, error: errorMessage })
        } else {
          // Retry with exponential backoff
          const backoffMinutes = Math.pow(2, newAttempts) // 2, 4, 8 minutes
          const nextRetry = new Date(Date.now() + backoffMinutes * 60000)

          await supabase
            .from('analysis_queue')
            .update({
              status: 'pending',
              attempts: newAttempts,
              next_retry_at: nextRetry.toISOString(),
              error_message: errorMessage
            })
            .eq('id', job.id)

          results.push({ id: job.id, status: 'retry', type: job.analysis_type, attempts: newAttempts })
        }
      }
    }

    console.log(`[PROCESS] Summary: Processed=${processed}, Failed=${failed}, Total=${queueItems.length}`)

    return new Response(
      JSON.stringify({
        success: true,
        processed,
        failed,
        total: queueItems.length,
        results
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
