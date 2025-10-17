import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database/local_entry_service.dart';
import 'sync/supabase_sync_service.dart';
import '../models/entry_models.dart';

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
    } catch (_) {
      return false;
    }
  }

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

  // Build complete entry data with all related fields
  Future<EntryData> _buildEntryData(Entry entry) async {
    final affirmations = await _localService.getAffirmations(entry.id);
    final priorities = await _localService.getPriorities(entry.id);
    final meals = await _localService.getMeals(entry.id);
    final gratitude = await _localService.getGratitude(entry.id);
    final selfCare = await _localService.getSelfCare(entry.id);
    final showerBath = await _localService.getShowerBath(entry.id);
    final tomorrowNotes = await _localService.getTomorrowNotes(entry.id);

    return EntryData(
      entry: entry,
      affirmations: affirmations,
      priorities: priorities,
      meals: meals,
      gratitude: gratitude,
      selfCare: selfCare,
      showerBath: showerBath,
      tomorrowNotes: tomorrowNotes,
    );
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
    if (await _isOnline()) {
      _syncService.syncEntry(updatedEntry).then((success) {
        if (success) {
          _localService.markAsSynced(updatedEntry.id);
        }
      });
    }
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

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncAffirmations(entryAffirmations);
    }
  }

  // Save priorities
  Future<void> savePriorities(
    String userId,
    DateTime date,
    List<PriorityItem> priorities,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryPriorities = EntryPriorities(
      entryId: entry.id,
      priorities: priorities,
    );

    await _localService.upsertPriorities(entryPriorities);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncPriorities(entryPriorities);
    }
  }

  // Save meals
  Future<void> saveMeals(
    String userId,
    DateTime date,
    String? breakfast,
    String? lunch,
    String? dinner,
    int waterCups,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryMeals = EntryMeals(
      entryId: entry.id,
      breakfast: breakfast,
      lunch: lunch,
      dinner: dinner,
      waterCups: waterCups,
    );

    await _localService.upsertMeals(entryMeals);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncMeals(entryMeals);
    }
  }

  // Save gratitude
  Future<void> saveGratitude(
    String userId,
    DateTime date,
    List<GratitudeItem> gratefulItems,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryGratitude = EntryGratitude(
      entryId: entry.id,
      gratefulItems: gratefulItems,
    );

    await _localService.upsertGratitude(entryGratitude);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncGratitude(entryGratitude);
    }
  }

  // Save self care
  Future<void> saveSelfCare(
    String userId,
    DateTime date,
    EntrySelfCare selfCare,
  ) async {
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

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncSelfCare(entrySelfCare);
    }
  }

  // Save shower bath
  Future<void> saveShowerBath(
    String userId,
    DateTime date,
    bool tookShower,
    String? note,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryShowerBath = EntryShowerBath(
      entryId: entry.id,
      tookShower: tookShower,
      note: note,
    );

    await _localService.upsertShowerBath(entryShowerBath);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncShowerBath(entryShowerBath);
    }
  }

  // Save tomorrow notes
  Future<void> saveTomorrowNotes(
    String userId,
    DateTime date,
    List<TomorrowNoteItem> tomorrowNotes,
  ) async {
    final entry = await _getOrCreateEntry(userId, date);

    final entryTomorrowNotes = EntryTomorrowNotes(
      entryId: entry.id,
      tomorrowNotes: tomorrowNotes,
    );

    await _localService.upsertTomorrowNotes(entryTomorrowNotes);

    // Sync to cloud (non-blocking)
    if (await _isOnline()) {
      _syncService.syncTomorrowNotes(entryTomorrowNotes);
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

  // Get or create entry
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

  // Get entries in date range
  Future<List<Entry>> getEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    return await _localService.getEntriesInRange(userId, start, end);
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
