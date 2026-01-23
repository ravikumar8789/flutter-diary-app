# RPC Batch Save Implementation Plan

**Date:** 2026-01-17  
**Status:** Ready for Implementation  
**Solution:** RPC Function for Single-Call Batch Saves

---

## Executive Summary

Implements Supabase RPC function (`batch_save_entry`) consolidating all entry saves into **1 API call** (down from 80+). Fixes mood/water logging, adds app lifecycle handling, comprehensive error logging.

**Expected Impact:**
- **API Calls:** 80+ → 1 call (98.75% reduction)
- **Mood/Water Logging:** Fixed (blocking syncs)
- **Data Loss Prevention:** Force save on app close
- **Error Tracking:** Comprehensive logging

---

## 1. Database Changes Required

### 1.1 Create RPC Function

**Execute this SQL in Supabase SQL Editor:**

```sql
CREATE OR REPLACE FUNCTION batch_save_entry(
  p_entry jsonb,
  p_affirmations jsonb DEFAULT NULL,
  p_priorities jsonb DEFAULT NULL,
  p_meals jsonb DEFAULT NULL,
  p_gratitude jsonb DEFAULT NULL,
  p_self_care jsonb DEFAULT NULL,
  p_shower_bath jsonb DEFAULT NULL,
  p_tomorrow_notes jsonb DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_entry_id uuid;
  v_result jsonb;
  v_error_message text;
BEGIN
  v_entry_id := (p_entry->>'id')::uuid;
  
  IF v_entry_id IS NULL THEN
    RAISE EXCEPTION 'Entry ID is required';
  END IF;
  
  -- Upsert entry
  INSERT INTO entries (
    id, user_id, entry_date, diary_text, mood_score, tags,
    source, is_backdated, created_at, updated_at
  )
  VALUES (
    (p_entry->>'id')::uuid,
    (p_entry->>'user_id')::uuid,
    (p_entry->>'entry_date')::date,
    p_entry->>'diary_text',
    CASE WHEN p_entry->>'mood_score' IS NOT NULL 
         THEN (p_entry->>'mood_score')::smallint 
         ELSE NULL END,
    CASE WHEN p_entry->>'tags' IS NOT NULL 
         THEN ARRAY(SELECT jsonb_array_elements_text(p_entry->'tags'))
         ELSE '{}'::text[] END,
    COALESCE(p_entry->>'source', 'mobile'),
    COALESCE((p_entry->>'is_backdated')::boolean, false),
    COALESCE((p_entry->>'created_at')::timestamptz, now()),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    diary_text = EXCLUDED.diary_text,
    mood_score = COALESCE(EXCLUDED.mood_score, entries.mood_score),
    tags = COALESCE(EXCLUDED.tags, entries.tags),
    updated_at = now();
  
  -- Upsert affirmations (only if provided)
  IF p_affirmations IS NOT NULL THEN
    INSERT INTO entry_affirmations (entry_id, affirmations)
    VALUES (v_entry_id, p_affirmations)
    ON CONFLICT (entry_id) DO UPDATE SET affirmations = EXCLUDED.affirmations;
  END IF;
  
  -- Upsert priorities (only if provided)
  IF p_priorities IS NOT NULL THEN
    INSERT INTO entry_priorities (entry_id, priorities)
    VALUES (v_entry_id, p_priorities)
    ON CONFLICT (entry_id) DO UPDATE SET priorities = EXCLUDED.priorities;
  END IF;
  
  -- Upsert meals (only if provided)
  IF p_meals IS NOT NULL THEN
    INSERT INTO entry_meals (entry_id, breakfast, lunch, dinner, water_cups)
    VALUES (
      v_entry_id,
      p_meals->>'breakfast',
      p_meals->>'lunch',
      p_meals->>'dinner',
      CASE WHEN p_meals->>'water_cups' IS NOT NULL 
           THEN (p_meals->>'water_cups')::smallint 
           ELSE 0 END
    )
    ON CONFLICT (entry_id) DO UPDATE SET
      breakfast = COALESCE(EXCLUDED.breakfast, entry_meals.breakfast),
      lunch = COALESCE(EXCLUDED.lunch, entry_meals.lunch),
      dinner = COALESCE(EXCLUDED.dinner, entry_meals.dinner),
      water_cups = COALESCE(EXCLUDED.water_cups, entry_meals.water_cups);
  END IF;
  
  -- Upsert gratitude (only if provided)
  IF p_gratitude IS NOT NULL THEN
    INSERT INTO entry_gratitude (entry_id, grateful_items)
    VALUES (v_entry_id, p_gratitude)
    ON CONFLICT (entry_id) DO UPDATE SET grateful_items = EXCLUDED.grateful_items;
  END IF;
  
  -- Upsert self care (only if provided)
  IF p_self_care IS NOT NULL THEN
    INSERT INTO entry_self_care (
      entry_id, sleep, get_up_early, fresh_air, learn_new,
      balanced_diet, podcast, me_moment, hydrated, read_book, exercise
    )
    VALUES (
      v_entry_id,
      COALESCE((p_self_care->>'sleep')::boolean, false),
      COALESCE((p_self_care->>'get_up_early')::boolean, false),
      COALESCE((p_self_care->>'fresh_air')::boolean, false),
      COALESCE((p_self_care->>'learn_new')::boolean, false),
      COALESCE((p_self_care->>'balanced_diet')::boolean, false),
      COALESCE((p_self_care->>'podcast')::boolean, false),
      COALESCE((p_self_care->>'me_moment')::boolean, false),
      COALESCE((p_self_care->>'hydrated')::boolean, false),
      COALESCE((p_self_care->>'read_book')::boolean, false),
      COALESCE((p_self_care->>'exercise')::boolean, false)
    )
    ON CONFLICT (entry_id) DO UPDATE SET
      sleep = COALESCE(EXCLUDED.sleep, entry_self_care.sleep),
      get_up_early = COALESCE(EXCLUDED.get_up_early, entry_self_care.get_up_early),
      fresh_air = COALESCE(EXCLUDED.fresh_air, entry_self_care.fresh_air),
      learn_new = COALESCE(EXCLUDED.learn_new, entry_self_care.learn_new),
      balanced_diet = COALESCE(EXCLUDED.balanced_diet, entry_self_care.balanced_diet),
      podcast = COALESCE(EXCLUDED.podcast, entry_self_care.podcast),
      me_moment = COALESCE(EXCLUDED.me_moment, entry_self_care.me_moment),
      hydrated = COALESCE(EXCLUDED.hydrated, entry_self_care.hydrated),
      read_book = COALESCE(EXCLUDED.read_book, entry_self_care.read_book),
      exercise = COALESCE(EXCLUDED.exercise, entry_self_care.exercise);
  END IF;
  
  -- Upsert shower bath (only if provided)
  IF p_shower_bath IS NOT NULL THEN
    INSERT INTO entry_shower_bath (entry_id, took_shower, note)
    VALUES (
      v_entry_id,
      COALESCE((p_shower_bath->>'took_shower')::boolean, false),
      p_shower_bath->>'note'
    )
    ON CONFLICT (entry_id) DO UPDATE SET
      took_shower = COALESCE(EXCLUDED.took_shower, entry_shower_bath.took_shower),
      note = COALESCE(EXCLUDED.note, entry_shower_bath.note);
  END IF;
  
  -- Upsert tomorrow notes (only if provided)
  IF p_tomorrow_notes IS NOT NULL THEN
    INSERT INTO entry_tomorrow_notes (entry_id, tomorrow_notes)
    VALUES (v_entry_id, p_tomorrow_notes)
    ON CONFLICT (entry_id) DO UPDATE SET tomorrow_notes = EXCLUDED.tomorrow_notes;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'entry_id', v_entry_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    INSERT INTO error_logs (
      error_code, error_message, stack_trace, error_severity,
      error_context, created_at
    )
    VALUES (
      'ERRDB001',
      SQLERRM,
      SQLSTATE || ' | ' || pg_catalog.format('%s', SQLERRM),
      'HIGH',
      jsonb_build_object(
        'function', 'batch_save_entry',
        'entry_id', v_entry_id
      ),
      now()
    );
    
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'ERRDB001',
      'error_message', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION batch_save_entry(jsonb, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb) TO authenticated;
```

