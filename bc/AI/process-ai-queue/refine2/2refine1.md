# **FIX PLAN: Jobs Stuck in Processing State**

## **🐛 ROOT CAUSE IDENTIFIED**

### **Issue Description**
Jobs are claimed (status = 'processing') **BEFORE** timezone verification. If they don't pass the timezone filter (`target_date <= yesterday`), they remain stuck in 'processing' state forever.

### **Reproduction Steps**
1. Entry created on Dec 5 before 1:30 AM
2. Cron runs at 1:30 AM on Dec 5
3. Job claimed → status = 'processing' (atomic lock)
4. Timezone check: `target_date (Dec 5) <= yesterday (Dec 4)` = **FALSE**
5. Job skipped, function returns early (line 197-207)
6. **Result**: Job stuck in 'processing' state

### **Code Flow (Current - Buggy)**
```
Line 79: claim_pending_jobs() → Jobs marked 'processing' (atomic)
Line 140-195: Timezone filtering happens AFTER claiming
Line 163: If target_date > yesterday → Job skipped (just logged)
Line 197: If no jobs pass → Function returns early
❌ Problem: Filtered-out jobs never reset to 'pending'
```

---

## **🔍 COMPLETE ISSUE ANALYSIS**

### **Issue #1: CRITICAL - Filtered Jobs Not Reset** ✅ ROOT CAUSE

**Location:** `supabase/functions/process-ai-queue/index.ts` (Line 197-207)

**Problem:**
- Jobs claimed before timezone check
- If filtered out, they stay in 'processing'
- Function returns early without resetting

**Impact:** HIGH - Jobs stuck forever, blocking queue

**Fix:** Reset filtered-out jobs to 'pending' before returning

---

### **Issue #2: Users Fetch Error Leaves Jobs Stuck**

**Location:** `supabase/functions/process-ai-queue/index.ts` (Line 113-129)

**Problem:**
- If `usersError` occurs, function throws (line 129)
- Claimed jobs stay in 'processing' state
- No cleanup before throwing

**Impact:** MEDIUM - Happens if users table has issues

**Fix:** Reset claimed jobs to 'pending' in catch block before throwing

---

### **Issue #3: Timezone Calculation Error Leaves Jobs Stuck**

**Location:** `supabase/functions/process-ai-queue/index.ts` (Line 168-194)

**Problem:**
- If timezone calculation throws error (line 168)
- Job is skipped (line 193) but stays in 'processing'
- Error is logged but job not reset

**Impact:** LOW - Rare, but possible with invalid timezones

**Fix:** Reset job to 'pending' in catch block (line 193)

---

### **Issue #4: Function Crash Leaves Jobs Stuck**

**Location:** `supabase/functions/process-ai-queue/index.ts` (Line 475-525)

**Problem:**
- If function crashes before processing (outer catch)
- Claimed jobs stay in 'processing'
- No cleanup in error handler

**Impact:** MEDIUM - Happens on unexpected crashes

**Fix:** Add cleanup in outer catch block to reset claimed jobs

---

### **Issue #5: Stuck Jobs Detection Doesn't Reset**

**Location:** `supabase/functions/process-ai-queue/index.ts` (Line 56-75)

**Problem:**
- Checks for stuck jobs (line 56-60)
- Only skips cron if too many active
- Doesn't reset old stuck jobs

**Impact:** LOW - Detection exists but no auto-recovery

**Fix:** Reset jobs stuck > 10 minutes to 'pending' (optional enhancement)

---

## **✅ FIX IMPLEMENTATION**

### **Fix #1: Reset Filtered-Out Jobs (CRITICAL)**

**Location:** After line 195, before line 197

**Code:**
```typescript
    // Reset jobs that didn't pass timezone filter back to pending
    // This prevents jobs from getting stuck in 'processing' state
    const filteredOutJobIds = allPendingJobs
      .filter(job => !queueItems.some(qi => qi.id === job.id))
      .map(job => job.id)

    if (filteredOutJobIds.length > 0) {
      console.log(`[PROCESS] Resetting ${filteredOutJobIds.length} jobs that didn't pass timezone filter back to pending`)
      try {
        await supabase
          .from('analysis_queue')
          .update({ status: 'pending' })
          .in('id', filteredOutJobIds)
        console.log(`[PROCESS] ✅ Reset ${filteredOutJobIds.length} filtered jobs to pending`)
      } catch (resetError) {
        console.error(`[PROCESS] ❌ Error resetting filtered jobs:`, resetError)
        // Don't throw - log error but continue
        // Jobs will be reset on next cron run or manual intervention
      }
    }
