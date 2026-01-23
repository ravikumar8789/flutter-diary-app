# Data Fetching on Startup Optimization - Implementation Plan

**Date:** January 2026  
**Objective:** Optimize data fetching strategy to ensure complete 7-day data for calculations and fresh today's data for multi-device sync

---

## 🎯 OBJECTIVES

1. **7-Day Data for Calculations:** Fetch complete 7-day data (with all related fields) on reinstall/relogin for accurate weekly stats
2. **Today's Data Freshness:** Fetch today's data (with all related fields) on every startup for multi-device sync
3. **Preserve Existing Functionality:** Ensure no breaking changes to current features
4. **Selective Error Logging:** Log only actual errors (network failures, write failures, timezone issues), not normal user behavior
5. **Timezone Precision:** Handle timezone conversions accurately for global users
6. **Sync Queue Integrity:** Ensure prefetched data doesn't pollute sync queue (data already synced)

---

## 📊 CURRENT STATE ANALYSIS

### Current Flow

**On App Startup:**
1. `calculateStreakOnAppLaunch()` - Fetches streaks (1 call)
2. `loadUserData()` - Fetches user profile + stats
3. Check `needsDataFetch` flag:
   - If `true`: `prefetch7DaysData()` - Fetches basic entries only (no joins) + habits + streaks
   - If `false`: No fetch
4. Cleanup old entries (7-day retention)

**Issues:**
- ❌ `prefetch7DaysData()` uses `fetchEntries()` - only basic entry data, missing related fields
- ❌ Weekly calculations need meals, self-care, etc. but local DB doesn't have them
- ❌ Today's data not fetched on normal startup - can be stale across devices
- ❌ No freshness check for today's data

---

## ✅ PROPOSED SOLUTION

### Two-Tier Fetching Strategy

**Scenario 1: Reinstall/Relogin (`needsDataFetch = true`)**
- Fetch **full 7 days** with ALL related data using `fetchEntriesWithJoins()`
- Store complete data in local DB for accurate weekly calculations
- Also fetch streaks

**Scenario 2: Normal Startup (`needsDataFetch = false`)**
- Fetch **only today's data** with ALL related data using `fetchEntriesWithJoins()` for single date
- Keep today's data fresh and synced across devices
- No 7-day fetch (local DB already has it)

---

## 🔧 IMPLEMENTATION DETAILS

### Step 1: Update `DataPrefetchService`

**File:** `lib/services/data_prefetch_service.dart`

**Changes:**

#### 1.1 Modify `prefetch7DaysData()` to use joins
- Change `_fetchEntries()` to use `fetchEntriesWithJoins()` instead of `fetchEntries()`
- Parse and store all related data in local DB
- Add comprehensive error logging

#### 1.2 Add new method `prefetchTodayData()`
- **Timezone Handling:** Get today's date in UTC for consistent querying
  - Convert local `DateTime.now()` to UTC
  - Extract date only: `DateTime(year, month, day)` in UTC
  - Format as `YYYY-MM-DD` for Supabase query
- Fetch today's data with joins using `fetchEntriesWithJoins()` for single UTC date
- **If no entry found:** Return early (no logging - expected behavior)
- **If entry found:** Parse and store all related data in local DB using `_storeEntriesWithRelatedData()`
- Add error logging **only for actual errors** (network failures, write failures)
- **Do NOT log** if today's entry doesn't exist (normal case)

#### 1.3 Add helper method `_storeEntriesWithRelatedData()`
- Parse joined response from Supabase
- **Use direct DB inserts (bypass LocalEntryService)** to avoid sync queue pollution
- Use `DatabaseManager().database` for direct SQLite operations
- Store each table with proper timezone handling:
  - `entries` table (mark as `is_synced = 1`, `last_sync_at = now()` in UTC)
  - `entry_affirmations` table (only if data exists, check for null)
  - `entry_priorities` table (only if data exists, check for null)
  - `entry_meals` table (only if data exists, check for null)
  - `entry_gratitude` table (only if data exists, check for null)
  - `entry_self_care` table (only if data exists, check for null)
  - `entry_tomorrow_notes` table (only if data exists, check for null)
- **Critical:** Data fetched from Supabase is already synced, so:
  - **DO NOT** add to sync queue
  - **DO NOT** call RPC batch update (`batchSaveEntry` is for syncing LOCAL → Supabase, not Supabase → LOCAL)
  - **DO** mark as `is_synced = 1` and `last_sync_at = now()`
  - **Note:** RPC batch update is designed to reduce API calls when syncing local changes to Supabase. Prefetch is the opposite direction (Supabase → Local), so we use direct DB inserts instead.
