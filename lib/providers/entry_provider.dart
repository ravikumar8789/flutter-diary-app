import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/entry_service.dart';
import '../models/entry_models.dart';
import '../services/error_logging_service.dart';
import '../services/user_data_service.dart';
import '../services/sync/supabase_sync_service.dart';
import 'sync_status_provider.dart';
import 'grace_system_provider.dart';
import 'data_providers.dart';

class EntryState {
  final Entry? entry;
  final EntryAffirmations? affirmations;
  final EntryPriorities? priorities;
  final EntryMeals? meals;
  final EntryGratitude? gratitude;
  final EntrySelfCare? selfCare;
  final EntryShowerBath? showerBath;
  final EntryTomorrowNotes? tomorrowNotes;
  final bool isLoading;
  final String? error;

  EntryState({
    this.entry,
    this.affirmations,
    this.priorities,
    this.meals,
    this.gratitude,
    this.selfCare,
    this.showerBath,
    this.tomorrowNotes,
    this.isLoading = false,
    this.error,
  });

  EntryState copyWith({
    Entry? entry,
    EntryAffirmations? affirmations,
    EntryPriorities? priorities,
    EntryMeals? meals,
    EntryGratitude? gratitude,
    EntrySelfCare? selfCare,
    EntryShowerBath? showerBath,
    EntryTomorrowNotes? tomorrowNotes,
    bool? isLoading,
    String? error,
  }) {
    return EntryState(
      entry: entry ?? this.entry,
      affirmations: affirmations ?? this.affirmations,
      priorities: priorities ?? this.priorities,
      meals: meals ?? this.meals,
      gratitude: gratitude ?? this.gratitude,
      selfCare: selfCare ?? this.selfCare,
      showerBath: showerBath ?? this.showerBath,
      tomorrowNotes: tomorrowNotes ?? this.tomorrowNotes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EntryState &&
        other.entry == entry &&
        other.affirmations == affirmations &&
        other.priorities == priorities &&
        other.meals == meals &&
        other.gratitude == gratitude &&
        other.selfCare == selfCare &&
        other.showerBath == showerBath &&
        other.tomorrowNotes == tomorrowNotes &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode {
    return entry.hashCode ^
        affirmations.hashCode ^
        priorities.hashCode ^
        meals.hashCode ^
        gratitude.hashCode ^
        selfCare.hashCode ^
        showerBath.hashCode ^
        tomorrowNotes.hashCode ^
        isLoading.hashCode ^
        error.hashCode;
  }
}

class EntryNotifier extends Notifier<EntryState> {
  Timer? _debounceTimer;
  final EntryService _entryService = EntryService();
  
  // Track pending changes for batch save
  String? _pendingDiaryText;
  List<AffirmationItem>? _pendingAffirmations;
  List<PriorityItem>? _pendingPriorities;
  EntryMealsData? _pendingMeals;
  List<GratitudeItem>? _pendingGratitude;
  EntrySelfCare? _pendingSelfCare;
  EntryShowerBathData? _pendingShowerBath;
  List<TomorrowNoteItem>? _pendingTomorrowNotes;
  int? _pendingMoodScore;
  List<String>? _pendingTags;
  
  String? _currentUserId;
  DateTime? _currentDate;

  @override
  EntryState build() => EntryState();

  // Load entry for selected date
  Future<void> loadEntry(String userId, DateTime date) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final entryData = await _entryService.loadEntryForDate(userId, date);

      if (entryData != null) {
        state = EntryState(
          entry: entryData.entry,
          affirmations: entryData.affirmations,
          priorities: entryData.priorities,
          meals: entryData.meals,
          gratitude: entryData.gratitude,
          selfCare: entryData.selfCare,
          showerBath: entryData.showerBath,
          tomorrowNotes: entryData.tomorrowNotes,
          isLoading: false,
          error: null,
        );
      } else {
        state = EntryState(isLoading: false, error: null);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load entry (ERRDATA016): $e',
      );
    }
  }

