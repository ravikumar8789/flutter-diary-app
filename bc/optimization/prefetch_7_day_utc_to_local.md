# Prefetch 7-Day Data: UTC to Local Date Fix

**Date:** January 2026  
**Objective:** Fix `prefetch7DaysData()` to use local device date instead of UTC date for consistency with rest of app

---

## 🎯 OBJECTIVE

Change `prefetch7DaysData()` to use local device date (like `prefetchTodayData()`) instead of UTC date to ensure:
- Consistent date handling across all prefetch operations
- Correct date range calculation for 7-day data
- Alignment with entry storage (local dates)
- No date mismatch issues

---

## 📊 CURRENT STATE

### Current Implementation (`prefetch7DaysData()`)

**Location:** `lib/services/data_prefetch_service.dart:21-71`

**Current Flow:**
1. Fetches `today_date` from Supabase streak table (assumed UTC)
2. Falls back to UTC calculation: `DateTime.now().toUtc()`
3. Calculates `weekStartUtc = todayUtc.subtract(Duration(days: 6))`
4. Calls `_fetchEntriesWithJoins()` and `_fetchHabits()` with UTC dates

**Issues:**
- ❌ Uses UTC date calculation (inconsistent with `prefetchTodayData()`)
- ❌ Depends on streak table's `today_date` (may be UTC)
- ❌ Date range might be off by 1 day for users ahead of UTC
- ❌ Inconsistent with entry storage (local dates)

---

## ✅ TARGET STATE

### After Fix

**New Flow:**
1. Use local device date: `DateTime.now()` → extract date components
2. Calculate week start: `todayLocal.subtract(Duration(days: 6))`
3. Call `_fetchEntriesWithJoins()` and `_fetchHabits()` with local dates
4. Match pattern used in `prefetchTodayData()`

**Benefits:**
- ✅ Consistent with `prefetchTodayData()` (local dates)
- ✅ Consistent with entry storage (local dates)
- ✅ Correct date range for all timezones
- ✅ No dependency on streak table's date format

---

## 🔧 IMPLEMENTATION PLAN

### Step 1: Update `prefetch7DaysData()` Method

**File:** `lib/services/data_prefetch_service.dart`

**Changes:**
1. Remove UTC date calculation logic (lines 26-45)
2. Replace with local date calculation (match `prefetchTodayData()` pattern)
3. Update comments to reflect local date usage
4. Remove dependency on streak table's `today_date`

**Code Pattern:**
```dart
// Use local device date (extract date components only, no timezone conversion)
// entry_date is stored as date only, so we use local date to match user's device date
final now = DateTime.now();
final todayLocal = DateTime(now.year, now.month, now.day);
final weekStartLocal = todayLocal.subtract(const Duration(days: 6)); // Last 7 days
```

**Update Function Calls:**
- Change `_fetchEntriesWithJoins(userId, weekStartUtc, todayUtc, ...)` 
- To: `_fetchEntriesWithJoins(userId, weekStartLocal, todayLocal, ...)`
- Change `_fetchHabits(userId, weekStartUtc, todayUtc, ...)`
- To: `_fetchHabits(userId, weekStartLocal, todayLocal, ...)`

---

### Step 2: Verify `_fetchEntriesWithJoins()` Compatibility

**File:** `lib/services/data_prefetch_service.dart:122-140`

**Check:**
- ✅ Already accepts `DateTime` parameters (no timezone assumption)
- ✅ Calls `dataFetchService.fetchEntriesWithJoins()` which converts to date string
- ✅ `fetchEntriesWithJoins()` uses `.toIso8601String().split('T')[0]` (date only)
- ✅ No changes needed - works with both UTC and local dates

**Action:** No changes required

---

### Step 3: Verify `_fetchHabits()` Compatibility

**File:** `lib/services/data_prefetch_service.dart:159-185`

**Check:**
- ✅ Already accepts `DateTime` parameters
- ✅ Calls `dataFetchService.fetchHabitsDaily()` which handles dates
- ✅ Need to verify `fetchHabitsDaily()` uses dates correctly

**Action:** Verify `fetchHabitsDaily()` implementation (check if it needs local dates)

---

### Step 4: Update Comments and Documentation

**Files to Update:**
1. `lib/services/data_prefetch_service.dart` - Method comments
2. Update class-level documentation if needed

**Comment Updates:**
- Remove references to UTC date logic
- Add note about local date usage (consistent with `prefetchTodayData()`)
- Update error context to reflect local date usage

---

### Step 5: Testing Checklist

**Scenarios to Test:**
1. ✅ **New Login:** Verify 7-day data fetched with correct date range
2. ✅ **New Device:** Verify data matches other devices
3. ✅ **Different Timezones:** Test with IST (UTC+5:30) user
4. ✅ **Date Boundary:** Test early morning (before UTC day change)
5. ✅ **Weekly Stats:** Verify home screen week cards show correct data
6. ✅ **History Screen:** Verify entries appear correctly (fetches fresh, but should match)

**Expected Results:**
- 7-day prefetch uses local date range
- Data matches what's stored in Supabase (local dates)
- No date mismatch in weekly calculations
- Consistent with `prefetchTodayData()` behavior

---

## ⚠️ POTENTIAL ISSUES & MITIGATION

### Issue 1: Existing Prefetched Data with UTC Dates
**Risk:** Low  
**Mitigation:** 
- Old prefetched data will be overwritten on next login
- `prefetchTodayData()` already handles today's data correctly
- Weekly stats recalculate from local DB (will use correct dates going forward)

### Issue 2: Habits Daily Date Mismatch
**Risk:** Low  
**Mitigation:**
- Verify `fetchHabitsDaily()` handles local dates correctly
- If not, update it to use local dates (separate fix)

### Issue 3: Cache Key Mismatch
**Risk:** None  
**Mitigation:**
- `fetchEntriesWithJoins()` cache key uses date string (works with any date format)
- Cache will be invalidated naturally on next fetch

---

## 📝 FILES TO MODIFY

1. **`lib/services/data_prefetch_service.dart`**
   - Method: `prefetch7DaysData()` (lines 21-71)
   - Update date calculation logic
   - Update comments
   - Update error context

---

## ✅ SUCCESS CRITERIA

1. ✅ `prefetch7DaysData()` uses local device date
2. ✅ Date range calculation matches `prefetchTodayData()` pattern
3. ✅ No UTC conversion in date calculation
4. ✅ Comments updated to reflect local date usage
5. ✅ Consistent with rest of app's date handling
6. ✅ Weekly stats show correct data after login

---

## 🔄 RELATED CHANGES

**Already Fixed:**
- ✅ `prefetchTodayData()` - Uses local dates
- ✅ `_getOrCreateEntry()` - Uses local dates
- ✅ `toSupabaseJson()` - Uses local dates

**This Fix:**
- 🔧 `prefetch7DaysData()` - Change to local dates

**Future Considerations:**
- Verify `fetchHabitsDaily()` uses local dates (if needed)

---

## 📋 IMPLEMENTATION STEPS SUMMARY

1. Open `lib/services/data_prefetch_service.dart`
2. Locate `prefetch7DaysData()` method (line 21)
3. Replace UTC date calculation (lines 26-45) with local date calculation
4. Update function calls to use local dates
5. Update comments
6. Test with different timezones
7. Verify weekly stats accuracy

---

**Estimated Complexity:** Low  
**Risk Level:** Low  
**Breaking Changes:** None  
**Backward Compatibility:** Yes (old prefetched data will be overwritten)
