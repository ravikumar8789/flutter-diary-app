import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/analytics_models.dart';
import '../models/history_entry_model.dart';
import 'database/database_manager.dart';

/// Helper for storing/reading yesterday's insight and entry insights locally.
/// Table holds only one row per user; overwrite on each fetch.
class EntryInsightStorageHelper {
  /// Store yesterday's insight (overwrites existing row for user).
  static Future<void> storeYesterdayInsight(
    String userId,
    Map<String, dynamic> insight,
  ) async {
    final db = await DatabaseManager().database;
    final entries = insight['entries'];
    final entryDate = entries is Map
        ? (entries['entry_date'] as String? ?? '')
        : '';

    final insightDetails = insight['insight_details'];
    final insightDetailsStr = insightDetails != null
        ? jsonEncode(insightDetails is Map ? insightDetails : {})
        : null;

    await db.insert(
      'yesterday_insight',
      {
        'user_id': userId,
        'id': insight['id'] as String,
        'entry_id': insight['entry_id'] as String,
        'entry_date': entryDate,
        'summary': insight['summary'] as String?,
        'insight_text': insight['insight_text'] as String?,
        'insight_details': insightDetailsStr,
        'sentiment_label': insight['sentiment_label'] as String?,
        'processed_at': insight['processed_at'] as String,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Clear yesterday's insight for user.
  static Future<void> clearYesterdayInsight(String userId) async {
    final db = await DatabaseManager().database;
    await db.delete(
      'yesterday_insight',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Read yesterday's insight from local DB. Returns null if none.
  static Future<DailyInsight?> getYesterdayInsightFromLocal(String userId) async {
    try {
      final db = await DatabaseManager().database;
      final rows = await db.query(
        'yesterday_insight',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      InsightDetails? insightDetails;
      final detailsStr = row['insight_details'] as String?;
      if (detailsStr != null && detailsStr.isNotEmpty) {
        try {
          insightDetails = InsightDetails.fromJson(
            jsonDecode(detailsStr) as Map<String, dynamic>,
          );
        } catch (_) {
          insightDetails = null;
        }
      }

      final insightText = row['summary'] as String? ??
          row['insight_text'] as String? ??
          '';
      final processedAtStr = row['processed_at'] as String?;
      if (processedAtStr == null) return null;

      return DailyInsight(
        id: row['id'] as String,
        entryId: row['entry_id'] as String,
        insightText: insightText,
        sentimentLabel: row['sentiment_label'] as String?,
        processedAt: DateTime.parse(processedAtStr),
        insightDetails: insightDetails,
      );
    } catch (_) {
      return null;
    }
  }

  /// Store entry insight in entry_insights_local (60-day cache for History).
  static Future<void> storeEntryInsightLocal(
    String userId,
    String entryId,
    String entryDate,
    Map<String, dynamic> insight,
  ) async {
    final db = await DatabaseManager().database;
    final insightDetails = insight['insight_details'];
    final insightDetailsStr = insightDetails != null
        ? jsonEncode(insightDetails is Map ? insightDetails : {})
        : null;
    final topics = insight['topics'];
    final topicsStr = topics is List
        ? jsonEncode(topics)
        : (topics != null ? jsonEncode([topics]) : '[]');

    await db.insert(
      'entry_insights_local',
      {
        'entry_id': entryId,
        'user_id': userId,
        'entry_date': entryDate,
        'id': insight['id'] as String,
        'summary': insight['summary'] as String?,
        'insight_text': insight['insight_text'] as String?,
        'insight_details': insightDetailsStr,
        'sentiment_label': insight['sentiment_label'] as String?,
        'topics': topicsStr,
        'processed_at': insight['processed_at'] as String,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Read entry insight from local DB. Returns null if none.
  static Future<HistoryDailyInsight?> getEntryInsightFromLocal(
    String entryId,
  ) async {
    try {
      final db = await DatabaseManager().database;
      final rows = await db.query(
        'entry_insights_local',
        where: 'entry_id = ?',
        whereArgs: [entryId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      InsightDetails? insightDetails;
      final detailsStr = row['insight_details'] as String?;
      if (detailsStr != null && detailsStr.isNotEmpty) {
        try {
          insightDetails = InsightDetails.fromJson(
            jsonDecode(detailsStr) as Map<String, dynamic>,
          );
        } catch (_) {
          insightDetails = null;
        }
      }

      List<String> topics = [];
      final topicsStr = row['topics'] as String?;
      if (topicsStr != null && topicsStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(topicsStr);
          if (decoded is List) {
            topics = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      final insightText = row['summary'] as String? ??
          row['insight_text'] as String? ??
          '';
      final processedAtStr = row['processed_at'] as String?;
      if (processedAtStr == null) return null;

      return HistoryDailyInsight(
        id: row['id'] as String,
        entryId: entryId,
        insightText: insightText,
        sentimentLabel: row['sentiment_label'] as String?,
        processedAt: DateTime.parse(processedAtStr),
        insightDetails: insightDetails,
        topics: topics,
        status: 'success',
      );
    } catch (_) {
      return null;
    }
  }

  /// Delete entry insights older than retentionDays.
  static Future<void> clearEntryInsightsOlderThan({
    int retentionDays = 60,
  }) async {
    final db = await DatabaseManager().database;
    final cutoff =
        DateTime.now().subtract(Duration(days: retentionDays));
    final cutoffStr = cutoff.toIso8601String().split('T')[0];
    await db.delete(
      'entry_insights_local',
      where: 'entry_date < ?',
      whereArgs: [cutoffStr],
    );
  }
}
