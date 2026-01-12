# Dynamic Streak Motivational Messages - Implementation Plan

## 🎯 Objective
Replace hardcoded "🔥 You're on fire! Keep it going!" with dynamic, streak-based motivational messages that rotate based on user's current streak and day.

---

## 📋 Approach

### Strategy
- **Session-based rotation**: Message selected on screen load/refresh
- **Hash-based selection**: Use `hash(streak + day)` to pick message from range
- **Same message for session**: Stable during app session
- **Different each day**: Users see variety over time
- **All messages shown**: As users open app 2-3 times/day, they'll see all messages in their streak range

### How It Works
```
User opens app → Get current streak → Determine range → Hash(streak + day) → Select message → Display
```

---

## 💬 Message Library

### **0 days (No streak yet)**
```dart
[
  "🌟 Every journey begins with a single step!",
  "✨ Ready to start your streak today?",
  "💫 Your first entry is just a tap away!",
]
```

### **1 day**
```dart
[
  "🎉 Great start! Keep the momentum going!",
  "✨ Day one done! You're building something amazing!",
  "🌟 You've taken the first step! Keep it up!",
]
```

### **2-3 days**
```dart
[
  "🔥 You're building a habit! Keep going!",
  "💪 Two days strong! You're on the right track!",
  "✨ Consistency is key! You're doing great!",
]
```

### **4-7 days**
```dart
[
  "🔥 You're on fire! Keep it going!",
  "💪 A week of reflection! Amazing progress!",
  "🌟 You're building a powerful habit!",
]
```

### **8-14 days**
```dart
[
  "🔥 Two weeks strong! You're unstoppable!",
  "💫 Your consistency is inspiring!",
  "✨ You're creating a beautiful routine!",
]
```

### **15-30 days**
```dart
[
  "🔥 Three weeks! You're unstoppable!",
  "💪 A month of growth! Incredible dedication!",
  "🌟 You're building something special!",
]
```

### **31-60 days**
```dart
[
  "🔥 Over a month! You're a journaling champion!",
  "💫 Your commitment is inspiring!",
  "✨ Two months strong! Keep the fire burning!",
]
```

### **61+ days**
```dart
[
  "🔥 You're a journaling master! Keep it going!",
  "💪 Your dedication is incredible!",
  "🌟 You're an inspiration! Keep shining!",
]
```

---

## 🔧 Implementation Details

### Step 1: Create Message Service
**File**: `lib/services/streak_motivation_service.dart`

**Purpose**: Centralized service to get motivational message based on streak

**Structure**:
```dart
class StreakMotivationService {
  // Message library organized by streak ranges
  static final Map<String, List<String>> _messages = {
    '0': [...],      // 0 days
    '1': [...],      // 1 day
    '2-3': [...],    // 2-3 days
    '4-7': [...],    // 4-7 days
    '8-14': [...],   // 8-14 days
    '15-30': [...],  // 15-30 days
    '31-60': [...],  // 31-60 days
    '61+': [...],    // 61+ days
  };
  
  /// Get motivational message for current streak
  /// Uses hash(streak + day) to select message consistently for the day
  static String getMotivationalMessage(int currentStreak) {
    // Determine range
    final range = _getStreakRange(currentStreak);
    
    // Get messages for this range
    final messages = _messages[range] ?? _messages['0']!;
    
    // Generate hash from streak + current date
    final today = DateTime.now();
    final dayKey = '${today.year}-${today.month}-${today.day}';
    final hashInput = '$currentStreak-$dayKey';
    final hash = hashInput.hashCode;
    
    // Select message using hash (consistent for the day)
    final index = hash.abs() % messages.length;
    return messages[index];
  }
  
  /// Determine streak range key
  static String _getStreakRange(int streak) {
    if (streak == 0) return '0';
    if (streak == 1) return '1';
    if (streak >= 2 && streak <= 3) return '2-3';
    if (streak >= 4 && streak <= 7) return '4-7';
    if (streak >= 8 && streak <= 14) return '8-14';
    if (streak >= 15 && streak <= 30) return '15-30';
    if (streak >= 31 && streak <= 60) return '31-60';
    return '61+'; // 61 and above
  }
}
```

### Step 2: Update Home Screen
**File**: `lib/screens/home_screen.dart`

