# Enhanced Option 1 - Streak Feature Implementation Plan

## 📋 **Current State Analysis**

### **Supabase Tables Status** ✅

#### **1. `streaks` Table** - ✅ EXISTS & COMPLETE
- `user_id` (uuid, PK)
- `current` (integer, default 0)
- `longest` (integer, default 0)
- `last_entry_date` (date, nullable)
- `freeze_credits` (integer, default 0) - **Repurpose as grace days (0-5)**
- `updated_at` (timestamptz, default now())
- `grace_pieces_total` (numeric, default 0.0) - ✅ Already exists

**Status:** ✅ **KEEP** - All columns needed for Enhanced Option 1 are present

#### **2. `habits_daily` Table** - ✅ EXISTS & COMPLETE
- `id` (uuid, PK)
- `user_id` (uuid, FK)
- `date` (date)
- `wrote_entry` (boolean, default false)
- `filled_affirmations` (boolean, default false)
- `filled_gratitude` (boolean, default false)
- `self_care_completed_count` (smallint, default 0)
- `grace_pieces_earned` (numeric, default 0.0) - ✅ Already exists

**Status:** ✅ **KEEP** - All columns needed for Enhanced Option 1 are present

#### **3. `streak_freeze_usage` Table** - ❌ NOT NEEDED
- Contains: `id`, `user_id`, `used_at`, `reason`, `streak_maintained`, `grace_period_days`, `created_at`, `grace_day_used`

**Status:** ❌ **REMOVE/DEPRECATE** - Not needed for Enhanced Option 1 (we track grace days in `streaks.freeze_credits` directly)

---

### **Local SQLite Status** ❌

#### **Current Local Tables:**
- ✅ `entries` - EXISTS
- ✅ `entry_affirmations` - EXISTS
- ✅ `entry_priorities` - EXISTS
- ✅ `entry_meals` - EXISTS
- ✅ `entry_gratitude` - EXISTS
- ✅ `entry_self_care` - EXISTS
- ✅ `entry_shower_bath` - EXISTS
- ✅ `entry_tomorrow_notes` - EXISTS
- ✅ `sync_queue` - EXISTS
- ❌ `streaks` - **MISSING** (needs to be added)
- ❌ `habits_daily` - **MISSING** (needs to be added)

**Status:** ❌ **NEEDS UPDATE** - Add local tables for offline support

---

### **Code Status** ⚠️

#### **Models:**
- ✅ `Streak` model exists in `lib/models/analytics_models.dart`
  - ❌ **MISSING**: `gracePiecesTotal` field
  - ✅ Has: `userId`, `current`, `longest`, `lastEntryDate`, `freezeCredits`, `updatedAt`
  
- ✅ `HabitsDaily` model exists in `lib/models/analytics_models.dart`
  - ✅ **COMPLETE**: All fields present including `gracePiecesEarned`

- ✅ `StreakSummary` model exists in `lib/models/home_summary_models.dart`
  - ✅ **COMPLETE**: Has `gracePiecesTotal` field

#### **Services (All Disconnected):**
- ❌ `UserDataService` - All streak methods return defaults/no-op
- ❌ `GraceSystemService` - All methods return defaults/no-op
- ❌ `DataFetchService` - `fetchStreaks()`, `fetchHabitsDaily()` return defaults
- ❌ `HomeSummaryService` - `_fetchStreak()` returns null
- ❌ `AnalyticsService` - All habits queries return empty lists

#### **Providers:**
- ⚠️ `entry_provider.dart` - Has commented out `recalculateStreak()` call
- ⚠️ `grace_system_provider.dart` - Has refresh guard but disconnected

---

## 🎯 **Implementation Plan for Enhanced Option 1**

### **Phase 1: Database Changes**

#### **1.1 Supabase - No Changes Needed** ✅
- ✅ `streaks` table already has all required columns
- ✅ `habits_daily` table already has all required columns
- ⚠️ **Optional**: Drop `streak_freeze_usage` table (not needed, but can keep for historical data)

#### **1.2 Local SQLite - Add Tables** ❌

