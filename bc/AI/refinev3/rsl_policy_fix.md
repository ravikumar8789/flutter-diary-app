# **RLS POLICY FIX - STEP BY STEP GUIDE**

## **OVERVIEW**

This guide fixes Row Level Security (RLS) policy violations that prevent entry data from syncing to Supabase. The errors occur because RLS policies are missing or incorrectly configured for entry-related tables.

**Error Symptoms:**
- `ERRSYS102`: Affirmations sync failed - RLS policy violation
- `ERRSYS103`: Priorities sync failed - RLS policy violation
- Similar errors for other entry tables
- Error logs flooding when user types

---

## **PREREQUISITES**

1. ✅ Access to Supabase Dashboard
2. ✅ SQL Editor access
3. ✅ Admin/owner permissions on the project

---

## **QUICK DIAGNOSTIC (IF STILL GETTING ERRORS)**

**Run this first to check if entry exists:**
```sql
-- Check if entry exists for the failing entry_id from error logs
-- Replace '09dc1d32-22c8-4463-8eb2-e73e8d2dbc5e' with actual entry_id from your error logs
SELECT 
  id,
  user_id,
  entry_date,
  created_at,
  CASE 
    WHEN id IS NULL THEN '❌ Entry DOES NOT EXIST - This is the problem!'
    ELSE '✅ Entry exists'
  END as status
FROM public.entries
WHERE id = '09dc1d32-22c8-4463-8eb2-e73e8d2dbc5e';
```

**If entry doesn't exist:** The code fix below will solve this. The entry sync happens after related data sync, causing RLS to fail.

---

## **STEP 1: VERIFY CURRENT RLS STATUS**

**Purpose:** Check which tables have RLS enabled and what policies exist.

**Run in Supabase SQL Editor:**

```sql
-- Check RLS status for all entry tables
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'entries',
    'entry_affirmations',
    'entry_priorities',
    'entry_meals',
    'entry_gratitude',
    'entry_self_care',
    'entry_shower_bath',
    'entry_tomorrow_notes'
  )
ORDER BY tablename;
```

**Expected Result:** Should show all tables and their RLS status (`true` or `false`).

---

## **STEP 2: CHECK EXISTING POLICIES**

**Purpose:** See what policies already exist (if any).

**Run in Supabase SQL Editor:**

```sql
-- Check existing policies for entry tables
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'entries',
    'entry_affirmations',
    'entry_priorities',
    'entry_meals',
    'entry_gratitude',
    'entry_self_care',
    'entry_shower_bath',
    'entry_tomorrow_notes'
  )
ORDER BY tablename, policyname;
```

**Expected Result:** Lists all existing policies (may be empty if none exist).

---

## **STEP 3: ENABLE RLS ON ALL ENTRY TABLES**

**Purpose:** Enable Row Level Security on all entry-related tables.

**Run in Supabase SQL Editor:**

```sql
-- Enable RLS on all entry tables
ALTER TABLE public.entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_affirmations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_priorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_gratitude ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_self_care ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_shower_bath ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_tomorrow_notes ENABLE ROW LEVEL SECURITY;
```

**Expected Result:** All commands should execute successfully.

**Verification:**
```sql
-- Verify RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE 'entry%'
ORDER BY tablename;
```

All should show `rowsecurity = true`.

---

## **STEP 4: DROP EXISTING POLICIES (IF ANY)**

**Purpose:** Remove any incorrect or conflicting policies before creating new ones.

**Run in Supabase SQL Editor:**