```

**Impact:**
- ✅ Fixes root cause
- ✅ No breaking changes
- ✅ Safe (wrapped in try-catch)

---

### **Fix #2: Reset Jobs on Users Fetch Error**

**Location:** Line 113-129, add cleanup before throw

**Code:**
```typescript
    if (usersError) {
      console.error(`[PROCESS] Error fetching user timezones:`, usersError)
      const duration = Date.now() - startTime
      
      // Reset claimed jobs before throwing
      if (allPendingJobs && allPendingJobs.length > 0) {
        const jobIds = allPendingJobs.map((job: any) => job.id)
        console.log(`[PROCESS] Resetting ${jobIds.length} claimed jobs due to users fetch error`)
        await supabase
          .from('analysis_queue')
          .update({ status: 'pending' })
          .in('id', jobIds)
          .catch(err => {
            console.error(`[PROCESS] Error resetting jobs on users error:`, err)
          })
      }
      
      await logAIError(supabase, usersError, {
        // ... existing code ...
      })
      
      throw usersError
    }
```

**Impact:**
- ✅ Prevents jobs from getting stuck on users fetch error
- ✅ Safe cleanup before throwing
- ✅ No breaking changes

---

### **Fix #3: Reset Job on Timezone Error**

**Location:** Line 168-194, add reset in catch block

**Code:**
```typescript
      } catch (error) {
        console.error(`[PROCESS] Error checking timezone for job ${job.id}:`, error)
        
        // Reset job to pending on timezone error
        try {
          await supabase
            .from('analysis_queue')
            .update({ status: 'pending' })
            .eq('id', job.id)
          console.log(`[PROCESS] Reset job ${job.id} to pending due to timezone error`)
        } catch (resetError) {
          console.error(`[PROCESS] Error resetting job ${job.id}:`, resetError)
        }
        
        // Log timezone calculation error
        try {
          await logAIError(supabase, error, {
            // ... existing code ...
          })
        } catch (logError) {
          console.error('Failed to log timezone error:', logError)
        }
        
        // Skip this job on error (already reset above)
      }
```

**Impact:**
- ✅ Prevents jobs from getting stuck on timezone errors
- ✅ Safe cleanup
- ✅ No breaking changes

---

### **Fix #4: Reset Jobs on Function Crash (Optional - Recommended)**

**Location:** Line 475-525, add cleanup in outer catch

**Code:**
```typescript
  } catch (error) {
    const duration = Date.now() - startTime
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'

    // Reset any claimed jobs that might be stuck
    // This is a safety net for unexpected crashes
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
          console.log(`[PROCESS] Reset stuck jobs in error handler`)
        }
        
        // Log overall function error
        // ... existing error logging code ...
      }
    } catch (cleanupError) {
      console.error('Failed to cleanup jobs in error handler:', cleanupError)
    }

    return new Response(
      // ... existing response ...
    )
  }
```

**Impact:**
- ✅ Safety net for unexpected crashes
- ✅ Only resets recent jobs (last 5 min)
- ✅ Low risk (wrapped in try-catch)

---

### **Fix #5: Auto-Reset Old Stuck Jobs (Optional Enhancement)**

**Location:** Line 56-75, add auto-reset logic

**Code:**
```typescript
    // For cron-triggered runs: Check if recursive processing is active
    if (!isRecursive) {
      // First, reset jobs stuck in processing for > 10 minutes
      try {
        const { data: stuckJobs, error: stuckError } = await supabase
          .from('analysis_queue')
          .select('id')
          .eq('status', 'processing')
          .lt('updated_at', new Date(Date.now() - 10 * 60 * 1000).toISOString())
        
        if (stuckError) {
          console.error(`[PROCESS] Error checking stuck jobs:`, stuckError)
        } else if (stuckJobs && stuckJobs.length > 0) {
          console.log(`[PROCESS] Found ${stuckJobs.length} stuck jobs, resetting to pending`)
          const stuckJobIds = stuckJobs.map((j: any) => j.id)
          await supabase
            .from('analysis_queue')
            .update({ status: 'pending' })
            .in('id', stuckJobIds)
            .catch(err => {
              console.error(`[PROCESS] Error resetting stuck jobs:`, err)
            })
        }
      } catch (resetError) {
        console.error(`[PROCESS] Error in stuck jobs cleanup:`, resetError)
      }
      
      // Then check active processing (existing code)
      const { data: activeProcessing, error: activeError } = await supabase
        .from('analysis_queue')
        .select('id')
        .eq('status', 'processing')
        .gte('updated_at', new Date(Date.now() - 10 * 60 * 1000).toISOString())
      
      // ... rest of existing code ...
    }
