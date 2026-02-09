import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/entry_models.dart';
import '../error_logging_service.dart';
import '../../models/error_models.dart';
import '../database/database_manager.dart';

class SupabaseSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, Future<Entry?>> _inFlightEntryFetches = {};

  // Sync entry to Supabase
  Future<bool> syncEntry(Entry entry) async {
    try {
      await _supabase.from('entries').upsert(entry.toSupabaseJson());
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS101',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': entry.id,
          'user_id': entry.userId,
          'entry_date': entry.entryDate.toIso8601String(),
          'operation': 'sync_entry',
        },
        ),
      );
      return false;
    }
  }

  // Sync affirmations to Supabase (JSONB format)
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncAffirmations(EntryAffirmations affirmations) async {
    try {
      await _supabase.from('entry_affirmations').upsert({
        'entry_id': affirmations.entryId,
        'affirmations': affirmations.affirmations
            .map((a) => a.toJson())
            .toList(),
      });
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS102',
            severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': affirmations.entryId,
          'affirmations_count': affirmations.affirmations.length,
          'operation': 'sync_affirmations',
        },
        ),
      );
      return false;
    }
  }

  // Sync priorities to Supabase (JSONB format)
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncPriorities(EntryPriorities priorities) async {
    try {
      await _supabase.from('entry_priorities').upsert({
        'entry_id': priorities.entryId,
        'priorities': priorities.priorities.map((p) => p.toJson()).toList(),
      });
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS103',
            severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': priorities.entryId,
          'priorities_count': priorities.priorities.length,
          'operation': 'sync_priorities',
        },
        ),
      );
      return false;
    }
  }

  // Sync meals to Supabase
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncMeals(EntryMeals meals) async {
    try {
      await _supabase.from('entry_meals').upsert(meals.toJson());
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS104',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': meals.entryId, 'operation': 'sync_meals'},
        ),
      );
      return false;
    }
  }

  // Sync gratitude to Supabase (JSONB format)
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncGratitude(EntryGratitude gratitude) async {
    try {
      await _supabase.from('entry_gratitude').upsert({
        'entry_id': gratitude.entryId,
        'grateful_items': gratitude.gratefulItems
            .map((g) => g.toJson())
            .toList(),
      });
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS105',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': gratitude.entryId,
          'grateful_items_count': gratitude.gratefulItems.length,
          'operation': 'sync_gratitude',
        },
        ),
      );
      return false;
    }
  }

  // Sync self care to Supabase
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncSelfCare(EntrySelfCare selfCare) async {
    try {
      await _supabase.from('entry_self_care').upsert(selfCare.toJson());
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS106',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': selfCare.entryId,
          'operation': 'sync_self_care',
        },
        ),
      );
      return false;
    }
  }

  // Sync shower bath to Supabase
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncShowerBath(EntryShowerBath showerBath) async {
    try {
      await _supabase.from('entry_shower_bath').upsert(showerBath.toJson());
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS107',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': showerBath.entryId,
          'operation': 'sync_shower_bath',
        },
        ),
      );
      return false;
    }
  }

  // Sync tomorrow notes to Supabase (JSONB format)
  // NOTE: Legacy method - kept for backward compatibility with EntryService
  // New code should use batchSaveEntry() RPC function instead
  Future<bool> syncTomorrowNotes(EntryTomorrowNotes tomorrowNotes) async {
    try {
      await _supabase.from('entry_tomorrow_notes').upsert({
        'entry_id': tomorrowNotes.entryId,
        'tomorrow_notes': tomorrowNotes.tomorrowNotes
            .map((t) => t.toJson())
            .toList(),
      });
      return true;
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS108',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': tomorrowNotes.entryId,
          'tomorrow_notes_count': tomorrowNotes.tomorrowNotes.length,
          'operation': 'sync_tomorrow_notes',
        },
        ),
      );
      return false;
    }
  }

  // Pull latest data from Supabase (for multi-device sync)
  Future<Entry?> fetchEntryFromCloud(String userId, DateTime date) async {
    // Use date as-is (local date from device)
    // entry_date is stored as date only, so format local date directly
    final dateOnly = DateTime(date.year, date.month, date.day);
    final dateStr = DateFormat('yyyy-MM-dd').format(dateOnly);
    final requestKey = '${userId}_$dateStr';

    final existingRequest = _inFlightEntryFetches[requestKey];
    if (existingRequest != null) {
      return await existingRequest;
    }

    final requestFuture = _fetchEntryFromCloudInternal(userId, dateStr);
    _inFlightEntryFetches[requestKey] = requestFuture;

    try {
      return await requestFuture;
    } finally {
      _inFlightEntryFetches.remove(requestKey);
    }
  }

  Future<Entry?> _fetchEntryFromCloudInternal(
    String userId,
    String dateStr,
  ) async {
    try {
      final response = await _supabase
          .from('entries')
          .select()
          .eq('user_id', userId)
          .eq('entry_date', dateStr)
          .maybeSingle();

      if (response == null) return null;
      return Entry.fromSupabaseJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS109',
            severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'user_id': userId,
          'entry_date': dateStr,
          'operation': 'fetch_entry',
        },
        ),
      );
      return null;
    }
  }

  // Fetch affirmations from cloud
  Future<EntryAffirmations?> fetchAffirmationsFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_affirmations')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryAffirmations.fromSupabaseJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS110',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': entryId, 'operation': 'fetch_affirmations'},
        ),
      );
      return null;
    }
  }

  // Fetch priorities from cloud
  Future<EntryPriorities?> fetchPrioritiesFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_priorities')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryPriorities.fromSupabaseJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS111',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': entryId, 'operation': 'fetch_priorities'},
        ),
      );
      return null;
    }
  }

  // Fetch meals from cloud
  Future<EntryMeals?> fetchMealsFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_meals')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryMeals.fromJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS112',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': entryId, 'operation': 'fetch_meals'},
        ),
      );
      return null;
    }
  }

  // Fetch gratitude from cloud
  Future<EntryGratitude?> fetchGratitudeFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_gratitude')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryGratitude.fromSupabaseJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS113',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': entryId, 'operation': 'fetch_gratitude'},
        ),
      );
      return null;
    }
  }

  // Fetch self care from cloud
  Future<EntrySelfCare?> fetchSelfCareFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_self_care')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntrySelfCare.fromJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS114',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': entryId, 'operation': 'fetch_self_care'},
        ),
      );
      return null;
    }
  }

  // Fetch shower bath from cloud
  Future<EntryShowerBath?> fetchShowerBathFromCloud(String entryId) async {
    try {
      final response = await _supabase
          .from('entry_shower_bath')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryShowerBath.fromJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS115',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {'entry_id': entryId, 'operation': 'fetch_shower_bath'},
        ),
      );
      return null;
    }
  }

  // Fetch tomorrow notes from cloud
  Future<EntryTomorrowNotes?> fetchTomorrowNotesFromCloud(
    String entryId,
  ) async {
    try {
      final response = await _supabase
          .from('entry_tomorrow_notes')
          .select()
          .eq('entry_id', entryId)
          .maybeSingle();

      if (response == null) return null;
      return EntryTomorrowNotes.fromSupabaseJson(response);
    } catch (e) {
      // Log error
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS116',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': entryId,
          'operation': 'fetch_tomorrow_notes',
        },
        ),
      );
      return null;
    }
  }

  // Sync streak to Supabase
  Future<bool> syncStreak(String userId, Map<String, dynamic> streakData) async {
    try {
      await _supabase.from('streaks').upsert({
        'user_id': userId,
        'current': streakData['current'],
        'longest': streakData['longest'],
        'last_entry_date': streakData['last_entry_date'],
        'freeze_credits': streakData['freeze_credits'],
        'grace_pieces_total': streakData['grace_pieces_total'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Mark as synced in local SQLite
      final db = await DatabaseManager().database;
      await db.update(
        'streaks',
        {
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS117',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'user_id': userId,
          'operation': 'sync_streak',
        },
        ),
      );
      return false;
    }
  }

  // Sync habits daily to Supabase
  Future<bool> syncHabitsDaily(
    String userId,
    String date,
    Map<String, dynamic> habitsData,
  ) async {
    try {
      await _supabase.from('habits_daily').upsert({
        'id': habitsData['id'],
        'user_id': userId,
        'date': date,
        'wrote_entry': habitsData['wrote_entry'],
        'filled_affirmations': habitsData['filled_affirmations'],
        'filled_gratitude': habitsData['filled_gratitude'],
        'self_care_completed_count': habitsData['self_care_completed_count'],
        'grace_pieces_earned': habitsData['grace_pieces_earned'],
      });

      // Mark as synced in local SQLite
      final db = await DatabaseManager().database;
      await db.update(
        'habits_daily',
        {
          'is_synced': 1,
          'last_sync_at': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
      );

      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS118',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'user_id': userId,
          'date': date,
          'operation': 'sync_habits_daily',
        },
        ),
      );
      return false;
    }
  }

  // NOTE: syncAllStreaks() and syncAllHabits() removed
  // Replaced by batchUpdateStreakData() RPC method for efficient single-call syncing

  // Process sync queue (for offline changes)
  Future<void> processSyncQueue() async {
    // This will be implemented in Phase 7 with the sync worker
  }

  // Batch save entry using RPC function (single API call)
  Future<bool> batchSaveEntry({
    required Entry entry,
    EntryAffirmations? affirmations,
    EntryPriorities? priorities,
    EntryMeals? meals,
    EntryGratitude? gratitude,
    EntrySelfCare? selfCare,
    EntryShowerBath? showerBath,
    EntryTomorrowNotes? tomorrowNotes,
  }) async {
    try {
      final entryData = entry.toSupabaseJson();
      final Map<String, dynamic> params = {'p_entry': entryData};
      
      if (affirmations != null) {
        params['p_affirmations'] = affirmations.affirmations.map((a) => a.toJson()).toList();
      }
      if (priorities != null) {
        params['p_priorities'] = priorities.priorities.map((p) => p.toJson()).toList();
      }
      if (meals != null) {
        params['p_meals'] = {
          'breakfast': meals.breakfast,
          'lunch': meals.lunch,
          'dinner': meals.dinner,
          'water_cups': meals.waterCups,
        };
      }
      if (gratitude != null) {
        params['p_gratitude'] = gratitude.gratefulItems.map((g) => g.toJson()).toList();
      }
      if (selfCare != null) {
        params['p_self_care'] = {
          'sleep': selfCare.sleep,
          'get_up_early': selfCare.getUpEarly,
          'fresh_air': selfCare.freshAir,
          'learn_new': selfCare.learnNew,
          'balanced_diet': selfCare.balancedDiet,
          'podcast': selfCare.podcast,
          'me_moment': selfCare.meMoment,
          'hydrated': selfCare.hydrated,
          'read_book': selfCare.readBook,
          'exercise': selfCare.exercise,
        };
      }
      if (showerBath != null) {
        params['p_shower_bath'] = {
          'took_shower': showerBath.tookShower,
          'note': showerBath.note,
        };
      }
      if (tomorrowNotes != null) {
        params['p_tomorrow_notes'] = tomorrowNotes.tomorrowNotes.map((t) => t.toJson()).toList();
      }
      
      final response = await _supabase.rpc('batch_save_entry', params: params);
      final result = response as Map<String, dynamic>;
      
      if (result['success'] == true) {
        return true;
      } else {
        await ErrorLoggingService.logHighError(
          error: ErrorContext.create(
          errorCode: result['error_code'] ?? 'ERRSYS200',
          errorMessage: 'RPC batch save failed: ${result['error_message']}',
            severity: ErrorSeverity.high,
          errorContext: {
            'entry_id': entry.id,
            'rpc_response': result,
            'operation': 'batch_save_entry_rpc',
          },
          ),
        );
        return false;
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS200',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'entry_id': entry.id,
          'operation': 'batch_save_entry_rpc',
        },
        ),
      );
      return false;
    }
  }

  /// Batch update streak data via RPC (single API call)
  /// Updates both streaks and habits_daily tables in one transaction
  Future<bool> batchUpdateStreakData({
    required String userId,
    required Map<String, dynamic> streakData,
    List<Map<String, dynamic>>? habitsData,
  }) async {
    try {
      final params = {
        'p_user_id': userId,
        'p_streak_data': {
          'current': streakData['current'] ?? 0,
          'longest': streakData['longest'] ?? 0,
          'last_entry_date': streakData['last_entry_date'],
          'freeze_credits': streakData['freeze_credits'] ?? 0,
          'grace_pieces_total': streakData['grace_pieces_total'] ?? 0.0,
          'today_date': streakData['today_date'],
          'today_diary': streakData['today_diary'] ?? false,
          'today_affirmations': streakData['today_affirmations'] ?? false,
          'today_gratitude': streakData['today_gratitude'] ?? false,
          'today_self_care_count': streakData['today_self_care_count'] ?? 0,
          'today_grace_pieces': streakData['today_grace_pieces'] ?? 0.0,
        },
      };

      // Always pass p_habits_data as empty array (deprecated, not used anymore)
      // This ensures Postgres can resolve the function overload (jsonb[] version)
      params['p_habits_data'] = <Map<String, dynamic>>[];

      final response = await _supabase.rpc('batch_update_streak_data', params: params);
      final result = response as Map<String, dynamic>;

      if (result['success'] == true) {
        print('🔥 STREAK DEBUG: RPC call successful, marking as synced in local DB');
        // Mark as synced in local DB
        final db = await DatabaseManager().database;
        await db.update(
          'streaks',
          {
            'is_synced': 1,
            'last_sync_at': DateTime.now().toIso8601String(),
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print('🔥 STREAK DEBUG: Streaks marked as synced');

        // Mark habits as synced
        if (habitsData != null) {
          print('🔥 STREAK DEBUG: Marking ${habitsData.length} habits as synced');
          for (final habit in habitsData) {
            await db.update(
              'habits_daily',
              {
                'is_synced': 1,
                'last_sync_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [habit['id']],
            );
          }
        }
        print('🔥 STREAK DEBUG: batchUpdateStreakData END - success');
        return true;
      } else {
        print('🔥 STREAK DEBUG: RPC call failed - error: ${result['error_message']}');
        await ErrorLoggingService.logHighError(
          error: ErrorContext.create(
          errorCode: result['error_code'] ?? 'ERRSYS300',
          errorMessage: 'RPC batch streak update failed: ${result['error_message']}',
            severity: ErrorSeverity.high,
          errorContext: {
            'user_id': userId,
            'rpc_response': result,
            'operation': 'batch_update_streak_data_rpc',
          },
          ),
        );
        return false;
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
        errorCode: 'ERRSYS300',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
        errorContext: {
          'user_id': userId,
          'operation': 'batch_update_streak_data_rpc',
        },
        ),
      );
      return false;
    }
  }
}
