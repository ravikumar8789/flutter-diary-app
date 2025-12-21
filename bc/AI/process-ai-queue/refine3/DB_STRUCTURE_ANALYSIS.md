# **DATABASE STRUCTURE ANALYSIS**

## **📊 Database Overview**

**Project URL:** `https://foqoterfgxoiwoxvuxqi.supabase.co`  
**Total Tables:** 30+ tables in `public` schema  
**RLS Enabled:** Most tables have Row Level Security enabled

---

## **🔍 Key Tables for AI Queue System**

### **1. `analysis_queue` Table**

**Structure:**
```sql
- id: uuid (PK)
- user_id: uuid (FK → users.id)
- analysis_type: text ('daily', 'weekly', 'monthly')
- target_date: date (NOT NULL) ⚠️ Currently stores entry_date, not UTC converted
- entry_id: uuid (nullable, for daily analysis)
- week_start: date (nullable, for weekly analysis)
- month_start: date (nullable, for monthly analysis)
- status: text ('pending', 'processing', 'completed', 'failed')
- attempts: integer (default 0)
- max_attempts: integer (default 3)
- next_retry_at: timestamptz (nullable) ⚠️ Currently NULL for new jobs
- error_message: text (nullable)
- created_at: timestamptz
- processed_at: timestamptz
- updated_at: timestamptz
```

**Indexes:**
1. `idx_analysis_queue_status_created` - (status, created_at) WHERE status = 'pending'
2. `idx_analysis_queue_pending` - (status, next_retry_at) WHERE status IN ('pending', 'failed')
3. `idx_analysis_queue_target_date` - (target_date, status)
4. `idx_analysis_queue_user_type` - (user_id, analysis_type, status)