```

**Impact:**
- ✅ Auto-recovery for old stuck jobs
- ✅ Runs on every cron (self-healing)
- ✅ Low risk (wrapped in try-catch)

---

## **📊 IMPACT ANALYSIS**

### **Functionality Impact**

| Fix | Impact on Existing Functionality | Risk Level |
|-----|----------------------------------|------------|
| Fix #1 (Filtered Jobs) | ✅ No impact - Only fixes bug | **LOW** |
| Fix #2 (Users Error) | ✅ No impact - Only adds cleanup | **LOW** |
| Fix #3 (Timezone Error) | ✅ No impact - Only adds cleanup | **LOW** |
| Fix #4 (Crash Handler) | ✅ No impact - Safety net only | **LOW** |
| Fix #5 (Auto-Reset) | ✅ No impact - Self-healing | **LOW** |

### **Performance Impact**

- **Fix #1**: Minimal - One UPDATE query when jobs filtered
- **Fix #2**: Minimal - Only on error (rare)
- **Fix #3**: Minimal - Only on error (rare)
- **Fix #4**: Minimal - Only on crash (rare)
- **Fix #5**: Minimal - One SELECT + UPDATE per cron (acceptable)

### **Data Integrity**

- ✅ All fixes reset to 'pending' (safe state)
- ✅ No data loss
- ✅ Jobs can be retried
- ✅ No breaking changes

---

## **🎯 RECOMMENDED FIX PRIORITY**

### **Priority 1: CRITICAL (Must Fix)**
- ✅ **Fix #1**: Reset filtered-out jobs
  - Fixes root cause
- ✅ **Fix #2**: Reset on users error
  - Prevents stuck jobs on common error

### **Priority 2: IMPORTANT (Should Fix)**
- ✅ **Fix #3**: Reset on timezone error
  - Prevents stuck jobs on timezone issues
- ✅ **Fix #4**: Reset on function crash
  - Safety net for unexpected errors

### **Priority 3: ENHANCEMENT (Nice to Have)**
- ⚠️ **Fix #5**: Auto-reset old stuck jobs
  - Self-healing mechanism
  - Can be added later if needed

---

## **✅ VALIDATION CHECKLIST**

After implementing fixes, verify:

- [ ] Jobs filtered by timezone are reset to 'pending'
- [ ] Jobs reset on users fetch error
- [ ] Jobs reset on timezone calculation error
- [ ] No jobs stuck in 'processing' after normal runs
- [ ] No jobs stuck in 'processing' after error scenarios
- [ ] Existing functionality still works (successful processing)
- [ ] Retry logic still works (failed jobs retry correctly)
- [ ] No performance degradation

---

## **🚀 DEPLOYMENT PLAN**

### **Step 1: Implement Critical Fixes**
1. Apply Fix #1 (filtered jobs reset)
2. Apply Fix #2 (users error reset)
3. Test with real data

### **Step 2: Implement Important Fixes**
4. Apply Fix #3 (timezone error reset)
5. Apply Fix #4 (crash handler reset)
6. Test error scenarios

### **Step 3: Optional Enhancement**
7. Apply Fix #5 (auto-reset) if needed
8. Monitor for stuck jobs

### **Step 4: Cleanup Existing Stuck Jobs**
```sql
-- Reset jobs stuck in processing for > 10 minutes
UPDATE analysis_queue
SET status = 'pending'
WHERE status = 'processing'
  AND updated_at < NOW() - INTERVAL '10 minutes';
```

---

## **📝 SUMMARY**

### **Root Cause**
Jobs claimed before timezone check, filtered out jobs never reset to 'pending'.

### **Solution**
Reset filtered-out jobs to 'pending' before function returns.

### **Additional Safeguards**
- Reset on users fetch error
- Reset on timezone calculation error
- Reset on function crash (safety net)
- Auto-reset old stuck jobs (optional)

### **Impact**
- ✅ Fixes critical bug
- ✅ No breaking changes
- ✅ No performance impact
- ✅ Safe to deploy

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-05  
**Status:** Ready for Implementation

