import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/entry_service.dart';
import '../models/entry_models.dart';
import '../services/error_logging_service.dart';
import 'sync_status_provider.dart';

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

  // Update diary text with debounced auto-save
  void updateDiaryText(String userId, DateTime date, String text) {
    // Update UI immediately (optimistic update)
    state = state.copyWith(entry: state.entry?.copyWith(diaryText: text));

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
        // Log error to Supabase
        await ErrorLoggingService.logHighError(
          errorCode: 'ERRDATA041',
          errorMessage: 'Diary text save failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          errorContext: {
            'text_length': text.length,
            'user_id': userId,
            'entry_date': date.toIso8601String(),
            'save_method': 'auto_save',
          },
        );

        ref.read(syncStatusProvider.notifier).setError('ERRDATA041: $e');
        state = state.copyWith(
          error: 'Failed to save diary text (ERRDATA041): $e',
        );
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
        state = state.copyWith(error: 'Failed to save affirmations: $e');
      }
    });
  }

  // Update priorities with debounced auto-save
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

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.savePriorities(userId, date, priorities);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save priorities: $e');
      }
    });
  }

  // Update meals with debounced auto-save
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

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveMeals(
          userId,
          date,
          breakfast,
          lunch,
          dinner,
          waterCups,
        );
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save meals: $e');
      }
    });
  }

  // Update gratitude with debounced auto-save
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

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveGratitude(userId, date, gratefulItems);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save gratitude: $e');
      }
    });
  }

  // Update self care with debounced auto-save
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

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveSelfCare(userId, date, selfCare);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save self care: $e');
      }
    });
  }

  // Update shower bath with debounced auto-save
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

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveShowerBath(userId, date, tookShower, note);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save shower bath: $e');
      }
    });
  }

  // Update tomorrow notes with debounced auto-save
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

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveTomorrowNotes(userId, date, tomorrowNotes);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save tomorrow notes: $e');
      }
    });
  }

  // Update mood score with debounced auto-save
  void updateMoodScore(String userId, DateTime date, int moodScore) {
    // Optimistic update
    state = state.copyWith(entry: state.entry?.copyWith(moodScore: moodScore));

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveMoodScore(userId, date, moodScore);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save mood score: $e');
      }
    });
  }

  // Update tags with debounced auto-save
  void updateTags(String userId, DateTime date, List<String> tags) {
    // Optimistic update
    state = state.copyWith(entry: state.entry?.copyWith(tags: tags));

    _debounceTimer?.cancel();
    ref.read(syncStatusProvider.notifier).setSyncing();

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        await _entryService.saveTags(userId, date, tags);
        ref.read(syncStatusProvider.notifier).setSaved();
      } catch (e) {
        ref.read(syncStatusProvider.notifier).setError(e.toString());
        state = state.copyWith(error: 'Failed to save tags: $e');
      }
    });
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Clear all data (for logout)
  void clearData() {
    _debounceTimer?.cancel();
    state = EntryState();
  }
}

final entryProvider = NotifierProvider<EntryNotifier, EntryState>(
  () => EntryNotifier(),
);
