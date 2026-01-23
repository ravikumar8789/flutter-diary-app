# Streak Feature Optimization - Final Approach (Option C)

## 🎯 Objective
Remove historical `habits_daily` table from Supabase. Store only today's task completion data in `streaks` table. Use local `habits_daily` as daily scratchpad for calculations. This approach saves DB space, reduces API calls, and simplifies the architecture.

---

## 📋 Core Design

### **Supabase `streaks` Table (Single Source of Truth)**
Stores all streak data including today's task completion:
- `current` (integer) - Current streak count
- `longest` (integer) - Longest streak achieved
- `last_entry_date` (date) - Last date with activity
- `freeze_credits` (integer) - Available grace days
- `grace_pieces_total` (numeric) - Total grace pieces earned
- `today_date` (date) - **NEW** - Date for today's task data
- `today_diary` (boolean) - **NEW** - Diary completed today
- `today_affirmations` (boolean) - **NEW** - Affirmations completed today
- `today_gratitude` (boolean) - **NEW** - Gratitude completed today
- `today_self_care_count` (integer) - **NEW** - Self-care tasks completed today
- `today_grace_pieces` (numeric) - **NEW** - Grace pieces earned today
- `updated_at` (timestamptz) - Last update timestamp

### **Local `habits_daily` Table (Daily Scratchpad)**
Used only for daily calculations, cleared on new day:
- Same structure as before
- Only stores today's data
- Cleared when `today_date` changes
- Populated from `streaks.today_*` fields on app startup

### **Local `streaks` Table (Cache)**
Caches Supabase streaks data:
- Same structure as Supabase
- Synced on app startup
- Updated locally, pushed via RPC

---

## 🔧 Database Changes

### 1. Supabase Database Changes

#### 1.1 Add New Columns to `streaks` Table

```sql
-- Add today's task completion fields to streaks table
ALTER TABLE public.streaks
ADD COLUMN IF NOT EXISTS today_date DATE,
ADD COLUMN IF NOT EXISTS today_diary BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS today_affirmations BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS today_gratitude BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS today_self_care_count SMALLINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS today_grace_pieces NUMERIC DEFAULT 0.0;

-- Add index for today_date (for quick lookups)
CREATE INDEX IF NOT EXISTS idx_streaks_today_date ON public.streaks(today_date);
```

#### 1.2 Remove `habits_daily` Table (Optional - Can Keep for Migration Period)

**Option A: Drop Table (Recommended after migration)**
```sql
-- Drop habits_daily table (after ensuring all data is migrated)
DROP TABLE IF EXISTS public.habits_daily CASCADE;
```

**Option B: Keep Table but Deprecate (Safer for migration)**
- Keep table structure
- Stop writing to it
- Can drop later after confirming new system works

**Recommendation:** Keep table initially, stop writing to it, drop after migration period.

#### 1.3 Update RPC Function `batch_update_streak_data`

