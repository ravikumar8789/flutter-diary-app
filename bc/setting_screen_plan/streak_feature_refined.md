# Streak Feature Refined - Comprehensive Analysis Report

## 🎯 **Overview**

This report analyzes the current streak compassion implementation and provides a complete plan to refactor it into a **simple, earned grace days system** where users earn grace days through daily task completion.

## 📊 **Current Implementation Analysis**

### **Existing System:**
- **Configurable grace periods** (1-3 days)
- **Manual freeze credits** (2-3 initial credits)
- **Complex UI** with multiple settings
- **Database-driven** grace period management

### **Proposed System:**
- **Fixed earning rate**: 0.5 pieces per task, 2 pieces per day, 10 pieces = 1 grace day
- **No manual settings** - purely behavior-driven
- **Simple UI** - just show earned grace days
- **Automatic tracking** of task completion

## 🗄️ **Database Changes Required**

### **✅ NO NEW TABLES NEEDED** - Using Existing Structure

The existing database already has all necessary tables:
- **`habits_daily`** - tracks daily task completion (affirmations, gratitude, diary, self-care)
- **`streaks`** - has `freeze_credits` field (repurpose as grace days)
- **`user_settings`** - has `streak_compassion_enabled` (repurpose as grace system enabled)

### **1. Modify `habits_daily` Table** - Add Grace Pieces Tracking
```sql
-- Add grace pieces calculation column
ALTER TABLE public.habits_daily ADD COLUMN grace_pieces_earned numeric(3,1) DEFAULT 0.0;

-- Add index for performance
CREATE INDEX idx_habits_daily_grace_pieces ON public.habits_daily(user_id, date) WHERE grace_pieces_earned > 0;
```

### **2. Modify `streaks` Table** - Repurpose Existing Fields
```sql
-- Repurpose freeze_credits as grace_days_available
-- freeze_credits will now represent earned grace days (0-5 max)

-- Add grace pieces tracking
ALTER TABLE public.streaks ADD COLUMN grace_pieces_total numeric(5,1) DEFAULT 0.0;

-- Remove unused compassion fields (cleanup)
ALTER TABLE public.streaks DROP COLUMN grace_period_active;
ALTER TABLE public.streaks DROP COLUMN grace_period_expires_at;
ALTER TABLE public.streaks DROP COLUMN compassion_used_count;
```

### **3. Modify `user_settings` Table** - Simplify Settings
```sql
-- Remove complex compassion settings (cleanup)
ALTER TABLE public.user_settings DROP COLUMN grace_period_days;
ALTER TABLE public.user_settings DROP COLUMN max_freeze_credits;
ALTER TABLE public.user_settings DROP COLUMN freeze_credits_earned;

-- Rename for clarity
ALTER TABLE public.user_settings RENAME COLUMN streak_compassion_enabled TO grace_system_enabled;
```

### **4. Update `streak_freeze_usage` Table** - Repurpose for Grace Days
```sql
-- Update reason constraint to include grace day usage
ALTER TABLE public.streak_freeze_usage DROP CONSTRAINT IF EXISTS streak_freeze_usage_reason_check;
ALTER TABLE public.streak_freeze_usage ADD CONSTRAINT streak_freeze_usage_reason_check 
  CHECK (reason = ANY (ARRAY['missed_day', 'manual_use', 'recovery', 'grace_day_used']));

-- Add grace day tracking
ALTER TABLE public.streak_freeze_usage ADD COLUMN grace_day_used boolean DEFAULT false;
```