```sql
-- Drop existing policies for entries table
DROP POLICY IF EXISTS "Users can insert own entries" ON public.entries;
DROP POLICY IF EXISTS "Users can update own entries" ON public.entries;
DROP POLICY IF EXISTS "Users can view own entries" ON public.entries;
DROP POLICY IF EXISTS "Users can delete own entries" ON public.entries;

-- Drop existing policies for entry_affirmations
DROP POLICY IF EXISTS "Users can insert own affirmations" ON public.entry_affirmations;
DROP POLICY IF EXISTS "Users can update own affirmations" ON public.entry_affirmations;
DROP POLICY IF EXISTS "Users can view own affirmations" ON public.entry_affirmations;

-- Drop existing policies for entry_priorities
DROP POLICY IF EXISTS "Users can insert own priorities" ON public.entry_priorities;
DROP POLICY IF EXISTS "Users can update own priorities" ON public.entry_priorities;
DROP POLICY IF EXISTS "Users can view own priorities" ON public.entry_priorities;

-- Drop existing policies for entry_meals
DROP POLICY IF EXISTS "Users can insert own meals" ON public.entry_meals;
DROP POLICY IF EXISTS "Users can update own meals" ON public.entry_meals;
DROP POLICY IF EXISTS "Users can view own meals" ON public.entry_meals;

-- Drop existing policies for entry_gratitude
DROP POLICY IF EXISTS "Users can insert own gratitude" ON public.entry_gratitude;
DROP POLICY IF EXISTS "Users can update own gratitude" ON public.entry_gratitude;
DROP POLICY IF EXISTS "Users can view own gratitude" ON public.entry_gratitude;

-- Drop existing policies for entry_self_care
DROP POLICY IF EXISTS "Users can insert own self care" ON public.entry_self_care;
DROP POLICY IF EXISTS "Users can update own self care" ON public.entry_self_care;
DROP POLICY IF EXISTS "Users can view own self care" ON public.entry_self_care;

-- Drop existing policies for entry_shower_bath
DROP POLICY IF EXISTS "Users can insert own shower bath" ON public.entry_shower_bath;
DROP POLICY IF EXISTS "Users can update own shower bath" ON public.entry_shower_bath;
DROP POLICY IF EXISTS "Users can view own shower bath" ON public.entry_shower_bath;

-- Drop existing policies for entry_tomorrow_notes
DROP POLICY IF EXISTS "Users can insert own tomorrow notes" ON public.entry_tomorrow_notes;
DROP POLICY IF EXISTS "Users can update own tomorrow notes" ON public.entry_tomorrow_notes;
DROP POLICY IF EXISTS "Users can view own tomorrow notes" ON public.entry_tomorrow_notes;
```