```sql
-- Update RPC to handle new today_* fields
CREATE OR REPLACE FUNCTION public.batch_update_streak_data(
  p_user_id UUID,
  p_streak_data JSONB,
  p_habits_data JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- Update streaks table with all data including today_* fields
  INSERT INTO public.streaks (
    user_id,
    current,
    longest,
    last_entry_date,
    freeze_credits,
    grace_pieces_total,
    today_date,
    today_diary,
    today_affirmations,
    today_gratitude,
    today_self_care_count,
    today_grace_pieces,
    updated_at
  )
  VALUES (
    p_user_id,
    (p_streak_data->>'current')::INTEGER,
    (p_streak_data->>'longest')::INTEGER,
    (p_streak_data->>'last_entry_date')::DATE,
    (p_streak_data->>'freeze_credits')::INTEGER,
    (p_streak_data->>'grace_pieces_total')::NUMERIC,
    (p_streak_data->>'today_date')::DATE,
    (p_streak_data->>'today_diary')::BOOLEAN,
    (p_streak_data->>'today_affirmations')::BOOLEAN,
    (p_streak_data->>'today_gratitude')::BOOLEAN,
    (p_streak_data->>'today_self_care_count')::SMALLINT,
    (p_streak_data->>'today_grace_pieces')::NUMERIC,
    NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    current = EXCLUDED.current,
    longest = EXCLUDED.longest,
    last_entry_date = EXCLUDED.last_entry_date,
    freeze_credits = EXCLUDED.freeze_credits,
    grace_pieces_total = EXCLUDED.grace_pieces_total,
    today_date = EXCLUDED.today_date,
    today_diary = EXCLUDED.today_diary,
    today_affirmations = EXCLUDED.today_affirmations,
    today_gratitude = EXCLUDED.today_gratitude,
    today_self_care_count = EXCLUDED.today_self_care_count,
    today_grace_pieces = EXCLUDED.today_grace_pieces,
    updated_at = EXCLUDED.updated_at;

  -- Note: p_habits_data is now ignored (not needed)
  -- All data is in p_streak_data

  RETURN jsonb_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
```

---

### 2. Local SQLite Database Changes

#### 2.1 Update `streaks` Table Schema

**File:** `lib/services/database/database_manager.dart`

```dart
// Update streaks table creation
await db.execute('''
  CREATE TABLE streaks (
    user_id TEXT PRIMARY KEY,
    current INTEGER DEFAULT 0,
    longest INTEGER DEFAULT 0,
    last_entry_date TEXT,
    freeze_credits INTEGER DEFAULT 0,
    grace_pieces_total REAL DEFAULT 0.0,
    today_date TEXT,                    -- NEW
    today_diary INTEGER DEFAULT 0,      -- NEW (boolean as int)
    today_affirmations INTEGER DEFAULT 0, -- NEW
    today_gratitude INTEGER DEFAULT 0,  -- NEW
    today_self_care_count INTEGER DEFAULT 0, -- NEW
    today_grace_pieces REAL DEFAULT 0.0, -- NEW
    updated_at TEXT NOT NULL,
    is_synced INTEGER DEFAULT 0,
    last_sync_at TEXT
  )
''');
```

#### 2.2 Keep `habits_daily` Table (For Daily Scratchpad)

**No changes needed** - Keep existing structure. It will be used as scratchpad for today's calculations only.

#### 2.3 Migration Logic

**File:** `lib/services/database/database_manager.dart`

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  try {
    if (oldVersion < 3) {
      // Migration from version 2 to 3: Add today_* fields to streaks table
      await _addTodayFieldsToStreaks(db);
    }
  } catch (e) {
    await ErrorLoggingService.logCriticalError(
      errorCode: 'ERRSYS003',
      errorMessage: 'Database upgrade failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {
        'old_version': oldVersion,
        'new_version': newVersion,
      },
    );
    rethrow;
  }
}

Future<void> _addTodayFieldsToStreaks(Database db) async {
  // Add new columns if they don't exist
  try {
    await db.execute('ALTER TABLE streaks ADD COLUMN today_date TEXT');
    await db.execute('ALTER TABLE streaks ADD COLUMN today_diary INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE streaks ADD COLUMN today_affirmations INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE streaks ADD COLUMN today_gratitude INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE streaks ADD COLUMN today_self_care_count INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE streaks ADD COLUMN today_grace_pieces REAL DEFAULT 0.0');
  } catch (e) {
    // Columns might already exist, ignore error
    if (!e.toString().contains('duplicate column')) {
      rethrow;
    }
  }
}
```

---

## 💻 Code Changes

### 3. Model Updates

#### 3.1 Update `Streak` Model

**File:** `lib/models/analytics_models.dart`

```dart
class Streak {
  final String userId;
  final int current;
  final int longest;
  final DateTime? lastEntryDate;
  final int freezeCredits;
  final double gracePiecesTotal;
  final DateTime? todayDate;              // NEW
  final bool todayDiary;                   // NEW
  final bool todayAffirmations;            // NEW
  final bool todayGratitude;              // NEW
  final int todaySelfCareCount;            // NEW
  final double todayGracePieces;          // NEW
  final DateTime updatedAt;