### **5. New Function: Calculate Grace Days from Habits**
```sql
CREATE OR REPLACE FUNCTION calculate_grace_days_from_habits(p_user_id uuid)
RETURNS TABLE(
  grace_days_available integer,
  grace_pieces_total numeric(5,1),
  pieces_today numeric(3,1),
  tasks_completed_today integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  total_pieces numeric(5,1) := 0;
  grace_days integer := 0;
  today_pieces numeric(3,1) := 0;
  today_tasks integer := 0;
  today_record RECORD;
BEGIN
  -- Get today's habits record
  SELECT * INTO today_record 
  FROM public.habits_daily 
  WHERE user_id = p_user_id AND date = CURRENT_DATE;
  
  -- Calculate today's pieces and tasks
  IF today_record.id IS NOT NULL THEN
    today_pieces := COALESCE(today_record.grace_pieces_earned, 0);
    today_tasks := (
      CASE WHEN today_record.filled_affirmations THEN 1 ELSE 0 END +
      CASE WHEN today_record.filled_gratitude THEN 1 ELSE 0 END +
      CASE WHEN today_record.wrote_entry THEN 1 ELSE 0 END +
      CASE WHEN today_record.self_care_completed_count > 0 THEN 1 ELSE 0 END
    );
  END IF;
  
  -- Calculate total pieces from all time
  SELECT COALESCE(SUM(grace_pieces_earned), 0) INTO total_pieces
  FROM public.habits_daily
  WHERE user_id = p_user_id;
  
  -- Calculate grace days (10 pieces = 1 grace day, max 5)
  grace_days := LEAST(FLOOR(total_pieces / 10), 5);
  
  RETURN QUERY SELECT grace_days, total_pieces, today_pieces, today_tasks;
END;
$$;
```

### **6. New Function: Update Grace Pieces When Tasks Complete**
```sql
CREATE OR REPLACE FUNCTION update_grace_pieces_on_task_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  new_pieces numeric(3,1) := 0;
  total_pieces numeric(5,1) := 0;
  grace_days integer := 0;
BEGIN
  -- Calculate pieces based on completed tasks (0.5 per task)
  new_pieces := (
    CASE WHEN NEW.filled_affirmations THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.filled_gratitude THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.wrote_entry THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.self_care_completed_count > 0 THEN 0.5 ELSE 0 END
  );
  
  -- Update the grace_pieces_earned for this record
  NEW.grace_pieces_earned := new_pieces;
  
  -- Calculate total pieces and grace days
  SELECT COALESCE(SUM(grace_pieces_earned), 0) INTO total_pieces
  FROM public.habits_daily
  WHERE user_id = NEW.user_id;
  
  grace_days := LEAST(FLOOR(total_pieces / 10), 5);
  
  -- Update streaks table
  UPDATE public.streaks 
  SET 
    freeze_credits = grace_days,
    grace_pieces_total = total_pieces,
    updated_at = now()
  WHERE user_id = NEW.user_id;
  
  RETURN NEW;
END;
$$;

-- Create trigger for automatic grace pieces calculation
CREATE TRIGGER trigger_update_grace_pieces
  BEFORE INSERT OR UPDATE ON public.habits_daily
  FOR EACH ROW
  EXECUTE FUNCTION update_grace_pieces_on_task_completion();
```

### **7. Remove Old Functions and Triggers**
```sql
-- Remove old compassion functions
DROP FUNCTION IF EXISTS calculate_streak_with_compassion(uuid);
DROP FUNCTION IF EXISTS update_streak_on_freeze_usage();
DROP TRIGGER IF EXISTS trigger_update_streak_on_freeze_usage ON public.streak_freeze_usage;
```

## 🔧 **Code Changes Required**