**Location**: `_buildStreakSection()` method (around line 630)

**Changes**:
1. Get current streak from `homeSummaryProvider`
2. Call `StreakMotivationService.getMotivationalMessage(streak)`
3. Replace hardcoded text with dynamic message

**Code**:
```dart
// Replace this:
Text(
  '🔥 You\'re on fire! Keep it going!',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.primary,
  ),
),

// With this:
Text(
  StreakMotivationService.getMotivationalMessage(currentStreakValue),
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.primary,
  ),
),
```

---

## 📊 How It Works

### Example Flow: User with 2-day streak

**Day 1:**
- User opens app → Streak: 2 → Range: "2-3" → Hash(2 + "2025-01-15") → Index: 0 → Message: "🔥 You're building a habit! Keep going!"
- User opens app again → Same hash → Same message (stable for session)
- User closes app

**Day 2:**
- User opens app → Streak: 3 → Range: "2-3" → Hash(3 + "2025-01-16") → Index: 1 → Message: "💪 Two days strong! You're on the right track!"
- User opens app again → Same hash → Same message
- User closes app

**Day 3:**
- User opens app → Streak: 4 → Range: "4-7" → Hash(4 + "2025-01-17") → Index: 0 → Message: "🔥 You're on fire! Keep it going!"

### Key Points:
- **Same day, same message**: Hash includes date, so message stays consistent for the day
- **Different day, different message**: Date changes, so hash changes, different message
- **All messages shown**: As user opens app multiple times and streak changes, they see all messages in their range
- **Range-based**: Messages change when user moves to different streak range

---

## 🎯 Edge Cases

### Edge Case 1: Streak Resets to 0
**Handling**: Shows "0 days" messages (encouraging, not demotivating)

### Edge Case 2: Streak Increases Mid-Day
**Handling**: Message stays same for the day (based on date hash), changes next day

### Edge Case 3: User Opens App Multiple Times Same Day
**Handling**: Same message shown (stable, not distracting)

### Edge Case 4: Streak Data Not Available
**Handling**: Default to "0 days" messages (safe fallback)

### Edge Case 5: Negative Streak (shouldn't happen, but safety)
**Handling**: Treat as 0 days

---

## 📝 Implementation Steps

### Step 1: Create Service File
1. Create `lib/services/streak_motivation_service.dart`
2. Add all message arrays
3. Implement `getMotivationalMessage()` method
4. Implement `_getStreakRange()` helper

### Step 2: Update Home Screen
1. Import `streak_motivation_service.dart`
2. Get current streak from provider
3. Replace hardcoded text with `StreakMotivationService.getMotivationalMessage(streak)`

### Step 3: Test
1. Test with streak = 0
2. Test with streak = 1
3. Test with streak = 2-3 (verify rotation)
4. Test with streak = 4-7
5. Test with higher streaks
6. Test same day multiple opens (should show same message)
7. Test next day (should show different message)

---

## ✅ Success Criteria

1. ✅ Message changes based on streak range
2. ✅ Same message for entire session (same day)
3. ✅ Different message each day
4. ✅ All messages in range are shown over time
5. ✅ Always motivational (never demotivating)
6. ✅ Handles edge cases gracefully

---

## 🔍 Technical Details

### Hash Function
- Uses Dart's built-in `hashCode` on string: `'$streak-$dayKey'`
- Ensures deterministic selection based on streak + date
- Modulo operation ensures index stays within array bounds

### Message Selection
```dart
final hashInput = '$currentStreak-$dayKey';  // e.g., "2-2025-01-15"
final hash = hashInput.hashCode;              // Generate hash
final index = hash.abs() % messages.length;   // Get index (0 to length-1)
return messages[index];                        // Return message
```

### Why This Works
- **Deterministic**: Same input (streak + day) = same output
- **Distributed**: Hash distributes evenly across messages
- **Simple**: No database needed, no state management
- **Fast**: O(1) lookup, no performance impact

---

## 📌 Notes

- **No database storage**: Messages are in code, easy to update
- **No state management**: Stateless service, called on demand
- **Future enhancement**: Could add user preferences or A/B testing
- **Message updates**: Easy to add/remove messages by editing arrays

---

**Status**: ✅ Plan Complete - Ready for Implementation