  Streak({
    required this.userId,
    this.current = 0,
    this.longest = 0,
    this.lastEntryDate,
    this.freezeCredits = 0,
    this.gracePiecesTotal = 0.0,
    this.todayDate,                        // NEW
    this.todayDiary = false,              // NEW
    this.todayAffirmations = false,       // NEW
    this.todayGratitude = false,          // NEW
    this.todaySelfCareCount = 0,          // NEW
    this.todayGracePieces = 0.0,          // NEW
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
      gracePiecesTotal: ((json['grace_pieces_total'] ?? 0.0) as num).toDouble(),
      todayDate: json['today_date'] != null
          ? DateTime.parse(json['today_date'] as String)
          : null,
      todayDiary: json['today_diary'] as bool? ?? false,
      todayAffirmations: json['today_affirmations'] as bool? ?? false,
      todayGratitude: json['today_gratitude'] as bool? ?? false,
      todaySelfCareCount: json['today_self_care_count'] as int? ?? 0,
      todayGracePieces: ((json['today_grace_pieces'] ?? 0.0) as num).toDouble(),
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
      'grace_pieces_total': gracePiecesTotal,
      'today_date': todayDate?.toIso8601String().split('T')[0],
      'today_diary': todayDiary,
      'today_affirmations': todayAffirmations,
      'today_gratitude': todayGratitude,
      'today_self_care_count': todaySelfCareCount,
      'today_grace_pieces': todayGracePieces,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
```

---

### 4. Service Updates

#### 4.1 Update `UserDataService.calculateStreakOnAppLaunch()`

**File:** `lib/services/user_data_service.dart`

**New Flow:**
1. Store `app_startup_date = DateTime.now()` (date only)
2. Fetch `streaks` table (1 call)
3. Check: `streaks.today_date` == `app_startup_date`?
   - If NO: Clear local `habits_daily`, reset `streaks.today_*`, set `today_date` = today
   - If YES: Populate local `habits_daily` from `streaks.today_*`
4. Calculate from local `habits_daily`
5. Update `streaks` via RPC

```dart
/// Calculate streak on app launch (using today_* fields from streaks table)
static Future<void> calculateStreakOnAppLaunch(String userId) async {
  try {
    final db = await DatabaseManager().database;
    final dataFetchService = DataFetchService(repository: DataRepository());

    // 1. Store app startup date (for all operations today)
    final appStartupDate = DateTime.now();
    final todayDateOnly = DateTime(
      appStartupDate.year,
      appStartupDate.month,
      appStartupDate.day,
    );
    final todayDateStr = todayDateOnly.toIso8601String().split('T')[0];

    // 2. Fetch streaks from Supabase (1 call)
    final supabaseStreak = await dataFetchService.fetchStreaks(userId);

    if (supabaseStreak == null) {
      await _ensureStreaksRecordExists(userId);
      return;
    }

    // 3. Cache streaks in local DB
    final localStreak = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (localStreak.isEmpty || localStreak.first['last_sync_at'] == null) {
      await db.insert(
        'streaks',
        {
          'user_id': userId,
          'current': supabaseStreak['current'] ?? 0,
          'longest': supabaseStreak['longest'] ?? 0,
          'last_entry_date': supabaseStreak['last_entry_date'],
          'freeze_credits': supabaseStreak['freeze_credits'] ?? 0,
          'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
          'today_date': supabaseStreak['today_date'],
          'today_diary': (supabaseStreak['today_diary'] ?? false) ? 1 : 0,
          'today_affirmations': (supabaseStreak['today_affirmations'] ?? false) ? 1 : 0,
          'today_gratitude': (supabaseStreak['today_gratitude'] ?? false) ? 1 : 0,
          'today_self_care_count': supabaseStreak['today_self_care_count'] ?? 0,
          'today_grace_pieces': supabaseStreak['today_grace_pieces'] ?? 0.0,
          'updated_at': supabaseStreak['updated_at'] ?? DateTime.now().toIso8601String(),
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 4. Check if today_date matches today
    final streakTodayDate = supabaseStreak['today_date'] as String?;
    final isNewDay = streakTodayDate != todayDateStr;

    if (isNewDay) {
      // New day - clear local habits_daily and reset today_* fields
      await db.delete(
        'habits_daily',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Reset today_* fields in local streaks
      await db.update(
        'streaks',
        {
          'today_date': todayDateStr,
          'today_diary': 0,
          'today_affirmations': 0,
          'today_gratitude': 0,
          'today_self_care_count': 0,
          'today_grace_pieces': 0.0,
          'is_synced': 0,
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Push reset to Supabase via RPC
      await _syncService.batchUpdateStreakData(
        userId: userId,
        streakData: {
          'current': supabaseStreak['current'] ?? 0,
          'longest': supabaseStreak['longest'] ?? 0,
          'last_entry_date': supabaseStreak['last_entry_date'],
          'freeze_credits': supabaseStreak['freeze_credits'] ?? 0,
          'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
          'today_date': todayDateStr,
          'today_diary': false,
          'today_affirmations': false,
          'today_gratitude': false,
          'today_self_care_count': 0,
          'today_grace_pieces': 0.0,
        },
      );
    } else {
      // Same day - populate local habits_daily from streaks.today_* fields
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, todayDateStr],
        limit: 1,
      );

      if (todayHabits.isEmpty) {
        // Create today's habits_daily record from streaks.today_* fields
        final uuid = Uuid().v4();
        await db.insert(
          'habits_daily',
          {
            'id': uuid,
            'user_id': userId,
            'date': todayDateStr,
            'wrote_entry': (supabaseStreak['today_diary'] ?? false) ? 1 : 0,
            'filled_affirmations': (supabaseStreak['today_affirmations'] ?? false) ? 1 : 0,
            'filled_gratitude': (supabaseStreak['today_gratitude'] ?? false) ? 1 : 0,
            'self_care_completed_count': supabaseStreak['today_self_care_count'] ?? 0,
            'grace_pieces_earned': supabaseStreak['today_grace_pieces'] ?? 0.0,
            'is_synced': 1,
            'last_sync_at': DateTime.now().toIso8601String(),
          },
        );
      }
    }

    // 5. Check for gaps and handle streak
    final lastEntryDateStr = supabaseStreak['last_entry_date'] as String?;
    if (lastEntryDateStr == null) {
      await recalculateStreak(userId, dataFetchService: dataFetchService);
      return;
    }

    final lastEntryDate = DateTime.parse(lastEntryDateStr);
    final lastDateOnly = DateTime(
      lastEntryDate.year,
      lastEntryDate.month,
      lastEntryDate.day,
    );
    final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

    if (daysDiff == 0) {
      // Same day - recalculate to ensure accuracy
      final currentStreak = supabaseStreak['current'] as int? ?? 0;
      final calculatedStreak = await _calculateStreakFromTodayHabits(userId);

      if (calculatedStreak != currentStreak) {
        await recalculateStreak(userId, dataFetchService: dataFetchService);
      }
      return;
    }

    if (daysDiff > 0) {
      // Gap detected - handle with grace days
      final graceDays = supabaseStreak['freeze_credits'] as int? ?? 0;

      if (daysDiff == 1 && graceDays > 0) {
        await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
        await recalculateStreak(userId, dataFetchService: dataFetchService);
      } else if (daysDiff > 1) {
        if (graceDays >= daysDiff - 1) {
          for (int i = 0; i < daysDiff - 1; i++) {
            await GraceSystemService.useGraceDay(userId, dataFetchService: dataFetchService);
          }
          await recalculateStreak(userId, dataFetchService: dataFetchService);
        } else {
          // Reset streak
          await db.update(
            'streaks',
            {
              'current': 0,
              'last_entry_date': null,
              'updated_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            },
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          await _syncService.batchUpdateStreakData(
            userId: userId,
            streakData: {
              'current': 0,
              'longest': supabaseStreak['longest'] ?? 0,
              'last_entry_date': null,
              'freeze_credits': graceDays,
              'grace_pieces_total': supabaseStreak['grace_pieces_total'] ?? 0.0,
              'today_date': todayDateStr,
              'today_diary': false,
              'today_affirmations': false,
              'today_gratitude': false,
              'today_self_care_count': 0,
              'today_grace_pieces': 0.0,
            },
          );
        }
      }
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS162',
      errorMessage: 'App launch streak calculation failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
  }
}

/// Calculate streak from today's habits_daily only (simplified)
static Future<int> _calculateStreakFromTodayHabits(String userId) async {
  try {
    final db = await DatabaseManager().database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Get today's habits
    final todayHabits = await db.query(
      'habits_daily',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, today],
      limit: 1,
    );

    if (todayHabits.isEmpty) return 0;

    final habit = todayHabits.first;
    final hasActivity = (habit['wrote_entry'] as int? ?? 0) == 1 ||
        (habit['filled_affirmations'] as int? ?? 0) == 1 ||
        (habit['filled_gratitude'] as int? ?? 0) == 1 ||
        (habit['self_care_completed_count'] as int? ?? 0) > 0;

    if (!hasActivity) return 0;

    // Get current streak from streaks table
    final streak = await db.query(
      'streaks',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (streak.isEmpty) return 0;

    final currentStreak = streak.first['current'] as int? ?? 0;
    final lastEntryDateStr = streak.first['last_entry_date'] as String?;

    if (lastEntryDateStr == null) return 1;

    final lastEntryDate = DateTime.parse(lastEntryDateStr);
    final lastDateOnly = DateTime(
      lastEntryDate.year,
      lastEntryDate.month,
      lastEntryDate.day,
    );
    final todayDateOnly = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

    if (daysDiff == 0) {
      // Same day - increment if not already incremented
      return currentStreak;
    } else if (daysDiff == 1) {
      // Consecutive day - increment
      return currentStreak + 1;
    } else {
      // Gap - reset or use grace days (handled elsewhere)
      return 0;
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYS160',
      errorMessage: 'Calculate streak from today habits failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
    return 0;
  }
}
```

#### 4.2 Update `GraceSystemService.trackTaskCompletion()`

**File:** `lib/services/grace_system_service.dart`

**Changes:**
- Update local `habits_daily` (today's record)
- Calculate pieces
- Update local `streaks.today_*` fields
- Push to Supabase via RPC (includes `today_*` fields)

```dart
static Future<void> trackTaskCompletion(
  String userId,
  String taskType,
  bool completed,
) async {
  try {
    final db = await DatabaseManager().database;
    final today = DateTime.now();
    final todayDateStr = today.toIso8601String().split('T')[0];

    // Get or create today's habits_daily record
    final todayHabits = await db.query(
      'habits_daily',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, todayDateStr],
      limit: 1,
    );

    Map<String, dynamic> habitData;
    if (todayHabits.isEmpty) {
      // Create new record
      final uuid = Uuid().v4();
      habitData = {
        'id': uuid,
        'user_id': userId,
        'date': todayDateStr,
        'wrote_entry': 0,
        'filled_affirmations': 0,
        'filled_gratitude': 0,
        'self_care_completed_count': 0,
        'grace_pieces_earned': 0.0,
        'is_synced': 0,
      };
      await db.insert('habits_daily', habitData);
    } else {
      habitData = Map<String, dynamic>.from(todayHabits.first);
    }

    // Update task completion
    switch (taskType) {
      case 'diary':
        habitData['wrote_entry'] = completed ? 1 : 0;
        break;
      case 'affirmations':
        habitData['filled_affirmations'] = completed ? 1 : 0;
        break;
      case 'gratitude':
        habitData['filled_gratitude'] = completed ? 1 : 0;
        break;
      case 'self_care':
        // Handle self_care count
        break;
    }

    // Calculate grace pieces
    final pieces = _calculatePiecesForToday(habitData);
    habitData['grace_pieces_earned'] = pieces;

    // Update local habits_daily
    await db.update(
      'habits_daily',
      habitData,
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, todayDateStr],
    );

    // Update local streaks.today_* fields
    await db.update(
      'streaks',
      {
        'today_date': todayDateStr,
        'today_diary': habitData['wrote_entry'] == 1,
        'today_affirmations': habitData['filled_affirmations'] == 1,
        'today_gratitude': habitData['filled_gratitude'] == 1,
        'today_self_care_count': habitData['self_care_completed_count'] ?? 0,
        'today_grace_pieces': pieces,
        'is_synced': 0,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Schedule sync via RPC
    _scheduleSync(userId, todayDateStr);
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRGRACE001',
      errorMessage: 'Track task completion failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId, 'task_type': taskType},
    );
  }
}
```

#### 4.3 Update `SupabaseSyncService.batchUpdateStreakData()`

**File:** `lib/services/sync/supabase_sync_service.dart`

**Changes:**
- Include `today_*` fields in RPC call
- Remove `habitsData` parameter (not needed)

```dart
Future<bool> batchUpdateStreakData({
  required String userId,
  required Map<String, dynamic> streakData,
  List<Map<String, dynamic>>? habitsData, // DEPRECATED - not used
}) async {
  try {
    // Prepare RPC params with today_* fields
    final params = {
      'p_user_id': userId,
      'p_streak_data': {
        'current': streakData['current'] ?? 0,
        'longest': streakData['longest'] ?? 0,
        'last_entry_date': streakData['last_entry_date'],
        'freeze_credits': streakData['freeze_credits'] ?? 0,
        'grace_pieces_total': streakData['grace_pieces_total'] ?? 0.0,
        'today_date': streakData['today_date'],
        'today_diary': streakData['today_diary'] ?? false,
        'today_affirmations': streakData['today_affirmations'] ?? false,
        'today_gratitude': streakData['today_gratitude'] ?? false,
        'today_self_care_count': streakData['today_self_care_count'] ?? 0,
        'today_grace_pieces': streakData['today_grace_pieces'] ?? 0.0,
      },
      'p_habits_data': null, // Not used anymore
    };

    final response = await _supabase.rpc('batch_update_streak_data', params: params);

    if (response['success'] == true) {
      // Mark as synced in local DB
      final db = await DatabaseManager().database;
      await db.update(
        'streaks',
        {
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return true;
    }

    return false;
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRSYNC001',
      errorMessage: 'Batch update streak data failed: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      errorContext: {'user_id': userId},
    );
    return false;
  }
}
```

#### 4.4 Remove `habits_daily` Fetching from `DataFetchService`

**File:** `lib/services/data_fetch_service.dart`

**Changes:**
- Remove or deprecate `fetchHabitsDaily()` method
- Keep `fetchHabitsForDate()` for today only (if needed)

```dart
/// DEPRECATED: No longer needed - habits_daily removed from Supabase
/// Use streaks.today_* fields instead
@Deprecated('Use streaks.today_* fields instead. This method is deprecated.')
Future<List<HabitsDaily>> fetchHabitsDaily({
  required String userId,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  // Return empty list - not used anymore
  return <HabitsDaily>[];
}
```

---

### 5. Edge Cases Handling

#### 5.1 Day Changes While App is Open

**Solution:** Check date on every operation

```dart
// In GraceSystemService.trackTaskCompletion()
static Future<void> trackTaskCompletion(...) async {
  final today = DateTime.now();
  final todayDateStr = today.toIso8601String().split('T')[0];

  // Check if day changed
  final db = await DatabaseManager().database;
  final streak = await db.query(
    'streaks',
    where: 'user_id = ?',
    whereArgs: [userId],
    limit: 1,
  );

  if (streak.isNotEmpty) {
    final streakTodayDate = streak.first['today_date'] as String?;
    if (streakTodayDate != todayDateStr) {
      // Day changed - reset
      await _resetForNewDay(userId, todayDateStr);
    }
  }

  // Continue with task tracking...
}
```

#### 5.2 Mid-Day Reinstall

**Solution:** Fetch `streaks` → populate `habits_daily` from `today_*` fields

Already handled in `calculateStreakOnAppLaunch()` - if `today_date` matches today, populate `habits_daily` from `streaks.today_*`.

#### 5.3 Multi-Device Sync

**Solution:** Last write wins (handled by RPC upsert)

- Device A: Complete task → RPC updates `streaks.today_*`
- Device B: Fetch `streaks` → gets updated `today_*` → complete more → RPC updates
- Device A: Fetch again → gets merged data

#### 5.4 Timezone Handling (Future)

**Solution:** Store dates in UTC, convert to user timezone for display

For now: Use `DateTime.now()` (local time). Will handle timezone in future update.

---

## 📊 API Calls Summary

### Before:
- **Startup:** 2 calls (streaks + habits_daily last 30 days)
- **Task completion:** 1 call (RPC with streaks + habits_daily)

### After:
- **Startup:** 1 call (streaks only - includes today_* fields)
- **Task completion:** 1 call (RPC with streaks only - includes today_* fields)

**Savings:** 50% reduction in API calls on startup

---

## ✅ Benefits

1. **Space Efficient:** No historical habits_daily data
2. **Faster Startup:** 1 API call instead of 2
3. **Simpler Logic:** Single source of truth (streaks table)
4. **Multi-Device:** Works seamlessly (last write wins)
5. **Mid-Day Reinstall:** Handled automatically
6. **Day Change:** Detected and handled

---

## 🧪 Testing Checklist

- [ ] Fresh install: Streak initializes correctly
- [ ] Normal restart: Streak calculates accurately
- [ ] New day: Local habits_daily cleared, today_* reset
- [ ] Mid-day reinstall: Populates habits_daily from streaks.today_*
- [ ] Day change while app open: Detected and handled
- [ ] Multi-device: Syncs correctly
- [ ] Task completion: Updates streaks.today_* correctly
- [ ] RPC sync: Includes today_* fields
- [ ] Gap detection: Works correctly
- [ ] Grace days: Used correctly

---

## 🚀 Implementation Order

1. **Database Changes:**
   - Add new columns to Supabase `streaks` table
   - Update RPC function
   - Update local SQLite schema

2. **Model Updates:**
   - Update `Streak` model with today_* fields

3. **Service Updates:**
   - Update `calculateStreakOnAppLaunch()`
   - Update `trackTaskCompletion()`
   - Update `batchUpdateStreakData()`
   - Remove/deprecate `fetchHabitsDaily()`

4. **Testing:**
   - Test all edge cases
   - Verify multi-device sync
   - Verify day change handling

5. **Cleanup:**
   - Remove unused `habits_daily` fetching code
   - Update documentation

---

## ⚠️ Migration Notes

1. **Existing Users:**
   - Existing `habits_daily` data can be ignored
   - New system starts fresh with `today_*` fields
   - No data loss (streak data preserved in `streaks` table)

2. **Rollback Plan:**
   - Keep `habits_daily` table initially (don't drop)
   - Can rollback by reverting code changes
   - Drop table after confirming new system works

3. **Backward Compatibility:**
   - Handle missing `today_*` fields gracefully (defaults to false/0)
   - Migration adds columns with defaults

---

**Status:** Ready for implementation
**Priority:** High
**Risk:** Medium (requires DB migration, but backward compatible)