### **1. New Service: `GraceSystemService`** - Using Existing Tables
```dart
// lib/services/grace_system_service.dart
class GraceSystemService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Constants
  static const double PIECES_PER_TASK = 0.5;
  static const double PIECES_PER_DAY = 2.0;
  static const double PIECES_PER_GRACE_DAY = 10.0;
  static const int MAX_GRACE_DAYS = 5; // Cap at 5 grace days
  
  // Get user's grace status from habits_daily table
  static Future<Map<String, dynamic>?> getGraceStatus(String userId) async {
    try {
      final response = await _supabase
          .rpc('calculate_grace_days_from_habits', params: {'p_user_id': userId})
          .single();
      
      return {
        'grace_days_available': response['grace_days_available'] ?? 0,
        'grace_pieces_total': response['grace_pieces_total'] ?? 0.0,
        'pieces_today': response['pieces_today'] ?? 0.0,
        'tasks_completed_today': response['tasks_completed_today'] ?? 0,
        'progress_percentage': ((response['pieces_today'] ?? 0.0) / 2.0 * 100).round(),
      };
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA120',
        errorMessage: 'Failed to get grace status: $e',
        errorContext: {'userId': userId},
      );
      return null;
    }
  }
  
  // Track task completion by updating habits_daily table
  static Future<bool> trackTaskCompletion({
    required String userId,
    required DateTime date,
    required String taskType, // 'affirmations', 'gratitude', 'diary', 'self_care'
    required bool completed,
  }) async {
    try {
      // Get or create today's habits record
      final todayRecord = await _getOrCreateTodayHabitsRecord(userId, date);
      
      // Update the specific task completion
      Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      switch (taskType) {
        case 'affirmations':
          updateData['filled_affirmations'] = completed;
          break;
        case 'gratitude':
          updateData['filled_gratitude'] = completed;
          break;
        case 'diary':
          updateData['wrote_entry'] = completed;
          break;
        case 'self_care':
          // For self-care, we track count, so we need to handle this differently
          if (completed) {
            updateData['self_care_completed_count'] = 1;
          } else {
            updateData['self_care_completed_count'] = 0;
          }
          break;
      }
      
      // Update the record (trigger will automatically calculate grace pieces)
      await _supabase
          .from('habits_daily')
          .update(updateData)
          .eq('user_id', userId)
          .eq('date', date.toIso8601String().split('T')[0]);
      
      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA121',
        errorMessage: 'Failed to track task completion: $e',
        errorContext: {'userId': userId, 'taskType': taskType, 'completed': completed},
      );
      return false;
    }
  }
  
  // Use grace day when streak would break
  static Future<bool> useGraceDay(String userId) async {
    try {
      final graceStatus = await getGraceStatus(userId);
      if (graceStatus == null) return false;
      
      final graceDays = graceStatus['grace_days_available'] as int;
      if (graceDays <= 0) return false;
      
      // Record grace day usage
      await _supabase.from('streak_freeze_usage').insert({
        'user_id': userId,
        'reason': 'grace_day_used',
        'streak_maintained': await _getCurrentStreak(userId),
        'grace_day_used': true,
        'grace_period_days': 1,
      });
      
      // Update streaks table (decrease grace days)
      await _supabase
          .from('streaks')
          .update({
            'freeze_credits': graceDays - 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA122',
        errorMessage: 'Failed to use grace day: $e',
        errorContext: {'userId': userId},
      );
      return false;
    }
  }
  
  // Helper: Get or create today's habits record
  static Future<Map<String, dynamic>> _getOrCreateTodayHabitsRecord(
    String userId, 
    DateTime date
  ) async {
    final dateStr = date.toIso8601String().split('T')[0];
    
    // Try to get existing record
    final existing = await _supabase
        .from('habits_daily')
        .select('*')
        .eq('user_id', userId)
        .eq('date', dateStr);
    
    if (existing.isNotEmpty) {
      return existing.first;
    }
    
    // Create new record
    final newRecord = {
      'user_id': userId,
      'date': dateStr,
      'wrote_entry': false,
      'filled_affirmations': false,
      'filled_gratitude': false,
      'self_care_completed_count': 0,
      'grace_pieces_earned': 0.0,
    };
    
    final response = await _supabase
        .from('habits_daily')
        .insert(newRecord)
        .select()
        .single();
    
    return response;
  }
  
  // Helper: Get current streak
  static Future<int> _getCurrentStreak(String userId) async {
    try {
      final response = await _supabase
          .from('streaks')
          .select('current')
          .eq('user_id', userId)
          .single();
      return response['current'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
```

### **2. Update Streak Calculation Logic** - Using Existing Tables
```dart
// lib/services/user_data_service.dart
static Future<int> calculateStreakWithGrace(String userId, List entries) async {
  try {
    // Get grace system data from habits_daily
    final graceData = await GraceSystemService.getGraceStatus(userId);
    final graceDaysAvailable = graceData?['grace_days_available'] ?? 0;
    
    // Calculate days since last entry
    if (entries.isEmpty) {
      if (graceDaysAvailable > 0) {
        // Use grace day to maintain streak
        await GraceSystemService.useGraceDay(userId);
        return await _getCurrentStreak(userId);
      }
      return 0;
    }
    
    final lastEntryDate = DateTime.parse(entries.first['created_at']);
    final daysSinceLastEntry = DateTime.now().difference(lastEntryDate).inDays;
    
    if (daysSinceLastEntry == 0) {
      // Entry written today, maintain streak
      return await _getCurrentStreak(userId);
    } else if (daysSinceLastEntry == 1 && graceDaysAvailable > 0) {
      // Missed yesterday, use grace day
      await GraceSystemService.useGraceDay(userId);
      return await _getCurrentStreak(userId);
    } else {
      // Multiple days missed or no grace days, break streak
      return 0;
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA123',
      errorMessage: 'Failed to calculate streak with grace: $e',
      errorContext: {'userId': userId},
    );
    return 0;
  }
}
```