**Notes:**
- Function uses `SECURITY DEFINER` to bypass RLS (required for batch operations)
- All operations are atomic (single transaction)
- Errors logged to `error_logs` automatically
- Only updates tables that have data provided

---

## 2. Code Changes Required

### 2.1 Update EntryService (Accessibility)

**File:** `lib/services/entry_service.dart`

**Add public getter/methods:**

```dart
// Add public getter for localService
LocalEntryService get localService => _localService;

// Make getOrCreateEntry public
Future<Entry> getOrCreateEntry(String userId, DateTime date) async {
  return await _getOrCreateEntry(userId, date);
}
```

### 2.2 Update SupabaseSyncService

**File:** `lib/services/sync/supabase_sync_service.dart`

**Add new method:**

```dart
Future<bool> batchSaveEntry({
  required Entry entry,
  EntryAffirmations? affirmations,
  EntryPriorities? priorities,
  EntryMeals? meals,
  EntryGratitude? gratitude,
  EntrySelfCare? selfCare,
  EntryShowerBath? showerBath,
  EntryTomorrowNotes? tomorrowNotes,
}) async {
  try {
    final entryData = entry.toSupabaseJson();
    final Map<String, dynamic> params = {'p_entry': entryData};
    
    if (affirmations != null) {
      params['p_affirmations'] = affirmations.affirmations.map((a) => a.toJson()).toList();
    }
    if (priorities != null) {
      params['p_priorities'] = priorities.priorities.map((p) => p.toJson()).toList();
    }
    if (meals != null) {
      params['p_meals'] = {
        'breakfast': meals.breakfast,
        'lunch': meals.lunch,
        'dinner': meals.dinner,
        'water_cups': meals.waterCups,
      };
    }
    if (gratitude != null) {
      params['p_gratitude'] = gratitude.gratefulItems.map((g) => g.toJson()).toList();
    }
    if (selfCare != null) {
      params['p_self_care'] = {
        'sleep': selfCare.sleep,
        'get_up_early': selfCare.getUpEarly,
        'fresh_air': selfCare.freshAir,
        'learn_new': selfCare.learnNew,
        'balanced_diet': selfCare.balancedDiet,
        'podcast': selfCare.podcast,
        'me_moment': selfCare.meMoment,
        'hydrated': selfCare.hydrated,
        'read_book': selfCare.readBook,
        'exercise': selfCare.exercise,
      };
    }
    if (showerBath != null) {
      params['p_shower_bath'] = {
        'took_shower': showerBath.tookShower,
        'note': showerBath.note,
      };
    }
    if (tomorrowNotes != null) {
      params['p_tomorrow_notes'] = tomorrowNotes.tomorrowNotes.map((t) => t.toJson()).toList();
    }
    
    final response = await _supabase.rpc('batch_save_entry', params);
    final result = response as Map<String, dynamic>;
    
    if (result['success'] == true) {
      return true;
    } else {
      await ErrorLoggingService.logHighError(
        errorCode: result['error_code'] ?? 'ERRSYS200',
        errorMessage: 'RPC batch save failed: ${result['error_message']}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'entry_id': entry.id,
          'rpc_response': result,
          'operation': 'batch_save_entry_rpc',
        },
      );
      return false;
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS200',
      errorMessage: 'RPC batch save exception: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'entry_id': entry.id,
        'operation': 'batch_save_entry_rpc',
      },
    );
    return false;
  }
}
```

