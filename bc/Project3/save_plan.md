# Save Functionality Implementation Plan
**Project:** Digital AI Journal Diary App  
**Feature:** Auto-save with Offline-First Architecture  
**Storage:** SQLite (sqflite) + Supabase Sync  
**Date:** October 9, 2025

---

## Executive Summary

Implement Google Keep-style auto-save functionality across all journaling screens with offline-first architecture using SQLite for local caching and Supabase for cloud sync. No explicit save buttons - changes sync automatically after user stops typing with visual feedback.

---

## Storage Strategy Decision: SQLite vs Hive

### Why SQLite (sqflite)?

**Advantages:**
- **Relational Structure**: Matches Supabase PostgreSQL schema perfectly
- **Complex Queries**: Support for JOINs, foreign keys, and analytical queries
- **ACID Compliance**: Better data integrity for critical user data
- **Migration Support**: Easy schema updates as app evolves
- **Flutter Maturity**: Well-tested with flutter_riverpod ecosystem
- **Offline Analytics**: Can run complex analytics queries locally

**Hive Disadvantages for This Use Case:**
- Limited relational capabilities
- No native JOIN support
- Harder to maintain schema consistency with Supabase
- More complex conflict resolution
- Limited query capabilities for analytics

**Decision:** Use SQLite (sqflite) for local caching with Supabase for cloud sync.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  (Morning Rituals, Wellness, Gratitude, Diary Screens)      │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                   State Management Layer                     │
│              (Riverpod Providers + Notifiers)               │
│  - EntryStateNotifier (debounced auto-save)                 │
│  - SyncStatusNotifier (syncing/saved/error)                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    Service Layer                             │
│  - EntryService (business logic)                            │
│  - SyncService (conflict resolution)                        │
└─────────┬───────────────────────────┬───────────────────────┘
          │                           │
┌─────────▼──────────┐    ┌──────────▼────────────┐
│  Local Database    │    │   Supabase Cloud      │
│  (SQLite/sqflite)  │◄───┤   (PostgreSQL)        │
│  - Offline cache   │    │   - Source of truth   │
│  - Fast reads      │    │   - Multi-device sync │
└────────────────────┘    └───────────────────────┘
```

---

## Database Schema Mapping

### SQLite Local Schema (mirrors Supabase)

```sql
-- Main entries table
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  entry_date TEXT NOT NULL,
  diary_text TEXT,
  mood_score INTEGER CHECK (mood_score >= 1 AND mood_score <= 5),
  tags TEXT, -- JSON array as text
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_synced INTEGER DEFAULT 0,
  last_sync_at TEXT
);