### **3. Update `StreakCompassionProvider` → `GraceSystemProvider`**
```dart
// lib/providers/grace_system_provider.dart
class GraceSystemState {
  final bool isLoading;
  final int graceDaysAvailable;
  final double piecesToday;
  final double piecesNeeded;
  final int progressPercentage;
  final String? error;
  
  // Simplified state - no complex settings
}

class GraceSystemNotifier extends Notifier<GraceSystemState> {
  // Remove: toggleCompassion, updateGracePeriodDays
  // Add: trackTaskCompletion, useGraceDay, refreshGraceStatus
  
  // Track when user completes tasks
  Future<void> trackTaskCompletion(String taskType, bool completed) async {
    if (_currentUserId == null) return;
    
    await GracePiecesService.trackTaskCompletion(
      userId: _currentUserId!,
      date: DateTime.now(),
      taskType: taskType,
      completed: completed,
    );
    
    // Refresh status
    await refreshGraceStatus();
  }
}
```

### **4. Update Entry Providers to Track Task Completion**

#### **Entry Provider Updates:**
```dart
// lib/providers/entry_provider.dart
class EntryNotifier extends Notifier<EntryState> {
  // Add grace system tracking to existing methods
  
  void updateDiaryText(String userId, DateTime date, String text) async {
    // Existing logic...
    
    // Track diary completion for grace pieces
    final graceProvider = ref.read(graceSystemProvider.notifier);
    await graceProvider.trackTaskCompletion('diary', text.trim().isNotEmpty);
  }
  
  void updateAffirmations(String userId, DateTime date, List<AffirmationItem> affirmations) async {
    // Existing logic...
    
    // Track affirmations completion
    final graceProvider = ref.read(graceSystemProvider.notifier);
    await graceProvider.trackTaskCompletion('affirmations', affirmations.isNotEmpty);
  }
  
  // Similar updates for wellness, gratitude, etc.
}
```

### **5. Update Streak Calculation Logic**
```dart
// lib/services/user_data_service.dart
static Future<int> calculateStreakWithGrace(String userId, List entries) async {
  try {
    // Get grace system data
    final graceData = await GraceSystemService.getGraceSystemData(userId);
    final graceDaysAvailable = graceData?['grace_days_available'] ?? 0;
    
    // Calculate days since last entry
    if (entries.isEmpty) {
      if (graceDaysAvailable > 0) {
        // Use grace day to maintain streak
        await GracePiecesService.useGraceDay(userId);
        return await _getCurrentStreak(userId);
      }
      return 0;
    }
    
    final lastEntryDate = DateTime.parse(entries.first['created_at']);
    final daysSinceLastEntry = DateTime.now().difference(lastEntryDate).inDays;
    
    if (daysSinceLastEntry == 0) {
      // Entry written today, maintain streak
      return await _getCurrentStreak(userId);
    } else if (daysSinceLastEntry == 1 && graceDaysAvailable > 0) {
      // Missed yesterday, use grace day
      await GracePiecesService.useGraceDay(userId);
      return await _getCurrentStreak(userId);
    } else {
      // Multiple days missed or no grace days, break streak
      return 0;
    }
  } catch (e) {
    await ErrorLoggingService.logHighError(
      errorCode: 'ERRDATA124',
      errorMessage: 'Failed to calculate streak with grace: $e',
      errorContext: {'userId': userId},
    );
    return 0;
  }
}
```

## 🎨 **UI Changes Required**

