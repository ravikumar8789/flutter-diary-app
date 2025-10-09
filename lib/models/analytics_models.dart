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