### 2.3 Update EntryProvider

**File:** `lib/providers/entry_provider.dart`

**Key Changes:**
1. Update debounce to 3 seconds (line 411)
2. Replace `_executeBatchSave()` with RPC implementation
3. Add `forceImmediateSave()` method
4. Add helper methods for local saves

**New `_executeBatchSave()` implementation:**

```dart
Future<void> _executeBatchSave() async {
  if (_currentUserId == null || _currentDate == null) return;
  
  final userId = _currentUserId!;
  final date = _currentDate!;
  
  try {
    // Get or create entry
    final entryData = await _entryService.loadEntryForDate(userId, date);
    Entry entry = entryData?.entry ?? await _entryService.getOrCreateEntry(userId, date);
    
    // Apply pending changes
    if (_pendingMoodScore != null) entry = entry.copyWith(moodScore: _pendingMoodScore);
    if (_pendingTags != null) entry = entry.copyWith(tags: _pendingTags);
    if (_pendingDiaryText != null) entry = entry.copyWith(diaryText: _pendingDiaryText);
    
    // Save to local DB first
    await _savePendingChangesToLocal(userId, date, entry);
    
    // Prepare data for RPC
    EntryAffirmations? affirmations = _pendingAffirmations != null
        ? EntryAffirmations(entryId: entry.id, affirmations: _pendingAffirmations!)
        : null;
    EntryPriorities? priorities = _pendingPriorities != null
        ? EntryPriorities(entryId: entry.id, priorities: _pendingPriorities!)
        : null;
    EntryMeals? meals = _pendingMeals != null
        ? EntryMeals(
            entryId: entry.id,
            breakfast: _pendingMeals!.breakfast,
            lunch: _pendingMeals!.lunch,
            dinner: _pendingMeals!.dinner,
            waterCups: _pendingMeals!.waterCups,
          )
        : null;
    EntryGratitude? gratitude = _pendingGratitude != null
        ? EntryGratitude(entryId: entry.id, gratefulItems: _pendingGratitude!)
        : null;
    EntrySelfCare? selfCare = _pendingSelfCare;
    EntryShowerBath? showerBath = _pendingShowerBath != null
        ? EntryShowerBath(
            entryId: entry.id,
            tookShower: _pendingShowerBath!.tookShower,
            note: _pendingShowerBath!.note,
          )
        : null;
    EntryTomorrowNotes? tomorrowNotes = _pendingTomorrowNotes != null
        ? EntryTomorrowNotes(entryId: entry.id, tomorrowNotes: _pendingTomorrowNotes!)
        : null;
    
    // Call RPC (single API call)
    final syncService = SupabaseSyncService();
    final success = await syncService.batchSaveEntry(
      entry: entry,
      affirmations: affirmations,
      priorities: priorities,
      meals: meals,
      gratitude: gratitude,
      selfCare: selfCare,
      showerBath: showerBath,
      tomorrowNotes: tomorrowNotes,
    );
    
    if (success) {
      await _markAllAsSynced(entry.id);
      
      // Invalidate cache
      final fetchService = ref.read(dataFetchServiceProvider);
      fetchService.invalidateEntriesCache(userId, date);
      fetchService.invalidateMonthlyCache(userId, date);
      
      // Track grace system
      await _batchTrackGraceTasks(userId, date);
      
      // Recalculate streak if diary text changed
      if (_pendingDiaryText != null && _pendingDiaryText!.trim().isNotEmpty) {
        final dataFetchService = ref.read(dataFetchServiceProvider);
        UserDataService.recalculateStreak(userId, dataFetchService: dataFetchService);
        dataFetchService.invalidateStreaksCache(userId);
      }
      
      ref.read(syncStatusProvider.notifier).setSaved();
    } else {
      ref.read(syncStatusProvider.notifier).setError('ERRSYS200: Batch save failed');
    }
    
    _clearPendingChanges();
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA260',
      errorMessage: 'Batch save failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'user_id': userId,
        'entry_date': date.toIso8601String(),
        'operation': 'batch_save_rpc',
      },
    );
    ref.read(syncStatusProvider.notifier).setError('ERRDATA260: $e');
  }
}

Future<void> _savePendingChangesToLocal(String userId, DateTime date, Entry entry) async {
  final localService = _entryService.localService;
  await localService.upsertEntry(entry);
  
  if (_pendingAffirmations != null) {
    await localService.upsertAffirmations(
      EntryAffirmations(entryId: entry.id, affirmations: _pendingAffirmations!),
    );
  }
  if (_pendingPriorities != null) {
    await localService.upsertPriorities(
      EntryPriorities(entryId: entry.id, priorities: _pendingPriorities!),
    );
  }
  if (_pendingMeals != null) {
    await localService.upsertMeals(
      EntryMeals(
        entryId: entry.id,
        breakfast: _pendingMeals!.breakfast,
        lunch: _pendingMeals!.lunch,
        dinner: _pendingMeals!.dinner,
        waterCups: _pendingMeals!.waterCups,
      ),
    );
  }
  if (_pendingGratitude != null) {
    await localService.upsertGratitude(
      EntryGratitude(entryId: entry.id, gratefulItems: _pendingGratitude!),
    );
  }
  if (_pendingSelfCare != null) {
    await localService.upsertSelfCare(_pendingSelfCare!);
  }
  if (_pendingShowerBath != null) {
    await localService.upsertShowerBath(
      EntryShowerBath(
        entryId: entry.id,
        tookShower: _pendingShowerBath!.tookShower,
        note: _pendingShowerBath!.note,
      ),
    );
  }
  if (_pendingTomorrowNotes != null) {
    await localService.upsertTomorrowNotes(
      EntryTomorrowNotes(entryId: entry.id, tomorrowNotes: _pendingTomorrowNotes!),
    );
  }
}

Future<void> _markAllAsSynced(String entryId) async {
  await _entryService.localService.markAsSynced(entryId);
}

void forceImmediateSave() {
  _debounceTimer?.cancel();
  if (_currentUserId != null && _currentDate != null) {
    _executeBatchSave();
  }
}
```