### **1. Simplify Settings Screen**
```dart
// lib/screens/settings_screen.dart
// Remove complex compassion settings UI
// Replace with simple grace system display

Widget buildGraceSystemSection() {
  return Consumer(
    builder: (context, ref, child) {
      final graceState = ref.watch(graceSystemProvider);
      
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Grace Days System', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              Text('Earn grace days by completing daily tasks'),
              SizedBox(height: 16),
              
              // Progress indicator
              LinearProgressIndicator(
                value: graceState.progressPercentage / 100.0,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              SizedBox(height: 8),
              Text('${graceState.piecesToday.toInt()}/10 pieces today'),
              
              SizedBox(height: 16),
              
              // Grace days display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grace Days Available'),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${graceState.graceDaysAvailable}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

### **2. Add Grace Status to Home Screen**
```dart
// Show grace days in streak display
Widget buildStreakDisplay() {
  return Consumer(
    builder: (context, ref, child) {
      final graceState = ref.watch(graceSystemProvider);
      
      return Column(
        children: [
          Text('${currentStreak} day streak'),
          if (graceState.graceDaysAvailable > 0)
            Text(
              '${graceState.graceDaysAvailable} grace days available',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
        ],
      );
    },
  );
}
```

### **3. Task Completion Indicators**
```dart
// Add visual indicators when tasks are completed
Widget buildTaskCompletionIndicator(String taskType, bool completed) {
  return Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: completed ? Colors.green : Colors.grey.shade300,
      shape: BoxShape.circle,
    ),
    child: Icon(
      completed ? Icons.check : Icons.circle_outlined,
      color: completed ? Colors.white : Colors.grey,
      size: 16,
    ),
  );
}
```

## 📊 **Task Completion Tracking**

### **How We Track Task Completion:**

#### **1. Affirmations**
- **Trigger**: When user saves affirmations in `morning_rituals_screen.dart`
- **Completion**: `affirmations.isNotEmpty`
- **Code**: Update `updateAffirmations()` in `entry_provider.dart`

#### **2. Wellness Tracker**
- **Trigger**: When user saves wellness data in `wellness_tracker_screen.dart`
- **Completion**: Any wellness field filled (breakfast, lunch, dinner, water)
- **Code**: Update `updateMeals()` in `entry_provider.dart`

#### **3. Gratitude & Reflection**
- **Trigger**: When user saves gratitude in `gratitude_reflection_screen.dart`
- **Completion**: `gratitude.isNotEmpty`
- **Code**: Update `updateGratitude()` in `entry_provider.dart`

#### **4. Daily Diary**
- **Trigger**: When user saves diary text in `new_diary_screen.dart`
- **Completion**: `diaryText.trim().isNotEmpty`
- **Code**: Update `updateDiaryText()` in `entry_provider.dart`

### **Tracking Implementation:**
```dart
// Add to each task completion method
Future<void> _trackTaskCompletion(String taskType, bool completed) async {
  final graceProvider = ref.read(graceSystemProvider.notifier);
  await graceProvider.trackTaskCompletion(taskType, completed);
}
```

## 🔄 **Migration Strategy**

### **Phase 1: Database Migration**
1. Create new `grace_pieces_earned` table
2. Add new columns to `streaks` table
3. Create new database functions
4. Test database changes

### **Phase 2: Service Layer**
1. Create `GracePiecesService`
2. Update `GraceSystemService` (renamed from `StreakCompassionService`)
3. Update streak calculation logic
4. Test service layer

### **Phase 3: Provider Layer**
1. Create `GraceSystemProvider` (renamed from `StreakCompassionProvider`)
2. Update `EntryProvider` to track task completion
3. Test provider layer

### **Phase 4: UI Layer**
1. Simplify settings screen
2. Add grace status to home screen
3. Add task completion indicators
4. Test UI changes

### **Phase 5: Cleanup**
1. Remove old compassion UI
2. Remove old database columns (optional)
3. Update documentation
4. Final testing

## 📈 **Benefits of New System**

### **For Users:**
- **Simpler to understand** - no complex settings
- **More motivating** - earn grace days through effort
- **Clear progress** - see pieces earned each day
- **Fair system** - everyone earns the same way

### **For Developers:**
- **Simpler codebase** - less complex logic
- **Easier maintenance** - fewer edge cases
- **Better tracking** - detailed task completion data
- **Cleaner UI** - less settings to manage

### **For Business:**
- **Higher engagement** - users work to earn protection
- **Better retention** - earned grace days feel valuable
- **Data insights** - track which tasks users complete most
- **Future features** - foundation for more gamification

## 🎯 **Success Metrics**

### **Technical Metrics:**
- **Database performance** - query times for grace calculations
- **UI responsiveness** - task completion tracking speed
- **Error rates** - grace system error frequency

### **User Metrics:**
- **Task completion rates** - % of users completing all 4 tasks daily
- **Grace day usage** - how often grace days are used
- **Streak retention** - % of users maintaining streaks with grace system
- **User satisfaction** - feedback on simplified system

## 🚀 **Implementation Timeline**

### **Week 1: Database & Services**
- Create new database tables and functions
- Implement `GracePiecesService`
- Update streak calculation logic

### **Week 2: Providers & Tracking**
- Create `GraceSystemProvider`
- Update `EntryProvider` for task tracking
- Test task completion tracking

### **Week 3: UI Updates**
- Simplify settings screen
- Add grace status displays
- Add task completion indicators

### **Week 4: Testing & Polish**
- End-to-end testing
- Performance optimization
- UI polish and animations

## 📋 **Implementation Checklist**

### **Database Changes:**
- [ ] Create `grace_pieces_earned` table
- [ ] Add columns to `streaks` table
- [ ] Create `calculate_grace_days_available` function
- [ ] Test database functions

### **Service Layer:**
- [ ] Create `GracePiecesService`
- [ ] Update `GraceSystemService`
- [ ] Update streak calculation logic
- [ ] Add error logging

### **Provider Layer:**
- [ ] Create `GraceSystemProvider`
- [ ] Update `EntryProvider` for task tracking
- [ ] Add grace day usage logic
- [ ] Test provider integration

### **UI Layer:**
- [ ] Simplify settings screen
- [ ] Add grace status to home screen
- [ ] Add task completion indicators
- [ ] Update streak display

### **Testing:**
- [ ] Unit tests for services
- [ ] Integration tests for providers
- [ ] UI tests for grace system
- [ ] End-to-end testing

---

## 🗄️ **Step-by-Step Supabase Database Update Queries**

### **⚠️ IMPORTANT: Run these queries in order to avoid breaking existing functionality**

### **Step 1: Add Grace Pieces Tracking to habits_daily**
```sql
-- Add grace pieces calculation column
ALTER TABLE public.habits_daily ADD COLUMN grace_pieces_earned numeric(3,1) DEFAULT 0.0;

