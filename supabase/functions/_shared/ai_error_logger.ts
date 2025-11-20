import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface ErrorLogContext {
  userId?: string
  entryId?: string | null
  analysisType: 'daily' | 'weekly' | 'monthly' | 'affirmation'
  errorCode: string
  requestBody?: any
  requestDurationMs?: number
  retryAttempt?: number
  edgeFunctionName: string
  failedAtStep?: string
  relatedRequestId?: string | null
  errorDetails?: Record<string, any>
}

/**
 * Logs AI function errors to ai_errors_log table with comprehensive context
 */
export async function logAIError(
  supabase: any,
  error: Error | unknown,
  context: ErrorLogContext
): Promise<void> {
  try {
    const errorMessage = error instanceof Error ? error.message : String(error)
    const stackTrace = error instanceof Error ? error.stack : undefined
    
    // Determine error type from message
    const errorType = determineErrorType(errorMessage)
    
    // Determine severity based on error type and analysis type
    const severity = determineSeverity(errorType, context.analysisType)
    
    // Infer failed step if not provided
    const failedStep = context.failedAtStep || inferFailedStep(errorMessage, context.edgeFunctionName)
    
    // Get environment
    const environment = Deno.env.get('ENVIRONMENT') || Deno.env.get('DENO_ENV') || 'production'
    
    // Get Deno version
    const denoVersion = Deno.version?.deno || 'unknown'
    
    await supabase.from('ai_errors_log').insert({
      user_id: context.userId || null,
      entry_id: context.entryId || null,
      analysis_type: context.analysisType,
      error_code: context.errorCode,
      error_message: errorMessage,
      error_type: errorType,
      error_severity: severity,
      request_body: context.requestBody || null,
      request_duration_ms: context.requestDurationMs || null,
      retry_attempt: context.retryAttempt || 0,
      edge_function_name: context.edgeFunctionName,
      environment: environment,
      deno_version: denoVersion,
      stack_trace: stackTrace || null,
      error_details: context.errorDetails || {},
      failed_at_step: failedStep,
      auto_retry_attempted: (context.retryAttempt || 0) > 0,
      related_request_id: context.relatedRequestId || null,
    })
  } catch (logError) {
    // Fallback: console error if logging fails (don't throw - we're already in error handler)
    console.error('Failed to log AI error to database:', logError)
    console.error('Original error that we tried to log:', error)
    console.error('Error context:', context)
  }
}

/**
 * Determines error type from error message
 */
function determineErrorType(errorMessage: string): string {
  const msg = errorMessage.toLowerCase()
  
  if (msg.includes('openai') || msg.includes('api key') || msg.includes('api error')) {
    return 'openai_api_error'
  }
  if (msg.includes('rate limit') || msg.includes('429') || msg.includes('too many requests')) {
    return 'rate_limit_error'
  }
  if (msg.includes('supabase') || msg.includes('database') || msg.includes('sql') || msg.includes('postgres')) {
    return 'supabase_error'
  }
  if (msg.includes('timeout') || msg.includes('timed out')) {
    return 'timeout_error'
  }
  if (msg.includes('network') || msg.includes('fetch') || msg.includes('connection') || msg.includes('econnrefused')) {
    return 'network_error'
  }
  if (msg.includes('validation') || msg.includes('invalid') || msg.includes('required') || msg.includes('missing')) {
    return 'validation_error'
  }
  if (msg.includes('not found') || msg.includes('entry') || msg.includes('does not exist')) {
    return 'data_error'
  }
  
  return 'unknown_error'
}

/**
 * Determines error severity based on error type and analysis type
 */
function determineSeverity(errorType: string, analysisType: string): string {
  // Critical: Data loss, security issues, critical system failures
  if (errorType === 'supabase_error' && analysisType === 'daily') {
    return 'HIGH' // Daily insights are important for user engagement
  }
  
  // High: API failures, network issues that affect core functionality
  if (['openai_api_error', 'network_error', 'timeout_error'].includes(errorType)) {
    return 'HIGH'
  }
  
  // Medium: Rate limits, validation errors that can be recovered
  if (['rate_limit_error', 'validation_error'].includes(errorType)) {
    return 'MEDIUM'
  }
  
  // Low: Unknown errors, minor issues
  if (errorType === 'data_error' && analysisType === 'weekly') {
    return 'MEDIUM' // Weekly analysis can wait
  }
  
  return 'LOW'
}

/**
 * Infers which step failed based on error message and function name
 */
function inferFailedStep(errorMessage: string, functionName: string): string {
  const msg = errorMessage.toLowerCase()
  
  if (msg.includes('entry not found') || msg.includes('fetch entry') || msg.includes('entry does not exist')) {
    return 'fetch_entry'
  }
  if (msg.includes('openai') || msg.includes('api') || msg.includes('chat/completions')) {
    return 'call_openai'
  }
  if (msg.includes('save') || msg.includes('insert') || msg.includes('upsert') || msg.includes('entry_insights') || msg.includes('weekly_insights')) {
    return 'save_insight'
  }
  if (msg.includes('template') || msg.includes('prompt') || msg.includes('ai_prompt_templates')) {
    return 'build_prompt'
  }
  if (msg.includes('context') || msg.includes('aggregate') || msg.includes('calculate')) {
    return 'build_context'
  }
  if (msg.includes('validate') || msg.includes('required') || msg.includes('missing')) {
    return 'validate_input'
  }
  if (msg.includes('parse') || msg.includes('json') || msg.includes('response')) {
    return 'parse_response'
  }
  
  return 'unknown'
}

