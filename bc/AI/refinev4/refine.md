# AI Queue System Timezone Fix Plan

## Overview
This document outlines the plan to fix 3 critical timezone-related issues in the AI analysis queue system that cause incorrect scheduling and processing of user entries.

---

## Issues Identified

### **Equation 1: `next_retry_at` Set to NOW Instead of Tomorrow Midnight**
- **Location**: `supabase/functions/populate-analysis-queue/index.ts` (lines 116, 179, 236, 288)
- **Problem**: `next_retry_at` is set to current UTC time instead of tomorrow midnight UTC
- **Impact**: Jobs may be processed immediately or at wrong times

### **Equation 2: `process-ai-queue` Uses UTC Instead of User Timezone**
- **Location**: `supabase/functions/process-ai-queue/index.ts` (lines 24-38)
- **Problem**: Calculates "yesterday" in UTC for all users, ignoring individual timezones
- **Impact**: Processes entries too early for users in timezones behind UTC (e.g., PST, EST)

### **Equation 3: `next_retry_at` Should Use User Timezone**
- **Location**: `supabase/functions/populate-analysis-queue/index.ts` (lines 116, 179, 236, 288)
- **Problem**: `next_retry_at` uses UTC NOW instead of tomorrow midnight in user's timezone
- **Impact**: Retry timing doesn't respect user's local timezone

---

## Impact Analysis on Other Functionalities

### **1. Database Schema**
- **No changes required**: `analysis_queue` table structure is compatible
- `next_retry_at` is already `timestamp with time zone`, can store any timezone
- `target_date` is `date` type, timezone-agnostic (correct)

### **2. Cron Jobs**
- **`populate-analysis-queue` (runs every 5 min)**: 
  - ✅ Already timezone-aware (uses user timezone)
  - ⚠️ Needs fix for `next_retry_at` calculation
- **`process-ai-queue` (runs at UTC midnight)**:
  - ❌ Currently uses UTC for all users
  - ✅ Needs to be timezone-aware per user

### **3. Retry Logic**
- **Location**: `supabase/functions/process-ai-queue/index.ts` (lines 207-216)
- **Current**: Exponential backoff uses UTC NOW + backoff minutes
- **Impact**: Retry timing is correct (relative to failure time), but initial `next_retry_at` is wrong
- **Action**: No change needed for retry logic itself, only initial queue time

### **4. AI Analysis Functions**
- **`ai-analyze-daily`**: No changes needed
- **`ai-analyze-weekly`**: No changes needed
- **`ai-analyze-monthly`**: No changes needed
- All functions receive `entry_id`/`user_id`/dates, timezone handling is in queue system

### **5. Flutter App**
- **No direct dependencies**: App doesn't read `next_retry_at` or queue status
- **Indirect impact**: Users may see insights appear at wrong times
- **Action**: No Flutter code changes required

### **6. Database RPC Functions**
- **`get_date_in_timezone`**: Already exists and working
- **`check_entry_completion`**: No changes needed
- Both functions are timezone-agnostic

### **7. Existing Queue Data**
- **Impact**: Old queue entries have incorrect `next_retry_at` values
- **Action**: May need cleanup query for stuck jobs (optional)

---

## Detailed Fix Plan

### **Phase 1: Fix `populate-analysis-queue` - `next_retry_at` Calculation**

#### **1.1 Create Helper Function for Tomorrow Midnight in User Timezone**

**Location**: `supabase/functions/populate-analysis-queue/index.ts`

**Implementation**:
```typescript
/**
 * Calculate tomorrow midnight in user's timezone, converted to UTC for storage
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
      // Fallback: JavaScript calculation
      const now = new Date()
      const tzDate = new Date(now.toLocaleString('en-US', { timeZone: userTimezone }))
      const tomorrow = new Date(tzDate)
      tomorrow.setDate(tomorrow.getDate() + 1)
      tomorrow.setHours(0, 0, 0, 0)
      
      // Convert to UTC equivalent
      const utcOffset = now.getTime() - new Date(now.toLocaleString('en-US', { timeZone: userTimezone })).getTime()
      const tomorrowMidnightUTC = new Date(tomorrow.getTime() - utcOffset)
      return tomorrowMidnightUTC.toISOString()
    }

    // tomorrowData is a date string, create Date object and set to midnight
    const tomorrowDate = new Date(tomorrowData)
    tomorrowDate.setHours(0, 0, 0, 0)
    
    // Convert to UTC for storage (database stores as UTC)
    // We need to get the UTC equivalent of midnight in user's timezone
    const now = new Date()
    const userNow = new Date(now.toLocaleString('en-US', { timeZone: userTimezone }))
    const utcOffset = now.getTime() - userNow.getTime()
    const tomorrowMidnightUTC = new Date(tomorrowDate.getTime() - utcOffset)
    
    return tomorrowMidnightUTC.toISOString()
  } catch (error) {
    // Ultimate fallback: tomorrow midnight UTC
    const tomorrow = new Date()
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1)
    tomorrow.setUTCHours(0, 0, 0, 0)
    return tomorrow.toISOString()
  }
}
```