**Expected Result:** All commands should execute (may show "does not exist" warnings - that's OK).

---

## **STEP 5: CREATE RLS POLICIES FOR `entries` TABLE**

**Purpose:** Allow users to manage their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert their own entries
CREATE POLICY "Users can insert own entries" 
ON public.entries
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own entries
CREATE POLICY "Users can update own entries" 
ON public.entries
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own entries
CREATE POLICY "Users can view own entries" 
ON public.entries
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can delete their own entries
CREATE POLICY "Users can delete own entries" 
ON public.entries
FOR DELETE
USING (auth.uid() = user_id);
```

**Expected Result:** All 4 policies created successfully.

---

## **STEP 6: CREATE RLS POLICIES FOR `entry_affirmations` TABLE**

**Purpose:** Allow users to manage affirmations for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert affirmations for their own entries
CREATE POLICY "Users can insert own affirmations" 
ON public.entry_affirmations
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_affirmations.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update affirmations for their own entries
CREATE POLICY "Users can update own affirmations" 
ON public.entry_affirmations
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_affirmations.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_affirmations.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own affirmations
CREATE POLICY "Users can view own affirmations" 
ON public.entry_affirmations
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_affirmations.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 7: CREATE RLS POLICIES FOR `entry_priorities` TABLE**

**Purpose:** Allow users to manage priorities for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert priorities for their own entries
CREATE POLICY "Users can insert own priorities" 
ON public.entry_priorities
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_priorities.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update priorities for their own entries
CREATE POLICY "Users can update own priorities" 
ON public.entry_priorities
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_priorities.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_priorities.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own priorities
CREATE POLICY "Users can view own priorities" 
ON public.entry_priorities
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_priorities.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 8: CREATE RLS POLICIES FOR `entry_meals` TABLE**

**Purpose:** Allow users to manage meals for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert meals for their own entries
CREATE POLICY "Users can insert own meals" 
ON public.entry_meals
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_meals.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update meals for their own entries
CREATE POLICY "Users can update own meals" 
ON public.entry_meals
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_meals.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_meals.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own meals
CREATE POLICY "Users can view own meals" 
ON public.entry_meals
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_meals.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 9: CREATE RLS POLICIES FOR `entry_gratitude` TABLE**

**Purpose:** Allow users to manage gratitude for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert gratitude for their own entries
CREATE POLICY "Users can insert own gratitude" 
ON public.entry_gratitude
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_gratitude.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update gratitude for their own entries
CREATE POLICY "Users can update own gratitude" 
ON public.entry_gratitude
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_gratitude.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_gratitude.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own gratitude
CREATE POLICY "Users can view own gratitude" 
ON public.entry_gratitude
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_gratitude.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 10: CREATE RLS POLICIES FOR `entry_self_care` TABLE**

**Purpose:** Allow users to manage self-care data for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert self-care for their own entries
CREATE POLICY "Users can insert own self care" 
ON public.entry_self_care
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_self_care.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update self-care for their own entries
CREATE POLICY "Users can update own self care" 
ON public.entry_self_care
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_self_care.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_self_care.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own self-care
CREATE POLICY "Users can view own self care" 
ON public.entry_self_care
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_self_care.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 11: CREATE RLS POLICIES FOR `entry_shower_bath` TABLE**

**Purpose:** Allow users to manage shower/bath data for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert shower/bath for their own entries
CREATE POLICY "Users can insert own shower bath" 
ON public.entry_shower_bath
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_shower_bath.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update shower/bath for their own entries
CREATE POLICY "Users can update own shower bath" 
ON public.entry_shower_bath
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_shower_bath.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_shower_bath.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own shower/bath
CREATE POLICY "Users can view own shower bath" 
ON public.entry_shower_bath
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_shower_bath.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 12: CREATE RLS POLICIES FOR `entry_tomorrow_notes` TABLE**

**Purpose:** Allow users to manage tomorrow notes for their own entries.

**Run in Supabase SQL Editor:**

```sql
-- Policy: Users can insert tomorrow notes for their own entries
CREATE POLICY "Users can insert own tomorrow notes" 
ON public.entry_tomorrow_notes
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_tomorrow_notes.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can update tomorrow notes for their own entries
CREATE POLICY "Users can update own tomorrow notes" 
ON public.entry_tomorrow_notes
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_tomorrow_notes.entry_id 
    AND entries.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_tomorrow_notes.entry_id 
    AND entries.user_id = auth.uid()
  )
);

-- Policy: Users can view their own tomorrow notes
CREATE POLICY "Users can view own tomorrow notes" 
ON public.entry_tomorrow_notes
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.entries 
    WHERE entries.id = entry_tomorrow_notes.entry_id 
    AND entries.user_id = auth.uid()
  )
);
```

**Expected Result:** All 3 policies created successfully.

---

## **STEP 13: VERIFY ALL POLICIES WERE CREATED**

**Purpose:** Confirm all policies exist and are correctly configured.

**Run in Supabase SQL Editor:**

```sql
-- Verify all policies were created
SELECT 
  tablename,
  policyname,
  cmd as operation,
  CASE 
    WHEN cmd = 'SELECT' THEN 'View'
    WHEN cmd = 'INSERT' THEN 'Insert'
    WHEN cmd = 'UPDATE' THEN 'Update'
    WHEN cmd = 'DELETE' THEN 'Delete'
    ELSE cmd
  END as permission
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'entries',
    'entry_affirmations',
    'entry_priorities',
    'entry_meals',
    'entry_gratitude',
    'entry_self_care',
    'entry_shower_bath',
    'entry_tomorrow_notes'
  )
ORDER BY tablename, cmd;
```

**Expected Result:**
- `entries`: 4 policies (SELECT, INSERT, UPDATE, DELETE)
- All other tables: 3 policies each (SELECT, INSERT, UPDATE)
- **Total: 25 policies**

---

## **STEP 14: TEST POLICIES (OPTIONAL)**

**Purpose:** Verify policies work correctly with a test query.

**⚠️ WARNING:** Only run this if you have a test user account. Replace `YOUR_USER_ID` with an actual user ID.

**Run in Supabase SQL Editor (as authenticated user):**

```sql
-- Test: Try to insert an entry (should work)
-- First, get your user ID
SELECT auth.uid() as current_user_id;