**Update debounce timer (line 411):**

```dart
_debounceTimer = Timer(const Duration(milliseconds: 3000), () {
  _executeBatchSave();
});
```

### 2.4 Update AppLifecycleService

**File:** `lib/services/app_lifecycle_service.dart`

**Update `didChangeAppLifecycleState()`:**

```dart
case AppLifecycleState.paused:
case AppLifecycleState.detached:
  // Force immediate save before app closes
  if (_container != null) {
    try {
      final entryNotifier = _container!.read(entryProvider.notifier);
      entryNotifier.forceImmediateSave();
    } catch (e) {
      ErrorLoggingService.logMediumError(
        errorCode: 'ERRSYS022',
        errorMessage: 'Force save on app close failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'lifecycle_state': state.toString(),
          'operation': 'force_save_on_close',
        },
      );
    }
  }
  _startAutoLockTimer();
  break;
```

---

## 3. Edge Cases & Error Handling

### 3.1 Edge Cases Covered

1. **App closes before debounce** → Force save on `paused`/`detached`
2. **Network failure** → Error logged, data in local DB, syncs on reconnect
3. **Partial data** → RPC only updates provided tables
4. **Entry doesn't exist** → Created in local DB first, then synced
5. **Rapid changes** → Debounce resets, only last state saved
6. **Multiple devices** → Last-write-wins (RPC upsert handles)
7. **Database function error** → Logged to `error_logs` automatically
8. **Invalid data** → RPC validates and returns error

