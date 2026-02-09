import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/entry_service.dart';
import '../models/entry_models.dart';
import '../models/error_models.dart';
import '../services/error_logging_service.dart';
import '../services/user_data_service.dart';
import '../services/sync/supabase_sync_service.dart';
import '../services/grace_system_service.dart';
import '../services/database/database_manager.dart';
import 'sync_status_provider.dart';
import 'grace_system_provider.dart';
import 'data_providers.dart';
import 'streak_provider.dart';

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
  bool _saveInProgress = false;
  bool _saveQueued = false;

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
    _pendingShowerBath = EntryShowerBathData(
      tookShower: tookShower,
      note: note,
    );
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

    // Start new debounce timer (3000ms - optimized for RPC batch save)
    // This reduces Supabase calls while still feeling instant to users
    _debounceTimer = Timer(const Duration(milliseconds: 3000), () {
      _executeBatchSave();
    });
  }

  /// Execute batch save for all pending changes using RPC
  Future<void> _executeBatchSave() async {
    if (_currentUserId == null || _currentDate == null) return;
    if (!_hasPendingChanges()) return;

    if (_saveInProgress) {
      _saveQueued = true;
      _scheduleBatchSave();
      return;
    }

    final userId = _currentUserId!;
    final date = _currentDate!;

    try {
      _saveInProgress = true;
      _saveQueued = false;

      // Get or create entry (avoid refetch if state already has it)
      Entry? entry = state.entry;
      if (entry == null) {
        final dateOnly = DateTime(date.year, date.month, date.day);
        entry = await _entryService.localService.getEntryByDate(
          userId,
          dateOnly,
        );
      }
      if (entry == null) {
        final entryData = await _entryService.loadEntryForDate(userId, date);
        entry = entryData?.entry;
      }
      entry ??= await _entryService.getOrCreateEntry(userId, date);

      // Apply pending changes
      if (_pendingMoodScore != null)
        entry = entry.copyWith(moodScore: _pendingMoodScore);
      if (_pendingTags != null) entry = entry.copyWith(tags: _pendingTags);
      if (_pendingDiaryText != null)
        entry = entry.copyWith(diaryText: _pendingDiaryText);

      // Save to local DB first
      await _savePendingChangesToLocal(userId, date, entry);

      // Prepare data for RPC
      EntryAffirmations? affirmations = _pendingAffirmations != null
          ? EntryAffirmations(
              entryId: entry.id,
              affirmations: _pendingAffirmations!,
            )
          : null;
      EntryPriorities? priorities = _pendingPriorities != null
          ? EntryPriorities(entryId: entry.id, priorities: _pendingPriorities!)
          : null;
      EntryMeals? meals = _pendingMeals != null
          ? EntryMeals(
              entryId: entry.id,
              breakfast: _pendingMeals!.breakfast,
              lunch: _pendingMeals!.lunch,
              dinner: _pendingMeals!.dinner,
              waterCups: _pendingMeals!.waterCups,
            )
          : null;
      EntryGratitude? gratitude = _pendingGratitude != null
          ? EntryGratitude(entryId: entry.id, gratefulItems: _pendingGratitude!)
          : null;
      EntrySelfCare? selfCare = _pendingSelfCare != null
          ? EntrySelfCare(
              entryId: entry.id,
              sleep: _pendingSelfCare!.sleep,
              getUpEarly: _pendingSelfCare!.getUpEarly,
              freshAir: _pendingSelfCare!.freshAir,
              learnNew: _pendingSelfCare!.learnNew,
              balancedDiet: _pendingSelfCare!.balancedDiet,
              podcast: _pendingSelfCare!.podcast,
              meMoment: _pendingSelfCare!.meMoment,
              hydrated: _pendingSelfCare!.hydrated,
              readBook: _pendingSelfCare!.readBook,
              exercise: _pendingSelfCare!.exercise,
            )
          : null;
      EntryShowerBath? showerBath = _pendingShowerBath != null
          ? EntryShowerBath(
              entryId: entry.id,
              tookShower: _pendingShowerBath!.tookShower,
              note: _pendingShowerBath!.note,
            )
          : null;
      EntryTomorrowNotes? tomorrowNotes = _pendingTomorrowNotes != null
          ? EntryTomorrowNotes(
              entryId: entry.id,
              tomorrowNotes: _pendingTomorrowNotes!,
            )
          : null;

      // Call RPC (single API call)
      final syncService = SupabaseSyncService();
      final success = await syncService.batchSaveEntry(
        entry: entry,
        affirmations: affirmations,
        priorities: priorities,
        meals: meals,
        gratitude: gratitude,
        selfCare: selfCare,
        showerBath: showerBath,
        tomorrowNotes: tomorrowNotes,
      );

      if (success) {
        await _markAllAsSynced(entry.id);

        // Invalidate cache
        final fetchService = ref.read(dataFetchServiceProvider);
        fetchService.invalidateEntriesCache(userId, date);
        fetchService.invalidateMonthlyCache(userId, date);

        // Track grace system
        await _batchTrackGraceTasks(userId, date);

        // Check for gaps and recalculate streak (with gap detection)
        await _checkGapsAndRecalculateStreak(userId);

        ref.read(syncStatusProvider.notifier).setSaved();
      } else {
        ref
            .read(syncStatusProvider.notifier)
            .setError('ERRSYS200: Batch save failed');
      }

      _clearPendingChanges();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA260',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'entry_date': date.toIso8601String(),
            'operation': 'batch_save_rpc',
          },
        ),
      );
      ref.read(syncStatusProvider.notifier).setError('ERRDATA260: $e');
    } finally {
      _saveInProgress = false;
      if (_saveQueued && _hasPendingChanges()) {
        _scheduleBatchSave();
      }
    }
  }

  /// Save pending changes to local database
  Future<void> _savePendingChangesToLocal(
    String userId,
    DateTime date,
    Entry entry,
  ) async {
    final localService = _entryService.localService;

    // Save entry
    try {
      await localService.upsertEntry(entry);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA270',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'entry_id': entry.id,
            'user_id': userId,
            'entry_date': date.toIso8601String(),
            'operation': 'batch_save_local_entry',
          },
        ),
      );
      // Continue with other saves even if entry save fails
    }

    // Save affirmations
    if (_pendingAffirmations != null) {
      try {
        await localService.upsertAffirmations(
          EntryAffirmations(
            entryId: entry.id,
            affirmations: _pendingAffirmations!,
          ),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA271',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'affirmations_count': _pendingAffirmations!.length,
              'operation': 'batch_save_local_affirmations',
            },
          ),
        );
      }
    }

    // Save priorities
    if (_pendingPriorities != null) {
      try {
        await localService.upsertPriorities(
          EntryPriorities(entryId: entry.id, priorities: _pendingPriorities!),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA272',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'priorities_count': _pendingPriorities!.length,
              'operation': 'batch_save_local_priorities',
            },
          ),
        );
      }
    }

    // Save meals
    if (_pendingMeals != null) {
      try {
        await localService.upsertMeals(
          EntryMeals(
            entryId: entry.id,
            breakfast: _pendingMeals!.breakfast,
            lunch: _pendingMeals!.lunch,
            dinner: _pendingMeals!.dinner,
            waterCups: _pendingMeals!.waterCups,
          ),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA273',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'water_cups': _pendingMeals!.waterCups,
              'has_breakfast': _pendingMeals!.breakfast != null,
              'has_lunch': _pendingMeals!.lunch != null,
              'has_dinner': _pendingMeals!.dinner != null,
              'operation': 'batch_save_local_meals',
            },
          ),
        );
      }
    }

    // Save gratitude
    if (_pendingGratitude != null) {
      try {
        await localService.upsertGratitude(
          EntryGratitude(entryId: entry.id, gratefulItems: _pendingGratitude!),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA274',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'grateful_items_count': _pendingGratitude!.length,
              'operation': 'batch_save_local_gratitude',
            },
          ),
        );
      }
    }

    // Save self-care
    if (_pendingSelfCare != null) {
      try {
        await localService.upsertSelfCare(
          EntrySelfCare(
            entryId: entry.id,
            sleep: _pendingSelfCare!.sleep,
            getUpEarly: _pendingSelfCare!.getUpEarly,
            freshAir: _pendingSelfCare!.freshAir,
            learnNew: _pendingSelfCare!.learnNew,
            balancedDiet: _pendingSelfCare!.balancedDiet,
            podcast: _pendingSelfCare!.podcast,
            meMoment: _pendingSelfCare!.meMoment,
            hydrated: _pendingSelfCare!.hydrated,
            readBook: _pendingSelfCare!.readBook,
            exercise: _pendingSelfCare!.exercise,
          ),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA275',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'self_care_data': {
                'sleep': _pendingSelfCare!.sleep,
                'get_up_early': _pendingSelfCare!.getUpEarly,
                'fresh_air': _pendingSelfCare!.freshAir,
                'learn_new': _pendingSelfCare!.learnNew,
                'balanced_diet': _pendingSelfCare!.balancedDiet,
                'podcast': _pendingSelfCare!.podcast,
                'me_moment': _pendingSelfCare!.meMoment,
                'hydrated': _pendingSelfCare!.hydrated,
                'read_book': _pendingSelfCare!.readBook,
                'exercise': _pendingSelfCare!.exercise,
              },
              'operation': 'batch_save_local_self_care',
            },
          ),
        );
      }
    }

    // Save shower bath
    if (_pendingShowerBath != null) {
      try {
        await localService.upsertShowerBath(
          EntryShowerBath(
            entryId: entry.id,
            tookShower: _pendingShowerBath!.tookShower,
            note: _pendingShowerBath!.note,
          ),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA276',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'took_shower': _pendingShowerBath!.tookShower,
              'has_note': _pendingShowerBath!.note != null,
              'operation': 'batch_save_local_shower_bath',
            },
          ),
        );
      }
    }

    // Save tomorrow notes
    if (_pendingTomorrowNotes != null) {
      try {
        await localService.upsertTomorrowNotes(
          EntryTomorrowNotes(
            entryId: entry.id,
            tomorrowNotes: _pendingTomorrowNotes!,
          ),
        );
      } catch (e) {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.fromException(
            errorCode: 'ERRDATA277',
            severity: ErrorSeverity.high,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {
              'entry_id': entry.id,
              'tomorrow_notes_count': _pendingTomorrowNotes!.length,
              'operation': 'batch_save_local_tomorrow_notes',
            },
          ),
        );
      }
    }
  }

  /// Mark all entry data as synced
  Future<void> _markAllAsSynced(String entryId) async {
    await _entryService.localService.markAsSynced(entryId);
  }

  /// Force immediate save (cancel debounce and save now)
  void forceImmediateSave() {
    _debounceTimer?.cancel();
    if (_currentUserId != null && _currentDate != null) {
      _executeBatchSave();
    }
  }

  /// Batch track grace system tasks (only once)
  Future<void> _batchTrackGraceTasks(String userId, DateTime date) async {
    try {
      final graceNotifier = ref.read(graceSystemProvider.notifier);

      // Initialize provider if not already initialized
      await graceNotifier.initialize(userId);

      // Track all tasks that changed
      if (_pendingDiaryText != null) {
        final hasDiary = _pendingDiaryText!.trim().isNotEmpty;
        await graceNotifier.trackTaskCompletion('diary', hasDiary);
      }

      if (_pendingAffirmations != null) {
        await graceNotifier.trackTaskCompletion(
          'affirmations',
          _pendingAffirmations!.isNotEmpty,
        );
      }

      if (_pendingGratitude != null) {
        await graceNotifier.trackTaskCompletion(
          'gratitude',
          _pendingGratitude!.isNotEmpty,
        );
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
        final hasSelfCare =
            _pendingSelfCare!.sleep ||
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
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA261',
          severity: ErrorSeverity.low,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'operation': 'batch_grace_tracking'},
        ),
      );
    }
  }

  /// Check for gaps in streak and auto-use grace days if needed
  Future<void> _checkGapsAndRecalculateStreak(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final dataFetchService = ref.read(dataFetchServiceProvider);

      // Get current streak data
      final streaks = await db.query(
        'streaks',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (streaks.isEmpty) {
        // No streak data, recalculate from scratch
        await UserDataService.recalculateStreak(
          userId,
          dataFetchService: dataFetchService,
        );
        dataFetchService.invalidateStreaksCache(userId);
        dataFetchService.invalidateHomeSummaryCache(userId);
        // Refresh providers to reflect UI changes
        ref.read(streakProvider.notifier).refresh();
        ref.invalidate(homeSummaryProvider);
        return;
      }

      final streak = streaks.first;
      final lastEntryDateStr = streak['last_entry_date'] as String?;

      if (lastEntryDateStr == null) {
        // No previous entry, recalculate from scratch
        await UserDataService.recalculateStreak(
          userId,
          dataFetchService: dataFetchService,
        );
        dataFetchService.invalidateStreaksCache(userId);
        dataFetchService.invalidateHomeSummaryCache(userId);
        // Refresh providers to reflect UI changes
        ref.read(streakProvider.notifier).refresh();
        ref.invalidate(homeSummaryProvider);
        return;
      }

      final lastEntryDate = DateTime.parse(lastEntryDateStr);
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final lastDateOnly = DateTime(
        lastEntryDate.year,
        lastEntryDate.month,
        lastEntryDate.day,
      );
      final daysDiff = todayDateOnly.difference(lastDateOnly).inDays;

      if (daysDiff == 0) {
        // Same day, just recalculate
        await UserDataService.recalculateStreak(
          userId,
          dataFetchService: dataFetchService,
        );
        dataFetchService.invalidateStreaksCache(userId);
        dataFetchService.invalidateHomeSummaryCache(userId);
        // Refresh providers to reflect UI changes
        ref.read(streakProvider.notifier).refresh();
        ref.invalidate(homeSummaryProvider);
        return;
      }

      if (daysDiff > 0) {
        // Gap detected
        final graceDays = streak['freeze_credits'] as int? ?? 0;

        if (daysDiff == 1 && graceDays > 0) {
          // 1 day gap - auto-use grace day
          await GraceSystemService.useGraceDay(
            userId,
            dataFetchService: dataFetchService,
          );
          // Recalculate streak (maintains current streak)
          await UserDataService.recalculateStreak(
            userId,
            dataFetchService: dataFetchService,
          );
          dataFetchService.invalidateStreaksCache(userId);
          dataFetchService.invalidateHomeSummaryCache(userId);
          // Refresh providers to reflect UI changes
          ref.read(streakProvider.notifier).refresh();
          ref.invalidate(homeSummaryProvider);
        } else if (daysDiff > 1) {
          // Multiple days gap
          if (graceDays >= daysDiff - 1) {
            // Use multiple grace days
            for (int i = 0; i < daysDiff - 1; i++) {
              await GraceSystemService.useGraceDay(
                userId,
                dataFetchService: dataFetchService,
              );
            }
            await UserDataService.recalculateStreak(
              userId,
              dataFetchService: dataFetchService,
            );
            dataFetchService.invalidateStreaksCache(userId);
            dataFetchService.invalidateHomeSummaryCache(userId);
            // Refresh providers to reflect UI changes
            ref.read(streakProvider.notifier).refresh();
            ref.invalidate(homeSummaryProvider);
          } else {
            // Not enough grace days - reset streak
            await db.update(
              'streaks',
              {
                'current': 0,
                'last_entry_date': null,
                'updated_at': DateTime.now().toIso8601String(),
                'is_synced': 0,
              },
              where: 'user_id = ?',
              whereArgs: [userId],
            );
            // Sync reset
            final syncService = SupabaseSyncService();
            await syncService.batchUpdateStreakData(
              userId: userId,
              streakData: {
                'current': 0,
                'longest': streak['longest'] ?? 0,
                'last_entry_date': null,
                'freeze_credits': graceDays,
                'grace_pieces_total': streak['grace_pieces_total'] ?? 0.0,
              },
            );
            dataFetchService.invalidateStreaksCache(userId);
            dataFetchService.invalidateHomeSummaryCache(userId);
            // Refresh providers to reflect UI changes
            ref.read(streakProvider.notifier).refresh();
            ref.invalidate(homeSummaryProvider);
          }
        }
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA280',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId},
        ),
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

  bool _hasPendingChanges() {
    return _pendingDiaryText != null ||
        _pendingAffirmations != null ||
        _pendingPriorities != null ||
        _pendingMeals != null ||
        _pendingGratitude != null ||
        _pendingSelfCare != null ||
        _pendingShowerBath != null ||
        _pendingTomorrowNotes != null ||
        _pendingMoodScore != null ||
        _pendingTags != null;
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

  EntryShowerBathData({required this.tookShower, this.note});
}

final entryProvider = NotifierProvider<EntryNotifier, EntryState>(
  () => EntryNotifier(),
);