-- Add index for performance
CREATE INDEX idx_habits_daily_grace_pieces ON public.habits_daily(user_id, date) WHERE grace_pieces_earned > 0;
```

### **Step 2: Update streaks table - Add grace pieces tracking**
```sql
-- Add grace pieces tracking
ALTER TABLE public.streaks ADD COLUMN grace_pieces_total numeric(5,1) DEFAULT 0.0;
```

### **Step 3: Clean up unused compassion fields from streaks table**
```sql
-- Remove unused compassion fields (cleanup)
ALTER TABLE public.streaks DROP COLUMN grace_period_active;
ALTER TABLE public.streaks DROP COLUMN grace_period_expires_at;
ALTER TABLE public.streaks DROP COLUMN compassion_used_count;
```

### **Step 4: Simplify user_settings table**
```sql
-- Remove complex compassion settings (cleanup)
ALTER TABLE public.user_settings DROP COLUMN grace_period_days;
ALTER TABLE public.user_settings DROP COLUMN max_freeze_credits;
ALTER TABLE public.user_settings DROP COLUMN freeze_credits_earned;

-- Rename for clarity
ALTER TABLE public.user_settings RENAME COLUMN streak_compassion_enabled TO grace_system_enabled;
```

### **Step 5: Update streak_freeze_usage table for grace days**
```sql
-- Update reason constraint to include grace day usage
ALTER TABLE public.streak_freeze_usage DROP CONSTRAINT IF EXISTS streak_freeze_usage_reason_check;
ALTER TABLE public.streak_freeze_usage ADD CONSTRAINT streak_freeze_usage_reason_check 
  CHECK (reason = ANY (ARRAY['missed_day', 'manual_use', 'recovery', 'grace_day_used']));