### 3.2 Error Logging

**All errors logged with:**
- Error code (unique per type)
- Stack trace
- User context (user_id, entry_id, date)
- Operation context

**Error Codes:**
- `ERRDB001`: Database function error (auto-logged)
- `ERRSYS200`: RPC call exception
- `ERRSYS201`: RPC returned failure
- `ERRDATA260`: Batch save exception
- `ERRSYS022`: Force save on app close failed

---

## 4. Impact on Other Functionality

### 4.1 Features That Continue Working

✅ **Data Centralization (Reading)** - No changes  
✅ **Grace System** - Still triggered after save  
✅ **Streak Calculation** - Still triggered after diary text  
✅ **Cache Invalidation** - Still works  
✅ **Offline Support** - Data saved locally first  
✅ **AI Analysis Queue** - Still triggered  
✅ **Sync Queue** - Still works (syncs entries only)

### 4.2 Features That Need Updates

⚠️ **EntryService Accessibility**
- Make `_localService` accessible (public getter)
- Make `_getOrCreateEntry()` accessible (public method)

---

## 5. Code to Remove (After Implementation)

### 5.1 Unused Sync Methods

**File:** `lib/services/sync/supabase_sync_service.dart`

**Can be removed (replaced by RPC) - KEPT for backward compatibility:**
- `syncAffirmations()` - **KEPT** (marked as legacy, still used by EntryService)
- `syncPriorities()` - **KEPT** (marked as legacy, still used by EntryService)
- `syncMeals()` - **KEPT** (marked as legacy, still used by EntryService)
- `syncGratitude()` - **KEPT** (marked as legacy, still used by EntryService)
- `syncSelfCare()` - **KEPT** (marked as legacy, still used by EntryService)
- `syncShowerBath()` - **KEPT** (marked as legacy, still used by EntryService)
- `syncTomorrowNotes()` - **KEPT** (marked as legacy, still used by EntryService)