**File:** `lib/services/database/database_manager.dart`

**Add to `_createTables()` method:**

```dart
// Streaks table (local cache)
await db.execute('''
  CREATE TABLE streaks (
    user_id TEXT PRIMARY KEY,
    current INTEGER DEFAULT 0,
    longest INTEGER DEFAULT 0,
    last_entry_date TEXT,
    freeze_credits INTEGER DEFAULT 0,
    grace_pieces_total REAL DEFAULT 0.0,
    updated_at TEXT NOT NULL,
    is_synced INTEGER DEFAULT 0,
    last_sync_at TEXT
  )
''');

// Habits daily table (local cache)
await db.execute('''
  CREATE TABLE habits_daily (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    date TEXT NOT NULL,
    wrote_entry INTEGER DEFAULT 0,
    filled_affirmations INTEGER DEFAULT 0,
    filled_gratitude INTEGER DEFAULT 0,
    self_care_completed_count INTEGER DEFAULT 0,
    grace_pieces_earned REAL DEFAULT 0.0,
    is_synced INTEGER DEFAULT 0,
    last_sync_at TEXT,
    UNIQUE(user_id, date)
  )
''');

// Indexes for performance
await db.execute('CREATE INDEX idx_streaks_user ON streaks(user_id)');
await db.execute('CREATE INDEX idx_habits_user_date ON habits_daily(user_id, date)');
```

**Update `_onUpgrade()` method:**
- Add migration logic to create these tables if they don't exist

**Update `clearAllData()` method:**
- Add deletion of `habits_daily` and `streaks` tables

---

### **Phase 2: Model Updates**

#### **2.1 Update `Streak` Model** ❌

**File:** `lib/models/analytics_models.dart`

**Add `gracePiecesTotal` field:**

```dart
class Streak {
  final String userId;
  final int current;
  final int longest;
  final DateTime? lastEntryDate;
  final int freezeCredits;
  final double gracePiecesTotal; // ✅ ADD THIS
  final DateTime updatedAt;

  Streak({
    required this.userId,
    this.current = 0,
    this.longest = 0,
    this.lastEntryDate,
    this.freezeCredits = 0,
    this.gracePiecesTotal = 0.0, // ✅ ADD THIS
    required this.updatedAt,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      userId: json['user_id'] as String,
      current: json['current'] as int? ?? 0,
      longest: json['longest'] as int? ?? 0,
      lastEntryDate: json['last_entry_date'] != null
          ? DateTime.parse(json['last_entry_date'] as String)
          : null,
      freezeCredits: json['freeze_credits'] as int? ?? 0,
      gracePiecesTotal: ((json['grace_pieces_total'] ?? 0.0) as num).toDouble(), // ✅ ADD THIS
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'current': current,
      'longest': longest,
      'last_entry_date': lastEntryDate?.toIso8601String().split('T')[0],
      'freeze_credits': freezeCredits,
      'grace_pieces_total': gracePiecesTotal, // ✅ ADD THIS
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
```

---

### **Phase 3: Service Reconnection (Local-First Approach)**

#### **3.1 Create `StreakService` (New)** ❌

**File:** `lib/services/streak_service.dart` (NEW)

**Purpose:** Centralized streak management with local-first approach

**Key Methods:**
- `getStreak(userId)` - Fetch from local cache, sync if stale
- `updateStreak(userId, updates)` - Update locally, sync to cloud (debounced)
- `calculateStreak(userId, entryDate)` - Calculate streak locally
- `updateGracePieces(userId, pieces)` - Increment pieces locally, sync
- `useGraceDay(userId)` - Decrement freeze_credits, sync

**Implementation Strategy:**
- Read from local SQLite first (fast)
- Sync to Supabase in background (debounced, 2s)
- On startup: Fetch from Supabase once, cache locally
- On write: Update local first, queue sync

---

#### **3.2 Update `GraceSystemService`** ❌

**File:** `lib/services/grace_system_service.dart`

**Reconnect with local-first approach:**

1. **`getGraceStatus()`** - ✅ RECONNECT
   - Read from local `streaks` table
   - Read today's `habits_daily` from local
   - Calculate pieces locally (no DB calls)
   - Return status

