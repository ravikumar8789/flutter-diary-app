# Streak Timezone Fix - Global Implementation Plan

## **Problem Analysis**

### **Current Issue:**
- App uses device timezone (e.g., IST +5:30)
- Supabase uses UTC timezone
- Date mismatch causes grace pieces to not update
- Function looks for wrong date records

### **Global Impact:**
- Users in different timezones will have broken streak tracking
- Grace pieces won't update for non-UTC users
- Daily task completion won't be tracked properly

## **Root Cause**
```sql
-- Current function uses hardcoded IST
app_today := (NOW() AT TIME ZONE 'Asia/Kolkata')::date;
```

## **Solution Strategy**

### **Option 1: Pass Date from App (Recommended)**
**Pros:**
- Simple implementation
- App controls the date logic
- Works for all timezones
- No timezone conversion needed

**Cons:**
- App must handle date logic
- Potential for date manipulation

### **Option 2: Pass Timezone from App**
**Pros:**
- Database handles timezone conversion
- More robust
- Consistent date calculation

**Cons:**
- More complex implementation
- Requires timezone string handling

## **Recommended Implementation: Pass Date**

### **Why Pass Date is Better:**
1. **Simplicity**: App already knows the correct date
2. **Consistency**: Same date used throughout app
3. **Reliability**: No timezone conversion errors
4. **Performance**: No timezone calculations in database

## **Implementation Plan**

### **Phase 1: Update Database Function**

```sql
CREATE OR REPLACE FUNCTION calculate_grace_days_from_habits(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
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
  -- Use passed date instead of hardcoded/calculated date
  SELECT * INTO today_record 
  FROM public.habits_daily 
  WHERE user_id = p_user_id AND date = p_date;
  
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

### **Phase 2: Update Flutter Code**

#### **2.1 Update Grace System Service**
```dart
// In lib/services/grace_system_service.dart
static Future<Map<String, dynamic>?> getGraceStatus(String userId) async {
  try {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final response = await _supabase
        .rpc(
          'calculate_grace_days_from_habits',
          params: {
            'p_user_id': userId,
            'p_date': today  // Pass app's current date
          },
        )
        .single();
    
    // Rest of function...
  }
}
```

#### **2.2 Update Task Tracking**
```dart
// In lib/services/grace_system_service.dart
static Future<bool> trackTaskCompletion({
  required String userId,
  required DateTime date,  // Already using app's date
  required String taskType,
  required bool completed,
}) async {
  // No changes needed - already uses app's date
}
```

#### **2.3 Update Manual Calculation**
```dart
// In lib/services/grace_system_service.dart
static Future<Map<String, dynamic>?> _calculateGraceStatusManually(
  String userId,
) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  
  // Use app's date for manual calculation
  for (var record in habitsData) {
    final recordDate = record['date'] as String;
    if (recordDate == today) {  // Compare with app's date
      // Calculate pieces...
    }
  }
}
```

### **Phase 3: Update All Date References**

#### **3.1 Entry Provider Updates**
```dart
// In lib/providers/entry_provider.dart
// All methods already use DateTime.now() - no changes needed
```

#### **3.2 Streak Calculations**
```dart
// In lib/services/user_data_service.dart
// Update streak calculations to use app's date
static Future<DataResult> _fetchUserStats(String userId) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  
  // Use today for streak calculations
  // No changes needed - already uses app's date
}
```

### **Phase 4: Test Scenarios**

#### **4.1 Timezone Testing**
- Test with different device timezones
- Verify date consistency across timezones
- Test edge cases (midnight transitions)

#### **4.2 Date Boundary Testing**
- Test at 11:59 PM local time
- Test at 12:01 AM local time
- Test across date boundaries

#### **4.3 Global User Testing**
- Test with users in different continents
- Verify grace pieces update correctly
- Test streak calculations

## **Database Changes Required**

### **1. Update Function Signature**
```sql
-- Add p_date parameter with default
CREATE OR REPLACE FUNCTION calculate_grace_days_from_habits(
  p_user_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
```

### **2. Update Function Logic**
```sql
-- Use p_date instead of calculated date
WHERE user_id = p_user_id AND date = p_date;
```

### **3. No Schema Changes**
- No new tables needed
- No new columns needed
- Existing data structure remains same

## **Flutter Code Changes Required**

### **1. Grace System Service**
- Update `getGraceStatus()` to pass date parameter
- No changes to `trackTaskCompletion()`
- Update manual calculation to use app's date

### **2. No Other Changes Needed**
- Entry provider already uses app's date
- User data service already uses app's date
- All date operations already use `DateTime.now()`

## **Testing Checklist**

### **Local Testing**
- [ ] Test with IST timezone
- [ ] Test with different device times
- [ ] Verify grace pieces update
- [ ] Test streak calculations

### **Global Testing**
- [ ] Test with UTC timezone
- [ ] Test with EST timezone
- [ ] Test with PST timezone
- [ ] Test with JST timezone

### **Edge Case Testing**
- [ ] Test at midnight (00:00)
- [ ] Test at 23:59
- [ ] Test date transitions
- [ ] Test with manual date changes

## **Deployment Plan**

### **Step 1: Update Database Function**
1. Deploy new function with date parameter
2. Test with existing data
3. Verify backward compatibility

### **Step 2: Update Flutter Code**
1. Update grace system service
2. Test with new function
3. Verify all features work

### **Step 3: Global Rollout**
1. Deploy to staging
2. Test with multiple timezones
3. Deploy to production
4. Monitor for issues

## **Rollback Plan**

### **If Issues Occur:**
1. Revert to hardcoded IST function
2. Update Flutter to not pass date parameter
3. Investigate and fix issues
4. Re-deploy with fixes

## **Monitoring**

### **Key Metrics to Watch:**
- Grace pieces update rate
- Streak calculation accuracy
- User complaints about timezone issues
- Database function performance

### **Alerts to Set:**
- Grace pieces not updating
- Streak calculations failing
- Database function errors
- High error rates in grace system

## **Conclusion**

**Passing date from app is the best solution because:**
1. **Simple**: Minimal code changes
2. **Reliable**: App controls date logic
3. **Global**: Works for all timezones
4. **Consistent**: Same date used throughout
5. **Maintainable**: Easy to debug and fix

**Implementation Priority:**
1. **High**: Update database function
2. **High**: Update Flutter grace service
3. **Medium**: Test with multiple timezones
4. **Low**: Add monitoring and alerts

**Estimated Time:**
- Database changes: 1 hour
- Flutter changes: 2 hours
- Testing: 4 hours
- Total: 7 hours
