# Entry Meals Offline Fix — Plan

**Goal:** Fix ERRSYS153 by reading `entry_meals` (water_cups) from local SQLite instead of Supabase when offline.

---

## 1. Problem

**Location:** `lib/services/home_summary_service.dart` — `_fetchTodayProgress` (lines 187–196)

**Current behavior:** When building today's progress, `water_cups` is always fetched from Supabase:

```dart
int waterCups = 0;
if (entry != null) {
  final meals = await _supabase
      .from('entry_meals')
      .select('water_cups')
      .eq('entry_id', entry['id'] as String)
      .maybeSingle();
  if (meals != null) waterCups = (meals['water_cups'] ?? 0) as int;
}
```

**Issue:** Offline → Supabase call fails → ERRSYS153.

---

## 2. Solution

Read `entry_meals` from local SQLite. The table exists and is populated during Splash prefetch (EntryStorageHelper stores entries with `entry_meals`).

**Local table:** `entry_meals` — columns: `entry_id`, `breakfast`, `lunch`, `dinner`, `water_cups`.

---

## 3. Change

**File:** `lib/services/home_summary_service.dart`

**Replace** (lines 187–196):

```dart
int waterCups = 0;
if (entry != null) {
  final meals = await _supabase
      .from('entry_meals')
      .select('water_cups')
      .eq('entry_id', entry['id'] as String)
      .maybeSingle();
  if (meals != null) waterCups = (meals['water_cups'] ?? 0) as int;
}
```

**With:**

```dart
int waterCups = 0;
if (entry != null) {
  final db = await DatabaseManager().database;
  final mealsRows = await db.query(
    'entry_meals',
    columns: ['water_cups'],
    where: 'entry_id = ?',
    whereArgs: [entry['id'] as String],
    limit: 1,
  );
  if (mealsRows.isNotEmpty) {
    waterCups = mealsRows.first['water_cups'] as int? ?? 0;
  }
}
```

---

## 4. Scope

- **Files:** 1 (`home_summary_service.dart`)
- **Lines:** ~10
- **Imports:** None (DatabaseManager already imported)
- **Tables:** Uses existing `entry_meals`

---

## 5. Verification

- [ ] Online: Home shows correct water cups (from local, populated by prefetch)
- [ ] Offline: No ERRSYS153; water cups from local or 0

---

## 6. Rollback

Revert the block to the Supabase query.
