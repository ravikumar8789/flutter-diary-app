# **AI INSIGHTS SYSTEM REFINEMENT - DETAILED IMPLEMENTATION PLAN**

## **OVERVIEW**

This plan implements a refined batch processing system for AI insights with the following key features:
- **Queue Today's Entries**: Throughout the day (every 5 minutes)
- **Process Yesterday's Queue**: Only at midnight (12:00 AM)
- **Catch-up Analysis**: Analyze ALL entries from previous dates (not just yesterday)
- **Timezone-Aware**: All operations respect user's timezone
- **Weekly Analysis**: Triggers on Sunday midnight (not Monday)
- **Monthly Analysis**: Triggers on 1st of month at midnight
- **Entry Validation**: Check completion before queuing
- **Comprehensive Logging**: Track all operations

---

## **CORE FLOW DESIGN**

### **Daily Flow Example (Nov 17)**

**Day 1 (Nov 17):**
- 6:00 AM: User writes entry → Saved to `entries` table
- 6:05 AM: `populate-analysis-queue` runs → Finds Nov 17 entry → Queues it (`target_date: 2025-11-17`)
- 10:00 AM: User completes all 4 sections → Entry updated
- 10:05 AM: `populate-analysis-queue` runs → Checks Nov 17 entry → Already queued, skips
- ... (runs every 5 minutes all day)
- 11:55 PM: Last queue check → Ensures Nov 17 entry is queued

**Day 2 (Nov 18):**
- 12:00 AM (midnight): `process-ai-queue` runs → Processes only `target_date = 2025-11-17` jobs
- 12:01 AM: If more jobs, runs again → Processes next batch
- ... (continues until all Nov 17 jobs are processed)
- 6:00 AM: User opens app → Sees "Yesterday's Insight" (from Nov 17)

---

## **PHASE 1: MODIFY `populate-analysis-queue` FUNCTION**

### **1.1 Change Daily Analysis Logic**

#### **Current Behavior:**
- Checks for YESTERDAY's entries only
- Queues yesterday's entry if found

#### **New Behavior:**
- Check TODAY's entries (in user's timezone)
- Queue today's entry with `target_date = today`
- Also check for ANY previous date entries that don't have insights (catch-up)

#### **Implementation Steps:**

**Step 1.1.1: Queue Today's Entry**
```typescript
// Calculate today's date in user's timezone
const todayStr = todayInTz.toISOString().split('T')[0]

// Find entry from TODAY
const { data: todayEntry } = await supabase
  .from('entries')
  .select('id, diary_text, entry_date')
  .eq('user_id', user.id)
  .eq('entry_date', todayStr)
  .single()

if (todayEntry) {
  // Check entry completion BEFORE queuing
  const { data: isComplete } = await supabase.rpc(
    'check_entry_completion',
    { entry_uuid: todayEntry.id }
  )

  if (isComplete && (todayEntry.diary_text?.length || 0) >= 50) {
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
      await supabase.from('analysis_queue').insert({
        user_id: user.id,
        analysis_type: 'daily',
        target_date: todayStr,  // TODAY's date
        entry_id: todayEntry.id,
        status: 'pending',
        next_retry_at: new Date().toISOString()
      })
      console.log(`[QUEUE] Queued today's entry for user ${user.id}, date: ${todayStr}, entry_id: ${todayEntry.id}`)
      dailyQueued++
    }
  }
}
```

**Step 1.1.2: Catch-up Analysis (Previous Dates)**
```typescript
// Find ALL entries from previous dates (before today) that don't have insights
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
      await supabase.from('analysis_queue').insert({
        user_id: user.id,
        analysis_type: 'daily',
        target_date: entry.entry_date,  // Previous date
        entry_id: entry.id,
        status: 'pending',
        next_retry_at: new Date().toISOString()
      })
      console.log(`[QUEUE] Queued catch-up entry for user ${user.id}, date: ${entry.entry_date}, entry_id: ${entry.id}`)
      dailyQueued++
    }
  }
}
```

**Step 1.1.3: Add Logging**
```typescript
// At the end of user processing
console.log(`[QUEUE] User ${user.id} (${userTimezone}): Daily=${dailyQueued}, Weekly=${weeklyQueued}, Monthly=${monthlyQueued}`)
```

---

### **1.2 Change Weekly Analysis Trigger**

#### **Current Behavior:**
- Triggers on Monday (`dayOfWeek === 1`)

#### **New Behavior:**
- Triggers on Sunday (`dayOfWeek === 0`)
- Only queue at midnight (12:00 AM) on Sunday

#### **Implementation:**
```typescript
// 2. WEEKLY: Check if Sunday and previous week needs analysis
const dayOfWeek = todayInTz.getDay() // 0 = Sunday, 1 = Monday
const currentHour = todayInTz.getHours()

