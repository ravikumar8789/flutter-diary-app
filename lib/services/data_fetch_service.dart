import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../models/entry_models.dart';
import '../models/analytics_models.dart';
import 'error_logging_service.dart';
import '../models/error_models.dart';
import 'analytics_service.dart';
import 'entry_storage_helper.dart';
import 'database/database_manager.dart';

/// Centralized data fetching service
///
/// All data fetching operations go through this service.
/// Local-first: reads from SQLite first, Supabase for refresh/store.
class DataFetchService {
  final SupabaseClient _supabase;

  DataFetchService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================================
  // LOCAL READ HELPERS
  // ============================================================================

  Future<Map<String, dynamic>?> _readUserProfileFromLocal(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final rows = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      return {
        'id': row['id'],
        'email': row['email'],
        'email_verified': (row['email_verified'] as int? ?? 0) == 1,
        'display_name': row['display_name'],
        'avatar_url': row['avatar_url'],
        'locale': row['locale'],
        'timezone': row['timezone'],
        'marketing_opt_in': (row['marketing_opt_in'] as int? ?? 0) == 1,
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readUserSettingsFromLocal(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final rows = await db.query(
        'user_settings',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final reminderDaysStr = row['reminder_days'] as String? ?? '[1,2,3,4,5,6,7]';
      List<dynamic> reminderDays;
      try {
        reminderDays = jsonDecode(reminderDaysStr) as List;
      } catch (_) {
        reminderDays = [1, 2, 3, 4, 5, 6, 7];
      }
      return {
        'user_id': row['user_id'],
        'reminder_enabled': (row['reminder_enabled'] as int? ?? 1) == 1,
        'reminder_time_local': row['reminder_time_local'],
        'reminder_days': reminderDays,
        'grace_system_enabled': (row['grace_system_enabled'] as int? ?? 1) == 1,
        'privacy_lock_enabled': (row['privacy_lock_enabled'] as int? ?? 0) == 1,
        'region_preference': row['region_preference'],
        'export_format_default': row['export_format_default'],
        'updated_at': row['updated_at'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Entry>> _readEntriesFromLocal(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await DatabaseManager().database;
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];
      final rows = await db.query(
        'entries',
        where: 'user_id = ? AND entry_date >= ? AND entry_date <= ?',
        whereArgs: [userId, startStr, endStr],
        orderBy: 'entry_date DESC',
      );
      return rows.map((r) => Entry.fromJson(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _readEntriesWithJoinsFromLocal(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final entries = await _readEntriesFromLocal(userId, startDate, endDate);
      if (entries.isEmpty) return [];
      final db = await DatabaseManager().database;
      final result = <Map<String, dynamic>>[];
      for (final entry in entries) {
        final entryMap = entry.toSupabaseJson();
        entryMap['created_at'] = entry.createdAt.toIso8601String();
        entryMap['updated_at'] = entry.updatedAt.toIso8601String();
        final entryId = entry.id;
        final affirmations = await db.query('entry_affirmations', where: 'entry_id = ?', whereArgs: [entryId]);
        if (affirmations.isNotEmpty) {
          entryMap['entry_affirmations'] = EntryAffirmations.fromJson(Map<String, dynamic>.from(affirmations.first)).toSupabaseJson();
        }
        final priorities = await db.query('entry_priorities', where: 'entry_id = ?', whereArgs: [entryId]);
        if (priorities.isNotEmpty) {
          entryMap['entry_priorities'] = EntryPriorities.fromJson(Map<String, dynamic>.from(priorities.first)).toSupabaseJson();
        }
        final meals = await db.query('entry_meals', where: 'entry_id = ?', whereArgs: [entryId]);
        if (meals.isNotEmpty) {
          entryMap['entry_meals'] = Map<String, dynamic>.from(meals.first);
        }
        final gratitude = await db.query('entry_gratitude', where: 'entry_id = ?', whereArgs: [entryId]);
        if (gratitude.isNotEmpty) {
          entryMap['entry_gratitude'] = EntryGratitude.fromJson(Map<String, dynamic>.from(gratitude.first)).toSupabaseJson();
        }
        final selfCare = await db.query('entry_self_care', where: 'entry_id = ?', whereArgs: [entryId]);
        if (selfCare.isNotEmpty) {
          final sc = Map<String, dynamic>.from(selfCare.first);
          entryMap['entry_self_care'] = _rowToSupabaseBoolMap(sc, ['sleep', 'get_up_early', 'fresh_air', 'learn_new', 'balanced_diet', 'podcast', 'me_moment', 'hydrated', 'read_book', 'exercise']);
        }
        final showerBath = await db.query('entry_shower_bath', where: 'entry_id = ?', whereArgs: [entryId]);
        if (showerBath.isNotEmpty) {
          final sb = Map<String, dynamic>.from(showerBath.first);
          entryMap['entry_shower_bath'] = {'entry_id': entryId, 'took_shower': (sb['took_shower'] as int? ?? 0) == 1, 'note': sb['note']};
        }
        final tomorrowNotes = await db.query('entry_tomorrow_notes', where: 'entry_id = ?', whereArgs: [entryId]);
        if (tomorrowNotes.isNotEmpty) {
          entryMap['entry_tomorrow_notes'] = EntryTomorrowNotes.fromJson(Map<String, dynamic>.from(tomorrowNotes.first)).toSupabaseJson();
        }
        result.add(entryMap);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _rowToSupabaseBoolMap(Map<String, dynamic> row, List<String> boolKeys) {
    final out = <String, dynamic>{};
    for (final k in row.keys) {
      out[k] = boolKeys.contains(k) ? (row[k] as int? ?? 0) == 1 : row[k];
    }
    return out;
  }

  Future<Entry?> _readEntryByDateFromLocal(String userId, DateTime date) async {
    try {
      final db = await DatabaseManager().database;
      final dateStr = date.toIso8601String().split('T')[0];
      final rows = await db.query(
        'entries',
        where: 'user_id = ? AND entry_date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Entry.fromJson(Map<String, dynamic>.from(rows.first));
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // SUPABASE FETCH (NO STORE) - for merge logic
  // ============================================================================

  /// Fetch user profile from Supabase only (no local store).
  Future<Map<String, dynamic>?> fetchUserProfileFromSupabaseOnly(String userId) async {
    return await _supabase.from('users').select('*').eq('id', userId).maybeSingle();
  }

  /// Fetch user settings from Supabase only (no local store).
  Future<Map<String, dynamic>?> fetchUserSettingsFromSupabaseOnly(String userId) async {
    return await _supabase.from('user_settings').select('*').eq('user_id', userId).maybeSingle();
  }

  /// Fetch entries with joins from Supabase only (no local store).
  Future<List<Map<String, dynamic>>> fetchEntriesWithJoinsFromSupabaseOnly(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];
    final response = await _supabase
        .from('entries')
        .select('''
          *,
          entry_self_care(*),
          entry_meals(*),
          entry_affirmations(*),
          entry_gratitude(*),
          entry_priorities(*),
          entry_tomorrow_notes(*)
        ''')
        .eq('user_id', userId)
        .gte('entry_date', startStr)
        .lte('entry_date', endStr)
        .order('entry_date', ascending: false);
    return (response as List).map((e) => e as Map<String, dynamic>).toList();
  }

  /// Fetch streaks from Supabase only (no local store).
  Future<Map<String, dynamic>?> fetchStreaksFromSupabaseOnly(String userId) async {
    return await _supabase.from('streaks').select('*').eq('user_id', userId).maybeSingle();
  }

  /// Fetch yesterday's insight from Supabase only (no local store).
  Future<Map<String, dynamic>?> fetchYesterdayInsightFromSupabase(String userId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';

    final response = await _supabase
        .from('entry_insights')
        .select('''
          id, entry_id, summary, insight_text, insight_details,
          sentiment_label, processed_at, status,
          entries!inner(entry_date, user_id)
        ''')
        .eq('entries.user_id', userId)
        .eq('entries.entry_date', yesterdayStr)
        .eq('status', 'success')
        .maybeSingle();

    return response;
  }

  /// Store user profile in local DB (used by merge logic).
  Future<void> storeUserProfile(String userId, Map<String, dynamic> response) async {
    final db = await DatabaseManager().database;
    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'id': response['id'],
      'email': response['email'],
      'email_verified': (response['email_verified'] == true) ? 1 : 0,
      'display_name': response['display_name'],
      'avatar_url': response['avatar_url'],
      'locale': response['locale'],
      'timezone': response['timezone'],
      'marketing_opt_in': (response['marketing_opt_in'] == true) ? 1 : 0,
      'created_at': response['created_at'],
      'updated_at': response['updated_at'],
      'is_synced': 1,
      'last_sync_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Store user settings in local DB (used by merge logic).
  Future<void> storeUserSettings(String userId, Map<String, dynamic> response) async {
    final db = await DatabaseManager().database;
    final reminderDays = response['reminder_days'];
    final reminderDaysStr = reminderDays is List ? jsonEncode(reminderDays) : (reminderDays?.toString() ?? '[1,2,3,4,5,6,7]');
    final now = DateTime.now().toIso8601String();
    await db.insert('user_settings', {
      'user_id': response['user_id'],
      'reminder_enabled': (response['reminder_enabled'] == true) ? 1 : 0,
      'reminder_time_local': response['reminder_time_local'],
      'reminder_days': reminderDaysStr,
      'grace_system_enabled': (response['grace_system_enabled'] == true) ? 1 : 0,
      'privacy_lock_enabled': (response['privacy_lock_enabled'] == true) ? 1 : 0,
      'region_preference': response['region_preference'],
      'export_format_default': response['export_format_default'],
      'updated_at': response['updated_at'] ?? now,
      'is_synced': 1,
      'last_sync_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ============================================================================
  // SUPABASE FETCH + STORE HELPERS
  // ============================================================================

  Future<Map<String, dynamic>?> _fetchUserProfileFromSupabaseAndStore(String userId) async {
    try {
      final response = await _supabase.from('users').select('*').eq('id', userId).maybeSingle();
      if (response == null) return null;
      final db = await DatabaseManager().database;
      final now = DateTime.now().toIso8601String();
      await db.insert('users', {
        'id': response['id'],
        'email': response['email'],
        'email_verified': (response['email_verified'] == true) ? 1 : 0,
        'display_name': response['display_name'],
        'avatar_url': response['avatar_url'],
        'locale': response['locale'],
        'timezone': response['timezone'],
        'marketing_opt_in': (response['marketing_opt_in'] == true) ? 1 : 0,
        'created_at': response['created_at'],
        'updated_at': response['updated_at'],
        'is_synced': 1,
        'last_sync_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return response;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA220',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'table': 'users', 'operation': 'fetch_user_profile'},
        ),
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserSettingsFromSupabaseAndStore(String userId) async {
    try {
      final response = await _supabase.from('user_settings').select('*').eq('user_id', userId).maybeSingle();
      if (response == null) return null;
      final db = await DatabaseManager().database;
      final reminderDays = response['reminder_days'];
      final reminderDaysStr = reminderDays is List ? jsonEncode(reminderDays) : (reminderDays?.toString() ?? '[1,2,3,4,5,6,7]');
      final now = DateTime.now().toIso8601String();
      await db.insert('user_settings', {
        'user_id': response['user_id'],
        'reminder_enabled': (response['reminder_enabled'] == true) ? 1 : 0,
        'reminder_time_local': response['reminder_time_local'],
        'reminder_days': reminderDaysStr,
        'grace_system_enabled': (response['grace_system_enabled'] == true) ? 1 : 0,
        'privacy_lock_enabled': (response['privacy_lock_enabled'] == true) ? 1 : 0,
        'region_preference': response['region_preference'],
        'export_format_default': response['export_format_default'],
        'updated_at': response['updated_at'] ?? now,
        'is_synced': 1,
        'last_sync_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return response;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA222',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {'user_id': userId, 'table': 'user_settings', 'operation': 'fetch_user_settings'},
        ),
      );
      rethrow;
    }
  }

  Future<List<Entry>> _fetchEntriesFromSupabaseAndStore(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];
    final response = await _supabase
        .from('entries')
        .select('*')
        .eq('user_id', userId)
        .gte('entry_date', startStr)
        .lte('entry_date', endStr)
        .order('entry_date', ascending: false);
    final entries = (response as List).map((e) => Entry.fromSupabaseJson(e as Map<String, dynamic>)).toList();
    final db = await DatabaseManager().database;
    final now = DateTime.now().toIso8601String();
    for (final entry in entries) {
      final json = entry.toJson();
      json['is_synced'] = 1;
      json['last_sync_at'] = now;
      await db.insert('entries', json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return entries;
  }

  Future<List<Map<String, dynamic>>> _fetchEntriesWithJoinsFromSupabaseAndStore(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];
    final response = await _supabase
        .from('entries')
        .select('''
          *,
          entry_self_care(*),
          entry_meals(*),
          entry_affirmations(*),
          entry_gratitude(*),
          entry_priorities(*),
          entry_tomorrow_notes(*)
        ''')
        .eq('user_id', userId)
        .gte('entry_date', startStr)
        .lte('entry_date', endStr)
        .order('entry_date', ascending: false);
    final list = (response as List).map((e) => e as Map<String, dynamic>).toList();
    if (list.isNotEmpty) {
      await EntryStorageHelper.storeEntriesWithRelatedData(list, userId);
    }
    return list;
  }

  // ============================================================================
  // PUBLIC FETCH METHODS
  // ============================================================================

  /// Fetch entries with date range (local-first, Supabase fallback)
  Future<List<Entry>> fetchEntries({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
    bool useLocalOnly = false,
  }) async {
    final local = await _readEntriesFromLocal(userId, startDate, endDate);
    if (useLocalOnly) return local;
    if (!forceRefresh && local.isNotEmpty) return local;
    try {
      return await _fetchEntriesFromSupabaseAndStore(userId, startDate, endDate);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA200',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDate.toIso8601String().split('T')[0],
            'end_date': endDate.toIso8601String().split('T')[0],
            'table': 'entries',
            'operation': 'fetch_entries',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch habits_daily with date range
  ///
  /// DEPRECATED: This method is deprecated. habits_daily table removed from Supabase.
  /// Use streaks.today_* fields instead. This method now only returns today's data from local DB.
  ///
  /// Returns today's data from local SQLite only (if available).
  /// No longer fetches from Supabase or historical data.
  @Deprecated(
    'Use streaks.today_* fields instead. This method only returns today\'s local data.',
  )
  Future<List<HabitsDaily>> fetchHabitsDaily({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // DEPRECATED: Only return today's data from local DB (if available)
    // No longer fetches from Supabase or historical data
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final db = await DatabaseManager().database;

      // Only return today's data from local DB
      final todayHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, today],
        limit: 1,
      );

      if (todayHabits.isEmpty) {
        return <HabitsDaily>[];
      }

      return todayHabits.map((h) {
        return HabitsDaily(
          id: h['id'] as String,
          userId: h['user_id'] as String,
          date: DateTime.parse(h['date'] as String),
          wroteEntry: (h['wrote_entry'] as int? ?? 0) == 1,
          filledAffirmations: (h['filled_affirmations'] as int? ?? 0) == 1,
          filledGratitude: (h['filled_gratitude'] as int? ?? 0) == 1,
          selfCareCompletedCount: h['self_care_completed_count'] as int? ?? 0,
          gracePiecesEarned: (h['grace_pieces_earned'] as num? ?? 0.0)
              .toDouble(),
        );
      }).toList();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA211',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'operation': 'fetch_habits_daily_deprecated',
          },
        ),
      );
      return <HabitsDaily>[];
    }
  }

  /// Fetch monthly insights list
  Future<List<MonthMetadata>> fetchMonthlyInsightsList({
    required String userId,
  }) async {
    try {
      final service = AnalyticsService();
      return await service.getMonthlyInsightsList(userId);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA205',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'table': 'monthly_insights',
            'operation': 'fetch_monthly_insights_list',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch monthly analytics
  Future<MonthlyAnalyticsData> fetchMonthlyAnalytics({
    required String userId,
    required DateTime monthStart,
  }) async {
    try {
      final service = AnalyticsService();
      return await service.getMonthlyAnalytics(monthStart);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA207',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'month_start': monthStart.toIso8601String(),
            'operation': 'fetch_monthly_analytics',
          },
        ),
      );
      rethrow;
    }
  }

  // ============================================================================
  // USER & SETTINGS METHODS
  // ============================================================================

  /// Fetch user profile from users table
  /// Fetch user profile (local-first, Supabase fallback)
  Future<Map<String, dynamic>?> fetchUserProfile(String userId, {bool forceRefresh = false, bool useLocalOnly = false}) async {
    final local = await _readUserProfileFromLocal(userId);
    if (useLocalOnly) return local;
    if (!forceRefresh && local != null) return local;
    return await _fetchUserProfileFromSupabaseAndStore(userId);
  }

  /// Fetch user settings (local-first, Supabase fallback)
  Future<Map<String, dynamic>?> fetchUserSettings(String userId, {bool forceRefresh = false, bool useLocalOnly = false}) async {
    final local = await _readUserSettingsFromLocal(userId);
    if (useLocalOnly) return local;
    if (!forceRefresh && local != null) return local;
    return await _fetchUserSettingsFromSupabaseAndStore(userId);
  }

  // fetchStreaks removed — app uses local only; splash uses fetchStreaksFromSupabaseOnly via fetchAndMergeStreaks

  // ============================================================================
  // EXTENDED ENTRY METHODS
  // ============================================================================

  /// Fetch single entry by date (local-first, Supabase fallback)
  Future<Entry?> fetchEntryByDate(String userId, DateTime date, {bool forceRefresh = false, bool useLocalOnly = false}) async {
    if (!forceRefresh) {
      final local = await _readEntryByDateFromLocal(userId, date);
      if (local != null) return local;
    }
    if (useLocalOnly) return null;
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await _supabase
          .from('entries')
          .select('*')
          .eq('user_id', userId)
          .eq('entry_date', dateStr)
          .maybeSingle();
      if (response == null) return null;
      final entry = Entry.fromSupabaseJson(response);
      final db = await DatabaseManager().database;
      final now = DateTime.now().toIso8601String();
      final json = entry.toJson();
      json['is_synced'] = 1;
      json['last_sync_at'] = now;
      await db.insert('entries', json, conflictAlgorithm: ConflictAlgorithm.replace);
      return entry;
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA226',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'date': date.toIso8601String().split('T')[0],
            'table': 'entries',
            'operation': 'fetch_entry_by_date',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch entries by mood with JOINs (for HistoryService mood filter)
  Future<List<Map<String, dynamic>>> fetchEntriesByMoodWithJoins({
    required String userId,
    required int moodScore,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      var query = _supabase
          .from('entries')
          .select('''
            *,
            entry_self_care(*),
            entry_meals(*),
            entry_affirmations(*),
            entry_gratitude(*),
            entry_priorities(*),
            entry_tomorrow_notes(*)
          ''')
          .eq('user_id', userId)
          .eq('mood_score', moodScore);

      if (endDate != null) {
        final endDateStrVal = endDate.toIso8601String().split('T')[0];
        query = query.lt('entry_date', endDateStrVal);
      }
      if (startDate != null) {
        final startDateStr = startDate.toIso8601String().split('T')[0];
        query = query.gte('entry_date', startDateStr);
      }

      final response = await query
          .order('entry_date', ascending: false)
          .range(offset, offset + limit - 1);
      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA232',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'mood_score': moodScore,
            'end_date': endDate?.toIso8601String(),
            'table': 'entries',
            'operation': 'fetch_entries_by_mood_with_joins',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch entries with JOINs (local-first, Supabase fallback)
  Future<List<Map<String, dynamic>>> fetchEntriesWithJoins({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
    bool useLocalOnly = false,
  }) async {
    final local = await _readEntriesWithJoinsFromLocal(userId, startDate, endDate);
    if (useLocalOnly) return local;
    if (!forceRefresh && local.isNotEmpty) return local;
    try {
      return await _fetchEntriesWithJoinsFromSupabaseAndStore(userId, startDate, endDate);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA228',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDate.toIso8601String().split('T')[0],
            'end_date': endDate.toIso8601String().split('T')[0],
            'table': 'entries',
            'operation': 'fetch_entries_with_joins',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch entries with specific select columns
  Future<List<Map<String, dynamic>>> fetchEntriesWithSelect({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required String select,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];

    try {
      final response = await _supabase
          .from('entries')
          .select(select)
          .eq('user_id', userId)
          .gte('entry_date', startDateStr)
          .lte('entry_date', endDateStr)
          .order('entry_date', ascending: false);

      return (response as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA230',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'start_date': startDateStr,
            'end_date': endDateStr,
            'select': select,
            'table': 'entries',
            'operation': 'fetch_entries_with_select',
          },
        ),
      );
      rethrow;
    }
  }

  // ============================================================================
  // EXTENDED HABITS METHODS
  // ============================================================================

  /// Fetch single day habits (local-only)
  ///
  /// habits_daily removed from Supabase; reads from local SQLite only.
  /// When local empty, returns null (no Supabase fallback).
  Future<HabitsDaily?> fetchHabitsForDate(String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];

    try {
      final db = await DatabaseManager().database;
      final localHabits = await db.query(
        'habits_daily',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, dateStr],
        limit: 1,
      );

      if (localHabits.isEmpty) return null;

      final habit = localHabits.first;
      return HabitsDaily(
        id: habit['id'] as String,
        userId: habit['user_id'] as String,
        date: DateTime.parse(habit['date'] as String),
        wroteEntry: (habit['wrote_entry'] as int? ?? 0) == 1,
        filledAffirmations: (habit['filled_affirmations'] as int? ?? 0) == 1,
        filledGratitude: (habit['filled_gratitude'] as int? ?? 0) == 1,
        selfCareCompletedCount: habit['self_care_completed_count'] as int? ?? 0,
        gracePiecesEarned: (habit['grace_pieces_earned'] as num? ?? 0.0)
            .toDouble(),
      );
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA234',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'date': dateStr,
            'table': 'habits_daily',
            'operation': 'fetch_habits_for_date',
          },
        ),
      );
      rethrow;
    }
  }

  // ============================================================================
  // ANALYTICS METHODS
  // ============================================================================

  /// Fetch weekly analytics
  Future<WeeklyAnalyticsData> fetchWeeklyAnalytics({
    required String userId,
    required DateTime weekStart,
  }) async {
    try {
      final service = AnalyticsService();
      return await service.getWeeklyAnalytics(weekStart);
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA236',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'week_start': weekStart.toIso8601String(),
            'operation': 'fetch_weekly_analytics',
          },
        ),
      );
      rethrow;
    }
  }

  /// Fetch entry insights
  Future<List<EntryInsights>> fetchEntryInsights({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? entryId,
  }) async {
    try {
      var query = _supabase
          .from('entry_insights')
          .select('''
            id,
            entry_id,
            summary,
            insight_text,
            insight_details,
            sentiment_label,
            sentiment_score,
            topics,
            processed_at,
            status,
            entries!inner(entry_date, user_id)
          ''')
          .eq('entries.user_id', userId)
          .eq('status', 'success');

      if (entryId != null) {
        query = query.eq('entry_id', entryId);
      } else if (startDate != null && endDate != null) {
        final startStr = startDate.toIso8601String().split('T')[0];
        final endStr = endDate.toIso8601String().split('T')[0];
        query = query
            .gte('entries.entry_date', startStr)
            .lte('entries.entry_date', endStr);
      }

      final response = await query.order(
        'processed_at',
        ascending: false,
      );

      return (response as List).map((e) {
        final json = e as Map<String, dynamic>;
        return EntryInsights.fromJson(json);
      }).toList();
    } catch (e) {
      await ErrorLoggingService.logHighError(
        error: ErrorContext.fromException(
          errorCode: 'ERRDATA238',
          severity: ErrorSeverity.high,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'user_id': userId,
            'entry_id': entryId,
            'start_date': startDate?.toIso8601String(),
            'end_date': endDate?.toIso8601String(),
            'table': 'entry_insights',
            'operation': 'fetch_entry_insights',
          },
        ),
      );
      rethrow;
    }
  }

  // ============================================================================
  // CACHE INVALIDATION (no-op — use ref.invalidate(provider) instead)
  // ============================================================================

  void invalidateEntriesCache(String userId, DateTime? date) {}
  void invalidateHabitsCache(String userId, DateTime? date) {}
  void invalidateHomeSummaryCache(String userId) {}
  void invalidateMonthlyCache(String userId, DateTime? monthStart) {}
  void invalidateUserSettingsCache(String userId) {}
  void invalidateStreaksCache(String userId) {}
  void invalidateAllUserCache(String userId) {}
}
