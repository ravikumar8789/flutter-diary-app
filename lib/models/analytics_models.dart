/// Entry insights model matching the entry_insights table
class EntryInsights {
  final String id;
  final String entryId;
  final DateTime processedAt;
  final SentimentLabel? sentimentLabel;
  final double? sentimentScore;
  final List<String> topics;
  final String? summary;
  final Map<String, dynamic>? embeddingJson;
  final Map<String, dynamic>? insightDetails;
  final String? modelVersion;
  final int costTokensPrompt;
  final int costTokensCompletion;
  final InsightStatus status;
  final String? errorMessage;

  EntryInsights({
    required this.id,
    required this.entryId,
    required this.processedAt,
    this.sentimentLabel,
    this.sentimentScore,
    this.topics = const [],
    this.summary,
    this.embeddingJson,
    this.insightDetails,
    this.modelVersion,
    this.costTokensPrompt = 0,
    this.costTokensCompletion = 0,
    this.status = InsightStatus.pending,
    this.errorMessage,
  });

  factory EntryInsights.fromJson(Map<String, dynamic> json) {
    return EntryInsights(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      processedAt: DateTime.parse(json['processed_at'] as String),
      sentimentLabel: SentimentLabel.fromString(
        json['sentiment_label'] as String?,
      ),
      sentimentScore: json['sentiment_score'] as double?,
      topics: List<String>.from(json['topics'] as List? ?? []),
      summary: json['summary'] as String?,
      embeddingJson: json['embedding_json'] != null
          ? Map<String, dynamic>.from(json['embedding_json'] as Map)
          : null,
      insightDetails: json['insight_details'] != null
          ? Map<String, dynamic>.from(json['insight_details'] as Map)
          : null,
      modelVersion: json['model_version'] as String?,
      costTokensPrompt: json['cost_tokens_prompt'] as int? ?? 0,
      costTokensCompletion: json['cost_tokens_completion'] as int? ?? 0,
      status: InsightStatus.fromString(json['status'] as String?),
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_id': entryId,
      'processed_at': processedAt.toIso8601String(),
      'sentiment_label': sentimentLabel?.value,
      'sentiment_score': sentimentScore,
      'topics': topics,
      'summary': summary,
      'embedding_json': embeddingJson,
      'insight_details': insightDetails,
      'model_version': modelVersion,
      'cost_tokens_prompt': costTokensPrompt,
      'cost_tokens_completion': costTokensCompletion,
      'status': status.value,
      'error_message': errorMessage,
    };
  }
}

/// Weekly insights model matching the weekly_insights table
class WeeklyInsights {
  final String id;
  final String userId;
  final DateTime weekStart;
  final double? moodAvg;
  final double? cupsAvg;
  final double? selfCareRate;
  final List<String> topTopics;
  final String? highlights;
  final DateTime generatedAt;

  WeeklyInsights({
    required this.id,
    required this.userId,
    required this.weekStart,
    this.moodAvg,
    this.cupsAvg,
    this.selfCareRate,
    this.topTopics = const [],
    this.highlights,
    required this.generatedAt,
  });

  factory WeeklyInsights.fromJson(Map<String, dynamic> json) {
    return WeeklyInsights(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      moodAvg: json['mood_avg'] as double?,
      cupsAvg: json['cups_avg'] as double?,
      selfCareRate: json['self_care_rate'] as double?,
      topTopics: List<String>.from(json['top_topics'] as List? ?? []),
      highlights: json['highlights'] as String?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'week_start': weekStart.toIso8601String().split('T')[0], // Date only
      'mood_avg': moodAvg,
      'cups_avg': cupsAvg,
      'self_care_rate': selfCareRate,
      'top_topics': topTopics,
      'highlights': highlights,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}

/// Analytics event model matching the analytics_events table
class AnalyticsEvent {
  final String id;
  final String? userId;
  final String eventType;
  final DateTime eventAt;
  final Map<String, dynamic> props;

  AnalyticsEvent({
    required this.id,
    this.userId,
    required this.eventType,
    required this.eventAt,
    this.props = const {},
  });

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      eventType: json['event_type'] as String,
      eventAt: DateTime.parse(json['event_at'] as String),
      props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'event_type': eventType,
      'event_at': eventAt.toIso8601String(),
      'props': props,
    };
  }
}

/// Streak model matching the streaks table
class Streak {
  final String userId;
  final int current;
  final int longest;
  final DateTime? lastEntryDate;
  final int freezeCredits;
  final DateTime updatedAt;

