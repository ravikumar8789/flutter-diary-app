import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';
import '../services/home_summary_service.dart';
import '../services/ai_service.dart';

// Note: homeSummaryProvider is now defined in data_providers.dart
// It's NOT autoDispose and uses DataRepository for caching
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

/// Provider for yesterday's insight
final yesterdayInsightProvider = FutureProvider.autoDispose<DailyInsight?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  
  final aiService = AIService(client: client);
  return await aiService.getYesterdayInsight(userId);
});