**Status:** All legacy methods marked with deprecation comments. They remain for backward compatibility with EntryService direct calls, but new code should use `batchSaveEntry()` RPC.

**Keep (still used):**
- `syncEntry()` - Used by sync queue
- `syncStreak()` - Used by streak system
- `syncHabitsDaily()` - Used by grace system
- All `fetch*FromCloud()` methods - Used for reading

### 5.2 EntryService Method Updates

**File:** `lib/services/entry_service.dart`

**Make Public:**
- `_localService` → Public getter
- `_getOrCreateEntry()` → Public method

**Can simplify (remove Supabase sync, keep local save):**
- `saveAffirmations()`, `savePriorities()`, `saveMeals()`, etc.
- Keep for backward compatibility (only saves locally, RPC handles sync)

---

## 6. Testing Checklist

### 6.1 Functional Tests
- [ ] Save mood only → Verifies in Supabase
- [ ] Save water only → Verifies in Supabase
- [ ] Save multiple fields → All saved in one call
- [ ] Save all fields → All saved correctly
- [ ] Rapid changes → Only last state saved
- [ ] App close before debounce → Data saved immediately
- [ ] Network failure → Data saved locally, syncs later
- [ ] Offline mode → Data saved locally, syncs on reconnect

### 6.2 Error Handling Tests
- [ ] Invalid entry_id → Error logged
- [ ] Database function error → Error logged to error_logs
- [ ] Network timeout → Error logged, retry works
- [ ] Partial data → Only provided fields updated

### 6.3 Integration Tests
- [ ] Grace system still works
- [ ] Streak calculation still works
- [ ] Cache invalidation still works
- [ ] Multi-device sync still works
- [ ] AI analysis queue still triggered

### 6.4 Performance Tests
- [ ] API calls reduced to 1 per batch save
- [ ] Save time < 500ms
- [ ] No UI freezing
- [ ] Memory usage stable

---

## 7. Migration Strategy