-- Entry affirmations
CREATE TABLE entry_affirmations (
  entry_id TEXT PRIMARY KEY,
  affirmations TEXT NOT NULL, -- JSONB array as text
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Entry priorities
CREATE TABLE entry_priorities (
  entry_id TEXT PRIMARY KEY,
  priorities TEXT NOT NULL, -- JSONB array as text
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Entry meals
CREATE TABLE entry_meals (
  entry_id TEXT PRIMARY KEY,
  breakfast TEXT,
  lunch TEXT,
  dinner TEXT,
  water_cups INTEGER DEFAULT 0 CHECK (water_cups >= 0 AND water_cups <= 8),
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Entry gratitude
CREATE TABLE entry_gratitude (
  entry_id TEXT PRIMARY KEY,
  grateful_items TEXT NOT NULL, -- JSONB array as text
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Entry self care
CREATE TABLE entry_self_care (
  entry_id TEXT PRIMARY KEY,
  sleep INTEGER DEFAULT 0,
  get_up_early INTEGER DEFAULT 0,
  fresh_air INTEGER DEFAULT 0,
  learn_new INTEGER DEFAULT 0,
  balanced_diet INTEGER DEFAULT 0,
  podcast INTEGER DEFAULT 0,
  me_moment INTEGER DEFAULT 0,
  hydrated INTEGER DEFAULT 0,
  read_book INTEGER DEFAULT 0,
  exercise INTEGER DEFAULT 0,
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Entry shower/bath
CREATE TABLE entry_shower_bath (
  entry_id TEXT PRIMARY KEY,
  took_shower INTEGER DEFAULT 0,
  note TEXT,
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Entry tomorrow notes
CREATE TABLE entry_tomorrow_notes (
  entry_id TEXT PRIMARY KEY,
  tomorrow_notes TEXT NOT NULL, -- JSONB array as text
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
);

-- Sync queue for offline changes
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id TEXT NOT NULL,
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL, -- 'insert', 'update', 'delete'
  data TEXT NOT NULL, -- JSON payload
  created_at TEXT NOT NULL,
  retry_count INTEGER DEFAULT 0
);
```

---

## Phase 1: Foundation & Infrastructure

**Duration:** Week 1  
**Goal:** Set up core architecture for auto-save functionality

### 1.1 Dependencies & Setup

**Add to `pubspec.yaml`:**
```yaml
dependencies:
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  path: ^1.8.3
```

### 1.2 Database Manager

**Create:** `lib/services/database/database_manager.dart`

```dart
class DatabaseManager {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'diary_app.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Create all tables with schema above
  }
}
```

### 1.3 Entry Models

**Create:** `lib/models/entry_models.dart` (enhance existing)

```dart
class Entry {
  final String id;
  final String userId;
  final DateTime entryDate;
  final String? diaryText;
  final int? moodScore;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final DateTime? lastSyncAt;
  
  // toJson, fromJson, copyWith methods
}

class EntryAffirmations {
  final String entryId;
  final List<AffirmationItem> affirmations;
  
  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'affirmations': affirmations.map((a) => a.toJson()).toList(),
  };
}

class AffirmationItem {
  final String text;
  final int order;
  
  Map<String, dynamic> toJson() => {'text': text, 'order': order};
}

// Similar models for Priorities, Gratitude, TomorrowNotes
```

### 1.4 Sync Status Provider

**Create:** `lib/providers/sync_status_provider.dart`

```dart
enum SyncStatus { idle, syncing, saved, error }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSavedAt;
  
  SyncState({
    required this.status,
    this.errorMessage,
    this.lastSavedAt,
  });
}

class SyncStatusNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState(status: SyncStatus.idle);
  
  void setSyncing() {
    state = SyncState(status: SyncStatus.syncing);
  }
  
  void setSaved() {
    state = SyncState(
      status: SyncStatus.saved,
      lastSavedAt: DateTime.now(),
    );
  }
  
  void setError(String message) {
    state = SyncState(
      status: SyncStatus.error,
      errorMessage: message,
    );
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncState>(
  () => SyncStatusNotifier(),
);
```

---

## Phase 2: Entry Service Layer

**Duration:** Week 1-2  
**Goal:** Implement core save/load operations with offline-first pattern

### 2.1 Local Database Service

**Create:** `lib/services/database/local_entry_service.dart`

```dart
class LocalEntryService {
  final DatabaseManager _dbManager;
  
  // Fetch today's entry (or any date)
  Future<Entry?> getEntryByDate(String userId, DateTime date) async {
    final db = await _dbManager.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final results = await db.query(
      'entries',
      where: 'user_id = ? AND entry_date = ?',
      whereArgs: [userId, dateStr],
    );
    
    if (results.isEmpty) return null;
    return Entry.fromJson(results.first);
  }
  
  // Upsert entry (insert or update)
  Future<void> upsertEntry(Entry entry) async {
    final db = await _dbManager.database;
    await db.insert(
      'entries',
      entry.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    // Add to sync queue
    await _addToSyncQueue(entry.id, 'entries', 'upsert', entry.toJson());
  }
  
  // Upsert affirmations
  Future<void> upsertAffirmations(EntryAffirmations affirmations) async {
    final db = await _dbManager.database;
    await db.insert(
      'entry_affirmations',
      affirmations.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await _addToSyncQueue(
      affirmations.entryId,
      'entry_affirmations',
      'upsert',
      affirmations.toJson(),
    );
  }
  
  // Similar methods for priorities, meals, gratitude, etc.
  
  // Get all entries from a date range
  Future<List<Entry>> getEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    // Implementation for history/analytics
  }
}
```

### 2.2 Supabase Sync Service

**Create:** `lib/services/sync/supabase_sync_service.dart`

```dart
class SupabaseSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalEntryService _localService;
  
  // Sync entry to Supabase
  Future<bool> syncEntry(Entry entry) async {
    try {
      await _supabase.from('entries').upsert(entry.toSupabaseJson());
      
      // Update local sync status
      await _localService.markAsSynced(entry.id);
      return true;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }
  
  // Sync affirmations to Supabase
  Future<bool> syncAffirmations(EntryAffirmations affirmations) async {
    try {
      await _supabase.from('entry_affirmations').upsert({
        'entry_id': affirmations.entryId,
        'affirmations': affirmations.affirmations.map((a) => a.toJson()).toList(),
      });
      return true;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }
  
  // Pull latest data from Supabase (for multi-device sync)
  Future<Entry?> fetchEntryFromCloud(String userId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final response = await _supabase
        .from('entries')
        .select()
        .eq('user_id', userId)
        .eq('entry_date', dateStr)
        .maybeSingle();
    
    if (response == null) return null;
    return Entry.fromSupabaseJson(response);
  }
  
  // Process sync queue (for offline changes)
  Future<void> processSyncQueue() async {
    final queue = await _localService.getSyncQueue();
    
    for (final item in queue) {
      final success = await _syncQueueItem(item);
      if (success) {
        await _localService.removeSyncQueueItem(item.id);
      } else {
        await _localService.incrementRetryCount(item.id);
      }
    }
  }
}
```

### 2.3 Unified Entry Service

**Create:** `lib/services/entry_service.dart`

```dart
class EntryService {
  final LocalEntryService _localService;
  final SupabaseSyncService _syncService;
  
  // Load entry for a specific date (offline-first)
  Future<EntryData?> loadEntryForDate(String userId, DateTime date) async {
    // 1. Try local first
    final localEntry = await _localService.getEntryByDate(userId, date);
    
    // 2. If online and not synced, fetch from cloud
    if (await _isOnline()) {
      final cloudEntry = await _syncService.fetchEntryFromCloud(userId, date);
      
      // 3. Merge and resolve conflicts (last-write-wins)
      if (cloudEntry != null) {
        if (localEntry == null || 
            cloudEntry.updatedAt.isAfter(localEntry.updatedAt)) {
          await _localService.upsertEntry(cloudEntry);
          return _buildEntryData(cloudEntry);
        }
      }
    }
    
    return localEntry != null ? _buildEntryData(localEntry) : null;
  }
  
  // Save diary text with auto-save
  Future<void> saveDiaryText(String userId, DateTime date, String text) async {
    // 1. Get or create entry
    final entry = await _getOrCreateEntry(userId, date);
    
    // 2. Update local database immediately
    final updatedEntry = entry.copyWith(
      diaryText: text,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _localService.upsertEntry(updatedEntry);
    
    // 3. Sync to cloud (non-blocking)
    _syncService.syncEntry(updatedEntry).then((success) {
      if (!success) {
        // Will retry via sync queue
        print('Sync failed, queued for retry');
      }
    });
  }
  
  // Save affirmations
  Future<void> saveAffirmations(
    String userId,
    DateTime date,
    List<AffirmationItem> affirmations,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);
    
    final entryAffirmations = EntryAffirmations(
      entryId: entry.id,
      affirmations: affirmations,
    );
    
    await _localService.upsertAffirmations(entryAffirmations);
    _syncService.syncAffirmations(entryAffirmations);
  }
  
  // Similar methods for priorities, meals, gratitude, etc.
  
  Future<Entry> _getOrCreateEntry(String userId, DateTime date) async {
    final existing = await _localService.getEntryByDate(userId, date);
    if (existing != null) return existing;
    
    // Create new entry
    final newEntry = Entry(
      id: const Uuid().v4(),
      userId: userId,
      entryDate: date,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: [],
      isSynced: false,
    );
    
    await _localService.upsertEntry(newEntry);
    return newEntry;
  }
}
```

---

## Phase 3: Auto-Save State Management

**Duration:** Week 2  
**Goal:** Implement debounced auto-save with Riverpod

### 3.1 Entry State Notifier

**Create:** `lib/providers/entry_provider.dart`

```dart
class EntryState {
  final Entry? entry;
  final EntryAffirmations? affirmations;
  final EntryPriorities? priorities;
  final EntryMeals? meals;
  final EntryGratitude? gratitude;
  final EntrySelfCare? selfCare;
  final EntryTomorrowNotes? tomorrowNotes;
  final bool isLoading;
  
  EntryState({
    this.entry,
    this.affirmations,
    this.priorities,
    this.meals,
    this.gratitude,
    this.selfCare,
    this.tomorrowNotes,
    this.isLoading = false,
  });
  
  EntryState copyWith({...}) => EntryState(...);
}

class EntryNotifier extends Notifier<EntryState> {
  Timer? _debounceTimer;
  final EntryService _entryService = EntryService();
  
  @override
  EntryState build() => EntryState();
  
  // Load entry for selected date
  Future<void> loadEntry(String userId, DateTime date) async {
    state = state.copyWith(isLoading: true);
    
    final entryData = await _entryService.loadEntryForDate(userId, date);
    
    state = EntryState(
      entry: entryData?.entry,
      affirmations: entryData?.affirmations,
      priorities: entryData?.priorities,
      meals: entryData?.meals,
      gratitude: entryData?.gratitude,
      selfCare: entryData?.selfCare,
      tomorrowNotes: entryData?.tomorrowNotes,
      isLoading: false,
    );
  }
  
  // Update diary text with debounced auto-save
  void updateDiaryText(String userId, DateTime date, String text) {
    // Update UI immediately (optimistic update)
    state = state.copyWith(
      entry: state.entry?.copyWith(diaryText: text),
    );
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Set sync status to syncing
    ref.read(syncStatusProvider.notifier).setSyncing();
    
    // Start new debounce timer (600ms)
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveDiaryText(userId, date, text);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
      }
    });
  }
  
  // Update affirmations with debounced auto-save
  void updateAffirmations(
    String userId,
    DateTime date,
    List<AffirmationItem> affirmations,
  ) {
    // Optimistic update
    state = state.copyWith(
      affirmations: EntryAffirmations(
        entryId: state.entry?.id ?? '',
        affirmations: affirmations,
      ),
    );
    
    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();
    
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveAffirmations(userId, date, affirmations);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
      }
    });
  }
  
  // Similar methods for priorities, meals, gratitude, etc.
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final entryProvider = NotifierProvider<EntryNotifier, EntryState>(
  () => EntryNotifier(),
);
```

---

## Phase 4: UI Integration - Daily Diary Screen

**Duration:** Week 3  
**Goal:** Integrate auto-save into Daily Diary screen

### 4.1 Update Daily Diary Screen

**Modify:** `lib/screens/new_diary_screen.dart`

```dart
class _NewDiaryScreenState extends ConsumerState<NewDiaryScreen> {
  final TextEditingController _diaryController = TextEditingController();
  bool _isInitialized = false;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Load entry data when screen mounts or date changes
    final selectedDate = ref.watch(selectedDateProvider);
    final userId = ref.read(authControllerProvider).user?.id;
    