- **Timezone Handling:**
  - Convert all dates to UTC before storing
  - Store dates as ISO8601 strings with timezone info
  - Log HIGH severity if timezone conversion fails
- Handle null/empty related data gracefully (check before storing, no logging)
- Add error logging **only for actual errors** (write failures, not missing data)
- Continue storing other entries even if one fails
- Use transactions where possible for atomicity
- **Validation:** After storing, verify no sync queue entries created for these entry IDs

---

### Step 2: Update `splash_screen.dart`

**File:** `lib/screens/splash_screen.dart`

**Changes:**

#### 2.1 Modify startup flow
- After `needsFetch` check:
  - If `true`: Call `prefetch7DaysData()` (already exists, but now with joins)
  - **Always** (regardless of flag): Call `prefetchTodayData()` after `needsFetch` block
- Add loading message for today's data fetch
- Handle errors gracefully (log but continue)

#### 2.2 Order of operations
```
1. calculateStreakOnAppLaunch()
2. loadUserData()
3. If needsFetch: prefetch7DaysData() (with joins)
4. Always: prefetchTodayData() (with joins)
5. cleanupOldEntries()
6. processSyncQueue()
```

---

### Step 3: Timezone Handling (CRITICAL)

**File:** `lib/services/data_prefetch_service.dart`

**Implementation:**

#### 3.1 UTC Date Conversion
```dart
// Get today's date in UTC
final nowUtc = DateTime.now().toUtc();
final todayUtc = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
final todayDateStr = DateFormat('yyyy-MM-dd').format(todayUtc);
```

#### 3.2 Date Storage
- Store all dates in local DB as ISO8601 strings (includes timezone)
- When parsing from Supabase, treat as UTC
- When storing, convert to ISO8601: `dateTime.toIso8601String()`

#### 3.3 Validation
- Compare device timezone with query date
- Log HIGH severity if timezone mismatch detected
- Log HIGH severity if date parsing fails

#### 3.4 Edge Cases
- User travels across timezone: Use UTC consistently, device timezone doesn't matter
- Daylight saving time: UTC handles this automatically
- Date boundary: Use UTC midnight for "today" calculation

---

### Step 4: Error Logging Strategy

**Error Codes:**
- `ERRSYS171`: Failed to prefetch today's data (network/API error)
- `ERRSYS172`: Failed to store entry in local DB (write error)
- `ERRSYS173`: Failed to store entry_affirmations in local DB (write error)
- `ERRSYS174`: Failed to store entry_priorities in local DB (write error)
- `ERRSYS175`: Failed to store entry_meals in local DB (write error)
- `ERRSYS176`: Failed to store entry_gratitude in local DB (write error)
- `ERRSYS177`: Failed to store entry_self_care in local DB (write error)
- `ERRSYS178`: Failed to store entry_tomorrow_notes in local DB (write error)
- `ERRSYS179`: Failed to parse joined entry data (data format error)
- `ERRSYS180`: Timezone conversion failed (HIGH severity)
- `ERRSYS181`: Date parsing failed (HIGH severity)
- `ERRSYS182`: Sync queue pollution detected (prefetched data in sync queue - HIGH severity)

**Error Context:**
- User ID
- Entry ID (if available)
- Operation type (prefetch_7days, prefetch_today, store_entry, etc.)
- Date range or specific date (in UTC)
- Timezone info (device timezone, UTC offset)
- Table name (for storage errors)
- Error details

**Logging Rules:**
- **DO NOT log:** Today's entry doesn't exist (expected)
- **DO NOT log:** Partial data (normal user behavior)
- **DO NOT log:** Data conflicts (normal sync operation)
- **DO log:** Network failures (HIGH severity)
- **DO log:** Write failures (CRITICAL severity)
- **DO log:** Timezone conversion failures (HIGH severity)
- **DO log:** Date parsing failures (HIGH severity)
- **DO log:** Sync queue pollution (HIGH severity - indicates bug)

---

## 🚨 EDGE CASES & POTENTIAL ISSUES

### Edge Case 1: Today's Entry Doesn't Exist
**Scenario:** User hasn't created today's entry yet  
**Solution:** 
- `fetchEntriesWithJoins()` returns empty list
- **No logging** - This is expected behavior, not an error
- Continue normally (user will create entry when they fill data)
- Return early from `prefetchTodayData()` if no entry found