#### **1.2 Update Daily Queue Insert (Today's Entry)**

**Location**: Line 116
**Change**:
```typescript
// Before:
next_retry_at: new Date().toISOString()

// After:
next_retry_at: await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
```

#### **1.3 Update Daily Queue Insert (Catch-up Entries)**

**Location**: Line 179
**Change**:
```typescript
// Before:
next_retry_at: new Date().toISOString()

// After:
next_retry_at: await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
```

#### **1.4 Update Weekly Queue Insert**

**Location**: Line 236
**Change**:
```typescript
// Before:
next_retry_at: new Date().toISOString()

// After:
next_retry_at: await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
```

#### **1.5 Update Monthly Queue Insert**

**Location**: Line 288
**Change**:
```typescript
// Before:
next_retry_at: new Date().toISOString()

// After:
next_retry_at: await getTomorrowMidnightInUserTimezone(supabase, userTimezone)
```

---

### **Phase 2: Fix `process-ai-queue` - Timezone-Aware Processing**

#### **2.1 Change Query Strategy**

**Current Approach** (Line 34-40):
- Fetches jobs where `target_date = UTC yesterday`
- Processes all matching jobs

**New Approach**:
- Fetch ALL pending jobs (not filtered by date)
- For each job, get user's timezone
- Calculate "yesterday" in user's timezone
- Only process if `target_date` matches user's "yesterday"

#### **2.2 Implementation**

**Location**: `supabase/functions/process-ai-queue/index.ts`

**Replace lines 24-40**:
```typescript
// OLD CODE (REMOVE):
// Calculate yesterday's date (in UTC for consistency)
const now = new Date()
const yesterday = new Date(now)
yesterday.setDate(yesterday.getDate() - 1)
const yesterdayStr = yesterday.toISOString().split('T')[0]

console.log(`[PROCESS] Starting queue processing at ${now.toISOString()}`)
console.log(`[PROCESS] Target date: ${yesterdayStr}`)

// Fetch pending jobs that are ready to process AND are for yesterday
const { data: queueItems, error: queueError } = await supabase
  .from('analysis_queue')
  .select('*')
  .eq('status', 'pending')
  .eq('target_date', yesterdayStr)  // ONLY yesterday's queue
  .lte('next_retry_at', now.toISOString())
  .limit(10)  // Process 10 jobs per run
```

**NEW CODE (REPLACE WITH)**:
```typescript
const now = new Date()
console.log(`[PROCESS] Starting queue processing at ${now.toISOString()}`)

// Fetch ALL pending jobs that are ready to process (not filtered by date yet)
const { data: allPendingJobs, error: queueError } = await supabase
  .from('analysis_queue')
  .select(`
    *,
    users!inner(id, timezone)
  `)
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

// Filter jobs where target_date is "yesterday" in user's timezone
const queueItems: any[] = []
for (const job of allPendingJobs) {
  const userTimezone = job.users?.timezone || 'UTC'
  
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

console.log(`[PROCESS] Found ${queueItems.length} jobs to process (filtered from ${allPendingJobs.length} pending jobs)`)
```

#### **2.3 Update Processing Loop**

**Location**: Line 63 onwards

**No changes needed** - the loop already processes `queueItems` correctly. The filtering happens before the loop.

#### **2.4 Update Summary Logging**

**Location**: Line 226

**Change**:
```typescript
// Before:
console.log(`[PROCESS] Summary: Processed=${processed}, Failed=${failed}, Total=${queueItems.length}, TargetDate=${yesterdayStr}`)

// After:
console.log(`[PROCESS] Summary: Processed=${processed}, Failed=${failed}, Total=${queueItems.length}`)
```

**Location**: Line 234

**Change**:
```typescript
// Before:
target_date: yesterdayStr,

// After:
// Remove target_date from response (no longer a single value)
```

---

### **Phase 3: Testing & Validation**

#### **3.1 Test Cases**

1. **User in IST (UTC+5:30)**:
   - Create entry on Nov 21 IST
   - Verify `next_retry_at` = Nov 22 00:00 IST (Nov 21 18:30 UTC)
   - Verify processing happens at Nov 22 00:00 IST

2. **User in PST (UTC-8)**:
   - Create entry on Nov 21 PST
   - Verify `next_retry_at` = Nov 22 00:00 PST (Nov 22 08:00 UTC)
   - Verify processing happens at Nov 22 00:00 PST

3. **User in UTC**:
   - Create entry on Nov 21 UTC
   - Verify `next_retry_at` = Nov 22 00:00 UTC
   - Verify processing happens at Nov 22 00:00 UTC

