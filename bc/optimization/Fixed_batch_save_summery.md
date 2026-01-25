# P1 Issue Fix Summary: Multi-Device Sync & Date Mismatch

**Date:** January 2026  
**Priority:** P1 (Critical)  
**Status:** ✅ Fixed

---

## 🚨 INITIAL PROBLEM REPORTED

### Symptoms
- **Multi-device sync failures:** Entries created on one device failed to sync on another device
- **Sync failure indicator:** Red sync status showing "sync failure" when filling affirmations
- **Restart issue:** On app restart, sync attempts failed again
- **Error logs:** `ERRDB001` and `ERRSYS101` errors showing duplicate key constraint violations

### Error Details
```
duplicate key value violates unique constraint "entries_user_id_entry_date_key"
Entry ID: 982fc765-2c7f-40bc-a1ff-69dcd4b9191e
Entry Date: 2026-01-24
```

---

## 🔍 ROOT CAUSE ANALYSIS

### Issue #1: Date Mismatch (Primary Root Cause)

**Problem:**
- **Write path:** App converted local date to UTC before storing
  - User enters data on 25th Jan (local) → UTC conversion → stored as 24th Jan
- **Fetch path:** App queried Supabase with local date (25th Jan)
  - Query: `WHERE entry_date = '2026-01-25'`
  - Supabase has: `entry_date = '2026-01-24'`
  - **Result:** No match → creates new entry → duplicate key violation

**Code Locations:**
1. `lib/services/entry_service.dart` - `_getOrCreateEntry()` (line 471-472)
   - Used `date.toUtc()` before extracting date components
2. `lib/models/entry_models.dart` - `toSupabaseJson()` (line 71-76)
   - Converted `entryDate.toUtc()` before sending to Supabase
3. `lib/services/data_prefetch_service.dart` - `prefetchTodayData()` (line 86-97)
   - Used UTC calculation from streak table

**Why It Happened:**
- UTC conversion was added during "data-fetching-on-startup-optimization" (Jan 2026)
- Intended to handle multi-timezone users
- But fetch functions already used local dates → mismatch created

---

### Issue #2: Multi-Device ID Conflict (Secondary Issue)

**Initial Hypothesis:**
- Different devices creating different IDs for same `(user_id, entry_date)` pair
- Device A: Creates entry with ID `abc123`, date 24th
- Device B: Creates entry with ID `def456`, date 24th
- Both try to sync → unique constraint violation

**Why This Wasn't the Real Issue:**
- `loadEntryForDate()` fetches from cloud FIRST (line 47)
- Device B gets same entry ID from Device A before creating new one
- Cloud-first fetch prevents ID conflicts
- **Date mismatch was preventing cloud fetch from finding existing entry**

---

## ✅ SOLUTION IMPLEMENTED

### Fix #1: Remove UTC Conversion from Entry Creation

**File:** `lib/services/entry_service.dart`

**Change:**
```dart
// BEFORE (WRONG):
final dateUtc = date.toUtc();
final dateUtcOnly = DateTime(dateUtc.year, dateUtc.month, dateUtc.day);

// AFTER (CORRECT):
final dateOnly = DateTime(date.year, date.month, date.day);
```

**Impact:**
- Entry creation now uses local device date
- Matches what user sees on their device
- Consistent with fetch operations

---

### Fix #2: Remove UTC Conversion from Supabase JSON

**File:** `lib/models/entry_models.dart`

**Change:**
```dart
// BEFORE (WRONG):
final entryDateUtc = entryDate.toUtc();
final entryDateStr = DateTime(
  entryDateUtc.year,
  entryDateUtc.month,
  entryDateUtc.day,
).toIso8601String().split('T')[0];

// AFTER (CORRECT):
final entryDateStr = DateTime(
  entryDate.year,
  entryDate.month,
  entryDate.day,
).toIso8601String().split('T')[0];
```

**Impact:**
- Entry date sent to Supabase matches local device date
- No date shift during storage
- Consistent across write and fetch

---

### Fix #3: Fix Prefetch Today Data

**File:** `lib/services/data_prefetch_service.dart`

**Change:**
```dart
// BEFORE (WRONG):
DateTime todayUtc;
final nowUtc = DateTime.now().toUtc();
todayUtc = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);

// AFTER (CORRECT):
final now = DateTime.now();
final todayLocal = DateTime(now.year, now.month, now.day);
```

**Impact:**
- Prefetch uses local date (consistent with entry storage)
- Today's data fetched correctly on every startup
- Multi-device sync works correctly

---

### Fix #4: Fix Prefetch 7-Day Data

**File:** `lib/services/data_prefetch_service.dart`

**Change:**
- Removed UTC calculation from streak table
- Removed dependency on streak table's `today_date`
- Uses local device date (matches `prefetchTodayData()` pattern)