2. **`trackTaskCompletion()`** - ✅ RECONNECT
   - Update local `habits_daily` (today's record)
   - Calculate pieces locally (0.5 per task, max 2.0/day)
   - Update local `streaks.grace_pieces_total` incrementally
   - Update local `streaks.freeze_credits` if pieces >= 10
   - Queue sync to Supabase (debounced, 2s)

3. **`useGraceDay()`** - ✅ RECONNECT
   - Check local `streaks.freeze_credits` > 0
   - Decrement locally
   - Queue sync to Supabase (debounced, 2s)

**Key Changes:**
- Remove all `fetchAllHabitsDaily()` calls (expensive)
- Use incremental updates instead of recalculation
- Local-first: Update local SQLite, sync to Supabase in background

---

#### **3.3 Update `UserDataService`** ❌

**File:** `lib/services/user_data_service.dart`

**Reconnect with local-first approach:**

1. **`calculateStreakWithGrace()`** - ✅ RECONNECT
   - Read local `streaks` table
   - Check `last_entry_date` vs today
   - If consecutive: increment `current` locally
   - If gap: check `freeze_credits`, use if available
   - Update `longest` if needed
   - Queue sync to Supabase (debounced, 2s)

2. **`recalculateStreak()`** - ✅ RECONNECT (but simplified)
   - Only recalculate if `last_entry_date` is > 1 day old
   - Read recent entries from local SQLite (last 7 days)
   - Calculate streak locally
   - Update local `streaks` table
   - Queue sync to Supabase (debounced, 2s)

3. **`_persistStreak()`** - ✅ RECONNECT
   - Update local `streaks` table
   - Queue sync to Supabase (debounced, 2s)

**Key Changes:**
- Remove expensive `fetchAllHabitsDaily()` calls
- Use local SQLite for reads
- Batch sync to Supabase

---

#### **3.4 Update `DataFetchService`** ❌

**File:** `lib/services/data_fetch_service.dart`

**Reconnect methods:**

1. **`fetchStreaks()`** - ✅ RECONNECT
   - Read from local SQLite first (fast)
   - If stale or missing: fetch from Supabase, cache locally
   - Return cached data

2. **`fetchHabitsDaily()`** - ✅ RECONNECT
   - Read from local SQLite (date range)
   - If missing: fetch from Supabase, cache locally
   - Return cached data

3. **`fetchAllHabitsDaily()`** - ❌ **REMOVE/DEPRECATE**
   - This method is expensive (fetches 365+ records)
   - Not needed for Enhanced Option 1 (we use incremental updates)

**Key Changes:**
- Add local SQLite reads before Supabase
- Cache results in local SQLite
- Remove expensive `fetchAllHabitsDaily()` method

---

#### **3.5 Update `HomeSummaryService`** ❌

**File:** `lib/services/home_summary_service.dart`

**Reconnect `_fetchStreak()`:**
- Use `DataFetchService.fetchStreaks()` (now reconnected)
- Return `StreakSummary` with all fields

**Reconnect `_fetchTodayProgress()`:**
- Read today's `habits_daily` from local SQLite
- Calculate pieces locally
- Return `TodayProgressSummary`

---

#### **3.6 Update `AnalyticsService`** ⚠️

**File:** `lib/services/analytics_service.dart`

**Status:** Keep disconnected for now (analytics can work without habits)
- Or reconnect to read from local SQLite only (no Supabase calls)

---

### **Phase 4: Provider Updates**

#### **4.1 Update `entry_provider.dart`** ❌

**File:** `lib/providers/entry_provider.dart`

**Reconnect streak tracking:**

1. **In `_executeBatchSave()`:**
   - After saving diary text, call `UserDataService.calculateStreakWithGrace()`
   - Track task completion for pieces (if affirmations/gratitude/self-care changed)

2. **Remove commented code:**
   - Uncomment `recalculateStreak()` call
   - Update to use new local-first approach

**Key Changes:**
- Reconnect streak calculation on entry save
- Track task completion for grace pieces
- Use local-first approach (no immediate DB calls)

---

#### **4.2 Update `grace_system_provider.dart`** ❌

**File:** `lib/providers/grace_system_provider.dart`

**Reconnect grace system:**
- Uncomment `GraceSystemService` calls
- Update to use local-first approach
- Remove refresh guard (not needed with local-first)

---

### **Phase 5: Sync Service Updates**

#### **5.1 Update `SupabaseSyncService`** ❌

**File:** `lib/services/supabase_sync_service.dart` (if exists)

**Add sync methods for streaks and habits:**

1. **`syncStreak(userId)`** - Sync local `streaks` to Supabase
2. **`syncHabitsDaily(userId, date)`** - Sync local `habits_daily` to Supabase
3. **`syncAllStreaks(userId)`** - Sync all pending streak changes
4. **`syncAllHabits(userId)`** - Sync all pending habits changes

**Implementation:**
- Read from local SQLite
- Upsert to Supabase
- Mark as synced in local SQLite

---

### **Phase 6: Code Cleanup**

#### **6.1 Remove Unused Code** ❌

**Files to clean:**
- Remove all commented-out "DISCONNECTED CODE" blocks
- Remove unused imports
- Remove dead code paths

**Files affected:**
- `lib/services/user_data_service.dart`
- `lib/services/grace_system_service.dart`
- `lib/services/data_fetch_service.dart`
- `lib/services/home_summary_service.dart`
- `lib/providers/entry_provider.dart`
- `lib/providers/grace_system_provider.dart`

---

#### **6.2 Remove Unused Table** ⚠️

**Table:** `streak_freeze_usage`

**Options:**
1. **Keep for historical data** (recommended)
2. **Drop table** (if no historical data needed)

**If dropping:**
```sql
DROP TABLE IF EXISTS public.streak_freeze_usage CASCADE;
```

**Note:** Check for foreign key constraints before dropping

---

## 📊 **DB Calls Optimization Summary**

### **Before (Disconnected):**
- 0 calls (feature disabled)

### **After (Enhanced Option 1):**

#### **On Startup:**
- 1 call: Fetch `streaks` table (once, cached locally)
- 1 call: Fetch today's `habits_daily` (optional, can calculate from entries)
- **Total: 1-2 calls**

#### **On Entry Save:**
- 0 calls immediately (local-first)
- 1 call after 2s debounce: Batch sync `streaks` + `habits_daily`
- **Total: 1 call (batched, debounced)**

#### **On Task Completion:**
- 0 calls immediately (local-first)
- 1 call after 2s debounce: Batch sync `habits_daily` + `streaks` (if pieces converted)
- **Total: 1 call (batched, debounced)**

#### **On Grace Day Use:**
- 0 calls immediately (local-first)
- 1 call after 2s debounce: Sync `streaks` (decrement freeze_credits)
- **Total: 1 call (debounced)**

---

## ✅ **What to Keep**

1. ✅ **Supabase Tables:**
   - `streaks` table (all columns)
   - `habits_daily` table (all columns)

2. ✅ **Models:**
   - `Streak` model (update to add `gracePiecesTotal`)
   - `HabitsDaily` model (complete)
   - `StreakSummary` model (complete)

3. ✅ **Services Structure:**
   - `GraceSystemService` (reconnect with local-first)
   - `UserDataService` (reconnect with local-first)
   - `DataFetchService` (reconnect methods)

---

## ❌ **What to Change/Modify**

1. ❌ **Add Local SQLite Tables:**
   - `streaks` table
   - `habits_daily` table

2. ❌ **Update Models:**
   - Add `gracePiecesTotal` to `Streak` model

3. ❌ **Reconnect Services:**
   - All disconnected methods in `GraceSystemService`
   - All disconnected methods in `UserDataService`
   - `fetchStreaks()` and `fetchHabitsDaily()` in `DataFetchService`
   - `_fetchStreak()` and `_fetchTodayProgress()` in `HomeSummaryService`

4. ❌ **Update Providers:**
   - Reconnect streak tracking in `entry_provider.dart`
   - Reconnect grace system in `grace_system_provider.dart`

5. ❌ **Add Sync Service:**
   - Add sync methods for streaks and habits

---

## 🗑️ **What to Remove**

1. 🗑️ **Code:**
   - All commented-out "DISCONNECTED CODE" blocks
   - Unused imports
   - Dead code paths
   - `fetchAllHabitsDaily()` method (expensive, not needed)

2. 🗑️ **Table (Optional):**
   - `streak_freeze_usage` table (not needed for Enhanced Option 1)
   - **Note:** Keep for historical data if needed, or drop if not

---

## 🔧 **Supabase Changes Required**

### **✅ NO CHANGES NEEDED** 

**Reason:**
- ✅ `streaks` table already has all required columns (`grace_pieces_total` exists)
- ✅ `habits_daily` table already has all required columns (`grace_pieces_earned` exists)
- ✅ All indexes and constraints are in place

### **⚠️ Optional Cleanup:**

**If you want to remove unused table:**
```sql
-- Check for dependencies first
SELECT 
  table_name, 
  constraint_name, 
  constraint_type
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
  AND table_name = 'streak_freeze_usage';

-- If no dependencies, drop table
DROP TABLE IF EXISTS public.streak_freeze_usage CASCADE;
```

**Recommendation:** Keep `streak_freeze_usage` table for now (historical data), focus on code implementation first.

---

## 📝 **Implementation Checklist**

### **Phase 1: Database** 
- [ ] Add `streaks` table to local SQLite
- [ ] Add `habits_daily` table to local SQLite
- [ ] Add indexes for performance
- [ ] Update `_onUpgrade()` for migrations
- [ ] Update `clearAllData()` method

### **Phase 2: Models**
- [ ] Add `gracePiecesTotal` to `Streak` model
- [ ] Update `fromJson()` method
- [ ] Update `toJson()` method

### **Phase 3: Services**
- [ ] Create `StreakService` (new, optional)
- [ ] Reconnect `GraceSystemService.getGraceStatus()`
- [ ] Reconnect `GraceSystemService.trackTaskCompletion()`
- [ ] Reconnect `GraceSystemService.useGraceDay()`
- [ ] Reconnect `UserDataService.calculateStreakWithGrace()`
- [ ] Reconnect `UserDataService.recalculateStreak()`
- [ ] Reconnect `UserDataService._persistStreak()`
- [ ] Reconnect `DataFetchService.fetchStreaks()`
- [ ] Reconnect `DataFetchService.fetchHabitsDaily()`
- [ ] Remove `DataFetchService.fetchAllHabitsDaily()`
- [ ] Reconnect `HomeSummaryService._fetchStreak()`
- [ ] Reconnect `HomeSummaryService._fetchTodayProgress()`

### **Phase 4: Providers**
- [ ] Reconnect streak tracking in `entry_provider.dart`
- [ ] Reconnect grace system in `grace_system_provider.dart`

### **Phase 5: Sync**
- [ ] Add `syncStreak()` method
- [ ] Add `syncHabitsDaily()` method
- [ ] Add batch sync methods

### **Phase 6: Cleanup**
- [ ] Remove all commented "DISCONNECTED CODE" blocks
- [ ] Remove unused imports
- [ ] Remove dead code paths
- [ ] Test all functionality

---

## 🎯 **Key Principles for Implementation**

1. **Local-First:** Always update local SQLite first, sync to Supabase in background
2. **Incremental Updates:** Add today's pieces to total, don't recalculate from all records
3. **Debounced Sync:** Batch all sync operations with 2s debounce
4. **Smart Caching:** Cache in local SQLite, fetch from Supabase only when stale
5. **Minimal DB Calls:** Target 1-2 calls on startup, 1 call per batch on write

---

## 📌 **Notes**

- **No Supabase migration needed** - All tables and columns already exist
- **Local SQLite migration needed** - Add new tables for offline support
- **Code reconnection needed** - All services need to be reconnected with local-first approach
- **Optional cleanup** - Remove `streak_freeze_usage` table if not needed for historical data
