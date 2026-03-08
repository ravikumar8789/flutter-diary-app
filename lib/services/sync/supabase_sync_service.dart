import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/entry_models.dart';
import '../error_logging_service.dart';
import '../../models/error_models.dart';
import '../database/database_manager.dart';

class SupabaseSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static final Map<String, Future<Entry?>> _inFlightEntryFetches = {};

  /// Insert error log to Supabase (used by SyncWorker for queued error_logs).
  /// Does not call ErrorLoggingService to avoid recursion.
  Future<bool> insertErrorLog(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('error_logs').insert(payload);
      return true;
    } catch (e) {
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

  /// Sync user profile to Supabase (upsert from local row)
  Future<bool> syncUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('users').upsert({
        'id': data['id'] ?? userId,
        'email': data['email'],
        'email_verified': (data['email_verified'] as int? ?? 0) == 1,
        'display_name': data['display_name'],
        'avatar_url': data['avatar_url'],
        'locale': data['locale'],
        'timezone': data['timezone'],
        'marketing_opt_in': (data['marketing_opt_in'] as int? ?? 0) == 1,
        'created_at': data['created_at'],
        'updated_at': DateTime.now().toIso8601String(),
      });
      final db = await DatabaseManager().database;
      await db.update(
        'users',
        {'is_synced': 1, 'last_sync_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS170',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'sync_user_profile'},
        ),
      );
      return false;
    }
  }

  /// Sync user settings to Supabase (upsert from local row)
  Future<bool> syncUserSettings(String userId, Map<String, dynamic> data) async {
    try {
      final reminderDays = data['reminder_days'];
      final reminderDaysList = reminderDays is String
          ? (jsonDecode(reminderDays) as List)
          : (reminderDays is List ? reminderDays : [1, 2, 3, 4, 5, 6, 7]);
      await _supabase.from('user_settings').upsert({
        'user_id': data['user_id'] ?? userId,
        'reminder_enabled': (data['reminder_enabled'] as int? ?? 1) == 1,
        'reminder_time_local': data['reminder_time_local'],
        'reminder_days': reminderDaysList,
        'grace_system_enabled': (data['grace_system_enabled'] as int? ?? 1) == 1,
        'privacy_lock_enabled': (data['privacy_lock_enabled'] as int? ?? 0) == 1,
        'region_preference': data['region_preference'],
        'export_format_default': data['export_format_default'],
        'updated_at': DateTime.now().toIso8601String(),
      });
      final db = await DatabaseManager().database;
      await db.update(
        'user_settings',
        {'is_synced': 1, 'last_sync_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS171',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'sync_user_settings'},
        ),
      );
      return false;
    }
  }

  /// Sync user profiles (theme, font) to Supabase
  Future<bool> syncUserProfiles(String userId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('user_profiles').upsert({
        'user_id': data['user_id'] ?? userId,
        'theme_preference': data['theme_preference'] ?? 'system',
        'diary_font': data['diary_font'],
        'font_size': data['font_size'],
        'paper_style': data['paper_style'] ?? 'ruled',
      }, onConflict: 'user_id');
      final db = await DatabaseManager().database;
      await db.update(
        'user_profiles',
        {'is_synced': 1, 'last_sync_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return true;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRSYS172',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'operation': 'sync_user_profiles'},
        ),
      );
      return false;
    }
  }

  // NOTE: syncStreak removed — sync queue uses batchUpdateStreakData RPC
  // NOTE: syncHabitsDaily removed — habits_daily deprecated from Supabase, local-only
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
  /// Updates streaks table only (habits_daily deprecated from Supabase, local-only)
  Future<bool> batchUpdateStreakData({
    required String userId,
    required Map<String, dynamic> streakData,
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
        return true;
      } else {
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
