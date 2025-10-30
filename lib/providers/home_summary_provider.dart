import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/home_summary_models.dart';
import '../services/home_summary_service.dart';

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  final service = HomeSummaryService(client: client);
  if (userId == null) return const HomeSummary();
  return await service.fetchAll(userId);
});