    if (userId != null && !_isInitialized) {
      _loadEntryData(userId, selectedDate);
      _isInitialized = true;
    }
  }
  
  Future<void> _loadEntryData(String userId, DateTime date) async {
    await ref.read(entryProvider.notifier).loadEntry(userId, date);
    
    // Update text controller with loaded data
    final entryState = ref.read(entryProvider);
    if (entryState.entry?.diaryText != null) {
      _diaryController.text = entryState.entry!.diaryText!;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final syncState = ref.watch(syncStatusProvider);
    final userId = ref.watch(authControllerProvider).user?.id;
    
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showDatePicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('MMM d, y').format(selectedDate)),
              const SizedBox(width: 4),
              Icon(Icons.calendar_today, size: 16),
            ],
          ),
        ),
        actions: [
          // Sync status indicator
          _buildSyncStatusIcon(syncState),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearContent,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'diary'),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Greeting section...
            
            // Diary text field with auto-save
            Expanded(
              child: TextField(
                controller: _diaryController,
                onChanged: (text) {
                  if (userId != null) {
                    ref.read(entryProvider.notifier).updateDiaryText(
                      userId,
                      selectedDate,
                      text,
                    );
                  }
                },
                // ... rest of TextField config
              ),
            ),
            
            // Status bar with sync indicator
            _buildStatusBar(syncState),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSyncStatusIcon(SyncState syncState) {
    switch (syncState.status) {
      case SyncStatus.syncing:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case SyncStatus.saved:
        return Icon(Icons.cloud_done, color: Colors.green[600]);
      case SyncStatus.error:
        return Icon(Icons.cloud_off, color: Colors.red[600]);
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildStatusBar(SyncState syncState) {
    String statusText = 'Not saved';
    Color statusColor = Colors.grey[500]!;
    
    switch (syncState.status) {
      case SyncStatus.syncing:
        statusText = 'Syncing...';
        statusColor = Colors.blue[600]!;
        break;
      case SyncStatus.saved:
        statusText = 'Auto-saved';
        statusColor = Colors.green[600]!;
        break;
      case SyncStatus.error:
        statusText = 'Save failed - will retry';
        statusColor = Colors.red[600]!;
        break;
      default:
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getSyncStatusIcon(syncState.status),
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ],
          ),
          if (syncState.lastSavedAt != null)
            Text(
              DateFormat('hh:mm a').format(syncState.lastSavedAt!),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
        ],
      ),
    );
  }
  
  IconData _getSyncStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.saved:
        return Icons.check_circle;
      case SyncStatus.error:
        return Icons.error_outline;
      default:
        return Icons.circle_outlined;
    }
  }
}
```

---

## Phase 5: UI Integration - Morning Rituals Screen

**Duration:** Week 3-4  
**Goal:** Integrate auto-save for affirmations and priorities

### 5.1 Update Morning Rituals Screen

**Modify:** `lib/screens/morning_rituals_screen.dart`

Key changes:
- Remove explicit save buttons from `DynamicFieldSection`
- Connect to `entryProvider` for auto-save
- Load existing data on mount
- Debounce each field change
- Show sync status in AppBar

```dart
class _MorningRitualsScreenState extends ConsumerState<MorningRitualsScreen> {
  List<TextEditingController> _affirmationControllers = [];
  List<TextEditingController> _priorityControllers = [];
  bool _isInitialized = false;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final selectedDate = ref.watch(selectedDateProvider);
    final userId = ref.read(authControllerProvider).user?.id;
    
