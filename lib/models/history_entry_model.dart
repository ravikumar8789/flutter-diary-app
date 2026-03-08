import 'entry_models.dart';
import 'analytics_models.dart';

/// Extended DailyInsight with topics for history screen
class HistoryDailyInsight {
  final String id;
  final String entryId;
  final String insightText;
  final String? sentimentLabel;
  final DateTime processedAt;
  final InsightDetails? insightDetails;
  final List<String> topics; // Added for history screen
  final String status; // 'success', 'pending', 'error'

  HistoryDailyInsight({
    required this.id,
    required this.entryId,
    required this.insightText,
    this.sentimentLabel,
    required this.processedAt,
    this.insightDetails,
    this.topics = const [],
    this.status = 'success',
  });

  bool get hasInsights => status == 'success' && insightText.isNotEmpty;
}

/// Complete history entry with all related data
class HistoryEntry {
  final Entry entry;
  final HistoryDailyInsight? insight;
  final EntrySelfCare? selfCare;
  final EntryMeals? meals;
  final EntryAffirmations? affirmations;
  final EntryGratitude? gratitude;
  final EntryPriorities? priorities;
  final EntryTomorrowNotes? tomorrowNotes;

  HistoryEntry({
    required this.entry,
    this.insight,
    this.selfCare,
    this.meals,
    this.affirmations,
    this.gratitude,
    this.priorities,
    this.tomorrowNotes,
  });

  // Computed properties for card display
  int get wordCount {
    final text = entry.diaryText ?? '';
    if (text.isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  int get selfCareCount => _countSelfCare();

  int get mealsCount => _countMeals();

  bool get hasInsights => insight?.hasInsights ?? false;

  String get sentiment => insight?.sentimentLabel ?? 'neutral';

  String get preview => _generatePreview();

  // Helper methods
  int _countSelfCare() {
    if (selfCare == null) return 0;
    int count = 0;
    if (selfCare!.sleep == true) count++;
    if (selfCare!.exercise == true) count++;
    if (selfCare!.freshAir == true) count++;
    if (selfCare!.learnNew == true) count++;
    if (selfCare!.balancedDiet == true) count++;
    if (selfCare!.podcast == true) count++;
    if (selfCare!.meMoment == true) count++;
    if (selfCare!.hydrated == true) count++;
    if (selfCare!.readBook == true) count++;
    if (selfCare!.getUpEarly == true) count++;
    return count;
  }

  int _countMeals() {
    if (meals == null) return 0;
    int count = 0;
    if (meals!.breakfast?.isNotEmpty == true) count++;
    if (meals!.lunch?.isNotEmpty == true) count++;
    if (meals!.dinner?.isNotEmpty == true) count++;
    return count;
  }

  String _generatePreview() {
    final text = entry.diaryText ?? '';
    if (text.isEmpty) return '';
    if (text.length <= 100) return text;
    return text.substring(0, 100) + '...';
  }
}