// Only queue on Sunday at midnight (00:00)
if (dayOfWeek === 0 && currentHour === 0) {
  const lastWeekStart = new Date(todayInTz)
  lastWeekStart.setDate(lastWeekStart.getDate() - 7)
  // Set to Monday of last week
  const dayOffset = lastWeekStart.getDay() === 0 ? 6 : lastWeekStart.getDay() - 1
  lastWeekStart.setDate(lastWeekStart.getDate() - dayOffset)
  const lastWeekStartStr = lastWeekStart.toISOString().split('T')[0]

  // ... rest of weekly logic
  console.log(`[QUEUE] Queued weekly analysis for user ${user.id}, week_start: ${lastWeekStartStr}`)
}
```

---

### **1.3 Change Monthly Analysis Trigger**

#### **Current Behavior:**
- Triggers on 1st of month (any time)

#### **New Behavior:**
- Triggers on 1st of month at midnight (00:00)

#### **Implementation:**
```typescript
// 3. MONTHLY: Check if 1st of month at midnight
const isFirstOfMonth = todayInTz.getDate() === 1
const currentHour = todayInTz.getHours()

if (isFirstOfMonth && currentHour === 0) {
  const lastMonth = new Date(todayInTz.getFullYear(), todayInTz.getMonth() - 1, 1)
  const lastMonthStr = lastMonth.toISOString().split('T')[0]

  // ... rest of monthly logic
  console.log(`[QUEUE] Queued monthly analysis for user ${user.id}, month_start: ${lastMonthStr}`)
}
```

---

### **1.4 Add Entry Completion Validation**

#### **Before Queuing Any Entry:**
```typescript
// Always check completion before queuing
const { data: isComplete, error: completionError } = await supabase.rpc(
  'check_entry_completion',
  { entry_uuid: entry.id }
)

if (completionError) {
  console.error(`[QUEUE] Completion check failed for entry ${entry.id}:`, completionError)
  continue // Skip this entry
}

if (!isComplete) {
  console.log(`[QUEUE] Skipping incomplete entry ${entry.id} for user ${user.id}`)
  continue // Skip incomplete entries
}
```

---

## **PHASE 2: MODIFY `process-ai-queue` FUNCTION**

### **2.1 Change to Process Only Yesterday's Queue**

#### **Current Behavior:**
- Processes ALL pending jobs (any `target_date`)

#### **New Behavior:**
- Only process jobs where `target_date = yesterday` (in UTC or user's timezone)
- Process in batches until queue is empty

#### **Implementation:**

**Step 2.1.1: Calculate Yesterday's Date**
```typescript
// Calculate yesterday's date (in UTC for consistency)
const now = new Date()
const yesterday = new Date(now)
yesterday.setDate(yesterday.getDate() - 1)
const yesterdayStr = yesterday.toISOString().split('T')[0]

console.log(`[PROCESS] Processing queue for target_date: ${yesterdayStr}`)
```

**Step 2.1.2: Filter by Yesterday's Date**
```typescript
// Fetch pending jobs that are ready to process AND are for yesterday
const { data: queueItems, error: queueError } = await supabase
  .from('analysis_queue')
  .select('*')
  .eq('status', 'pending')
  .eq('target_date', yesterdayStr)  // ONLY yesterday's queue
  .lte('next_retry_at', now.toISOString())
  .limit(10)  // Process 10 jobs per run

if (queueError) throw queueError