    if (userId != null && !_isInitialized) {
      _loadEntryData(userId, selectedDate);
      _isInitialized = true;
    }
  }
  
  Future<void> _loadEntryData(String userId, DateTime date) async {
    await ref.read(entryProvider.notifier).loadEntry(userId, date);
    
    final entryState = ref.read(entryProvider);
    
    // Populate affirmations
    if (entryState.affirmations != null) {
      _affirmationControllers.clear();
      for (var item in entryState.affirmations!.affirmations) {
        final controller = TextEditingController(text: item.text);
        controller.addListener(() => _onAffirmationChanged());
        _affirmationControllers.add(controller);
      }
    }
    
    // Populate priorities
    if (entryState.priorities != null) {
      _priorityControllers.clear();
      for (var item in entryState.priorities!.priorities) {
        final controller = TextEditingController(text: item.text);
        controller.addListener(() => _onPriorityChanged());
        _priorityControllers.add(controller);
      }
    }
    
    setState(() {});
  }
  
  void _onAffirmationChanged() {
    final userId = ref.read(authControllerProvider).user?.id;
    final selectedDate = ref.read(selectedDateProvider);
    
    if (userId == null) return;
    
    final affirmations = _affirmationControllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.isNotEmpty)
        .map((entry) => AffirmationItem(
              text: entry.value.text.trim(),
              order: entry.key + 1,
            ))
        .toList();
    
    ref.read(entryProvider.notifier).updateAffirmations(
      userId,
      selectedDate,
      affirmations,
    );
  }
  
  void _onPriorityChanged() {
    final userId = ref.read(authControllerProvider).user?.id;
    final selectedDate = ref.read(selectedDateProvider);
    
    if (userId == null) return;
    
    final priorities = _priorityControllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.isNotEmpty)
        .map((entry) => PriorityItem(
              text: entry.value.text.trim(),
              order: entry.key + 1,
            ))
        .toList();
    
    ref.read(entryProvider.notifier).updatePriorities(
      userId,
      selectedDate,
      priorities,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStatusProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Morning Rituals'),
        actions: [
          _buildSyncStatusIcon(syncState),
        ],
      ),
      // ... rest of UI
    );
  }
}
```

---

## Phase 6: Remaining Screens Integration

**Duration:** Week 4-5  
**Goal:** Integrate auto-save for all remaining screens

### 6.1 Wellness Tracker Screen

**Files to modify:**
- `lib/screens/wellness_tracker_screen.dart`

**Data to save:**
- Meals (breakfast, lunch, dinner)
- Water cups (0-8)
- Self-care checkboxes (10 items)
- Shower/bath notes

**Implementation pattern:**
- Same as Morning Rituals
- Connect each field to `entryProvider.notifier.updateMeals()`, `updateSelfCare()`, etc.
- Load existing data on mount

### 6.2 Gratitude & Reflection Screen

**Files to modify:**
- `lib/screens/gratitude_reflection_screen.dart`

**Data to save:**
- Gratitude items (6 text fields)
- Tomorrow notes (4 text fields)

**Implementation pattern:**
- Connect to `entryProvider.notifier.updateGratitude()`, `updateTomorrowNotes()`
- Debounced auto-save on each change

---

## Phase 7: Sync Queue & Background Sync

**Duration:** Week 5-6  
**Goal:** Handle offline mode and background sync

### 7.1 Connectivity Monitoring

**Create:** `lib/services/sync/connectivity_service.dart`

```dart
class ConnectivityService {
  final _connectivityController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  
  void startMonitoring() {
    Timer.periodic(const Duration(seconds: 30), (_) async {
      final connected = await isConnected;
      _connectivityController.add(connected);
    });
  }
}
```

### 7.2 Background Sync Worker

**Create:** `lib/services/sync/sync_worker.dart`

```dart
class SyncWorker {
  final SupabaseSyncService _syncService;
  final LocalEntryService _localService;
  