  // Update diary text with unified batch debounce
  void updateDiaryText(String userId, DateTime date, String text) {
    // Update UI immediately (optimistic update)
    state = state.copyWith(entry: state.entry?.copyWith(diaryText: text));

    // Store pending change
    _pendingDiaryText = text;
    _currentUserId = userId;
    _currentDate = date;

    // Set sync status to syncing
    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update affirmations with unified batch debounce
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

    // Store pending change
    _pendingAffirmations = affirmations;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update priorities with unified batch debounce
  void updatePriorities(
    String userId,
    DateTime date,
    List<PriorityItem> priorities,
  ) {
    // Optimistic update
    state = state.copyWith(
      priorities: EntryPriorities(
        entryId: state.entry?.id ?? '',
        priorities: priorities,
      ),
    );

    // Store pending change
    _pendingPriorities = priorities;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update meals with unified batch debounce
  void updateMeals(
    String userId,
    DateTime date,
    String? breakfast,
    String? lunch,
    String? dinner,
    int waterCups,
  ) {
    // Optimistic update
    state = state.copyWith(
      meals: EntryMeals(
        entryId: state.entry?.id ?? '',
        breakfast: breakfast,
        lunch: lunch,
        dinner: dinner,
        waterCups: waterCups,
      ),
    );

    // Store pending change
    _pendingMeals = EntryMealsData(
      breakfast: breakfast,
      lunch: lunch,
      dinner: dinner,
      waterCups: waterCups,
    );
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update gratitude with unified batch debounce
  void updateGratitude(
    String userId,
    DateTime date,
    List<GratitudeItem> gratefulItems,
  ) {
    // Optimistic update
    state = state.copyWith(
      gratitude: EntryGratitude(
        entryId: state.entry?.id ?? '',
        gratefulItems: gratefulItems,
      ),
    );

    // Store pending change
    _pendingGratitude = gratefulItems;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update self care with unified batch debounce
  void updateSelfCare(String userId, DateTime date, EntrySelfCare selfCare) {
    // Optimistic update
    state = state.copyWith(
      selfCare: EntrySelfCare(
        entryId: state.entry?.id ?? '',
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
      ),
    );

    // Store pending change
    _pendingSelfCare = selfCare;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update shower bath with unified batch debounce
  void updateShowerBath(
    String userId,
    DateTime date,
    bool tookShower,
    String? note,
  ) {
    // Optimistic update
    state = state.copyWith(
      showerBath: EntryShowerBath(
        entryId: state.entry?.id ?? '',
        tookShower: tookShower,
        note: note,
      ),
    );

    // Store pending change
    _pendingShowerBath = EntryShowerBathData(tookShower: tookShower, note: note);
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update tomorrow notes with unified batch debounce
  void updateTomorrowNotes(
    String userId,
    DateTime date,
    List<TomorrowNoteItem> tomorrowNotes,
  ) {
    // Optimistic update
    state = state.copyWith(
      tomorrowNotes: EntryTomorrowNotes(
        entryId: state.entry?.id ?? '',
        tomorrowNotes: tomorrowNotes,
      ),
    );

    // Store pending change
    _pendingTomorrowNotes = tomorrowNotes;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update mood score with unified batch debounce
  void updateMoodScore(String userId, DateTime date, int moodScore) {
    // Optimistic update
    state = state.copyWith(entry: state.entry?.copyWith(moodScore: moodScore));

    // Store pending change
    _pendingMoodScore = moodScore;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Update tags with unified batch debounce
  void updateTags(String userId, DateTime date, List<String> tags) {
    // Optimistic update
    state = state.copyWith(entry: state.entry?.copyWith(tags: tags));

    // Store pending change
    _pendingTags = tags;
    _currentUserId = userId;
    _currentDate = date;

    ref.read(syncStatusProvider.notifier).setSyncing();

    // Schedule unified batch save
    _scheduleBatchSave();
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Clear all data (for logout)
  void clearData() {
    _debounceTimer?.cancel();
    _clearPendingChanges();
    state = EntryState();
  }
  
  /// Schedule unified batch save (debounced)
  /// 
  /// Collects all pending changes and saves them in one operation.
  /// This prevents multiple simultaneous saves when user changes multiple fields.
  void _scheduleBatchSave() {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Start new debounce timer (2000ms - optimized like Microsoft Office approach)
    // This reduces Supabase calls while still feeling instant to users
    _debounceTimer = Timer(const Duration(milliseconds: 2000), () {
      _executeBatchSave();
    });
  }
  
  /// Execute batch save for all pending changes
  Future<void> _executeBatchSave() async {
    if (_currentUserId == null || _currentDate == null) {
      return;
    }
    
    final userId = _currentUserId!;
    final date = _currentDate!;
    
    try {
      // STEP 1: Get entry once and sync it once (if any field needs entry sync)
      bool needsEntrySync = _pendingAffirmations != null ||
          _pendingPriorities != null ||
          _pendingMeals != null ||
          _pendingGratitude != null ||
          _pendingSelfCare != null ||
          _pendingShowerBath != null ||
          _pendingTomorrowNotes != null;
      
      if (needsEntrySync) {
        // Get entry by calling saveDiaryText with empty text (it will get/create entry)
        // Then sync entry once before all field saves
        // We'll use a temporary save to get the entry, then sync it
        final tempEntry = await _entryService.loadEntryForDate(userId, date);
        if (tempEntry != null) {
          final syncService = SupabaseSyncService();
          await syncService.syncEntry(tempEntry.entry);
        } else {
          // Entry doesn't exist, create it first via saveDiaryText with empty text
          await _entryService.saveDiaryText(userId, date, '');
          final createdEntry = await _entryService.loadEntryForDate(userId, date);
          if (createdEntry != null) {
            final syncService = SupabaseSyncService();
            await syncService.syncEntry(createdEntry.entry);
          }
        }
      }
      
      // STEP 2: Save all pending changes in parallel (skip entry sync for field-only saves)
      final saveOperations = <Future>[];
      
      if (_pendingDiaryText != null) {
        // Diary text updates entry itself, so it handles entry sync
        saveOperations.add(_entryService.saveDiaryText(userId, date, _pendingDiaryText!));
      }
      
      if (_pendingAffirmations != null) {
        saveOperations.add(_entryService.saveAffirmations(
          userId,
          date,
          _pendingAffirmations!,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingPriorities != null) {
        saveOperations.add(_entryService.savePriorities(
          userId,
          date,
          _pendingPriorities!,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingMeals != null) {
        saveOperations.add(_entryService.saveMeals(
          userId,
          date,
          _pendingMeals!.breakfast,
          _pendingMeals!.lunch,
          _pendingMeals!.dinner,
          _pendingMeals!.waterCups,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingGratitude != null) {
        saveOperations.add(_entryService.saveGratitude(
          userId,
          date,
          _pendingGratitude!,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingSelfCare != null) {
        saveOperations.add(_entryService.saveSelfCare(
          userId,
          date,
          _pendingSelfCare!,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingShowerBath != null) {
        saveOperations.add(_entryService.saveShowerBath(
          userId,
          date,
          _pendingShowerBath!.tookShower,
          _pendingShowerBath!.note,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingTomorrowNotes != null) {
        saveOperations.add(_entryService.saveTomorrowNotes(
          userId,
          date,
          _pendingTomorrowNotes!,
          skipEntrySync: true, // Entry already synced
        ));
      }
      
      if (_pendingMoodScore != null) {
        // Mood score updates entry itself, so it handles entry sync
        saveOperations.add(_entryService.saveMoodScore(userId, date, _pendingMoodScore!));
      }
      
      if (_pendingTags != null) {
        // Tags update entry itself, so it handles entry sync
        saveOperations.add(_entryService.saveTags(userId, date, _pendingTags!));
      }
      
      // Execute all saves in parallel
      if (saveOperations.isNotEmpty) {
        await Future.wait(saveOperations);
        
        // Invalidate cache once after all saves
        final fetchService = ref.read(dataFetchServiceProvider);
        fetchService.invalidateEntriesCache(userId, date);
        fetchService.invalidateMonthlyCache(userId, date);
        
        // Track grace system tasks (batch these too)
        await _batchTrackGraceTasks(userId, date);
        
        // Recalculate streak once (only if diary text changed)
        if (_pendingDiaryText != null && _pendingDiaryText!.trim().isNotEmpty) {
          final dataFetchService = ref.read(dataFetchServiceProvider);
          UserDataService.recalculateStreak(
            userId,
            dataFetchService: dataFetchService,
          );
          dataFetchService.invalidateStreaksCache(userId);
        }
        
        ref.read(syncStatusProvider.notifier).setSaved();
      }
      
      // Clear pending changes
      _clearPendingChanges();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRDATA260',
        errorMessage: 'Batch save failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'entry_date': date.toIso8601String(),
          'operation': 'batch_save',
        },
      );
      
      ref.read(syncStatusProvider.notifier).setError('ERRDATA260: $e');
      state = state.copyWith(error: 'Failed to save: $e');
    }
  }
  
  /// Batch track grace system tasks (only once)
  Future<void> _batchTrackGraceTasks(String userId, DateTime date) async {
    try {
      final graceNotifier = ref.read(graceSystemProvider.notifier);
      
      // Track all tasks that changed
      if (_pendingDiaryText != null) {
        await graceNotifier.trackTaskCompletion('diary', _pendingDiaryText!.trim().isNotEmpty);
      }
      
      if (_pendingAffirmations != null) {
        await graceNotifier.trackTaskCompletion('affirmations', _pendingAffirmations!.isNotEmpty);
      }
      
      if (_pendingGratitude != null) {
        await graceNotifier.trackTaskCompletion('gratitude', _pendingGratitude!.isNotEmpty);
      }
      
      if (_pendingMeals != null) {
        final hasWellnessData =
            _pendingMeals!.breakfast?.isNotEmpty == true ||
            _pendingMeals!.lunch?.isNotEmpty == true ||
            _pendingMeals!.dinner?.isNotEmpty == true ||
            _pendingMeals!.waterCups > 0;
        await graceNotifier.trackTaskCompletion('self_care', hasWellnessData);
      }
      
      if (_pendingSelfCare != null) {
        final hasSelfCare = _pendingSelfCare!.sleep ||
            _pendingSelfCare!.getUpEarly ||
            _pendingSelfCare!.freshAir ||
            _pendingSelfCare!.learnNew ||
            _pendingSelfCare!.balancedDiet ||
            _pendingSelfCare!.podcast ||
            _pendingSelfCare!.meMoment ||
            _pendingSelfCare!.hydrated ||
            _pendingSelfCare!.readBook ||
            _pendingSelfCare!.exercise;
        await graceNotifier.trackTaskCompletion('self_care', hasSelfCare);
      }
    } catch (e) {
      // Log but don't fail batch save
      ErrorLoggingService.logLowError(
        errorCode: 'ERRDATA261',
        errorMessage: 'Batch grace tracking failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {'operation': 'batch_grace_tracking'},
      );
    }
  }
  
  /// Clear all pending changes
  void _clearPendingChanges() {
    _pendingDiaryText = null;
    _pendingAffirmations = null;
    _pendingPriorities = null;
    _pendingMeals = null;
    _pendingGratitude = null;
    _pendingSelfCare = null;
    _pendingShowerBath = null;
    _pendingTomorrowNotes = null;
    _pendingMoodScore = null;
    _pendingTags = null;
  }
}

/// Helper classes for pending data
class EntryMealsData {
  final String? breakfast;
  final String? lunch;
  final String? dinner;
  final int waterCups;
  
  EntryMealsData({
    this.breakfast,
    this.lunch,
    this.dinner,
    required this.waterCups,
  });
}

class EntryShowerBathData {
  final bool tookShower;
  final String? note;
  
  EntryShowerBathData({
    required this.tookShower,
    this.note,
  });
}

final entryProvider = NotifierProvider<EntryNotifier, EntryState>(
  () => EntryNotifier(),
);