-- Then test insert (replace with your actual user_id)
-- This should work if you're authenticated
INSERT INTO public.entries (user_id, entry_date, diary_text)
VALUES (auth.uid(), CURRENT_DATE, 'Test entry')
RETURNING id;

-- Test: Try to insert affirmations for that entry
-- (Replace ENTRY_ID with the ID returned above)
INSERT INTO public.entry_affirmations (entry_id, affirmations)
VALUES ('ENTRY_ID', '[{"text": "Test", "order": 1}]'::jsonb)
RETURNING *;
```

**Expected Result:** Both inserts should succeed if policies are correct.

---

## **STEP 15: VERIFY IN SUPABASE DASHBOARD**

**Purpose:** Visual confirmation that RLS is enabled.

**Steps:**
1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **Authentication** → **Policies**
3. Or go to **Table Editor** → Select any entry table
4. Click on **"Policies"** tab
5. Verify policies are listed

**Expected:** You should see all the policies we created.

---

## **TROUBLESHOOTING**

### **Issue 1: "Policy already exists" Error**

**Solution:**
```sql
-- Drop the policy first, then recreate
DROP POLICY IF EXISTS "Policy Name" ON public.table_name;
-- Then run the CREATE POLICY again
```

### **Issue 2: "Permission denied" When Running Queries**

**Solution:**
- Ensure you're logged in as the project owner/admin
- Check that you have the correct permissions
- Try running queries in the Supabase SQL Editor (not from app)

### **Issue 3: Policies Created But Still Getting RLS Errors**

**⚠️ MOST COMMON CAUSE: Entry doesn't exist in Supabase when related data tries to sync**

**Root Cause:** Entry sync is non-blocking, so affirmations/priorities/etc sync before entry exists in Supabase. RLS policies check if entry exists - if it doesn't, sync fails.

**Diagnostic Steps:**

**Step 1: Check if policies exist**
```sql
-- Verify policies were created
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE schemaname = 'public' 
  AND tablename IN ('entry_affirmations', 'entry_priorities', 'entry_meals', 'entry_gratitude', 'entry_self_care', 'entry_shower_bath', 'entry_tomorrow_notes')
ORDER BY tablename, cmd;
```

**Expected:** Should see 3 policies per table (SELECT, INSERT, UPDATE)

**Step 2: Check if entry exists for failing sync**
```sql
-- Replace with actual entry_id from error logs
SELECT 
  e.id,
  e.user_id,
  e.entry_date,
  e.created_at,
  CASE 
    WHEN e.id IS NULL THEN 'Entry DOES NOT EXIST'
    ELSE 'Entry exists'
  END as entry_status
FROM public.entries e
WHERE e.id = '09dc1d32-22c8-4463-8eb2-e73e8d2dbc5e';  -- Replace with actual entry_id
```

**If entry doesn't exist:** This confirms the sync order issue. Fix code (see below).

**Step 3: Check user authentication**
```sql
-- Check current authenticated user
SELECT auth.uid() as current_user_id;
```

**If NULL:** User not authenticated - that's why RLS fails.

**Step 4: Verify entry belongs to user**
```sql
-- Check if entry user_id matches auth user
SELECT 
  e.id,
  e.user_id,
  auth.uid() as current_auth_user,
  CASE 
    WHEN e.user_id = auth.uid() THEN 'Match - Should work'
    WHEN e.user_id IS NULL THEN 'Entry not found'
    ELSE 'Mismatch - Wrong user'
  END as status
FROM public.entries e
WHERE e.id = '09dc1d32-22c8-4463-8eb2-e73e8d2dbc5e';  -- Replace with actual entry_id
```

### **Issue 4: Still Getting Error Logs After Fix**

**Check:**
1. Verify policies are active (Step 13)
2. Check if entry exists before syncing related data
3. Ensure user is authenticated when syncing
4. Check error logs for specific error codes

---

## **POST-FIX VERIFICATION**

### **1. Check Error Logs**

After applying fixes, monitor error logs:

```sql
-- Check recent RLS errors (should be zero after fix)
SELECT 
  error_code,
  error_message,
  created_at,
  COUNT(*) as error_count