**Impact:**
- Consistent date handling across all prefetch operations
- Correct date range for weekly stats calculations
- No date mismatch in local DB

---

## 📊 WHY THE FIX WORKS

### Before Fix:
1. Device A: Creates entry with local date 25th → UTC conversion → stores as 24th
2. Device B: Queries cloud with local date 25th → doesn't find entry (stored as 24th)
3. Device B: Creates new entry → duplicate key violation

### After Fix:
1. Device A: Creates entry with local date 25th → stores as 25th
2. Device B: Queries cloud with local date 25th → finds entry (stored as 25th)
3. Device B: Uses same entry ID → no conflict → syncs successfully

**Key Insight:**
- Date mismatch prevented cloud fetch from finding existing entries
- Once dates match, cloud-first fetch ensures both devices use same ID
- No ID conflict resolution needed

---

## 🎯 FILES MODIFIED

1. **`lib/services/entry_service.dart`**
   - `_getOrCreateEntry()` - Removed UTC conversion
   - Updated comments to reflect local date usage

2. **`lib/models/entry_models.dart`**
   - `toSupabaseJson()` - Removed UTC conversion
   - Updated comments about local date usage

3. **`lib/services/data_prefetch_service.dart`**
   - `prefetchTodayData()` - Changed to local date
   - `prefetch7DaysData()` - Changed to local date
   - Removed UTC calculation logic

---

## ✅ VERIFICATION

### Testing Scenarios
1. ✅ **Multi-device sync:** Tested with phone + emulator
   - Device A creates entry → Device B sees it correctly
   - Device B updates entry → Device A sees updates
   - No sync failures

2. ✅ **Date consistency:** Verified dates match across devices
   - Entry created on 25th Jan → stored as 25th Jan
   - No date shift issues

3. ✅ **New users:** Confirmed no issues for fresh installs
   - All date handling uses local dates consistently

4. ✅ **Existing users:** Old entries with wrong dates don't break app
   - New entries use correct dates
   - Old entries can be manually fixed if needed

---

## 📝 KEY LEARNINGS

### What We Learned
1. **Date handling must be consistent:** Write and fetch must use same date logic
2. **UTC conversion not needed:** Supabase `entry_date` is DATE type (no timezone)
3. **Cloud-first fetch prevents conflicts:** Fetching from cloud first ensures same IDs
4. **Local dates work better:** Matches user's device date, simpler logic

### Why UTC Was Added (Original Intent)
- Multi-timezone users: Handle users in different timezones
- Date consistency: Ensure same date across devices
- AI functions: Need correct dates for analysis

### Why UTC Caused Problems
- Fetch already used local dates
- UTC conversion created mismatch
- Query didn't match stored date → duplicate entries

---

## 🔄 RELATED FIXES

### Additional Changes Made
1. **Internet permissions:** Added `INTERNET` and `ACCESS_NETWORK_STATE` to AndroidManifest.xml
2. **APK build:** Verified APK builds correctly for testing

---

## 🚀 DEPLOYMENT NOTES

### For New Users
- ✅ No issues expected
- ✅ All date handling uses local dates from start
- ✅ Multi-device sync works correctly

### For Existing Users
- ✅ New entries will use correct dates
- ✅ Old entries with wrong dates won't break app
- ✅ Can manually fix old entries if needed (rare)

### Rollback Plan
- If issues occur, revert UTC conversion changes
- But this would reintroduce date mismatch issues
- Not recommended unless critical

---

## 📚 FUTURE REFERENCE

### When to Use UTC
- **Don't use UTC** for `entry_date` (DATE type, no timezone)
- **Use UTC** for timestamps (`created_at`, `updated_at`) if needed
- **Use local dates** for user-facing dates (matches device)

### Date Handling Best Practices
1. Extract date components first: `DateTime(year, month, day)`
2. Don't convert date-only values to UTC
3. Use same date logic for write and fetch
4. Match user's device date for consistency

---

## ✅ RESOLUTION STATUS

**Status:** ✅ **FIXED**

**Date Fixed:** January 2026

**Verification:**
- ✅ Multi-device sync working
- ✅ No duplicate key violations
- ✅ Dates consistent across devices
- ✅ No sync failures reported

**Impact:**
- Critical issue resolved
- App ready for production
- Multi-device testing successful

---

## 📋 SUMMARY

**Problem:** Multi-device sync failures due to date mismatch (UTC vs local)

**Root Cause:** UTC conversion in write path, but fetch used local dates → mismatch → duplicate entries

**Solution:** Remove UTC conversion, use local dates consistently

**Result:** Multi-device sync works correctly, no date mismatch issues

**Files Changed:** 3 files (entry_service.dart, entry_models.dart, data_prefetch_service.dart)

**Complexity:** Low (simple date logic change)

**Risk:** Low (no breaking changes, backward compatible)