  Streak({
    required this.userId,
    this.current = 0,
    this.longest = 0,
    this.lastEntryDate,
    this.freezeCredits = 0,
    required this.updatedAt,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      userId: json['user_id'] as String,
      current: json['current'] as int? ?? 0,
      longest: json['longest'] as int? ?? 0,
      lastEntryDate: json['last_entry_date'] != null
          ? DateTime.parse(json['last_entry_date'] as String)
          : null,
      freezeCredits: json['freeze_credits'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'current': current,
      'longest': longest,
      'last_entry_date': lastEntryDate?.toIso8601String().split(
        'T',
      )[0], // Date only
      'freeze_credits': freezeCredits,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Daily habits model matching the habits_daily table
class HabitsDaily {
  final String id;
  final String userId;
  final DateTime date;
  final bool wroteEntry;
  final bool filledAffirmations;
  final bool filledGratitude;
  final int selfCareCompletedCount;

  HabitsDaily({
    required this.id,
    required this.userId,
    required this.date,
    this.wroteEntry = false,
    this.filledAffirmations = false,
    this.filledGratitude = false,
    this.selfCareCompletedCount = 0,
  });

  factory HabitsDaily.fromJson(Map<String, dynamic> json) {
    return HabitsDaily(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      wroteEntry: json['wrote_entry'] as bool? ?? false,
      filledAffirmations: json['filled_affirmations'] as bool? ?? false,
      filledGratitude: json['filled_gratitude'] as bool? ?? false,
      selfCareCompletedCount: json['self_care_completed_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0], // Date only
      'wrote_entry': wroteEntry,
      'filled_affirmations': filledAffirmations,
      'filled_gratitude': filledGratitude,
      'self_care_completed_count': selfCareCompletedCount,
    };
  }
}

/// Sentiment label enum
enum SentimentLabel {
  negative('negative'),
  neutral('neutral'),
  positive('positive');

  const SentimentLabel(this.value);
  final String value;

  static SentimentLabel? fromString(String? value) {
    switch (value) {
      case 'negative':
        return SentimentLabel.negative;
      case 'neutral':
        return SentimentLabel.neutral;
      case 'positive':
        return SentimentLabel.positive;
      default:
        return null;
    }
  }
}

/// Insight status enum
enum InsightStatus {
  pending('pending'),
  success('success'),
  error('error');

  const InsightStatus(this.value);
  final String value;

  static InsightStatus fromString(String? value) {
    switch (value) {
      case 'success':
        return InsightStatus.success;
      case 'error':
        return InsightStatus.error;
      default:
        return InsightStatus.pending;
    }
  }
}

/// Analytics period enum
enum AnalyticsPeriod {
  weekly,
  monthly;

  String get label {
    switch (this) {
      case AnalyticsPeriod.weekly:
        return 'Weekly';
      case AnalyticsPeriod.monthly:
        return 'Monthly';
    }
  }
}

/// Mood data point for charts
class MoodDataPoint {
  final DateTime date;
  final double moodScore;
  final String? label;

  MoodDataPoint({
    required this.date,
    required this.moodScore,
    this.label,
  });
}

/// Weekly analytics data model
class WeeklyAnalyticsData {
  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int entriesCount;
  final double? moodAvg;
  final double cupsAvg;
  final double selfCareRate;
  final String? moodTrend;
  final String? highlights;
  final List<String> keyInsights;
  final List<String> recommendations;
  final double? consistencyScore;
  final List<String> topTopics;
  final List<MoodDataPoint> moodTrendData;
  final dynamic weeklyInsight; // WeeklyInsight from ai_service.dart

  WeeklyAnalyticsData({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.entriesCount,
    this.moodAvg,
    required this.cupsAvg,
    required this.selfCareRate,
    this.moodTrend,
    this.highlights,
    this.keyInsights = const [],
    this.recommendations = const [],
    this.consistencyScore,
    this.topTopics = const [],
    this.moodTrendData = const [],
    this.weeklyInsight,
  });
}

/// Monthly analytics data model (aggregated)
class MonthlyAnalyticsData {
  final DateTime monthStart;
  final DateTime monthEnd;
  final int totalEntries;
  final double avgMood;
  final double avgCups;
  final double avgSelfCareRate;
  final double? overallConsistency;
  final List<String> combinedTopics;
  final String? overallMoodTrend;
  final String combinedHighlights;
  final List<String> keyInsights;
  final List<String> recommendations;
  final List<MoodDataPoint> moodTrendData;
  final dynamic monthlyInsight; // MonthlyInsight from ai_service.dart

  MonthlyAnalyticsData({
    required this.monthStart,
    required this.monthEnd,
    required this.totalEntries,
    required this.avgMood,
    required this.avgCups,
    required this.avgSelfCareRate,
    this.overallConsistency,
    this.combinedTopics = const [],
    this.overallMoodTrend,
    this.combinedHighlights = '',
    this.keyInsights = const [],
    this.recommendations = const [],
    this.moodTrendData = const [],
    this.monthlyInsight,
  });
}

/// Daily insight with date information for carousel
class DailyInsightWithDate {
  final String id;
  final String entryId;
  final String insightText;
  final String? sentimentLabel;
  final DateTime processedAt;
  final DateTime entryDate;
  final String relativeDateLabel; // "Today", "Yesterday", "2 days ago"
  final double? moodScore;

  DailyInsightWithDate({
    required this.id,
    required this.entryId,
    required this.insightText,
    this.sentimentLabel,
    required this.processedAt,
    required this.entryDate,
    required this.relativeDateLabel,
    this.moodScore,
  });

  factory DailyInsightWithDate.fromJson(Map<String, dynamic> json) {
    final entryDate = DateTime.parse(json['entries']['entry_date'] as String);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
    final daysDiff = today.difference(entryDay).inDays;

    String relativeLabel;
    if (daysDiff == 0) {
      relativeLabel = 'Today';
    } else if (daysDiff == 1) {
      relativeLabel = 'Yesterday';
    } else {
      relativeLabel = '$daysDiff days ago';
    }

    return DailyInsightWithDate(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      insightText: json['insight_text'] as String? ?? json['summary'] as String? ?? '',
      sentimentLabel: json['sentiment_label'] as String?,
      processedAt: DateTime.parse(json['processed_at'] as String),
      entryDate: entryDate,
      relativeDateLabel: relativeLabel,
      moodScore: (json['entries']['mood_score'] as num?)?.toDouble(),
    );
  }
}

/// Structured insight details from AI analysis
class InsightDetails {
  final String? whatWentWell;
  final String? progressArea;
  final String? selfCareBalance;
  final String? emotionalPattern;

  InsightDetails({
    this.whatWentWell,
    this.progressArea,
    this.selfCareBalance,
    this.emotionalPattern,
  });

  factory InsightDetails.fromJson(Map<String, dynamic> json) {
    return InsightDetails(
      whatWentWell: json['what_went_well'] as String?,
      progressArea: json['progress_area'] as String?,
      selfCareBalance: json['self_care_balance'] as String?,
      emotionalPattern: json['emotional_pattern'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'what_went_well': whatWentWell,
      'progress_area': progressArea,
      'self_care_balance': selfCareBalance,
      'emotional_pattern': emotionalPattern,
    };
  }

  bool get hasData => 
    whatWentWell != null || 
    progressArea != null || 
    selfCareBalance != null || 
    emotionalPattern != null;
}

/// Daily insight model (basic)
class DailyInsight {
  final String id;
  final String entryId;
  final String insightText;
  final String? sentimentLabel;
  final DateTime processedAt;
  final InsightDetails? insightDetails;

  DailyInsight({
    required this.id,
    required this.entryId,
    required this.insightText,
    this.sentimentLabel,
    required this.processedAt,
    this.insightDetails,
  });
}

/// Daily insight with mood for timeline
class DailyInsightWithMood {
  final DailyInsight insight;
  final DateTime entryDate;
  final double? moodScore;
  final String dayLabel; // "Monday", "Tuesday", etc.

  DailyInsightWithMood({
    required this.insight,
    required this.entryDate,
    this.moodScore,
    required this.dayLabel,
  });

  factory DailyInsightWithMood.fromJson(Map<String, dynamic> json) {
    final entryDate = DateTime.parse(json['entries']['entry_date'] as String);
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayLabel = dayNames[entryDate.weekday - 1];

    return DailyInsightWithMood(
      insight: DailyInsight(
        id: json['id'] as String,
        entryId: json['entry_id'] as String,
        insightText: json['insight_text'] as String? ?? json['summary'] as String? ?? '',
        sentimentLabel: json['sentiment_label'] as String?,
        processedAt: DateTime.parse(json['processed_at'] as String),
      ),
      entryDate: entryDate,
      moodScore: (json['entries']['mood_score'] as num?)?.toDouble(),
      dayLabel: dayLabel,
    );
  }
}

/// Period comparison data
class PeriodComparison {
  final PeriodData current;
  final PeriodData previous;
  final ComparisonMetrics metrics;

  PeriodComparison({
    required this.current,
    required this.previous,
    required this.metrics,
  });
}

class PeriodData {
  final DateTime startDate;
  final DateTime endDate;
  final int entriesCount;
  final double? avgMood;
  final double consistencyScore;
  final double selfCareRate;

  PeriodData({
    required this.startDate,
    required this.endDate,
    required this.entriesCount,
    this.avgMood,
    required this.consistencyScore,
    required this.selfCareRate,
  });
}

class ComparisonMetrics {
  final double moodChange;
  final int entriesChange;
  final double consistencyChange;
  final double selfCareChange;
  final String overallTrend; // 'improving', 'declining', 'stable'

  ComparisonMetrics({
    required this.moodChange,
    required this.entriesChange,
    required this.consistencyChange,
    required this.selfCareChange,
    required this.overallTrend,
  });
}

/// Homescreen insight set - 5 insights per entry for carousel display
class HomescreenInsightSet {
  final String id;
  final String entryId;
  final String userId;
  final DateTime entryDate;
  final String insight1; // Improvement
  final String insight2; // Lacking
  final String insight3; // Best Thing
  final String insight4; // Achievement
  final String insight5; // Progress
  final DateTime generatedAt;
  final String status;

  HomescreenInsightSet({
    required this.id,
    required this.entryId,
    required this.userId,
    required this.entryDate,
    required this.insight1,
    required this.insight2,
    required this.insight3,
    required this.insight4,
    required this.insight5,
    required this.generatedAt,
    this.status = 'success',
  });

  factory HomescreenInsightSet.fromJson(Map<String, dynamic> json) {
    final entryDate = json['entries'] != null
        ? DateTime.parse(json['entries']['entry_date'] as String)
        : DateTime.parse(json['generated_at'] as String);

    return HomescreenInsightSet(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      userId: json['user_id'] as String,
      entryDate: entryDate,
      insight1: json['insight_1'] as String,
      insight2: json['insight_2'] as String,
      insight3: json['insight_3'] as String,
      insight4: json['insight_4'] as String,
      insight5: json['insight_5'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      status: json['status'] as String? ?? 'success',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_id': entryId,
      'user_id': userId,
      'entry_date': entryDate.toIso8601String().split('T')[0],
      'insight_1': insight1,
      'insight_2': insight2,
      'insight_3': insight3,
      'insight_4': insight4,
      'insight_5': insight5,
      'generated_at': generatedAt.toIso8601String(),
      'status': status,
    };
  }

  /// Get all insights as a list
  List<String> get allInsights => [insight1, insight2, insight3, insight4, insight5];

  /// Get insight by index (1-5)
  String getInsight(int index) {
    switch (index) {
      case 1:
        return insight1;
      case 2:
        return insight2;
      case 3:
        return insight3;
      case 4:
        return insight4;
      case 5:
        return insight5;
      default:
        return '';
    }
  }

  /// Get insight category label
  String getCategoryLabel(int index) {
    switch (index) {
      case 1:
        return 'Improvement';
      case 2:
        return 'Areas to Focus';
      case 3:
        return 'Best Thing';
      case 4:
        return 'Achievement';
      case 5:
        return 'Progress';
      default:
        return '';
    }
  }
}

/// Insight status for daily insights display
enum InsightDisplayStatus {
  available,
  pending,
  incomplete,
  none;

  String get message {
    switch (this) {
      case InsightDisplayStatus.available:
        return 'Analysis available';
      case InsightDisplayStatus.pending:
        return 'Analysis in progress...';
      case InsightDisplayStatus.incomplete:
        return 'Complete all 4 sections to get insight';
      case InsightDisplayStatus.none:
        return 'No entry for this day';
    }
  }
}

/// Daily insight status with message
class DailyInsightStatus {
  final InsightDisplayStatus status;
  final HomescreenInsightSet? insightSet;
  final DateTime? entryDate;
  final String message;

  DailyInsightStatus({
    required this.status,
    this.insightSet,
    this.entryDate,
    required this.message,
  });

  factory DailyInsightStatus.available(HomescreenInsightSet insightSet, DateTime entryDate) {
    return DailyInsightStatus(
      status: InsightDisplayStatus.available,
      insightSet: insightSet,
      entryDate: entryDate,
      message: 'Analysis available',
    );
  }

  factory DailyInsightStatus.pending(DateTime? entryDate) {
    return DailyInsightStatus(
      status: InsightDisplayStatus.pending,
      entryDate: entryDate,
      message: "Today's insight will be generated at midnight",
    );
  }

  factory DailyInsightStatus.incomplete(DateTime? entryDate) {
    return DailyInsightStatus(
      status: InsightDisplayStatus.incomplete,
      entryDate: entryDate,
      message: 'Complete all 4 sections to get today\'s insight',
    );
  }

  factory DailyInsightStatus.none(DateTime? entryDate) {
    return DailyInsightStatus(
      status: InsightDisplayStatus.none,
      entryDate: entryDate,
      message: 'No entry for this day',
    );
  }
}