  Future<void> syncPendingChanges() async {
    final queue = await _localService.getSyncQueue();
    
    print('Processing ${queue.length} pending sync items');
    
    for (final item in queue) {
      try {
        await _processSyncItem(item);
        await _localService.removeSyncQueueItem(item.id);
      } catch (e) {
        print('Sync failed for item ${item.id}: $e');
        await _localService.incrementRetryCount(item.id);
        
        // Stop retrying after 5 attempts
        if (item.retryCount >= 5) {
          await _localService.markSyncItemFailed(item.id);
        }
      }
    }
  }
  
  Future<void> _processSyncItem(SyncQueueItem item) async {
    switch (item.tableName) {
      case 'entries':
        await _syncService.syncEntry(Entry.fromJson(item.data));
        break;
      case 'entry_affirmations':
        await _syncService.syncAffirmations(
          EntryAffirmations.fromJson(item.data),
        );
        break;
      // ... handle other tables
    }
  }
}
```

### 7.3 App Lifecycle Sync

**Modify:** `lib/main.dart`

```dart
class MyApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start connectivity monitoring
    ref.read(connectivityServiceProvider).startMonitoring();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync when app comes back to foreground
      ref.read(syncWorkerProvider).syncPendingChanges();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

---

## Phase 8: Conflict Resolution