### Phase 1: Database Setup (Day 1)
1. Execute SQL to create RPC function
2. Test function manually
3. Verify error logging works

### Phase 2: Code Implementation (Day 2-3)
1. Add `batchSaveEntry()` to `SupabaseSyncService`
2. Update `EntryProvider._executeBatchSave()`
3. Add `forceImmediateSave()` method
4. Update `AppLifecycleService`
5. Make EntryService methods accessible

### Phase 3: Testing (Day 4)
1. Test all edge cases
2. Verify error logging
3. Check API call reduction
4. Test app lifecycle scenarios

### Phase 4: Cleanup (Day 5)
1. Remove unused sync methods (optional)
2. Update documentation
3. Monitor error logs

---

## 8. Rollback Plan

If issues occur:
1. Revert code changes (keep RPC function)
2. RPC function can coexist with old code
3. No data loss (local DB still works)
4. No user impact (fallback to old save method)

---

## 9. Monitoring & Metrics

### Key Metrics
- **API Calls:** Should drop from 80+ to 1 per batch
- **Save Success Rate:** Should be > 99%
- **Error Rate:** Should be < 1%
- **Save Latency:** Should be < 500ms

### Error Log Queries

```sql
-- Check RPC errors
SELECT * FROM error_logs 
WHERE error_code = 'ERRDB001' 
ORDER BY created_at DESC LIMIT 100;

-- Check app errors
SELECT * FROM error_logs 
WHERE error_code IN ('ERRSYS200', 'ERRSYS201', 'ERRDATA260')
ORDER BY created_at DESC LIMIT 100;
```

---

## 10. Success Criteria

✅ **API Calls:** Reduced from 80+ to 1 per batch save  
✅ **Mood/Water:** Logs consistently  
✅ **Data Loss:** Prevented (force save on app close)  
✅ **Error Logging:** Comprehensive (all errors logged)  
✅ **Other Features:** No impact (grace, streak, etc. still work)  
✅ **Performance:** Faster saves, less server load  

---

## 11. Implementation Checklist

### Database
- [ ] Execute RPC function SQL
- [ ] Verify function created
- [ ] Test function manually
- [ ] Verify error logging works

### Code Changes
- [ ] **EntryService:** Add `localService` getter
- [ ] **EntryService:** Add `getOrCreateEntry()` public method
- [ ] **SupabaseSyncService:** Add `batchSaveEntry()` method
- [ ] **EntryProvider:** Update `_executeBatchSave()`
- [ ] **EntryProvider:** Add `_savePendingChangesToLocal()` helper
- [ ] **EntryProvider:** Add `_markAllAsSynced()` helper
- [ ] **EntryProvider:** Add `forceImmediateSave()` method
- [ ] **EntryProvider:** Update debounce timer to 3 seconds
- [ ] **AppLifecycleService:** Update for force save

### Testing
- [ ] Test mood only save
- [ ] Test water only save
- [ ] Test multiple fields save
- [ ] Test app close scenario
- [ ] Test network failure
- [ ] Test error logging
- [ ] Verify API call reduction

### Cleanup
- [x] Remove unused sync methods (optional) - **KEPT for backward compatibility** (marked as legacy in code)
- [x] Update documentation - **Added deprecation comments to legacy sync methods**
- [ ] Monitor error logs - **Ongoing task**

---

**End of Implementation Plan**

**Status Update:** RPC function `batch_save_entry` SQL query executed successfully in Supabase (2026-01-17).

**Cleanup Completed (2026-01-17):**
- ✅ Added deprecation comments to legacy sync methods (`syncAffirmations`, `syncPriorities`, `syncMeals`, `syncGratitude`, `syncSelfCare`, `syncShowerBath`, `syncTomorrowNotes`)
- ✅ Legacy methods kept for backward compatibility with EntryService direct calls
- ✅ All methods documented to indicate new code should use `batchSaveEntry()` RPC instead
- ✅ Report updated to reflect cleanup status