**Current Data State:**
- 18 total rows
- Old jobs have `next_retry_at` values (e.g., "2025-12-04 18:30:00+00")
- New jobs would have `next_retry_at = NULL` (function doesn't set it anymore)
- `target_date` = entry_date (not UTC converted yet)

---

### **2. `users` Table**

**Key Columns:**
- `id`: uuid (PK, FK → auth.users.id)
- `timezone`: text (nullable) - IANA timezone string (e.g., 'Asia/Kolkata')
- `email`: text
- `created_at`: timestamptz

**Current State:**
- 8 users
- All have timezone set (Asia/Kolkata based on sample data)

---

### **3. `entries` Table**

**Key Columns:**
- `id`: uuid (PK)
- `user_id`: uuid (FK → users.id)
- `entry_date`: date (NOT NULL) - Date only, no timezone
- `diary_text`: text
- `created_at`: timestamptz

**Current State:**
- 44 entries
- `entry_date` is a DATE type (no time component)

---

## **🔧 Database Functions**

### **1. `claim_pending_jobs(p_batch_size, p_max_retry_at)`**

**Current Implementation (IN DATABASE):**
```sql
WHERE aq.status = 'pending'
  AND aq.target_date <= CURRENT_DATE  -- ⚠️ Date comparison (processes too early)
```

**Issue:** Uses `target_date` (date only), processes at any time on that date

**Returns:** Job details including `next_retry_at` (but it's NULL for new jobs)

---

### **2. `process_analysis_queue_batch()`**

**Current Implementation (IN DATABASE):**
```sql
-- ⚠️ OLD VERSION - Not yet deployed!
-- Sets target_date = entry_date (not UTC converted)
-- Does NOT set next_retry_at (removed)
```

**What It Does:**
- Finds eligible entries (today's entries, catchup, weekly, monthly)
- Inserts into `analysis_queue` with:
  - `target_date = entry_date` (old logic)
  - `next_retry_at = NULL` (not set)

**Issue:** Doesn't calculate UTC conversion or set `next_retry_at`

---

### **3. `calculate_next_midnight_utc(p_timezone, p_user_today)`**

**Purpose:** Calculates exact UTC timestamp for tomorrow midnight in user timezone

**Returns:** `timestamptz` (e.g., "2025-12-05 18:30:00+00" for IST user)

**Status:** ✅ Exists and works correctly

---

### **4. `get_date_in_timezone(p_timezone, p_offset_days)`**

**Purpose:** Gets date in user timezone with offset

**Returns:** `date` (e.g., "2025-12-05")

**Status:** ✅ Exists and works correctly

---

### **5. `check_entry_completion(entry_uuid)`**

**Purpose:** Checks if entry has all required sections filled

**Returns:** `boolean`

**Checks:**
- Morning Ritual (affirmations OR priorities)
- Wellness Tracker (meals OR self_care)
- Gratitude
- Diary (>= 50 chars)

**Status:** ✅ Exists and works correctly

---

## **🚨 CRITICAL FINDINGS**

### **Issue #1: Database Function Mismatch**

**Problem:**
- Local migration file (`004_process_analysis_queue_batch.sql`) has NEW code (UTC conversion)
- Database has OLD code (no UTC conversion, no `next_retry_at`)
- Migration hasn't been deployed yet!

**Evidence:**
- Database function sets `target_date = entry_date` (old)
- Database function doesn't set `next_retry_at` (removed)
- Sample data shows old jobs have `next_retry_at`, new ones would be NULL

---

### **Issue #2: Filter Logic Problem**

**Current Filter:**
```sql
AND aq.target_date <= CURRENT_DATE
```

**Problem:**
- `target_date = "2025-12-05"` (entry date)
- `CURRENT_DATE = "2025-12-05"` (UTC date)
- Processes at ANY time on Dec 5 UTC (even 00:00 UTC = 05:30 IST) ❌

**Should Be:**
```sql
AND aq.next_retry_at <= NOW()
```

**But:** `next_retry_at` is NULL for new jobs (function doesn't set it)

---

### **Issue #3: Index Availability**

**Good News:**
- Index `idx_analysis_queue_pending` exists on `(status, next_retry_at)`
- Perfect for filtering by `next_retry_at`!

**But:** Only useful if `next_retry_at` is set (currently NULL for new jobs)

---

## **💡 SOLUTION PATH**

### **Option A: Use `next_retry_at` for Filtering (Recommended)**

**Steps:**
1. Update `process_analysis_queue_batch` to:
   - Calculate `target_date = (entry_date + 1 day) → UTC date` ✅ (already in migration)
   - Calculate `next_retry_at = calculate_next_midnight_utc(...)` ✅ (needs to be added back)
2. Update `claim_pending_jobs` to:
   - Filter by `next_retry_at <= NOW()` ✅ (exact timestamp comparison)

**Benefits:**
- Uses existing index (`idx_analysis_queue_pending`)
- Exact timestamp comparison (no early processing)
- `next_retry_at` already calculated correctly

---

### **Option B: Use `target_date` with Time Check**

**Steps:**
1. Keep `target_date = (entry_date + 1 day) → UTC date` ✅
2. Update `claim_pending_jobs` to:
   - Filter by `target_date < CURRENT_DATE OR (target_date = CURRENT_DATE AND hour check)`
   - But hour check is complex for all timezones

**Drawbacks:**
- More complex logic
- Harder to maintain
- Less efficient

---

## **📋 RECOMMENDED FIX**

**Use Option A: Restore `next_retry_at` calculation and use it for filtering**

**Changes Needed:**

1. **Update `process_analysis_queue_batch`:**
   - Keep `target_date` UTC conversion ✅
   - **Add back** `next_retry_at` calculation using `calculate_next_midnight_utc()`

2. **Update `claim_pending_jobs`:**
   - Change filter from `target_date <= CURRENT_DATE` 
   - To: `next_retry_at <= NOW()` (or `next_retry_at IS NOT NULL AND next_retry_at <= NOW()`)

3. **Edge Function:**
   - Already updated (removed timezone filtering) ✅
   - Already has infinite recursion fix ✅

---

## **🔍 Database Statistics**

- **Users:** 8
- **Entries:** 44
- **Analysis Queue Jobs:** 18 (all completed)
- **Extensions:** 70+ available (pg_cron, pgcrypto, etc. installed)

---

## **✅ Next Steps**

1. Deploy updated `process_analysis_queue_batch` function (with UTC conversion + `next_retry_at`)
2. Update `claim_pending_jobs` to use `next_retry_at <= NOW()`
3. Test with real data
4. Verify timing is correct

---

**Analysis Date:** 2025-12-05  
**Database Version:** Current production  
**Status:** Ready for fix implementation

