# Simplest Streak Feature Approach

## Core Principle: **Incremental Updates + Smart Recalculation**

---

## 🎯 **What We Track**

**In `streaks` table (already exists):**
- `current` - current streak count
- `freeze_credits` - grace days available (0-5)
- `grace_pieces_total` - total pieces earned (0-50 max)
- `last_entry_date` - last entry date (for gap detection)

**In `habits_daily` table (already exists):**
- `grace_pieces_earned` - pieces for that day (0-2.0)
- Task flags: `filled_affirmations`, `filled_gratitude`, `wrote_entry`, `self_care_completed_count`

---

## 📊 **Simple Flow**

### **1. App Startup (1 DB Call)**
```
Fetch streaks table → Load into local cache
If last_entry_date is old → Recalculate streak (only if needed)
```

### **2. Task Completion (2-3 DB Calls)**
```
Update habits_daily (task flag) → 1 call
Calculate today's pieces → In memory
Update streaks.grace_pieces_total incrementally → 1 call
Update streaks.freeze_credits if needed → 1 call (only if pieces reached 10)
```

### **3. Entry Save (1 DB Call)**
```
Save entry → 1 call
Update streak locally (increment if consecutive day)
Update streaks table → 1 call (only if streak changed)
```

### **4. Daily Recalculation (Background, 1 DB Call)**
```
Use DB SUM() to verify total pieces → 1 call
If mismatch → Recalculate and update
```

---

## 🔧 **Key Simplifications**

### **1. Incremental Piece Updates (Not Recalculation)**
**Current (BAD):**
```dart
// Fetches ALL habits_daily records (365+ records)
final allHabits = await _supabase.from('habits_daily').select('*').eq('user_id', userId);
// Recalculates total from all records
```

**Simple (GOOD):**
```dart
// Get current total from streaks table
final currentTotal = streak.grace_pieces_total;
// Add today's pieces
final newTotal = currentTotal + todayPieces;
// Update streaks table (1 record)
await _supabase.from('streaks').update({'grace_pieces_total': newTotal});
```

**DB Calls:** 365+ → 1 ✅

---

### **2. Use DB SUM() for Verification (Not Fetch All)**
**When needed (app startup, daily check):**
```dart
// DB does the calculation (optimized)
final result = await _supabase
  .from('habits_daily')
  .select('grace_pieces_earned')
  .eq('user_id', userId);
  
// Or use RPC function with SUM() - even better
```

**DB Calls:** Fetch all records → Single aggregated value ✅

---

### **3. Streak Calculation Only When Needed**
**Don't recalculate on every entry save**

**Recalculate only when:**
- App startup (if last_entry_date is old)
- Gap detected (missed days)
- User explicitly refreshes

**Otherwise:** Increment locally if consecutive day

---

### **4. Local Cache for Instant UI**
```dart
// Store in memory/Riverpod
class StreakCache {
  int current;
  int graceDays;
  double pieces;
  DateTime lastEntryDate;
}

// Update UI instantly
// Sync to DB in background (debounced 2-3 seconds)
```

---

## 📈 **DB Call Reduction**

### **Current Approach:**
- Task completion: 6-7 calls
- Entry save: 6-7 calls
- App startup: 3-4 calls
- **Total: ~30-35 calls/day**

### **Simple Approach:**
- Task completion: 2-3 calls (incremental update)
- Entry save: 1-2 calls (only if streak changes)
- App startup: 1 call (fetch streaks)
- Daily verification: 1 call (background)
- **Total: ~8-12 calls/day**

**Reduction: 70-80%** ✅

---

## 🌍 **Timezone Handling**

**Already handled correctly:**
- Dates stored as `YYYY-MM-DD` (no timezone)
- App uses `DateTime.now()` (local timezone)
- `entry_date` field is date-only
- No changes needed ✅

---

## 🔄 **Multi-Device Sync**

**Strategy: Last Write Wins**
- Each device updates `streaks` table directly
- On app startup: Fetch latest from DB
- If local cache differs from DB → Use DB value (source of truth)
- Works for all regions ✅

---

## 💾 **Implementation Changes**

### **1. Modify `trackTaskCompletion()`**
```dart
// OLD: Fetch all habits_daily, recalculate total
// NEW: Incremental update
final currentTotal = await _getCurrentPiecesTotal(userId);
final newTotal = currentTotal + todayPieces;
await _updatePiecesTotal(userId, newTotal);
```

### **2. Modify `getGraceStatus()`**
```dart
// OLD: Fetch all habits_daily
// NEW: Use DB SUM() or read from streaks table
final streak = await _getStreakData(userId);
return {
  'grace_days_available': streak.freezeCredits,
  'grace_pieces_total': streak.gracePiecesTotal,
  // Calculate today's pieces from today's habits_daily only
  'pieces_today': await _getTodayPieces(userId),
};
```

### **3. Modify `recalculateStreak()`**
```dart
// Only recalculate if:
// - App startup AND last_entry_date is old (>1 day)
// - Gap detected
// - User explicitly refreshes

// Otherwise: Increment locally if consecutive day
```

### **4. Add Local Cache**
```dart
// Riverpod provider for streak cache
final streakCacheProvider = StateNotifierProvider<StreakCacheNotifier, StreakCache>((ref) {
  return StreakCacheNotifier();
});

// Update UI instantly, sync to DB in background
```

---

## ✅ **Benefits**

1. **70-80% fewer DB calls**
2. **Faster UI** (local cache)
3. **Works offline** (cache + sync later)
4. **Multi-device safe** (DB is source of truth)
5. **Timezone safe** (date-only fields)
6. **Simple logic** (incremental updates)
7. **Scalable** (works for 1 user or 1M users)

---

## 🚨 **Edge Cases Handled**

1. **App reinstall after days:**
   - Fetch from DB on startup
   - Check gap between last_entry_date and today
   - Use grace days if available
   - Recalculate streak

2. **Multiple devices:**
   - Last write wins
   - Fetch on startup to sync

3. **Network failure:**
   - Update local cache
   - Queue DB write
   - Sync when online

4. **Data mismatch:**
   - Daily verification with DB SUM()
   - Recalculate if mismatch detected

---

## 📝 **Summary**

**Simplest approach:**
- Incremental updates (not recalculation)
- Local cache for instant UI
- DB SUM() for verification
- Recalculate only when needed
- **Result: 70-80% fewer DB calls, works everywhere**

