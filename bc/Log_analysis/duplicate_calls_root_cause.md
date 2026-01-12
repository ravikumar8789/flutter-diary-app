# Root Cause: Duplicate Supabase Calls

## Problem

User added:
- Some text in entry
- One affirmation  
- One meal

**Expected:** 3-4 Supabase calls (1 entry + 1 affirmation + 1 meal, maybe 1 extra for entry sync)

**Actual:** 20+ calls to entries, 20+ calls to meals, 10+ calls to affirmations

---

## Root Cause Analysis

### Issue #1: **Each Save Method Syncs Entry Separately** ⚠️ CRITICAL

**Problem:**
Every save method (`saveMeals`, `saveAffirmations`, `savePriorities`, etc.) calls `syncEntry()` FIRST to ensure entry exists:

```dart
// In saveMeals():
final entrySynced = await _syncService.syncEntry(entry);  // ← POST to entries
_syncService.syncMeals(entryMeals);                      // ← POST to entry_meals

// In saveAffirmations():
final entrySynced = await _syncService.syncEntry(entry);  // ← POST to entries (DUPLICATE!)
_syncService.syncAffirmations(entryAffirmations);          // ← POST to entry_affirmations

// In saveDiaryText():
_syncService.syncEntry(updatedEntry);                     // ← POST to entries (DUPLICATE!)
```

**Result:**
- If you save diary text + affirmations + meals:
  - `saveDiaryText()` → 1 POST to entries
  - `saveAffirmations()` → 1 POST to entries (DUPLICATE!)
  - `saveMeals()` → 1 POST to entries (DUPLICATE!)
  - Total: **3 POST calls to entries table** for same entry!

---

### Issue #2: **Parallel Execution Causes Race Conditions** ⚠️ HIGH

**Problem:**
Batch save executes all saves in parallel:

```dart
await Future.wait([
  saveDiaryText(...),      // ← Calls syncEntry()
  saveAffirmations(...),   // ← Calls syncEntry() (parallel!)
  saveMeals(...),          // ← Calls syncEntry() (parallel!)
]);
```

All three `syncEntry()` calls happen **simultaneously**, creating:
- 3 identical POST requests to entries table
- Race condition: which one completes first?
- All three succeed, creating duplicate/overwriting entries

---

### Issue #3: **No Deduplication for Entry Sync** ⚠️ HIGH

**Problem:**
Each save method independently syncs the entry, even though:
- Entry was already synced by previous save
- Entry hasn't changed
- All saves are for the same entry

**Expected Behavior:**
- Sync entry ONCE before all field saves
- Then sync each field separately
- Total: 1 entry sync + N field syncs

**Current Behavior:**
- Each save syncs entry independently
- Total: N entry syncs + N field syncs

---

## Evidence from Log

Looking at timestamps (nanoseconds):
- `1767888785220000` - POST entry_meals
- `1767888785047000` - POST entries
- `1767888785024000` - POST entry_meals (duplicate!)
- `1767888784889000` - POST entries (duplicate!)

**Pattern:** Multiple calls to same tables within milliseconds, indicating parallel execution without coordination.

---

## Solution

### Fix: **Sync Entry Once Before All Field Saves**

**Current Flow:**
```
Batch Save Executes
  ↓
Parallel:
  ├─ saveDiaryText() → syncEntry() + syncDiaryText()
  ├─ saveAffirmations() → syncEntry() + syncAffirmations()
  └─ saveMeals() → syncEntry() + syncMeals()
  
Result: 3 entry syncs + 3 field syncs = 6 calls
```

**Fixed Flow:**
```
Batch Save Executes
  ↓
1. Sync entry ONCE (await)
  ↓
2. Parallel field syncs:
  ├─ syncAffirmations()
  ├─ syncMeals()
  └─ syncDiaryText() (if needed)
  
Result: 1 entry sync + 3 field syncs = 4 calls
```

---

## Implementation Plan

1. **Modify `_executeBatchSave()` to sync entry first**
   - Get entry once
   - Sync entry once (await)
   - Then sync all fields in parallel

2. **Remove `syncEntry()` calls from individual save methods**
   - Only `saveDiaryText()` should sync entry (it updates entry itself)
   - Other methods assume entry already exists

3. **Add entry sync check**
   - Before field syncs, ensure entry is synced
   - If not, sync it once

---

## Expected Impact

**Before Fix:**
- 3 fields = 3 entry syncs + 3 field syncs = **6 calls**

**After Fix:**
- 3 fields = 1 entry sync + 3 field syncs = **4 calls**

**Reduction: 33% fewer calls**

For user's case (text + 1 affirmation + 1 meal):
- Before: 3 entry syncs + 3 field syncs = 6 calls
- After: 1 entry sync + 3 field syncs = 4 calls
- **Reduction: 2 fewer calls (33%)**

