import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { logAIError } from '../_shared/ai_error_logger.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

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

    console.log(`[QUEUE] Invoking process_analysis_queue_batch at ${new Date().toISOString()}`)

    const { data, error } = await supabase.rpc('process_analysis_queue_batch')

    if (error) {
      console.error('[QUEUE] RPC failed:', error)
      const duration = Date.now() - startTime
      
      // Log RPC failure
      await logAIError(supabase, error, {
        userId: undefined,
        entryId: null,
        analysisType: 'daily', // Default for queue function
        errorCode: 'ERRQUEUE_POPULATE_002',
        requestBody: { rpc_name: 'process_analysis_queue_batch' },
        requestDurationMs: duration,
        edgeFunctionName: 'populate-analysis-queue',
        failedAtStep: 'rpc_call',
        errorDetails: { 
          rpc_error: error.message,
          rpc_code: error.code,
          rpc_details: error.details,
          rpc_hint: error.hint
        }
      })
      
      throw error
    }

    const responsePayload = {
      success: true,
      users_processed: data?.users_processed ?? 0,
      daily_jobs_created: data?.daily_jobs_created ?? 0,
      weekly_jobs_created: data?.weekly_jobs_created ?? 0,
      monthly_jobs_created: data?.monthly_jobs_created ?? 0
    }

    console.log('[QUEUE] Batch summary:', responsePayload)

    return new Response(
      JSON.stringify(responsePayload),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('[QUEUE] Execution error:', error)
    const duration = Date.now() - startTime
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'

    // Try to log the error
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      
      if (supabaseUrl && supabaseServiceKey) {
        const supabase = createClient(supabaseUrl, supabaseServiceKey)
        
        // Determine error code based on error type
        let errorCode = 'ERRQUEUE_POPULATE_003'
        let failedStep = 'unknown'
        
        if (errorMessage.includes('Missing Supabase')) {
          errorCode = 'ERRQUEUE_POPULATE_001'
          failedStep = 'config_check'
        } else if (errorMessage.includes('RPC') || errorMessage.includes('rpc')) {
          errorCode = 'ERRQUEUE_POPULATE_002'
          failedStep = 'rpc_call'
        } else if (errorMessage.includes('database') || errorMessage.includes('connection')) {
          errorCode = 'ERRQUEUE_POPULATE_003'
          failedStep = 'db_connection'
        }
        
        await logAIError(supabase, error, {
          userId: undefined,
          entryId: null,
          analysisType: 'daily', // Default for queue function
          errorCode: errorCode,
          requestBody: null,
          requestDurationMs: duration,
          edgeFunctionName: 'populate-analysis-queue',
          failedAtStep: failedStep,
          errorDetails: { error_message: errorMessage }
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
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