FROM public.error_logs
WHERE error_code IN ('ERRSYS102', 'ERRSYS103', 'ERRSYS104', 'ERRSYS105', 'ERRSYS106', 'ERRSYS107', 'ERRSYS108')
  AND created_at > NOW() - INTERVAL '1 hour'
GROUP BY error_code, error_message, created_at
ORDER BY created_at DESC;
```

### **2. Test App Sync**

1. Open the app
2. Create a new entry
3. Add affirmations, priorities, etc.
4. Check Supabase tables to verify data was saved
5. Monitor error logs - should see no RLS errors

---

## **SUMMARY**

**What We Fixed:**
- ✅ Enabled RLS on all 8 entry-related tables
- ✅ Created 25 RLS policies (INSERT, UPDATE, SELECT for each table)
- ✅ Policies check entry ownership via `entries` table
- ✅ Users can only access their own data

**Expected Outcome:**
- ✅ No more RLS policy violation errors
- ✅ Data syncs successfully to Supabase
- ✅ Error logs stop flooding
- ✅ Users can save entries, affirmations, priorities, etc.

---

## **CRITICAL CODE FIX - SYNC ORDER**

**⚠️ REQUIRED:** The RLS errors are happening because related data (affirmations, priorities, etc.) tries to sync before the entry exists in Supabase.

**Problem:** Entry sync is non-blocking, so affirmations sync immediately but entry might not be in Supabase yet.

**Solution:** Ensure entry sync completes BEFORE syncing related data.

### **Fix 1: Update `saveAffirmations` method**

**File:** `lib/services/entry_service.dart`

**Current Code (lines 106-125):**
```dart
// Sync to cloud (non-blocking)
if (await _isOnline()) {
  _syncService.syncAffirmations(entryAffirmations);
}
```

**Fixed Code:**
```dart
// Sync to cloud - ensure entry exists first
if (await _isOnline()) {
  // FIRST: Ensure entry exists in Supabase
  final entrySynced = await _syncService.syncEntry(entry);
  
  // THEN: Sync affirmations (only if entry sync succeeded)
  if (entrySynced) {
    _syncService.syncAffirmations(entryAffirmations);
  }
}
```

### **Fix 2: Apply same pattern to ALL save methods**

Update these methods in `lib/services/entry_service.dart`:
- `savePriorities()` (line 127)
- `saveMeals()` (line 148)
- `saveGratitude()` (line 180)
- `saveSelfCare()` (line 201)
- `saveShowerBath()` (line 232)
- `saveTomorrowNotes()` (line 254)

**Pattern for each:**
```dart
// Sync to cloud - ensure entry exists first
if (await _isOnline()) {
  // FIRST: Ensure entry exists in Supabase
  final entrySynced = await _syncService.syncEntry(entry);
  
  // THEN: Sync related data (only if entry sync succeeded)
  if (entrySynced) {
    _syncService.sync[RelatedData](...);
  }
}
```

### **Alternative Fix: Check entry exists before sync**

If you prefer to keep non-blocking sync, add entry existence check in sync service:

**File:** `lib/services/sync/supabase_sync_service.dart`

**Add to each sync method:**
```dart
Future<bool> syncAffirmations(EntryAffirmations affirmations) async {
  try {
    // Check if entry exists in Supabase first
    final entryExists = await _supabase
        .from('entries')
        .select('id')
        .eq('id', affirmations.entryId)
        .maybeSingle();
    
    if (entryExists == null) {
      // Entry doesn't exist yet, skip sync (will retry later)
      return false;
    }
    
    await _supabase.from('entry_affirmations').upsert({
      'entry_id': affirmations.entryId,
      'affirmations': affirmations.affirmations
          .map((a) => a.toJson())
          .toList(),
    });
    return true;
  } catch (e) {
    // ... existing error logging
  }
}
```

**Recommendation:** Use Fix 1 (ensure entry syncs first) - it's more reliable.

---

## **END OF GUIDE**

If you encounter any issues, refer to the Troubleshooting section or check the Supabase logs for specific error messages.

