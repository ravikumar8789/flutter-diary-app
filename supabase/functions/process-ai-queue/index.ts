import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logAIError } from '../_shared/ai_error_logger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Constants for recursive self-invocation
const BATCH_SIZE = 20  // Reduced from 50 for safety margin (20% of 400s timeout)
const MAX_RECURSION_DEPTH = 50  // Safety limit to prevent infinite recursion
const ACTIVE_PROCESSING_THRESHOLD = 30  // Jobs processing threshold for cron conflict check

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Parse request body for recursive flag
    const requestBody = await req.json().catch(() => ({}))
    const isRecursive = requestBody?.recursive === true
    const batchNumber = requestBody?.batch_number || 0

    const now = new Date()
    console.log(`[PROCESS] Starting queue processing at ${now.toISOString()}${isRecursive ? ` (recursive batch ${batchNumber})` : ' (cron-triggered)'}`)

    // Check recursion depth limit
    if (batchNumber >= MAX_RECURSION_DEPTH) {
      console.log(`[PROCESS] Max recursion depth reached (${MAX_RECURSION_DEPTH})`)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Max recursion depth reached',
          processed: 0,
          batch_number: batchNumber
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // For cron-triggered runs: Check if recursive processing is active
    if (!isRecursive) {
      // First, reset jobs stuck in processing for > 10 minutes (self-healing)
      try {
        const { data: stuckJobs, error: stuckError } = await supabase
          .from('analysis_queue')
          .select('id')
          .eq('status', 'processing')
          .lt('updated_at', new Date(Date.now() - 10 * 60 * 1000).toISOString())
        
        if (stuckError) {
          console.error(`[PROCESS] Error checking stuck jobs:`, stuckError)
        } else if (stuckJobs && stuckJobs.length > 0) {
          console.log(`[PROCESS] Found ${stuckJobs.length} stuck jobs (>10 min), resetting to pending`)
          const stuckJobIds = stuckJobs.map((j: any) => j.id)
          try {
            await supabase
              .from('analysis_queue')
              .update({ status: 'pending' })
              .in('id', stuckJobIds)
            console.log(`[PROCESS] ✅ Reset ${stuckJobIds.length} stuck jobs to pending`)
          } catch (resetError) {
            console.error(`[PROCESS] ❌ Error resetting stuck jobs:`, resetError)
          }
        }
      } catch (resetError) {
        console.error(`[PROCESS] Error in stuck jobs cleanup:`, resetError)
      }
      
      // Then check active processing (existing logic)
      const { data: activeProcessing, error: activeError } = await supabase
        .from('analysis_queue')
        .select('id')
        .eq('status', 'processing')
        .gte('updated_at', new Date(Date.now() - 10 * 60 * 1000).toISOString())
      
      if (activeError) {
        console.error(`[PROCESS] Error checking active processing:`, activeError)
      } else if (activeProcessing && activeProcessing.length > ACTIVE_PROCESSING_THRESHOLD) {
        console.log(`[PROCESS] Skipping cron run - ${activeProcessing.length} jobs already processing`)
        return new Response(
          JSON.stringify({
            success: true,
            message: 'Recursive processing active, skipping cron run',
            skipped: true,
            active_jobs: activeProcessing.length
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Use atomic job claiming instead of SELECT + UPDATE (prevents race conditions)
    const { data: claimedJobs, error: claimError } = await supabase.rpc('claim_pending_jobs', {
      p_batch_size: BATCH_SIZE
      // Removed p_max_retry_at - not used anymore, kept parameter for backward compatibility
    })

    if (claimError) {
      console.error(`[PROCESS] Error claiming jobs:`, claimError)
      throw claimError
    }

    if (!claimedJobs || claimedJobs.length === 0) {
      console.log(`[PROCESS] No jobs to process`)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No jobs to process',
          processed: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[PROCESS] Claimed ${claimedJobs.length} jobs for processing`)

    // SUPER LOGIC: Database already filtered by process_after (next_retry_at) <= NOW()
    // All claimed jobs are eligible - no timezone filtering needed!
    const queueItems = claimedJobs

    // Get unique user IDs and fetch their timezones (only needed for AI analysis functions)
    const userIds = [...new Set(queueItems.map((job: any) => job.user_id))]
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, timezone')
      .in('id', userIds)

    if (usersError) {
      console.error(`[PROCESS] Error fetching user timezones:`, usersError)
      const duration = Date.now() - startTime
      
      // Reset claimed jobs before throwing to prevent them from getting stuck
      if (queueItems && queueItems.length > 0) {
        const jobIds = queueItems.map((job: any) => job.id)
        console.log(`[PROCESS] Resetting ${jobIds.length} claimed jobs due to users fetch error`)
        try {
          await supabase
            .from('analysis_queue')
            .update({ status: 'pending' })
            .in('id', jobIds)
          console.log(`[PROCESS] ✅ Reset ${jobIds.length} jobs to pending due to users error`)
        } catch (resetError) {
          console.error(`[PROCESS] ❌ Error resetting jobs on users error:`, resetError)
        }
      }
      
      await logAIError(supabase, usersError, {
        userId: undefined,
        entryId: null,
        analysisType: 'daily',
        errorCode: 'ERRQUEUE_PROCESS_002',
        requestBody: { user_ids: userIds },
        requestDurationMs: duration,
        edgeFunctionName: 'process-ai-queue',
        failedAtStep: 'fetch_users',
        errorDetails: { error: usersError.message, code: usersError.code }
      })
      
      throw usersError
    }

    // Create a map of user_id -> timezone (only needed for AI analysis functions)
    const userTimezoneMap = new Map<string, string>()
    users?.forEach((user: any) => {
      userTimezoneMap.set(user.id, user.timezone || 'UTC')
    })

    if (queueItems.length === 0) {
      console.log(`[PROCESS] No jobs to process (all eligible jobs already processed)`)
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No jobs to process', 
          processed: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`[PROCESS] Found ${queueItems.length} eligible jobs to process (database filtered by process_after)`)

    let processed = 0
    let failed = 0
    const results: any[] = []

    for (const job of queueItems) {
      try {
        console.log(`[PROCESS] Processing job ${job.id}: type=${job.analysis_type}, user=${job.user_id}, target_date=${job.target_date}, entry_id=${job.entry_id || 'N/A'}`)
        
        // Note: Job status already set to 'processing' by claim_pending_jobs()
        // No need to update again

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
        const jobDuration = Date.now() - startTime

        // Determine error code and failed step
        let errorCode = 'ERRQUEUE_PROCESS_003'
        let failedStep = 'job_processing'
        
        if (errorMessage.includes('invoke') || errorMessage.includes('Function')) {
          errorCode = 'ERRQUEUE_PROCESS_004'
          failedStep = 'invoke_function'
        } else if (errorMessage.includes('Missing') || errorMessage.includes('required')) {
          errorCode = 'ERRQUEUE_PROCESS_003'
          failedStep = 'validate_job'
        }

        // Log job processing error
        try {
          await logAIError(supabase, error, {
            userId: job.user_id,
            entryId: job.entry_id || null,
            analysisType: job.analysis_type || 'daily',
            errorCode: errorCode,
            requestBody: {
              job_id: job.id,
              job_type: job.analysis_type,
              target_date: job.target_date,
              entry_id: job.entry_id,
              week_start: job.week_start,
              month_start: job.month_start,
              attempts: job.attempts
            },
            requestDurationMs: jobDuration,
            retryAttempt: job.attempts,
            edgeFunctionName: 'process-ai-queue',
            failedAtStep: failedStep,
            errorDetails: {
              job_id: job.id,
              analysis_type: job.analysis_type,
              max_attempts: job.max_attempts,
              current_attempts: newAttempts
            }
          })
        } catch (logError) {
          console.error('Failed to log job error:', logError)
        }

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
          // Retry - hourly cron will handle timing automatically
          await supabase
            .from('analysis_queue')
            .update({
              status: 'pending',
              attempts: newAttempts,
              error_message: errorMessage
              // Removed next_retry_at - hourly cron handles retries
            })
            .eq('id', job.id)

          results.push({ id: job.id, status: 'retry', type: job.analysis_type, attempts: newAttempts })
        }
      }
    }

    console.log(`[PROCESS] Summary: Processed=${processed}, Failed=${failed}, Total=${queueItems.length}`)

    // SUPER LOGIC: Check for remaining eligible jobs (database filters by process_after <= NOW())
    // Only self-invoke if progress was made (prevents infinite recursion)
    if (processed > 0 || failed > 0) {
      const { data: remainingJobs, error: remainingError } = await supabase
        .from('analysis_queue')
        .select('id')
        .eq('status', 'pending')
        .or('next_retry_at.is.null,next_retry_at.lte.' + new Date().toISOString())
        .limit(1)

      if (remainingError) {
        console.error(`[PROCESS] Error checking remaining jobs:`, remainingError)
      }

      if (remainingJobs && remainingJobs.length > 0) {
        console.log(`[PROCESS] Progress made (processed=${processed}, failed=${failed}), self-invoking next batch (batch ${batchNumber + 1})`)
        
        // Fire-and-forget self-invocation (don't await)
        supabase.functions.invoke('process-ai-queue', {
          body: {
            recursive: true,
            batch_number: batchNumber + 1
          }
        }).catch(err => {
          console.error(`[PROCESS] Self-invoke failed for batch ${batchNumber + 1}:`, err)
        })
        
        return new Response(
          JSON.stringify({
            success: true,
            processed,
            failed,
            total: queueItems.length,
            results,
            remaining: remainingJobs.length,
            next_batch_triggered: true,
            batch_number: batchNumber
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      } else {
        console.log(`[PROCESS] No remaining eligible jobs, processing complete`)
      }
    } else {
      console.log(`[PROCESS] No progress made (processed=${processed}, failed=${failed}), stopping recursion to prevent infinite loop`)
    }

    // No remaining jobs, return normal response
    return new Response(
      JSON.stringify({
        success: true,
        processed,
        failed,
        total: queueItems.length,
        results,
        remaining: 0,
        next_batch_triggered: false,
        batch_number: batchNumber
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    const duration = Date.now() - startTime
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'

    // Reset any claimed jobs that might be stuck (safety net for unexpected crashes)
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      
      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey)
        
        // Reset jobs stuck in processing for this function run
        // Only reset jobs updated in last 5 minutes (likely from this run)
        const { error: resetError } = await supabase
          .from('analysis_queue')
          .update({ status: 'pending' })
          .eq('status', 'processing')
          .gte('updated_at', new Date(Date.now() - 5 * 60 * 1000).toISOString())
        
        if (resetError) {
          console.error(`[PROCESS] Error resetting stuck jobs in error handler:`, resetError)
        } else {
          console.log(`[PROCESS] Reset stuck jobs in error handler (safety net)`)
        }
        
        // Log overall function error
        // Determine error code
        let errorCode = 'ERRQUEUE_PROCESS_002'
        let failedStep = 'unknown'
        
        if (errorMessage.includes('Missing Supabase')) {
          errorCode = 'ERRQUEUE_PROCESS_001'
          failedStep = 'config_check'
        } else if (errorMessage.includes('queue') || errorMessage.includes('fetch')) {
          errorCode = 'ERRQUEUE_PROCESS_002'
          failedStep = 'fetch_queue'
        }
        
        await logAIError(supabase, error, {
          userId: undefined,
          entryId: null,
          analysisType: 'daily',
          errorCode: errorCode,
          requestBody: null,
          requestDurationMs: duration,
          edgeFunctionName: 'process-ai-queue',
          failedAtStep: failedStep,
          errorDetails: { error_message: errorMessage }
        })
      }
    } catch (logError) {
      console.error('Failed to log function error:', logError)
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
