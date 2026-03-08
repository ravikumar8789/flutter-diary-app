import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';
import '../services/home_summary_service.dart';
import '../services/ai_service.dart';
import '../services/connectivity_service.dart';
import '../services/entry_insight_storage_helper.dart';

// Note: homeSummaryProvider is now defined in data_providers.dart
// It's NOT autoDispose
// Screens should import 'data_providers.dart' to use it

// Keep other providers with autoDispose (they're less frequently used)
final aiInsightProvider = FutureProvider.autoDispose<String?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  final service = HomeSummaryService(client: client);
  if (userId == null) return null;
  return await service.fetchAiInsight(userId);
});

final recentInsightsProvider = FutureProvider.autoDispose<List<DailyInsightWithDate>>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  
  final aiService = AIService(client: client);
  return await aiService.getRecentInsights(userId, limit: 7);
});

/// Provider for yesterday's insight (local-first: read local, fetch online only when empty).
final yesterdayInsightProvider = FutureProvider.autoDispose<DailyInsight?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final local = await EntryInsightStorageHelper.getYesterdayInsightFromLocal(userId);
  if (local != null) return local;

  final isOnline = await ConnectivityService().isOnline();
  if (!isOnline) return null;

  final aiService = AIService(client: client);
  final insight = await aiService.getYesterdayInsight(userId);
  if (insight != null) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final entryDateStr = '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
    await EntryInsightStorageHelper.storeYesterdayInsight(userId, {
      'id': insight.id,
      'entry_id': insight.entryId,
      'summary': insight.insightText,
      'insight_text': insight.insightText,
      'insight_details': insight.insightDetails?.toJson(),
      'sentiment_label': insight.sentimentLabel,
      'processed_at': insight.processedAt.toIso8601String(),
      'entries': {'entry_date': entryDateStr, 'user_id': userId},
    });
  }
  return insight;
});


