class StreakSummary {
  final int current;
  final int longest;
  final int freezeCredits;
  final double gracePiecesTotal;
  const StreakSummary({
    required this.current,
    required this.longest,
    required this.freezeCredits,
    required this.gracePiecesTotal,
  });
}

class TodayProgressSummary {
  final bool wroteEntry;
  final bool filledAffirmations;
  final bool filledGratitude;
  final int selfCareCompletedCount;
  final double gracePiecesEarned;
  final int waterCups;
  const TodayProgressSummary({
    required this.wroteEntry,
    required this.filledAffirmations,
    required this.filledGratitude,
    required this.selfCareCompletedCount,
    required this.gracePiecesEarned,
    required this.waterCups,
  });

  int get tasksCompletedCount {
    int count = 0;
    if (wroteEntry) count++;
    if (filledAffirmations) count++;
    if (filledGratitude) count++;
    if (selfCareCompletedCount > 0) count++;
    return count;
  }
}

class WeeklySnapshotSummary {
  final num? moodAvg;
  final num? cupsAvg;
  final num? selfCareRate;
  final List<dynamic>? topTopics;
  final String? highlights;
  final num? moodDelta; // vs previous week if available
  const WeeklySnapshotSummary({
    this.moodAvg,
    this.cupsAvg,
    this.selfCareRate,
    this.topTopics,
    this.highlights,
    this.moodDelta,
  });
}

class PromptMotivationSummary {
  final String promptText;
  final int freezeCredits;
  final String? nextReminderTime;
  const PromptMotivationSummary({
    required this.promptText,
    required this.freezeCredits,
    this.nextReminderTime,
  });
}

class HomeSummary {
  final StreakSummary? streak;
  final TodayProgressSummary? today;
  final WeeklySnapshotSummary? weekly;
  final PromptMotivationSummary? prompt;
  const HomeSummary({
    this.streak,
    this.today,
    this.weekly,
    this.prompt,
  });
}