if (!queueItems || queueItems.length === 0) {
  return new Response(
    JSON.stringify({ 
      success: true, 
      message: `No items to process for ${yesterdayStr}`, 
      processed: 0,
      target_date: yesterdayStr
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

console.log(`[PROCESS] Found ${queueItems.length} jobs to process for ${yesterdayStr}`)
```

**Step 2.1.3: Add Detailed Logging**
```typescript
// Log each job being processed
console.log(`[PROCESS] Processing job ${job.id}: type=${job.analysis_type}, user=${job.user_id}, target_date=${job.target_date}`)

// Log success/failure
if (result && result.success !== false) {
  console.log(`[PROCESS] ✅ Job ${job.id} completed successfully`)
} else {
  console.log(`[PROCESS] ⚠️ Job ${job.id} failed: ${errorMsg}`)
}
```

**Step 2.1.4: Handle Multiple Runs (Batch Processing)**
```typescript
// Since we process 10 jobs per run, if there are 50 jobs:
// - Run 1 (12:00 AM): Processes 10 jobs
// - Run 2 (12:01 AM): Processes next 10 jobs
// - ... continues until queue is empty

// The cron job will keep running every minute at midnight until no jobs remain
// This is handled by the cron schedule: '0 0 * * *' (midnight only)
// But we can also add a loop if needed (see alternative below)
```

**Alternative: Process All Jobs in Single Run**
```typescript
// Option: Process ALL jobs in a loop until queue is empty
let totalProcessed = 0
let hasMoreJobs = true

while (hasMoreJobs) {
  const { data: batch } = await supabase
    .from('analysis_queue')
    .select('*')
    .eq('status', 'pending')
    .eq('target_date', yesterdayStr)
    .lte('next_retry_at', new Date().toISOString())
    .limit(10)

  if (!batch || batch.length === 0) {
    hasMoreJobs = false
    break
  }

  // Process batch
  for (const job of batch) {
    // ... process job
    totalProcessed++
  }

  // Small delay to avoid overwhelming the system
  await new Promise(resolve => setTimeout(resolve, 1000))
}

console.log(`[PROCESS] Completed processing ${totalProcessed} jobs for ${yesterdayStr}`)
```

**Recommendation:** Use the cron approach (runs every minute at midnight) rather than a loop, as it's more resilient to failures.

---

### **2.2 Add Timezone-Aware Processing**

#### **For Multi-User Processing:**
```typescript
// When processing, we need to ensure we're processing the right date
// Since queue is populated with user's timezone, target_date should match

// Example: User in PST (UTC-8)
// - Nov 17, 11:00 PM PST = Nov 18, 7:00 AM UTC
// - Queue has target_date = 2025-11-17 (PST date)
// - At midnight UTC, we process target_date = 2025-11-17
// - But for PST user, it's still Nov 17, 4:00 PM (not midnight yet)

// Solution: Process based on UTC midnight, but queue based on user's timezone
// This means some users' "yesterday" might be processed slightly early/late
// But it's acceptable for batch processing

// Better solution: Process in user's timezone (requires more complex logic)
// For now, UTC-based processing is simpler and acceptable
```

---

## **PHASE 3: UPDATE CRON SCHEDULES**

### **3.1 Update `populate-analysis-queue` Schedule**

#### **Current:**
- Runs every 5 minutes: `'*/5 * * * *'`

#### **New:**
- Keep same: `'*/5 * * * *'` (every 5 minutes, 24x7)

**SQL:**
```sql
-- Update existing schedule or create new
SELECT cron.unschedule('populate-analysis-queue');
SELECT cron.schedule(
  'populate-analysis-queue',
  '*/5 * * * *',  -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/populate-analysis-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

---

### **3.2 Update `process-ai-queue` Schedule**

#### **Current:**
- Runs every minute: `'* * * * *'`

#### **New:**
- Run only at midnight: `'0 0 * * *'` (00:00 every day)

**SQL:**
```sql
-- Update existing schedule
SELECT cron.unschedule('process-ai-queue');
SELECT cron.schedule(
  'process-ai-queue',
  '0 0 * * *',  -- Midnight only (00:00)
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-ai-queue',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Note:** Since we process 10 jobs per run, if there are more than 10 jobs, the function will need to run multiple times. We can either:
1. Keep cron running every minute at midnight (00:00, 00:01, 00:02, etc.) until queue is empty
2. Add a loop inside the function to process all jobs in one run

**Recommendation:** Option 1 (multiple cron runs) is more resilient to failures.

---

## **PHASE 4: ENHANCE LOGGING**

### **4.1 Add Comprehensive Logging to `populate-analysis-queue`**

```typescript
// Start of function
console.log(`[QUEUE] Starting queue population at ${new Date().toISOString()}`)

// Per user
console.log(`[QUEUE] Processing user ${user.id} (timezone: ${userTimezone})`)

// Per entry queued
console.log(`[QUEUE] ✅ Queued daily analysis: user=${user.id}, date=${target_date}, entry_id=${entry_id}`)
console.log(`[QUEUE] ⏭️ Skipped (already queued): user=${user.id}, date=${target_date}`)
console.log(`[QUEUE] ⏭️ Skipped (incomplete entry): user=${user.id}, entry_id=${entry_id}`)
console.log(`[QUEUE] ⏭️ Skipped (insight exists): user=${user.id}, entry_id=${entry_id}`)

// Summary
console.log(`[QUEUE] Summary: Users=${users.length}, Daily=${dailyQueued}, Weekly=${weeklyQueued}, Monthly=${monthlyQueued}`)
```

### **4.2 Add Comprehensive Logging to `process-ai-queue`**

```typescript
// Start of function
console.log(`[PROCESS] Starting queue processing at ${new Date().toISOString()}`)
console.log(`[PROCESS] Target date: ${yesterdayStr}`)

// Per job
console.log(`[PROCESS] Processing job ${job.id}: type=${job.analysis_type}, user=${job.user_id}, entry_id=${job.entry_id || 'N/A'}`)

// Success
console.log(`[PROCESS] ✅ Job ${job.id} completed: ${job.analysis_type} for user ${job.user_id}`)

// Failure
console.log(`[PROCESS] ❌ Job ${job.id} failed: ${errorMessage}`)
console.log(`[PROCESS] ⏭️ Job ${job.id} skipped (validation error): ${errorMsg}`)

// Summary
console.log(`[PROCESS] Summary: Processed=${processed}, Failed=${failed}, Total=${queueItems.length}`)
```

---

## **PHASE 5: TESTING & VALIDATION**

### **5.1 Test Scenarios**

#### **Scenario 1: Today's Entry Queuing**
1. User creates entry on Nov 17
2. Wait for `populate-analysis-queue` to run (within 5 minutes)
3. Check `analysis_queue` table:
   - Should have 1 job with `target_date = 2025-11-17`
   - Status should be `pending`

#### **Scenario 2: Catch-up Analysis**
1. Create entries for Nov 15, Nov 16 (without insights)
2. Run `populate-analysis-queue`
3. Check `analysis_queue`:
   - Should have jobs for Nov 15, Nov 16, Nov 17
   - All with `target_date` matching entry dates

#### **Scenario 3: Midnight Processing**
1. Queue entries for Nov 17 throughout the day
2. At midnight (Nov 18, 00:00), `process-ai-queue` should run
3. Check `analysis_queue`:
   - All Nov 17 jobs should be `completed` or `failed`
4. Check `entry_insights`:
   - Should have insights for Nov 17 entries

#### **Scenario 4: Weekly Analysis**
1. On Sunday at midnight, `populate-analysis-queue` should queue weekly analysis
2. `process-ai-queue` should process it
3. Check `weekly_insights` table for results

#### **Scenario 5: Monthly Analysis**
1. On 1st of month at midnight, `populate-analysis-queue` should queue monthly analysis
2. `process-ai-queue` should process it
3. Check `monthly_insights` table for results

#### **Scenario 6: Incomplete Entry**
1. Create entry with only 2 sections completed
2. Run `populate-analysis-queue`
3. Check `analysis_queue`:
   - Should NOT have job for incomplete entry

#### **Scenario 7: Timezone Handling**
1. User in PST (UTC-8) creates entry on Nov 17
2. Entry should be queued with `target_date = 2025-11-17` (PST date)
3. At UTC midnight (Nov 18, 00:00 UTC = Nov 17, 4:00 PM PST), process should run
4. This is acceptable - slight timing difference is okay for batch processing

---

### **5.2 Validation Queries**

#### **Check Queue Status:**
```sql
-- Count pending jobs by target_date
SELECT target_date, COUNT(*) as pending_count
FROM analysis_queue
WHERE status = 'pending'
GROUP BY target_date
ORDER BY target_date DESC;

-- Check today's queued entries
SELECT aq.*, e.entry_date, e.diary_text
FROM analysis_queue aq
JOIN entries e ON aq.entry_id = e.id
WHERE aq.target_date = CURRENT_DATE
  AND aq.status = 'pending';

-- Check yesterday's processed jobs
SELECT aq.*, ei.id as insight_id
FROM analysis_queue aq
LEFT JOIN entry_insights ei ON aq.entry_id = ei.entry_id
WHERE aq.target_date = CURRENT_DATE - INTERVAL '1 day'
ORDER BY aq.processed_at DESC;
```

---

## **PHASE 6: DEPLOYMENT STEPS**

### **6.1 Pre-Deployment Checklist**
- [ ] Backup `analysis_queue` table (if has data)
- [ ] Backup `entry_insights` table
- [ ] Test in development/staging first
- [ ] Verify cron jobs are set up correctly
- [ ] Verify timezone handling works

### **6.2 Deployment Order**
1. **Deploy `populate-analysis-queue` function** (updated logic)
2. **Deploy `process-ai-queue` function** (updated logic)
3. **Update cron schedules** (change `process-ai-queue` to midnight only)
4. **Monitor logs** for first 24 hours
5. **Verify queue population** (check every 5 minutes)
6. **Verify midnight processing** (check at 12:00 AM)

### **6.3 Rollback Plan**
- If issues occur, revert to previous function versions
- Cron schedules can be updated back to every minute
- Queue will continue to populate (no data loss)

---

## **PHASE 7: MONITORING & MAINTENANCE**

### **7.1 Key Metrics to Monitor**
- Queue population rate (jobs queued per day)
- Processing success rate (completed vs failed)
- Average processing time per job
- Queue backlog (pending jobs count)
- Error rates by type

### **7.2 Alert Conditions**
- Queue backlog > 100 jobs
- Processing failure rate > 10%
- No jobs processed at midnight (indicates cron issue)
- Queue population stopped (indicates function issue)

### **7.3 Maintenance Tasks**
- Weekly review of failed jobs
- Monthly cleanup of old queue entries (older than 30 days)
- Monitor OpenAI API costs
- Review and optimize prompts if needed

---

## **SUMMARY OF CHANGES**

### **Files to Modify:**
1. `supabase/functions/populate-analysis-queue/index.ts`
   - Change daily logic: Queue today's entries (not yesterday's)
   - Add catch-up logic: Queue all previous date entries without insights
   - Change weekly trigger: Sunday midnight (not Monday)
   - Change monthly trigger: 1st of month at midnight
   - Add entry completion validation
   - Add comprehensive logging

2. `supabase/functions/process-ai-queue/index.ts`
   - Filter by `target_date = yesterday` only
   - Add detailed logging
   - Process in batches (10 jobs per run)

3. Cron Schedules (SQL)
   - `populate-analysis-queue`: Keep `'*/5 * * * *'` (every 5 min)
   - `process-ai-queue`: Change to `'0 0 * * *'` (midnight only)

### **Key Benefits:**
- ✅ Queues today's entries as they're written
- ✅ Batch processes at midnight (cost efficient)
- ✅ Catches up on missed entries (2-3 days ago)
- ✅ Timezone-aware (respects user's timezone)
- ✅ Validates entry completion before queuing
- ✅ Comprehensive logging for debugging
- ✅ Predictable timing (users see insights in morning)

---

## **END OF PLAN**

This plan provides a complete implementation guide for the refined AI insights batch processing system. Follow each phase sequentially and test thoroughly before moving to the next phase.

