import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database/local_entry_service.dart';
import 'sync/supabase_sync_service.dart';
import '../models/entry_models.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';

class EntryService {
  final LocalEntryService _localService = LocalEntryService();
  final SupabaseSyncService _syncService = SupabaseSyncService();
  final Connectivity _connectivity = Connectivity();

  // Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;

      // Additional check with actual internet connection
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logLowError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS129',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'operation': 'check_connectivity'},
        ),
      );
      return false;
    }
  }

  // Load entry for a specific date (server-first to prevent race conditions)
  Future<EntryData?> loadEntryForDate(String userId, DateTime date) async {
    // Use the date as-is (local date from device)
    // entry_date is stored as date only (no time), so we use local date directly
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    try {
      // 1. If online, fetch from server FIRST to get latest data (prevents race condition)
      // This ensures server data (from other devices) is loaded before local unsynced data
      Entry? cloudEntry;
      if (await _isOnline()) {
        try {
          cloudEntry = await _syncService.fetchEntryFromCloud(userId, dateOnly);
        } catch (e) {
          await ErrorLoggingService.logError(
            ErrorContext.fromException(
            errorCode: 'ERRSYS186',
              severity: ErrorSeverity.medium,
              exception: e,
              stackTrace: StackTrace.current,
            errorContext: {
              'user_id': userId,
              'date': dateOnly.toIso8601String().split('T')[0],
              'operation': 'load_entry_fetch_cloud',
            },
            ),
          );
          // Continue with local data if cloud fetch fails
        }
      }
      
      // 2. Get local entry
      final localEntry = await _localService.getEntryByDate(userId, dateOnly);

      // 3. Merge and resolve conflicts (server wins if newer)
      if (cloudEntry != null) {
        if (localEntry == null || 
            cloudEntry.updatedAt.isAfter(localEntry.updatedAt)) {
          // Server data is newer or local doesn't exist - use server data
          await _localService.upsertEntry(cloudEntry);
          return _buildEntryDataParallel(cloudEntry);
        } else if (localEntry.updatedAt.isAfter(cloudEntry.updatedAt)) {
          // Local data is newer - use local (will sync later)
          return _buildEntryDataParallel(localEntry);
        } else {
          // Same timestamp - use server data (source of truth)
          await _localService.upsertEntry(cloudEntry);
          return _buildEntryDataParallel(cloudEntry);
        }
      }

      // 4. If no cloud entry, use local entry
      return localEntry != null ? _buildEntryDataParallel(localEntry) : null;
      
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS187',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'user_id': userId,
          'date': dateOnly.toIso8601String().split('T')[0],
          'operation': 'load_entry_for_date',
        },
        ),
      );
      // Return null on error - entry screen will handle empty state
      return null;
    }
  }

  // Build complete entry data with all related fields
  Future<EntryData> _buildEntryDataParallel(Entry entry) async {
    final results = await Future.wait([
      _localService.getAffirmations(entry.id),
      _localService.getPriorities(entry.id),
      _localService.getMeals(entry.id),
      _localService.getGratitude(entry.id),
      _localService.getSelfCare(entry.id),
      _localService.getShowerBath(entry.id),
      _localService.getTomorrowNotes(entry.id),
    ]);

    return EntryData(
      entry: entry,
      affirmations: results[0] as EntryAffirmations?,
      priorities: results[1] as EntryPriorities?,
      meals: results[2] as EntryMeals?,
      gratitude: results[3] as EntryGratitude?,
      selfCare: results[4] as EntrySelfCare?,
      showerBath: results[5] as EntryShowerBath?,
      tomorrowNotes: results[6] as EntryTomorrowNotes?,
    );
  }

  // Save diary text with auto-save
  Future<void> saveDiaryText(String userId, DateTime date, String text) async {
    // 1. Get or create entry (cached)
    final entry = await _getOrCreateEntry(userId, date);

    // 2. Update local database immediately
    final updatedEntry = entry.copyWith(
      diaryText: text,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
    await _localService.upsertEntry(updatedEntry);
    
    // Update cache
    final dateStr = date.toIso8601String().split('T')[0];
    final cacheKey = '${userId}_$dateStr';
    _entryCache[cacheKey] = updatedEntry;

    // 3. Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncEntry(updatedEntry).then((success) {
        if (success) {
          _localService.markAsSynced(updatedEntry.id);
          // Update cache with synced entry
          final syncedEntry = updatedEntry.copyWith(isSynced: true);
          _entryCache[cacheKey] = syncedEntry;
          // AI analysis triggered by database completion check
          // No immediate trigger needed
        }
      });
    }
  }

  // Save affirmations
  Future<void> saveAffirmations(
    String userId,
    DateTime date,
    List<AffirmationItem> affirmations, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryAffirmations = EntryAffirmations(
      entryId: entry.id,
      affirmations: affirmations,
    );

    await _localService.upsertAffirmations(entryAffirmations);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync affirmations (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncAffirmations(entryAffirmations);
        }
      } else {
        // Entry already synced in batch, just sync affirmations
        _syncService.syncAffirmations(entryAffirmations);
      }
    }
  }

  // Save priorities
  Future<void> savePriorities(
    String userId,
    DateTime date,
    List<PriorityItem> priorities, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryPriorities = EntryPriorities(
      entryId: entry.id,
      priorities: priorities,
    );

    await _localService.upsertPriorities(entryPriorities);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync priorities (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncPriorities(entryPriorities);
        }
      } else {
        // Entry already synced in batch, just sync priorities
        _syncService.syncPriorities(entryPriorities);
      }
    }
  }

  // Save meals
  Future<void> saveMeals(
    String userId,
    DateTime date,
    String? breakfast,
    String? lunch,
    String? dinner,
    int waterCups, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryMeals = EntryMeals(
      entryId: entry.id,
      breakfast: breakfast,
      lunch: lunch,
      dinner: dinner,
      waterCups: waterCups,
    );

    await _localService.upsertMeals(entryMeals);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync meals (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncMeals(entryMeals);
        }
      } else {
        // Entry already synced in batch, just sync meals
        _syncService.syncMeals(entryMeals);
      }
    }
  }

  // Save gratitude
  Future<void> saveGratitude(
    String userId,
    DateTime date,
    List<GratitudeItem> gratefulItems, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryGratitude = EntryGratitude(
      entryId: entry.id,
      gratefulItems: gratefulItems,
    );

    await _localService.upsertGratitude(entryGratitude);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync gratitude (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncGratitude(entryGratitude);
        }
      } else {
        // Entry already synced in batch, just sync gratitude
        _syncService.syncGratitude(entryGratitude);
      }
    }
  }

  // Save self care
  Future<void> saveSelfCare(
    String userId,
    DateTime date,
    EntrySelfCare selfCare, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entrySelfCare = EntrySelfCare(
      entryId: entry.id,
      sleep: selfCare.sleep,
      getUpEarly: selfCare.getUpEarly,
      freshAir: selfCare.freshAir,
      learnNew: selfCare.learnNew,
      balancedDiet: selfCare.balancedDiet,
      podcast: selfCare.podcast,
      meMoment: selfCare.meMoment,
      hydrated: selfCare.hydrated,
      readBook: selfCare.readBook,
      exercise: selfCare.exercise,
    );

    await _localService.upsertSelfCare(entrySelfCare);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync self-care (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncSelfCare(entrySelfCare);
        }
      } else {
        // Entry already synced in batch, just sync self-care
        _syncService.syncSelfCare(entrySelfCare);
      }
    }
  }

  // Save shower bath
  Future<void> saveShowerBath(
    String userId,
    DateTime date,
    bool tookShower,
    String? note, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryShowerBath = EntryShowerBath(
      entryId: entry.id,
      tookShower: tookShower,
      note: note,
    );

    await _localService.upsertShowerBath(entryShowerBath);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync shower/bath (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncShowerBath(entryShowerBath);
        }
      } else {
        // Entry already synced in batch, just sync shower/bath
        _syncService.syncShowerBath(entryShowerBath);
      }
    }
  }

  // Save tomorrow notes
  Future<void> saveTomorrowNotes(
    String userId,
    DateTime date,
    List<TomorrowNoteItem> tomorrowNotes, {
    bool skipEntrySync = false,
  }) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryTomorrowNotes = EntryTomorrowNotes(
      entryId: entry.id,
      tomorrowNotes: tomorrowNotes,
    );

    await _localService.upsertTomorrowNotes(entryTomorrowNotes);

    // Sync to cloud - ensure entry exists first (unless skipped for batch save)
    if (await _isOnline()) {
      if (!skipEntrySync) {
        // FIRST: Ensure entry exists in Supabase
        final entrySynced = await _syncService.syncEntry(entry);
        
        // THEN: Sync tomorrow notes (only if entry sync succeeded)
        if (entrySynced) {
          _syncService.syncTomorrowNotes(entryTomorrowNotes);
        }
      } else {
        // Entry already synced in batch, just sync tomorrow notes
        _syncService.syncTomorrowNotes(entryTomorrowNotes);
      }
    }
  }

  // Save mood score
  Future<void> saveMoodScore(
    String userId,
    DateTime date,
    int moodScore,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);

    final updatedEntry = entry.copyWith(
      moodScore: moodScore,
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await _localService.upsertEntry(updatedEntry);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncEntry(updatedEntry).then((success) {
        if (success) {
          _localService.markAsSynced(updatedEntry.id);
        }
      });
    }
  }

  // Save tags
  Future<void> saveTags(String userId, DateTime date, List<String> tags) async {
    final entry = await _getOrCreateEntry(userId, date);

    final updatedEntry = entry.copyWith(
      tags: tags,
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await _localService.upsertEntry(updatedEntry);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncEntry(updatedEntry).then((success) {
        if (success) {
          _localService.markAsSynced(updatedEntry.id);
        }
      });
    }
  }

  // Cache for entry creation (prevents repeated queries)
  final Map<String, Entry> _entryCache = {};
  
  // Public getter for localService
  LocalEntryService get localService => _localService;
  
  // Public method to get or create entry
  Future<Entry> getOrCreateEntry(String userId, DateTime date) async {
    return await _getOrCreateEntry(userId, date);
  }
  
  // Get or create entry (with caching)
  Future<Entry> _getOrCreateEntry(String userId, DateTime date) async {
    // Use local date directly (extract date components only, no timezone conversion)
    // entry_date is stored as date only, so we use local date to match user's device date
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    // Generate cache key using local date
    final dateStr = dateOnly.toIso8601String().split('T')[0];
    final cacheKey = '${userId}_$dateStr';
    
    // Check cache first
    if (_entryCache.containsKey(cacheKey)) {
      return _entryCache[cacheKey]!;
    }
    
    // Check local database (use local date for querying)
    final existing = await _localService.getEntryByDate(userId, dateOnly);
    if (existing != null) {
      _entryCache[cacheKey] = existing;
      return existing;
    }

    // Create new entry with local date and default mood score of 3
    final newEntry = Entry(
      id: const Uuid().v4(),
      userId: userId,
      entryDate: dateOnly, // Store local date (matches user's device date)
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      moodScore: 3, // Default mood score
      tags: [],
      isSynced: false,
    );

    await _localService.upsertEntry(newEntry);
    
    // Cache the new entry
    _entryCache[cacheKey] = newEntry;
    
    return newEntry;
  }
  
  /// Clear entry cache (call when entry is deleted or date changes)
  void clearEntryCache(String userId, DateTime? date) {
    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      final cacheKey = '${userId}_$dateStr';
      _entryCache.remove(cacheKey);
    } else {
      // Clear all entries for user
      _entryCache.removeWhere((key, _) => key.startsWith('${userId}_'));
    }
  }

  // Get entries in date range
  Future<List<Entry>> getEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return await _localService.getEntriesInRange(userId, start, end);
  }

  // Clean up old entries (7-day retention policy)
  Future<void> cleanupOldEntries({int retentionDays = 7}) async {
    await _localService.clearOldEntries(retentionDays: retentionDays);
  }
}

// Complete entry data model
class EntryData {
  final Entry entry;
  final EntryAffirmations? affirmations;
  final EntryPriorities? priorities;
  final EntryMeals? meals;
  final EntryGratitude? gratitude;
  final EntrySelfCare? selfCare;
  final EntryShowerBath? showerBath;
  final EntryTomorrowNotes? tomorrowNotes;

  EntryData({
    required this.entry,
    this.affirmations,
    this.priorities,
    this.meals,
    this.gratitude,
    this.selfCare,
    this.showerBath,
    this.tomorrowNotes,
  });
}
