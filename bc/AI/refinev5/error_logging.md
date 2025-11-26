# Error Logging Implementation Plan

## Current Status

### ✅ Functions with Error Logging
- `ai-analyze-daily` - Logs to `ai_errors_log` ✅
- `ai-analyze-weekly` - Logs to `ai_errors_log` ✅
- `ai-analyze-monthly` - Logs to `ai_errors_log` ✅

### ❌ Functions Missing Error Logging
- `populate-analysis-queue` - Only console.error
- `process-ai-queue` - Only console.log/error

---

## Error Logging Fields (ai_errors_log table)

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `user_id` | uuid | Affected user (if applicable) | User who triggered analysis |
| `entry_id` | uuid | Affected entry (if applicable) | Entry being analyzed |
| `analysis_type` | text | Type of analysis | 'daily', 'weekly', 'monthly', 'affirmation' |
| `error_code` | text | Unique error identifier | 'ERRQUEUE_POPULATE_001' |
| `error_message` | text | Human-readable error | Full error message |
| `error_type` | text | Categorized error | 'supabase_error', 'network_error', etc. |
| `error_severity` | text | Impact level | 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW' |
| `request_body` | jsonb | Request context | Function input parameters |
| `request_duration_ms` | integer | Execution time | 1234 |
| `retry_attempt` | integer | Retry count | 0, 1, 2 |
| `edge_function_name` | text | Function identifier | 'populate-analysis-queue' |
| `environment` | text | Deployment env | 'production' |
| `deno_version` | text | Runtime version | '2.1.4' |
| `stack_trace` | text | Full stack trace | Error stack |
| `error_details` | jsonb | Additional context | Custom metadata |
| `failed_at_step` | text | Where it failed | 'rpc_call', 'job_processing' |
| `auto_retry_attempted` | boolean | Retry status | true/false |
| `related_request_id` | uuid | Linked request | ai_requests_log.id |

---

## Implementation Plan

### 1. populate-analysis-queue

**Error Scenarios:**
- Missing Supabase config
- RPC call failure (`process_analysis_queue_batch`)
- Database connection errors

**Error Codes:**
- `ERRQUEUE_POPULATE_001` - Missing Supabase configuration
- `ERRQUEUE_POPULATE_002` - RPC call failed
- `ERRQUEUE_POPULATE_003` - Database connection error

**Context to Capture:**
- `analysis_type`: null (queue function, not analysis)
- `user_id`: null (batch operation)
- `entry_id`: null
- `request_body`: RPC response data (if available)
- `failed_at_step`: 'rpc_call', 'config_check', 'db_connection'
- `error_details`: { rpc_data, users_processed, jobs_created }

**Severity Mapping:**
- Config errors → HIGH (blocks all queue population)
- RPC failures → HIGH (critical function)
- Network errors → MEDIUM (retryable)

---

### 2. process-ai-queue

**Error Scenarios:**
- Missing Supabase config
- Queue fetch errors
- Job processing failures (per job)
- Function invocation errors
- Timezone calculation errors

**Error Codes:**
- `ERRQUEUE_PROCESS_001` - Missing Supabase configuration
- `ERRQUEUE_PROCESS_002` - Queue fetch failed
- `ERRQUEUE_PROCESS_003` - Job processing failed (per job)
- `ERRQUEUE_PROCESS_004` - Function invocation failed
- `ERRQUEUE_PROCESS_005` - Timezone calculation error

**Context to Capture:**
- `analysis_type`: From job (daily/weekly/monthly)
- `user_id`: From job.user_id
- `entry_id`: From job.entry_id (if daily)
- `request_body`: { job_id, job_type, target_date, attempts }
- `retry_attempt`: From job.attempts
- `failed_at_step`: 'fetch_queue', 'invoke_function', 'timezone_check', 'job_update'
- `error_details`: { job_id, analysis_type, function_name, response_data }

**Severity Mapping:**
- Config errors → HIGH
- Queue fetch → HIGH (blocks processing)
- Job failures → MEDIUM (individual jobs, retryable)
- Invocation errors → MEDIUM (function-level, retryable)

**Special Handling:**
- Log per-job errors (inside job loop)
- Log overall function errors (outer catch)
- Track retry attempts from job.attempts

---

## Implementation Steps

1. **Import error logger** in both functions
   ```ts
   import { logAIError } from '../_shared/ai_error_logger.ts'
   ```

2. **Add error logging to populate-analysis-queue**
   - Wrap RPC call in try-catch
   - Log config errors
   - Log RPC failures with response data
   - Capture execution duration

3. **Add error logging to process-ai-queue**
   - Log overall function errors (outer catch)
   - Log per-job errors (inner catch)
   - Track job context (job_id, type, attempts)
   - Log function invocation failures

4. **Update error logger helper** (if needed)
   - Add queue-specific failed_at_step values
   - Handle null analysis_type for queue functions

---

## Error Code Reference

### Queue Functions
- `ERRQUEUE_POPULATE_001` - Config missing
- `ERRQUEUE_POPULATE_002` - RPC failed
- `ERRQUEUE_POPULATE_003` - DB connection error
- `ERRQUEUE_PROCESS_001` - Config missing
- `ERRQUEUE_PROCESS_002` - Queue fetch failed
- `ERRQUEUE_PROCESS_003` - Job processing failed
- `ERRQUEUE_PROCESS_004` - Function invocation failed
- `ERRQUEUE_PROCESS_005` - Timezone error

### Analysis Functions (existing)
- `ERRAI_DAILY_001` - Daily analysis error
- `ERRAI_DAILY_SAVE_001` - Daily save error
- `ERRAI_WEEKLY_001` - Weekly analysis error
- `ERRAI_MONTHLY_001` - Monthly analysis error
- `ERRAI_MONTHLY_SAVE_001` - Monthly save error

---

## Testing Checklist

- [ ] Config errors logged correctly
- [ ] RPC failures captured with context
- [ ] Per-job errors logged with job details
- [ ] Retry attempts tracked correctly
- [ ] Error severity assigned appropriately
- [ ] Stack traces included
- [ ] Request duration captured
- [ ] Error details contain relevant context

---

## Notes

- Queue functions don't have direct `analysis_type` - use from job context or null
- `populate-analysis-queue` is batch operation (no user_id/entry_id)
- `process-ai-queue` handles multiple jobs - log each failure separately
- Track retry attempts from `job.attempts` field
- Use appropriate severity based on impact (queue blocking = HIGH)