**Duration:** Week 6  
**Goal:** Handle multi-device sync conflicts

### 8.1 Conflict Resolution Strategy

**Last-Write-Wins with Diff Preview:**
- Compare `updated_at` timestamps
- Cloud version newer → overwrite local
- Local version newer → push to cloud
- Show user diff if both modified recently (< 5 minutes apart)

**Create:** `lib/services/sync/conflict_resolver.dart`

```dart
class ConflictResolver {
  Future<Entry> resolveEntryConflict(
    Entry localEntry,
    Entry cloudEntry,
  ) async {
    // Simple last-write-wins
    if (cloudEntry.updatedAt.isAfter(localEntry.updatedAt)) {
      return cloudEntry;
    }
    return localEntry;
  }
  
  // For critical conflicts, show user dialog
  Future<Entry?> showConflictDialog(
    BuildContext context,
    Entry localEntry,
    Entry cloudEntry,
  ) async {
    return showDialog<Entry>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This entry was modified on another device.'),
            const SizedBox(height: 16),
            Text('Local: ${localEntry.diaryText?.substring(0, 50)}...'),
            Text('Cloud: ${cloudEntry.diaryText?.substring(0, 50)}...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, localEntry),
            child: const Text('Keep Local'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, cloudEntry),
            child: const Text('Use Cloud'),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 9: Testing & Edge Cases

**Duration:** Week 7  
**Goal:** Comprehensive testing and edge case handling

### 9.1 Unit Tests

**Create:** `test/services/entry_service_test.dart`

```dart
void main() {
  group('EntryService', () {
    test('creates new entry if none exists', () async {
      // Test auto-creation of entries
    });
    
    test('updates existing entry', () async {
      // Test update flow
    });
    
    test('debounces rapid changes', () async {
      // Test debounce logic
    });
    
    test('handles offline mode gracefully', () async {
      // Test offline functionality
    });
    
    test('syncs pending changes on reconnect', () async {
      // Test sync queue processing
    });
  });
}
```

### 9.2 Edge Cases to Handle

1. **Rapid date switching:** Cancel pending debounce timers
2. **App killed during save:** Sync queue ensures no data loss
3. **Network timeout:** Retry with exponential backoff
4. **Large text entries:** Chunk if > 1MB (unlikely for text)
5. **Empty entries:** Don't create entry row until first real data
6. **Concurrent edits:** Last-write-wins with timestamp
7. **Clock skew:** Use server timestamps from Supabase
8. **Auth expiry mid-save:** Queue for retry after re-auth

---

## Phase 10: Performance Optimization

**Duration:** Week 7-8  
**Goal:** Optimize for production performance

### 10.1 Database Indexing

```sql
-- SQLite indexes for fast queries
CREATE INDEX idx_entries_user_date ON entries(user_id, entry_date);
CREATE INDEX idx_entries_sync ON entries(is_synced, updated_at);
CREATE INDEX idx_sync_queue_entry ON sync_queue(entry_id, created_at);
```

### 10.2 Lazy Loading

- Load only visible date's data
- Prefetch adjacent dates in background
- Cache last 7 days in memory

### 10.3 Memory Management

- Dispose controllers properly
- Cancel timers on screen dispose
- Limit sync queue to 1000 items (archive old failures)

---

## Implementation Checklist

### Phase 1: Foundation ✓
- [ ] Add sqflite dependencies
- [ ] Create DatabaseManager
- [ ] Define SQLite schema
- [ ] Create Entry models
- [ ] Setup SyncStatusProvider

### Phase 2: Services ✓
- [ ] LocalEntryService (SQLite operations)
- [ ] SupabaseSyncService (cloud sync)
- [ ] EntryService (unified interface)
- [ ] Sync queue implementation

### Phase 3: State Management ✓
- [ ] EntryNotifier with debounce
- [ ] Auto-save helpers
- [ ] Date change handling

### Phase 4: Daily Diary ✓
- [ ] Load entry on mount
- [ ] Auto-save diary text
- [ ] Sync status indicator
- [ ] Status bar updates

### Phase 5: Morning Rituals ✓
- [ ] Load affirmations/priorities
- [ ] Auto-save on change
- [ ] Remove explicit save buttons
- [ ] Sync status in AppBar

### Phase 6: Remaining Screens ✓
- [ ] Wellness Tracker integration
- [ ] Gratitude & Reflection integration
- [ ] Mood score saving
- [ ] Tags saving

### Phase 7: Background Sync ✓
- [ ] Connectivity monitoring
- [ ] Sync worker
- [ ] App lifecycle hooks
- [ ] Retry logic

### Phase 8: Conflict Resolution ✓
- [ ] Last-write-wins logic
- [ ] Conflict dialog (optional)
- [ ] Server timestamp sync

### Phase 9: Testing ✓
- [ ] Unit tests for services
- [ ] Widget tests for screens
- [ ] Integration tests
- [ ] Edge case handling

### Phase 10: Optimization ✓
- [ ] Database indexing
- [ ] Lazy loading
- [ ] Memory management
- [ ] Performance profiling

---

## Success Metrics

**User Experience:**
- Auto-save latency < 1s
- Sync status visible within 100ms
- No data loss in offline mode
- Conflict resolution success rate > 95%

**Technical:**
- Database query time < 50ms
- Sync queue processing < 5s
- Memory usage < 100MB
- Battery impact < 2% per hour

**Reliability:**
- Crash-free sessions > 99.5%
- Successful sync rate > 98%
- Data consistency across devices > 99%

---

## Risk Mitigation

**Data Loss:**
- Multi-layered: SQLite + Supabase + sync queue
- Automated backups to Supabase every 5 minutes
- Export functionality for user control

**Performance:**
- Debouncing reduces API calls by 80%
- Indexing keeps queries fast
- Lazy loading prevents memory bloat

**Conflicts:**
- Last-write-wins is simple and predictable
- Timestamps prevent most conflicts
- User override available for edge cases

**Offline Mode:**
- Full functionality without network
- Sync queue ensures eventual consistency
- Clear UI feedback for sync status

---

## Future Enhancements

**Phase 11+:**
- Real-time sync via Supabase Realtime
- Version history per entry
- Undo/redo functionality
- Rich text formatting
- Voice-to-text integration
- Attachment support (images, audio)
- End-to-end encryption option
- Multi-device collaboration indicators

---

## Conclusion

This plan implements robust, Google Keep-style auto-save functionality with offline-first architecture using SQLite for local storage and Supabase for cloud sync. The phased approach ensures stable progress while maintaining existing functionality.

**Key Benefits:**
- No data loss with multi-layered persistence
- Fast, responsive UI with optimistic updates
- Works offline with background sync
- Scalable architecture for future features
- Clean separation of concerns

**Timeline:** 8 weeks for complete implementation  
**Team:** 1-2 developers  
**Priority:** High (core user experience feature)

