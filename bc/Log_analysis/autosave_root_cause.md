# Autosave Root Cause Analysis

## Problem

**900 calls/3min when writing journal** - All related to autosave triggering multiple Supabase calls.

---

## Root Causes Identified

### 1. **ALL Save Methods Share ONE Debounce Timer** ⚠️ CRITICAL

**Problem:**
- `updateDiaryText()` uses `_debounceTimer`
- `updateAffirmations()` uses SAME `_debounceTimer` → **CANCELS previous timer**
- `updatePriorities()` uses SAME `_debounceTimer` → **CANCELS previous timer**
- `updateMeals()` uses SAME `_debounceTimer` → **CANCELS previous timer**

**Result:**
- User types diary → timer starts (600ms)
- User fills affirmation → timer CANCELED, new timer starts
- User fills priority → timer CANCELED, new timer starts
- **Each cancellation triggers the previous save!**
- **Multiple saves happening simultaneously**

### 2. **Each Save Operation Makes 5-6 Supabase Calls** ⚠️ CRITICAL

**Flow for `saveDiaryText()`:**
1. `_getOrCreateEntry()` → **QUERY Supabase** (check if entry exists)
2. `syncEntry()` → **UPSERT entries table**
3. `trackTaskCompletion()` → **PATCH habits_daily**
4. `recalculateStreak()` → **QUERY streaks** + **PATCH streaks**
5. Cache invalidations → **Multiple refetches**

**Flow for `saveAffirmations()`:**
1. `_getOrCreateEntry()` → **QUERY Supabase** (AGAIN!)
2. `syncEntry()` → **UPSERT entries table** (AGAIN!)
3. `syncAffirmations()` → **UPSERT entry_affirmations**
4. `trackTaskCompletion()` → **PATCH habits_daily** (AGAIN!)
5. Cache invalidations → **Multiple refetches**

**Result:** Each field change = 5-6 Supabase calls

### 3. **Duplicate Save Logic in Screen** ⚠️ HIGH

**Problem:**
- `new_diary_screen.dart` has its own save methods (`_onDiaryTextChanged()`, `_onAffirmationsChanged()`, etc.)
- These call `EntryService` directly **WITHOUT debouncing**
- Screen saves + Provider saves = **DOUBLE SAVES**

### 4. **Entry Creation Queried Every Time** ⚠️ HIGH

**Problem:**
- `_getOrCreateEntry()` queries Supabase EVERY TIME
- Even if entry was just created 1 second ago
- No caching of entry existence

**Example:**
- Save diary text → `_getOrCreateEntry()` → QUERY
- Save affirmations → `_getOrCreateEntry()` → QUERY (same entry!)
- Save priorities → `_getOrCreateEntry()` → QUERY (same entry!)

### 5. **Multiple Simultaneous Saves** ⚠️ MEDIUM

**Problem:**
- User types diary text → save triggered
- User fills affirmation → save triggered (while diary save still running)
- User fills priority → save triggered (while both still running)
- **3 saves happening simultaneously = 15-18 Supabase calls**

---

## Evidence from Code

### EntryProvider (lib/providers/entry_provider.dart):
```dart
Timer? _debounceTimer; // SINGLE timer for ALL fields!

void updateDiaryText(...) {
  _debounceTimer?.cancel(); // Cancels if other field changed
  _debounceTimer = Timer(600ms, () => saveDiaryText());
}

void updateAffirmations(...) {
  _debounceTimer?.cancel(); // Cancels diary timer!
  _debounceTimer = Timer(600ms, () => saveAffirmations());
}
```

### EntryService (lib/services/entry_service.dart):
```dart
Future<void> saveDiaryText(...) async {
  final entry = await _getOrCreateEntry(...); // QUERY every time
  await _localService.upsertEntry(...);
  _syncService.syncEntry(...); // UPSERT
  // Then triggers trackTaskCompletion, recalculateStreak, etc.
}

Future<void> saveAffirmations(...) async {
  final entry = await _getOrCreateEntry(...); // QUERY AGAIN!
  await _localService.upsertAffirmations(...);
  await _syncService.syncEntry(entry); // UPSERT entry AGAIN!
  _syncService.syncAffirmations(...); // UPSERT affirmations
}
```

### Screen (lib/screens/new_diary_screen.dart):
```dart
void _onDiaryTextChanged() async {
  await entryService.saveDiaryText(...); // NO DEBOUNCING!
}

void _onAffirmationChanged() async {
  await entryService.saveAffirmations(...); // NO DEBOUNCING!
}
```

---

## Impact Calculation

**Scenario: User writes journal entry (types text, fills 3 affirmations, sets 2 priorities)**

### Current Flow:
1. Type diary text → `updateDiaryText()` → debounce → `saveDiaryText()` → 5 calls
2. Fill affirmation 1 → `updateAffirmations()` → **CANCELS diary timer** → debounce → `saveAffirmations()` → 5 calls
3. Fill affirmation 2 → `updateAffirmations()` → **CANCELS previous timer** → debounce → `saveAffirmations()` → 5 calls
4. Fill affirmation 3 → `updateAffirmations()` → **CANCELS previous timer** → debounce → `saveAffirmations()` → 5 calls
5. Set priority 1 → `updatePriorities()` → **CANCELS previous timer** → debounce → `savePriorities()` → 5 calls
6. Set priority 2 → `updatePriorities()` → **CANCELS previous timer** → debounce → `savePriorities()` → 5 calls

**Total: 30 Supabase calls for simple journal entry!**

---

## Solutions Required

### 1. **Single Unified Debounce Timer** (Priority 1)
- One timer for ALL field changes
- Batch all pending changes together
- Save everything in one operation

### 2. **Cache Entry Creation** (Priority 1)
- Cache entry ID after first creation
- Don't query Supabase every time
- Reuse cached entry for subsequent saves

### 3. **Batch Save Operation** (Priority 1)
- Collect all field changes
- Save all at once in single transaction
- One `_getOrCreateEntry()` call
- One batch sync operation

### 4. **Remove Duplicate Save Logic** (Priority 2)
- Remove save methods from screen
- Use only provider methods
- Screen should only call provider

### 5. **Debounce Grace System & Streak** (Priority 2)
- Don't trigger on every save
- Batch grace system updates
- Batch streak recalculations

---

## Expected Impact After Fixes

- **Current:** 30 calls for simple journal entry
- **Target:** 3-5 calls for complete journal entry
- **Reduction:** 85-90%