### Edge Case 2: Partial Data in Supabase
**Scenario:** Entry exists but some related tables are null/empty  
**Solution:**
- Check for null before storing each related table
- Store entry even if related data is missing
- **No logging** - This is normal user behavior (user may not fill all fields)
- Handle gracefully: Only store tables that have data

### Edge Case 3: Network Failure During Prefetch
**Scenario:** Network unavailable during startup  
**Solution:**
- Catch exception, log as HIGH severity
- Don't block app startup
- Data will be fetched on-demand when screens open
- Keep `needsDataFetch` flag as `true` if 7-day prefetch fails

### Edge Case 4: Local DB Write Failure
**Scenario:** SQLite write fails (disk full, permissions, etc.)  
**Solution:**
- Catch exception, log as CRITICAL severity
- Continue with other entries (don't fail entire prefetch)
- Log which entry failed
- App continues (data will be fetched on-demand)

### Edge Case 5: Data Conflict (Entry Already Exists)
**Scenario:** Entry exists in local DB with different data  
**Solution:**
- Use `ConflictAlgorithm.replace` for entries table
- Use `INSERT OR REPLACE` for related tables
- Server data takes precedence (fresh fetch)
- **No logging** - This is expected behavior (normal sync operation)
- This ensures local DB matches server (source of truth)

### Edge Case 6: Timezone Issues (HIGH PRIORITY)
**Scenario:** User in different timezone, "today" might differ between device and server  
**Solution:**
- **Critical:** Always use UTC for date comparisons and storage
- Get user's timezone from device: `DateTime.now().timeZoneName` or `DateTime.now().timeZoneOffset`
- Convert local "today" to UTC before querying Supabase
- Supabase stores all dates in UTC
- When fetching today's data:
  1. Get current UTC date: `DateTime.now().toUtc()`
  2. Extract date only: `DateTime(year, month, day)` in UTC
  3. Query Supabase with UTC date string: `YYYY-MM-DD` format
  4. Parse response dates as UTC
- When storing in local DB, store dates as ISO8601 strings (includes timezone)
- **Log as HIGH severity** if timezone conversion fails or mismatches detected
- **Log as HIGH severity** if date parsing fails
- Add validation: Compare device timezone with stored user timezone (if available)
- Handle edge case: User travels across timezone, "today" changes mid-day

### Edge Case 7: Large Response Size
**Scenario:** 7 days of data with all joins might be large  
**Solution:**
- Single query is still efficient (Postgres handles it)
- Response size typically < 1MB for 7 days
- If timeout occurs, log and retry once
- Fallback to on-demand fetching

### Edge Case 8: Concurrent Writes
**Scenario:** User saves entry while prefetch is running  
**Solution:**
- SQLite handles concurrent writes (queue)
- Last write wins (expected behavior)
- User's save will sync to Supabase
- Next startup will fetch updated data

### Edge Case 11: Sync Queue Pollution & RPC Batch Update
**Scenario:** Using `LocalEntryService` methods adds entries to sync queue, but data is already synced from Supabase. RPC batch update feature is used to sync entries efficiently.  
**Solution:**
- **Critical:** Data fetched from Supabase is already synced, must NOT be added to sync queue
- **Option A (NOT Recommended):** After storing, manually remove entries from sync queue - Complex and error-prone
- **Option B (Recommended):** Use direct DB inserts (bypass LocalEntryService) and mark as synced
  - Directly insert into local DB tables using `DatabaseManager`
  - Mark entries as `is_synced = 1` and `last_sync_at = now()`
  - **Do NOT** add to sync queue
  - **Do NOT** call RPC batch update (data already in Supabase)
- **Important:** RPC batch update (`batchSaveEntry`) is for syncing LOCAL changes to Supabase
- **Important:** Prefetch is for syncing SUPABASE data to local (opposite direction)
- **Validation:** After storing, verify `is_synced = 1` and no sync queue entries for these entry IDs
- **Error Handling:** If sync queue has entries for prefetched data, log as HIGH severity (indicates bug)

### Edge Case 9: Cleanup Interferes with Prefetch
**Scenario:** Cleanup runs before prefetch completes  
**Solution:**
- Run cleanup AFTER prefetch (current order is correct)
- Cleanup only deletes entries older than 7 days
- Today's data and 7-day range won't be affected

### Edge Case 10: Multiple Devices Simultaneous Access
**Scenario:** User opens app on Device A and B simultaneously  
**Solution:**
- Each device fetches independently
- Supabase handles concurrent reads
- Last write wins (expected behavior)
- Today's fetch ensures both devices get latest data

---

## 🔍 TESTING STRATEGY

### Test Case 1: Fresh Install
**Steps:**
1. Uninstall app
2. Install fresh
3. Login
4. Verify 7-day data fetched with all related fields
5. Verify today's data fetched
6. Check local DB has complete data
7. Verify weekly stats show correct values

**Expected:** All data present, calculations accurate

### Test Case 2: Normal Startup
**Steps:**
1. Open app (not fresh install)
2. Verify only today's data fetched
3. Verify 7-day data not refetched
4. Check today's data is fresh (matches Supabase)

**Expected:** Today's data fresh, no unnecessary 7-day fetch

### Test Case 3: Multi-Device Sync
**Steps:**
1. Fill data on Device A
2. Open app on Device B
3. Verify Device B shows today's data from Device A
4. Fill different data on Device B
5. Open app on Device A
6. Verify Device A shows updated data

**Expected:** Today's data synced across devices

### Test Case 4: Network Failure
**Steps:**
1. Disable network
2. Open app
3. Verify app doesn't crash
4. Verify errors logged
5. Enable network
6. Verify data fetched on-demand when screens open

**Expected:** Graceful degradation, no crashes

### Test Case 5: Partial Data
**Steps:**
1. Create entry with only diary (no related data)
2. Reinstall app
3. Verify entry stored correctly
4. Verify related tables are empty (not null errors)
5. Verify no error logs for missing related data

**Expected:** Entry stored, related tables empty but valid, no unnecessary logs

### Test Case 6: Weekly Calculations
**Steps:**
1. Fill 7 days of complete data
2. Reinstall app
3. Verify weekly stats calculated correctly:
   - Avg mood
   - Water intake
   - Self-care %
   - Consistency

**Expected:** All stats accurate

### Test Case 7: Large Dataset
**Steps:**
1. Create 7 days of entries with all fields filled
2. Reinstall app
3. Verify all data fetched and stored
4. Check performance (should be < 3 seconds)

**Expected:** All data present, acceptable performance

### Test Case 8: Error Logging
**Steps:**
1. Trigger various error scenarios (network failure, write failure)
2. Check error logs in Supabase
3. Verify error codes are correct
4. Verify error context is complete
5. Verify normal cases (no entry, partial data) are NOT logged

**Expected:** Only actual errors logged, normal cases not logged

### Test Case 9: Timezone Handling
**Steps:**
1. Set device to different timezone
2. Create entry on one device
3. Open app on another device in different timezone
4. Verify today's data fetched correctly
5. Verify dates stored in UTC
6. Verify no timezone-related errors

**Expected:** Dates handled correctly across timezones, no errors

### Test Case 10: Sync Queue Validation
**Steps:**
1. Prefetch 7 days of data
2. Check sync queue
3. Verify no entries in sync queue for prefetched data
4. Verify all prefetched entries marked as `is_synced = 1`

**Expected:** No sync queue pollution, all entries marked as synced

---

## 📝 IMPLEMENTATION CHECKLIST

### Phase 1: Core Changes
- [ ] Update `DataPrefetchService.prefetch7DaysData()` to use `fetchEntriesWithJoins()`
- [ ] Add `DataPrefetchService.prefetchTodayData()` method with UTC timezone handling
- [ ] Add `DataPrefetchService._storeEntriesWithRelatedData()` helper method (direct DB inserts)
- [ ] Update `splash_screen.dart` to call `prefetchTodayData()` on every startup
- [ ] Add timezone conversion utilities
- [ ] Add selective error logging (only actual errors, not normal cases)

### Phase 2: Error Handling & Validation
- [ ] Handle today's entry doesn't exist case (no logging)
- [ ] Handle partial data cases (no logging)
- [ ] Handle network failures gracefully (log HIGH severity)
- [ ] Handle local DB write failures (log CRITICAL severity)
- [ ] Handle data conflicts (no logging - normal operation)
- [ ] Handle timezone conversion (log HIGH severity on failure)
- [ ] Validate sync queue (no entries for prefetched data)
- [ ] Validate entries marked as synced after prefetch

### Phase 3: Testing
- [ ] Test fresh install scenario
- [ ] Test normal startup scenario
- [ ] Test multi-device sync
- [ ] Test network failure handling
- [ ] Test partial data handling
- [ ] Test weekly calculations accuracy
- [ ] Test error logging

### Phase 4: Validation
- [ ] Verify no existing functionality broken
- [ ] Verify weekly stats accurate
- [ ] Verify today's data fresh
- [ ] Verify history screen unaffected
- [ ] Verify error logs comprehensive

---

## 🚀 ROLLOUT PLAN

### Step 1: Development
- Implement all changes in development branch
- Test thoroughly with all test cases
- Fix any issues found

### Step 2: Staging
- Deploy to staging environment
- Test with real user scenarios
- Monitor error logs
- Verify performance

### Step 3: Production
- Deploy to production
- Monitor error logs closely for first 24 hours
- Watch for any performance issues
- Be ready to rollback if critical issues found

### Rollback Plan
- If critical issues found:
  1. Revert `DataPrefetchService` changes
  2. Revert `splash_screen.dart` changes
  3. App will fall back to current behavior (on-demand fetching)
  4. No data loss (all data still in Supabase)

---

## 📊 PERFORMANCE IMPACT

### Current (Before Changes)
- **Reinstall/Relogin:** 2-3 API calls (entries basic, habits, streaks)
- **Normal Startup:** 1 API call (streaks only)
- **Weekly Stats:** Inaccurate (missing related data)

### After Changes
- **Reinstall/Relogin:** 2 API calls (entries with joins, streaks)
- **Normal Startup:** 2 API calls (streaks, today's data with joins)
- **Weekly Stats:** Accurate (complete data)

### Trade-offs
- ✅ Weekly stats accurate
- ✅ Today's data always fresh
- ✅ Multi-device sync improved
- ⚠️ 1 extra API call on normal startup (acceptable for freshness)

---

## 🔐 DATA INTEGRITY

### Guarantees
- Server data is source of truth
- Local DB is cache (can be rebuilt)
- No data loss (all data in Supabase)
- Conflicts resolved: Server data wins

### Validation
- Verify all related tables stored correctly
- Verify foreign key constraints maintained
- Verify data matches Supabase after fetch
- Verify calculations use correct data

---

## 📚 DOCUMENTATION UPDATES

### Code Comments
- Document new methods in `DataPrefetchService`
- Document error codes and their meanings
- Document edge cases handled

### User-Facing
- No user-facing changes (background operation)
- Users will notice faster weekly stats (if they were broken before)
- Users will notice better multi-device sync

---

## 🎯 SUCCESS CRITERIA

1. ✅ Weekly stats calculated accurately from local DB
2. ✅ Today's data fresh on every startup
3. ✅ Multi-device sync works correctly
4. ✅ No existing functionality broken
5. ✅ All errors logged with proper context
6. ✅ Performance acceptable (< 3 seconds for prefetch)
7. ✅ No crashes or data loss

---

## 🔄 FUTURE ENHANCEMENTS

### Potential Improvements
1. **Smart Prefetch:** Only fetch if local data is stale (> 1 hour old)
2. **Incremental Sync:** Only fetch changed entries since last sync
3. **Background Sync:** Sync in background without blocking startup
4. **Compression:** Compress large responses for faster transfer
5. **Caching Strategy:** More sophisticated cache invalidation

### Not in Scope (For Now)
- Background sync (keep startup sync for now)
- Incremental sync (full fetch is simpler and more reliable)
- Compression (response size is acceptable)

---

## 📞 SUPPORT & MONITORING

### Error Monitoring
- Monitor error logs daily for first week
- Watch for error codes: ERRSYS171-ERRSYS179
- Check for any CRITICAL errors
- Verify error context is complete

### Performance Monitoring
- Track prefetch duration
- Track API call counts
- Track local DB write times
- Alert if performance degrades

### User Feedback
- Monitor for any user complaints about:
  - Missing data
  - Incorrect stats
  - Slow startup
  - Sync issues

---

## ✅ FINAL NOTES

- **Preserve Existing Flow:** All changes are additive, no breaking changes
- **Error Handling First:** Comprehensive logging before optimization
- **Test Thoroughly:** All edge cases must be tested
- **Monitor Closely:** Watch for issues in first week after deployment
- **Be Ready to Rollback:** Have rollback plan ready

---

**End of Implementation Plan**