4. **Multiple Users Different Timezones**:
   - Create entries for users in IST, PST, UTC
   - Verify each processes at correct time in their timezone

#### **3.2 Validation Queries**

```sql
-- Check next_retry_at values are in future
SELECT 
  id,
  user_id,
  target_date,
  next_retry_at,
  status,
  created_at
FROM analysis_queue
WHERE status = 'pending'
ORDER BY next_retry_at;

-- Check timezone distribution
SELECT 
  u.timezone,
  COUNT(aq.id) as pending_jobs
FROM analysis_queue aq
JOIN users u ON aq.user_id = u.id
WHERE aq.status = 'pending'
GROUP BY u.timezone;
```

---

### **Phase 4: Cleanup (Optional)**

#### **4.1 Fix Stuck Jobs**

If there are old jobs with incorrect `next_retry_at` values:

```sql
-- Update stuck pending jobs (older than 2 days, still pending)
UPDATE analysis_queue
SET 
  next_retry_at = (NOW() AT TIME ZONE 'UTC' + INTERVAL '1 day')::timestamp,
  status = 'pending'
WHERE 
  status = 'pending'
  AND next_retry_at < NOW() - INTERVAL '2 days'
  AND attempts < max_attempts;
```

#### **4.2 Monitor Queue Health**

```sql
-- Check queue health
SELECT 
  status,
  COUNT(*) as count,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM analysis_queue
GROUP BY status;
```

---

## Implementation Steps

### **Step 1: Update `populate-analysis-queue`**
1. Add helper function `getTomorrowMidnightInUserTimezone`
2. Replace all 4 instances of `next_retry_at: new Date().toISOString()`
3. Test with single user

### **Step 2: Update `process-ai-queue`**
1. Replace date filtering logic (lines 24-40)
2. Add timezone-aware filtering loop
3. Update logging
4. Test with multiple users in different timezones

### **Step 3: Deploy Edge Functions**
```bash
# Deploy populate-analysis-queue
supabase functions deploy populate-analysis-queue

# Deploy process-ai-queue
supabase functions deploy process-ai-queue
```

### **Step 4: Monitor & Validate**
1. Check logs for first 24 hours
2. Verify jobs process at correct times
3. Check for any errors

### **Step 5: Cleanup (if needed)**
1. Run cleanup query for stuck jobs
2. Monitor queue health

---

## Flutter App Changes

### **No Changes Required**

The Flutter app does not directly interact with:
- `analysis_queue` table
- `next_retry_at` field
- Queue processing logic

### **Indirect Benefits**

After fixes:
- ✅ Users will see insights appear at correct times (midnight in their timezone)
- ✅ No more early/late insight delivery
- ✅ Better user experience for timezone-aware scheduling

### **Optional: Add Queue Status UI (Future Enhancement)**

If you want to show queue status to users (not required for this fix):

```dart
// Example: Check if entry is queued for analysis
Future<bool> isEntryQueued(String entryId) async {
  final response = await supabase
    .from('analysis_queue')
    .select('id, status, next_retry_at')
    .eq('entry_id', entryId)
    .in('status', ['pending', 'processing'])
    .maybeSingle();
  
  return response != null;
}
```

**Note**: This is optional and not part of the current fix plan.

---

## Summary

### **Files to Modify**
1. `supabase/functions/populate-analysis-queue/index.ts`
   - Add helper function
   - Update 4 `next_retry_at` assignments

2. `supabase/functions/process-ai-queue/index.ts`
   - Replace date filtering logic
   - Add timezone-aware filtering

### **Files NOT Modified**
- Flutter app code (no changes needed)
- Database schema (no changes needed)
- AI analysis functions (no changes needed)
- Other edge functions (no changes needed)

### **Testing Required**
- Single user in IST
- Single user in PST
- Multiple users in different timezones
- Verify processing times

### **Deployment**
- Deploy both edge functions
- Monitor for 24-48 hours
- Optional cleanup if needed

---

## Risk Assessment

### **Low Risk**
- Changes are isolated to queue system
- No database schema changes
- No breaking changes to existing functionality
- Can rollback easily if issues occur

### **Mitigation**
- Test thoroughly before production
- Monitor logs closely after deployment
- Keep old function code for quick rollback
- Have cleanup queries ready

---

## Success Criteria

✅ `next_retry_at` is set to tomorrow midnight in user's timezone  
✅ `process-ai-queue` processes jobs based on user's timezone  
✅ Jobs process at correct times for all timezones  
✅ No early/late processing  
✅ Queue system works correctly for IST, PST, UTC, and other timezones  

---

## Notes

- All date calculations use `get_date_in_timezone` RPC with JavaScript fallback
- `next_retry_at` is stored as UTC timestamp (database standard)
- `target_date` remains as date string (timezone-agnostic, correct)
- Processing happens at UTC midnight, but filtering is timezone-aware
- Retry logic (exponential backoff) remains unchanged (already correct)