-- Add grace day tracking
ALTER TABLE public.streak_freeze_usage ADD COLUMN grace_day_used boolean DEFAULT false;
```

### **Step 6: Create new grace calculation function**
```sql
CREATE OR REPLACE FUNCTION calculate_grace_days_from_habits(p_user_id uuid)
RETURNS TABLE(
  grace_days_available integer,
  grace_pieces_total numeric(5,1),
  pieces_today numeric(3,1),
  tasks_completed_today integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  total_pieces numeric(5,1) := 0;
  grace_days integer := 0;
  today_pieces numeric(3,1) := 0;
  today_tasks integer := 0;
  today_record RECORD;
BEGIN
  -- Get today's habits record
  SELECT * INTO today_record 
  FROM public.habits_daily 
  WHERE user_id = p_user_id AND date = CURRENT_DATE;
  
  -- Calculate today's pieces and tasks
  IF today_record.id IS NOT NULL THEN
    today_pieces := COALESCE(today_record.grace_pieces_earned, 0);
    today_tasks := (
      CASE WHEN today_record.filled_affirmations THEN 1 ELSE 0 END +
      CASE WHEN today_record.filled_gratitude THEN 1 ELSE 0 END +
      CASE WHEN today_record.wrote_entry THEN 1 ELSE 0 END +
      CASE WHEN today_record.self_care_completed_count > 0 THEN 1 ELSE 0 END
    );
  END IF;
  
  -- Calculate total pieces from all time
  SELECT COALESCE(SUM(grace_pieces_earned), 0) INTO total_pieces
  FROM public.habits_daily
  WHERE user_id = p_user_id;
  
  -- Calculate grace days (10 pieces = 1 grace day, max 5)
  grace_days := LEAST(FLOOR(total_pieces / 10), 5);
  
  RETURN QUERY SELECT grace_days, total_pieces, today_pieces, today_tasks;
END;
$$;
```

### **Step 7: Create automatic grace pieces calculation trigger**
```sql
CREATE OR REPLACE FUNCTION update_grace_pieces_on_task_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  new_pieces numeric(3,1) := 0;
  total_pieces numeric(5,1) := 0;
  grace_days integer := 0;
BEGIN
  -- Calculate pieces based on completed tasks (0.5 per task)
  new_pieces := (
    CASE WHEN NEW.filled_affirmations THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.filled_gratitude THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.wrote_entry THEN 0.5 ELSE 0 END +
    CASE WHEN NEW.self_care_completed_count > 0 THEN 0.5 ELSE 0 END
  );
  
  -- Update the grace_pieces_earned for this record
  NEW.grace_pieces_earned := new_pieces;
  
  -- Calculate total pieces and grace days
  SELECT COALESCE(SUM(grace_pieces_earned), 0) INTO total_pieces
  FROM public.habits_daily
  WHERE user_id = NEW.user_id;
  
  grace_days := LEAST(FLOOR(total_pieces / 10), 5);
  
  -- Update streaks table
  UPDATE public.streaks 
  SET 
    freeze_credits = grace_days,
    grace_pieces_total = total_pieces,
    updated_at = now()
  WHERE user_id = NEW.user_id;
  
  RETURN NEW;
END;
$$;

-- Create trigger for automatic grace pieces calculation
CREATE TRIGGER trigger_update_grace_pieces
  BEFORE INSERT OR UPDATE ON public.habits_daily
  FOR EACH ROW
  EXECUTE FUNCTION update_grace_pieces_on_task_completion();
```

### **Step 8: Remove old compassion functions and triggers**
```sql
-- Remove old compassion functions
DROP FUNCTION IF EXISTS calculate_streak_with_compassion(uuid);
DROP FUNCTION IF EXISTS update_streak_on_freeze_usage();
DROP TRIGGER IF EXISTS trigger_update_streak_on_freeze_usage ON public.streak_freeze_usage;
```

### **Step 9: Verify the changes**
```sql
-- Test the new function
SELECT * FROM calculate_grace_days_from_habits('your-user-id-here');

-- Check table structures
\d public.habits_daily
\d public.streaks
\d public.user_settings
\d public.streak_freeze_usage
```

### **✅ Database Update Complete!**

**What Changed:**
- ✅ **No new tables** - used existing `habits_daily`, `streaks`, `user_settings`
- ✅ **Cleaned up unused fields** - removed old compassion columns
- ✅ **Added grace pieces tracking** - automatic calculation via trigger
- ✅ **Simplified settings** - single `grace_system_enabled` toggle
- ✅ **Repurposed existing fields** - `freeze_credits` now represents grace days

**Key Benefits:**
- **Backward compatible** - existing data preserved
- **Automatic calculation** - grace pieces calculated via database trigger
- **Simple structure** - no complex joins needed
- **Performance optimized** - proper indexes added

---

**This refined system transforms the complex streak compassion feature into a simple, engaging grace days system that rewards consistent daily task completion while maintaining the core benefit of streak protection.**
