# Performance Analysis - Streak Feature

## Current DB Calls & Calculations

### 1. **trackTaskCompletion()** - Called 4x/day (diary, affirmations, gratitude, self-care)

**DB Calls per task:**
- 1 select: `_getOrCreateTodayHabitsRecord()` (check if exists)
- 1 insert/update: Create/update habits_daily record
- 1 update: Update task completion flag
- 1 select: Get updated record (to calculate pieces)
- 1 update: Update grace_pieces_earned
- **1 select: ALL habits_daily records for user** ⚠️ EXPENSIVE
- 1 update: Update streaks table

**Total: 6-7 DB calls per task completion**

**Calculations:**
- Sum all pieces (fold operation on all habits_daily records)
- Calculate grace days: `floor(total / 10)`
- Simple math: O(n) where n = days user has been active

**Frequency:** 4 times per day per user

---

### 2. **getGraceStatus()** - Called on UI load/status check

**DB Calls:**
- **1 select: ALL habits_daily records for user** ⚠️ EXPENSIVE

**Calculations:**
- Sum all pieces (fold operation)
- Count today's tasks
- Calculate progress percentage
- Simple math: O(n)

**Frequency:** On home screen load, when checking grace status

---

### 3. **recalculateStreak()** - Called after entry save

**DB Calls:**
- 1 select: All entries (with entry_date)
- 1 select: user_settings (grace_enabled)
- 1 select: habits_daily for today
- Calls `getGraceStatus()` → **1 select: ALL habits_daily** ⚠️
- 1 select: streaks (current streak)
- 1 update: streaks table

**Total: 6-7 DB calls per entry save**

**Calculations:**
- Create set of entry dates: O(n)
- Count consecutive days: O(m) where m = streak length
- Simple date math

**Frequency:** Every time user saves entry (debounced 600ms)

---

## Performance Issues

### ⚠️ **CRITICAL: Fetching ALL habits_daily records**

**Problem:**
- `trackTaskCompletion()` fetches ALL habits_daily records every time
- `getGraceStatus()` fetches ALL habits_daily records
- For a user active 365 days = 365 records fetched every time

**Impact:**
- 4 tasks/day × 365 records = 1,460 record fetches per day per user
- Network overhead: ~50-100KB per fetch (depending on data)
- DB load: High query volume

### ⚠️ **Redundant Calculations**

**Problem:**
- `trackTaskCompletion()` recalculates total pieces every time
- `getGraceStatus()` also recalculates total pieces
- Both do same calculation independently

---

## Current Performance Metrics

**Per User Per Day:**
- DB calls: ~30-35 calls/day (4 tasks × 7 calls + entry saves)
- Data fetched: ~365 records × 5-6 times = ~1,825 records/day
- Network: ~100-200KB/day per user
- CPU: Minimal (simple math operations)

**For 1,000 Active Users:**
- DB calls: ~30,000-35,000 calls/day
- Data fetched: ~1.8M records/day
- Network: ~100-200MB/day

---

## Is This Bearable?

### ✅ **For Small Scale (< 1,000 users):**
- **Acceptable** - Modern DBs handle this easily
- Network overhead is minimal
- CPU usage is negligible

### ⚠️ **For Medium Scale (1,000-10,000 users):**
- **Borderline** - May need optimization
- DB load increases linearly
- Network costs add up

### ❌ **For Large Scale (> 10,000 users):**
- **Not optimal** - Needs optimization
- DB load becomes significant
- Network costs become expensive

---

## Optimization Recommendations

### **Option 1: Cache Total Pieces in streaks Table** ⭐ RECOMMENDED

**Change:**
- Store `grace_pieces_total` in streaks table (already doing this)
- Only recalculate when needed (not every task completion)
- Update incrementally: `total += new_pieces` instead of recalculating

**Benefits:**
- Reduce DB calls: 6-7 → 4-5 per task
- Eliminate expensive "fetch all habits_daily" query
- 50-70% reduction in DB load

**Implementation:**
- On task completion: Update today's pieces, increment total in streaks
- Only recalculate if data seems inconsistent

### **Option 2: Batch Updates**

**Change:**
- Don't update streaks table on every task completion
- Batch updates: Update once per day or on app close

**Benefits:**
- Reduce DB calls: 6-7 → 2-3 per task
- 60-70% reduction in DB load

**Trade-off:**
- Slight delay in grace days update (acceptable)

### **Option 3: Use DB Aggregation**

**Change:**
- Use SQL `SUM()` in query instead of fetching all records
- `SELECT SUM(grace_pieces_earned) FROM habits_daily WHERE user_id = ?`

**Benefits:**
- DB does calculation (optimized)
- Only returns single number, not all records
- 80-90% reduction in data transfer

**Trade-off:**
- Still one DB call, but much lighter

---

## Recommended Approach

**For Professional App:**
1. **Use Option 1 + Option 3** (Cache + DB aggregation)
2. **Keep incremental updates** in streaks table
3. **Use DB SUM()** when recalculation needed
4. **Batch streak recalculation** (not on every entry save)

**Expected Improvement:**
- DB calls: 30-35 → 10-15 per day per user
- Data transfer: 100-200KB → 10-20KB per day
- **70-80% reduction in load**

---

## Verdict

**Current State:** ⚠️ **Acceptable for small scale, needs optimization for scale**

**Professional App Standard:** Should optimize to reduce DB calls by 50-70%

**Priority:** Medium (works now, but will become bottleneck at scale)

