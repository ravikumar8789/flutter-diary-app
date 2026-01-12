# Monthly Analysis Screen Enhancement - Implementation Plan

## Executive Summary

**Goal:** Implement professional monthly analysis screen with month navigation chips, default to last month, and display all monthly insight fields using centralized data fetching system.

**Key Requirements:**
- Month chips navigation (like weekly screen)
- Last month shown by default (not current month)
- Professional UI matching weekly screen
- Display all monthly_insights table fields
- Use centralized DataFetchService for caching/deduplication
- Comprehensive error logging at every step
- No impact on existing functionality

**Expected Impact:**
- 70-80% reduction in DB calls for monthly operations
- Improved app performance
- Better user experience

---

## Phase 1: Data Models & Services (Foundation)

### 1.1 Create MonthMetadata Model

**File:** `lib/models/analytics_models.dart`

**Add after WeekMetadata class:**
```dart
/// Month metadata for navigation chips
class MonthMetadata {
  final DateTime monthStart;
  final DateTime monthEnd;
  final String status; // 'success', 'pending', 'error', 'none'
  final int entriesCount;
  final double? moodAvg;
  final bool hasAnalysis;

  MonthMetadata({
    required this.monthStart,
    required this.monthEnd,
    required this.status,
    this.entriesCount = 0,
    this.moodAvg,
    this.hasAnalysis = false,
  });

  factory MonthMetadata.fromJson(Map<String, dynamic> json) {
    final monthStart = DateTime.parse(json['month_start'] as String);
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    
    return MonthMetadata(
      monthStart: monthStart,
      monthEnd: monthEnd,
      status: json['status'] as String? ?? 'none',
      entriesCount: json['entries_count'] as int? ?? 0,
      moodAvg: (json['mood_avg'] as num?)?.toDouble(),
      hasAnalysis: (json['status'] as String?) == 'success',
    );
  }
}
```

**Error Logging:** Add try-catch in `fromJson` with error code `ERRMODEL001`

---

### 1.2 Add getMonthlyInsightsList() to AnalyticsService

**File:** `lib/services/analytics_service.dart`

**Add method after getWeeklyInsightsList():**
```dart
/// Get list of months with insights (for navigation chips)
Future<List<MonthMetadata>> getMonthlyInsightsList(String userId) async {
  try {
    // Fetch months with insights
    final insightsResponse = await _supabase
        .from('monthly_insights')
        .select('month_start, status, entries_count, mood_avg')
        .eq('user_id', userId)
        .order('month_start', ascending: false)
        .limit(12); // Last 12 months

    final monthsList = <MonthMetadata>[];

    // Process months with insights
    for (final insight in insightsResponse as List) {
      monthsList.add(MonthMetadata.fromJson(insight));
    }

    // Get all month starts we already have
    final existingMonthStarts = monthsList
        .map((m) => '${m.monthStart.year}-${m.monthStart.month}')
        .toSet();

    // Also check for months with entries but no insights (last 3 months)
    final now = DateTime.now();
    final monthsToCheck = <String>[];
    final monthStartDates = <String, DateTime>{};

    for (int i = 1; i <= 3; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthKey = '${monthStart.year}-${monthStart.month}';

      if (!existingMonthStarts.contains(monthKey)) {
        final monthStartStr =
            '${monthStart.year.toString().padLeft(4, '0')}-'
            '${monthStart.month.toString().padLeft(2, '0')}-01';
        monthsToCheck.add(monthStartStr);
        monthStartDates[monthStartStr] = monthStart;
      }
    }

    // Batch query for entries in all months at once
    if (monthsToCheck.isNotEmpty) {
      final earliestMonth = monthsToCheck.last;
      final latestMonthEnd = DateTime(
        monthStartDates[monthsToCheck.first]!.year,
        monthStartDates[monthsToCheck.first]!.month + 1,
        0,
      );
      final latestMonthEndStr =
          '${latestMonthEnd.year.toString().padLeft(4, '0')}-'
          '${latestMonthEnd.month.toString().padLeft(2, '0')}-'
          '${latestMonthEnd.day.toString().padLeft(2, '0')}';

      final entriesResponse = await _supabase
          .from('entries')
          .select('entry_date')
          .eq('user_id', userId)
          .gte('entry_date', earliestMonth)
          .lte('entry_date', latestMonthEndStr);

      // Group entries by month
      final entriesByMonth = <String, int>{};
      for (final entry in entriesResponse) {
        final entryDate = DateTime.parse(entry['entry_date'] as String);
        final monthKey = '${entryDate.year}-${entryDate.month}';
        entriesByMonth[monthKey] = (entriesByMonth[monthKey] ?? 0) + 1;
      }

      // Add months with entries
      for (final monthStartStr in monthsToCheck) {
        final monthStart = monthStartDates[monthStartStr]!;
        final monthKey = '${monthStart.year}-${monthStart.month}';
        final entriesCount = entriesByMonth[monthKey] ?? 0;

        if (entriesCount > 0) {
          monthsList.add(
            MonthMetadata(
              monthStart: monthStart,
              monthEnd: DateTime(monthStart.year, monthStart.month + 1, 0),
              status: 'none',
              entriesCount: entriesCount,
              hasAnalysis: false,
            ),
          );
        }
      }
    }

    // Sort by month_start descending
    monthsList.sort((a, b) => b.monthStart.compareTo(a.monthStart));

    return monthsList;
  } catch (e) {
    await ErrorLoggingService.logError(
      errorCode: 'ERRANA004',
      errorMessage: 'Failed to get monthly insights list: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      severity: 'MEDIUM',
      errorContext: {
        'user_id': userId,
        'operation': 'get_monthly_insights_list',
      },
    );
    rethrow;
  }
}
```

**Error Logging:** Error code `ERRANA004` with full context

---

### 1.3 Integrate with DataFetchService (Centralized System)

**File:** `lib/services/data_fetch_service.dart` (if exists, else create)

**Add methods:**
```dart
/// Fetch monthly insights list with caching
Future<List<MonthMetadata>> fetchMonthlyInsightsList({
  required String userId,
}) async {
  final key = 'monthly_insights_list_$userId';
  
  return await _repository.fetch(
    key: key,
    fetcher: () async {
      final service = AnalyticsService();
      return await service.getMonthlyInsightsList(userId);
    },
    ttl: const Duration(minutes: 5),
  );
}

/// Fetch monthly analytics with caching
Future<MonthlyAnalyticsData> fetchMonthlyAnalytics({
  required String userId,
  required DateTime monthStart,
}) async {
  final monthKey = '${monthStart.year}-${monthStart.month}';
  final key = 'monthly_analytics_${userId}_$monthKey';
  
  return await _repository.fetch(
    key: key,
    fetcher: () async {
      final service = AnalyticsService();
      return await service.getMonthlyAnalytics(monthStart);
    },
    ttl: const Duration(minutes: 5),
  );
}
```

**Error Logging:** Error codes `ERRDATA205` (list fetch), `ERRDATA206` (analytics fetch)

---

## Phase 2: Providers (State Management)

### 2.1 Create Selected Month Provider

**File:** `lib/providers/analytics_provider.dart`

**Add after selectedWeekProvider:**
```dart
/// Selected month notifier (defaults to last month)
class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    // Default to last month (not current month)
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return lastMonth;
  }

  void setMonth(DateTime monthStart) {
    state = monthStart;
  }
}

/// Selected month provider
final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  () => SelectedMonthNotifier(),
);
```

**Error Logging:** Add error handling in `setMonth` with error code `ERRPROV001`

---

### 2.2 Create Monthly Insights List Provider

**File:** `lib/providers/analytics_provider.dart`

**Add after weeklyInsightsListProvider:**
```dart
/// Monthly insights list provider (uses centralized fetching)
final monthlyInsightsListProvider =
    FutureProvider.autoDispose<List<MonthMetadata>>((ref) async {
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          await ErrorLoggingService.logError(
            errorCode: 'ERRPROV002',
            errorMessage: 'User not authenticated for monthly insights list',
            stackTrace: StackTrace.current.toString(),
            severity: 'MEDIUM',
            errorContext: {'operation': 'monthly_insights_list_provider'},
          );
          return [];
        }

        // Use centralized DataFetchService if available, else direct service
        final dataFetchService = ref.watch(dataFetchServiceProvider);
        return await dataFetchService.fetchMonthlyInsightsList(userId: userId);
      } catch (e) {
        await ErrorLoggingService.logError(
          errorCode: 'ERRPROV003',
          errorMessage: 'Monthly insights list provider failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          severity: 'HIGH',
          errorContext: {'operation': 'monthly_insights_list_provider'},
        );
        rethrow;
      }
    });
```

**Error Logging:** Error codes `ERRPROV002` (auth), `ERRPROV003` (fetch)

---

### 2.3 Update Monthly Analytics Provider

**File:** `lib/providers/analytics_provider.dart`

**Replace existing monthlyAnalyticsProvider:**
```dart
/// Monthly analytics provider (uses selected month, centralized fetching)
final monthlyAnalyticsProvider =
    FutureProvider.autoDispose<MonthlyAnalyticsData>((ref) async {
      try {
        final selectedMonth = ref.watch(selectedMonthProvider);
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        
        if (userId == null) {
          await ErrorLoggingService.logError(
            errorCode: 'ERRPROV004',
            errorMessage: 'User not authenticated for monthly analytics',
            stackTrace: StackTrace.current.toString(),
            severity: 'MEDIUM',
            errorContext: {
              'operation': 'monthly_analytics_provider',
              'month_start': selectedMonth.toIso8601String(),
            },
          );
          throw Exception('User not authenticated');
        }

        // Use centralized DataFetchService if available, else direct service
        final dataFetchService = ref.watch(dataFetchServiceProvider);
        return await dataFetchService.fetchMonthlyAnalytics(
          userId: userId,
          monthStart: selectedMonth,
        );
      } catch (e) {
        await ErrorLoggingService.logError(
          errorCode: 'ERRPROV005',
          errorMessage: 'Monthly analytics provider failed: ${e.toString()}',
          stackTrace: StackTrace.current.toString(),
          severity: 'HIGH',
          errorContext: {
            'operation': 'monthly_analytics_provider',
            'month_start': ref.read(selectedMonthProvider).toIso8601String(),
          },
        );
        rethrow;
      }
    });
```

**Error Logging:** Error codes `ERRPROV004` (auth), `ERRPROV005` (fetch)

---

## Phase 3: UI Components

### 3.1 Create MonthChipsCarousel Widget

**File:** `lib/widgets/month_chips_carousel.dart`

**Create new file (similar to WeekChipsCarousel):**
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';

/// Month chips carousel for month navigation
/// Displays months in chronological order (oldest to newest, left to right)
/// Auto-scrolls to newest month (rightmost) on initial load
class MonthChipsCarousel extends StatefulWidget {
  final List<MonthMetadata> months;
  final DateTime selectedMonth;
  final Function(DateTime) onMonthSelected;

  const MonthChipsCarousel({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  @override
  State<MonthChipsCarousel> createState() => _MonthChipsCarouselState();
}

class _MonthChipsCarouselState extends State<MonthChipsCarousel> {
  late ScrollController _scrollController;
  DateTime? _previousSelectedMonth;
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _previousSelectedMonth = widget.selectedMonth;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MonthChipsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.selectedMonth != _previousSelectedMonth) {
      _previousSelectedMonth = widget.selectedMonth;
      _scrollToSelectedMonth();
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToSelectedMonth() {
    if (!_scrollController.hasClients || widget.months.isEmpty) return;

    final reversedMonths = widget.months.reversed.toList();
    final index = reversedMonths.indexWhere((m) =>
        m.monthStart.year == widget.selectedMonth.year &&
        m.monthStart.month == widget.selectedMonth.month);

    if (index != -1 && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final itemWidth = 120.0;
          final targetOffset = index * (itemWidth + 8);
          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.months.isEmpty) {
      return const SizedBox.shrink();
    }

    final reversedMonths = widget.months.reversed.toList();
    
    if (!_hasScrolledToEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasScrolledToEnd) {
          _hasScrolledToEnd = true;
          _scrollToEnd();
        }
      });
    }
    
    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reversedMonths.length,
        itemBuilder: (context, index) {
          final month = reversedMonths[index];
          final isSelected = month.monthStart.year == widget.selectedMonth.year &&
              month.monthStart.month == widget.selectedMonth.month;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MonthChip(
              month: month,
              isSelected: isSelected,
              onTap: () => widget.onMonthSelected(month.monthStart),
            ),
          );
        },
      ),
    );
  }
}

class _MonthChip extends StatefulWidget {
  final MonthMetadata month;
  final bool isSelected;
  final VoidCallback onTap;

  const _MonthChip({
    required this.month,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MonthChip> createState() => _MonthChipState();
}

class _MonthChipState extends State<_MonthChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_MonthChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatMonth(DateTime monthStart) {
    return DateFormat('MMM yyyy').format(monthStart);
  }

  Color _getStatusColor() {
    if (!widget.month.hasAnalysis) {
      return Colors.grey;
    }
    switch (widget.month.status) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: widget.isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatMonth(widget.month.monthStart),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (widget.month.entriesCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        '${widget.month.entriesCount} entries',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

**Error Logging:** Add try-catch in build methods with error code `ERRUI001`

---

### 3.2 Update Analytics Screen - Add Month Navigation

**File:** `lib/screens/analytics_screen.dart`

**Add method after _buildWeekNavigation():**
```dart
Widget _buildMonthNavigation(BuildContext context) {
  final monthsListAsync = ref.watch(monthlyInsightsListProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  return monthsListAsync.when(
    loading: () => const SizedBox.shrink(),
    error: (error, stack) {
      // Log error
      ErrorLoggingService.logError(
        errorCode: 'ERRUI002',
        errorMessage: 'Failed to load month navigation: ${error.toString()}',
        stackTrace: stack.toString(),
        severity: 'MEDIUM',
        errorContext: {'operation': 'month_navigation'},
      );
      return const SizedBox.shrink();
    },
    data: (months) {
      if (months.isEmpty) return const SizedBox.shrink();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month chips carousel
          MonthChipsCarousel(
            months: months,
            selectedMonth: selectedMonth,
            onMonthSelected: (monthStart) {
              ref.read(selectedMonthProvider.notifier).setMonth(monthStart);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(height: 8),
          // Calendar toggle button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  // TODO: Implement month calendar picker
                  // Similar to weekly calendar picker
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: const Text('Select Month'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
```

**Error Logging:** Error code `ERRUI002` for navigation errors

---

### 3.3 Update Analytics Screen - Add Month Navigation to UI

**File:** `lib/screens/analytics_screen.dart`

**In build method, update the body section:**
```dart
// Around line 98-109, add month navigation
if (period == AnalyticsPeriod.weekly)
  _buildWeekNavigation(context),
if (period == AnalyticsPeriod.monthly)
  _buildMonthNavigation(context),
```

**Error Logging:** Already handled in navigation methods

---

### 3.4 Enhance Monthly Content UI

**File:** `lib/screens/analytics_screen.dart`

**Update _buildMonthlyContent() to match weekly screen structure:**
```dart
Widget _buildMonthlyContent(BuildContext context, bool isTablet) {
  final monthlyAsync = ref.watch(monthlyAnalyticsProvider);

  return monthlyAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, stack) {
      // Log error
      ErrorLoggingService.logError(
        errorCode: 'ERRUI003',
        errorMessage: 'Failed to load monthly content: ${error.toString()}',
        stackTrace: stack.toString(),
        severity: 'HIGH',
        errorContext: {'operation': 'monthly_content'},
      );
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading analytics: $error'),
          ],
        ),
      );
    },
    data: (data) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCardsMonthly(context, isTablet, data),
          const SizedBox(height: 32),

          // Mood Trend Chart
          _buildSectionHeader(context, 'Mood Trends'),
          const SizedBox(height: 16),
          _buildMoodChart(context, data.moodTrendData, isWeekly: false),
          const SizedBox(height: 32),

          // AI Insights (Enhanced with all fields)
          _buildSectionHeader(context, 'AI Insights'),
          const SizedBox(height: 16),
          _buildAiInsightsCardMonthly(context, data),
          const SizedBox(height: 32),

          // Habit Analysis (if available)
          if (data.monthlyInsight != null &&
              (data.monthlyInsight as MonthlyInsight).habitAnalysis != null) ...[
            _buildSectionHeader(context, 'Habit Analysis'),
            const SizedBox(height: 16),
            _buildHabitAnalysisCard(context, data.monthlyInsight as MonthlyInsight),
            const SizedBox(height: 32),
          ],

          // Period Comparison
          PeriodComparisonCard(period: AnalyticsPeriod.monthly),
          const SizedBox(height: 32),
        ],
      );
    },
  );
}
```

**Error Logging:** Error code `ERRUI003` for content loading errors

---

### 3.5 Enhance Monthly AI Insights Card

**File:** `lib/screens/analytics_screen.dart`

**Update _buildAiInsightsCardMonthly() to display all fields:**
```dart
Widget _buildAiInsightsCardMonthly(
  BuildContext context,
  MonthlyAnalyticsData data,
) {
  try {
    final monthlyInsight = data.monthlyInsight as MonthlyInsight?;
    
    if (monthlyInsight == null || data.combinedHighlights.isEmpty) {
      // Show empty state
      return _buildEmptyMonthlyInsightsCard(context);
    }

    // Extract all fields
    final growthAreas = monthlyInsight.growthAreas;
    final achievements = monthlyInsight.achievements;
    final nextMonthGoals = monthlyInsight.nextMonthGoals;
    final strengths = monthlyInsight.strengths;
    final keyMoments = monthlyInsight.keyMoments;
    final reflectionQuestions = monthlyInsight.reflectionQuestions;
    final habitAnalysis = monthlyInsight.habitAnalysis;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with trend badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI Monthly Insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (data.overallMoodTrend != null)
                  _buildTrendBadge(context, data.overallMoodTrend!),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Row
            _buildMonthlyStatsRow(
              context,
              moodAvg: data.avgMood,
              entriesCount: data.totalEntries,
              wordCount: monthlyInsight.wordCountTotal,
              consistencyScore: monthlyInsight.consistencyScore ?? data.overallConsistency ?? 0,
            ),
            const SizedBox(height: 24),

            // Monthly Highlights (10-12 lines)
            if (data.combinedHighlights.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Monthly Highlights'),
              const SizedBox(height: 12),
              Text(
                data.combinedHighlights,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
            ],

            // Achievements
            if (achievements.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Achievements'),
              const SizedBox(height: 12),
              ...achievements.map((achievement) => _buildBulletPoint(context, achievement)),
              const SizedBox(height: 24),
            ],

            // Strengths
            if (strengths.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Strengths'),
              const SizedBox(height: 12),
              ...strengths.map((strength) => _buildBulletPoint(context, strength)),
              const SizedBox(height: 24),
            ],

            // Key Moments
            if (keyMoments.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Key Moments'),
              const SizedBox(height: 12),
              ...keyMoments.map((moment) => _buildBulletPoint(context, moment)),
              const SizedBox(height: 24),
            ],

            // Growth Areas
            if (growthAreas.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Growth Areas'),
              const SizedBox(height: 12),
              ...growthAreas.map((area) => _buildBulletPoint(context, area)),
              const SizedBox(height: 24),
            ],

            // Next Month Goals
            if (nextMonthGoals.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Next Month Goals'),
              const SizedBox(height: 12),
              ...nextMonthGoals.map((goal) => _buildBulletPoint(context, goal)),
              const SizedBox(height: 24),
            ],

            // Reflection Questions
            if (reflectionQuestions.isNotEmpty) ...[
              _buildSectionSubHeader(context, 'Reflection Questions'),
              const SizedBox(height: 12),
              ...reflectionQuestions.map((question) => _buildBulletPoint(context, question, icon: Icons.help_outline)),
            ],
          ],
        ),
      ),
    );
  } catch (e) {
    ErrorLoggingService.logError(
      errorCode: 'ERRUI004',
      errorMessage: 'Failed to build monthly insights card: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      severity: 'MEDIUM',
      errorContext: {'operation': 'build_monthly_insights_card'},
    );
    return _buildErrorCard(context, 'Failed to load insights');
  }
}
```

**Add helper methods:**
```dart
Widget _buildSectionSubHeader(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
}

Widget _buildBulletPoint(BuildContext context, String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon ?? Icons.circle,
          size: 8,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyMonthlyInsightsCard(BuildContext context) {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.insights, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Monthly Insights Coming Soon',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your monthly analysis will appear here once you\'ve completed more entries this month.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

Widget _buildErrorCard(BuildContext context, String message) {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
```

**Error Logging:** Error code `ERRUI004` for card building errors

---

### 3.6 Add Habit Analysis Card

**File:** `lib/screens/analytics_screen.dart`

**Add new method:**
```dart
Widget _buildHabitAnalysisCard(BuildContext context, MonthlyInsight insight) {
  try {
    final habitAnalysis = insight.habitAnalysis;
    if (habitAnalysis == null || habitAnalysis.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'Habit Analysis'),
            const SizedBox(height: 16),
            // Display habit analysis data
            // Format based on habitAnalysis structure
            Text(
              'Habit analysis data will be displayed here',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  } catch (e) {
    ErrorLoggingService.logError(
      errorCode: 'ERRUI005',
      errorMessage: 'Failed to build habit analysis card: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      severity: 'MEDIUM',
      errorContext: {'operation': 'build_habit_analysis_card'},
    );
    return const SizedBox.shrink();
  }
}
```

**Error Logging:** Error code `ERRUI005` for habit analysis errors

---

## Phase 4: Cache Invalidation

### 4.1 Invalidate Monthly Cache on Data Updates

**File:** `lib/services/entry_service.dart` (or wherever entries are saved)

**Add cache invalidation:**
```dart
// After saving entry
void _invalidateMonthlyCache(String userId, DateTime entryDate) {
  try {
    final monthStart = DateTime(entryDate.year, entryDate.month, 1);
    final monthKey = '${monthStart.year}-${monthStart.month}';
    
    // Invalidate monthly analytics cache
    final dataRepository = ref.read(dataRepositoryProvider);
    dataRepository.invalidate('monthly_analytics_${userId}_$monthKey');
    
    // Invalidate monthly insights list
    dataRepository.invalidate('monthly_insights_list_$userId');
  } catch (e) {
    ErrorLoggingService.logError(
      errorCode: 'ERRCACHE001',
      errorMessage: 'Failed to invalidate monthly cache: ${e.toString()}',
      stackTrace: StackTrace.current.toString(),
      severity: 'LOW',
      errorContext: {
        'user_id': userId,
        'entry_date': entryDate.toIso8601String(),
      },
    );
  }
}
```

**Error Logging:** Error code `ERRCACHE001` for cache invalidation errors

---

## Phase 5: Testing & Validation

### 5.1 Test Scenarios

1. **Month Navigation:**
   - [ ] Default shows last month (not current)
   - [ ] Month chips display correctly
   - [ ] Last month chip on right, older months to left
   - [ ] Month selection updates analytics
   - [ ] Calendar picker works (if implemented)

2. **Data Loading:**
   - [ ] Monthly insights list loads
   - [ ] Monthly analytics loads for selected month
   - [ ] Caching works (no duplicate queries)
   - [ ] Error states display correctly

3. **UI Display:**
   - [ ] All monthly insight fields displayed
   - [ ] Professional UI matching weekly screen
   - [ ] Empty states handled
   - [ ] Loading states shown

4. **Error Handling:**
   - [ ] All errors logged with proper codes
   - [ ] User-friendly error messages
   - [ ] No crashes on errors

5. **Performance:**
   - [ ] No duplicate DB calls
   - [ ] Cache hit rate >70%
   - [ ] Smooth scrolling/navigation

### 5.2 Error Code Reference

| Code | Description | Severity |
|------|-------------|----------|
| ERRMODEL001 | MonthMetadata fromJson error | MEDIUM |
| ERRANA004 | getMonthlyInsightsList failed | MEDIUM |
| ERRDATA205 | fetchMonthlyInsightsList failed | MEDIUM |
| ERRDATA206 | fetchMonthlyAnalytics failed | MEDIUM |
| ERRPROV001 | SelectedMonthNotifier error | MEDIUM |
| ERRPROV002 | Monthly insights list auth error | MEDIUM |
| ERRPROV003 | Monthly insights list fetch error | HIGH |
| ERRPROV004 | Monthly analytics auth error | MEDIUM |
| ERRPROV005 | Monthly analytics fetch error | HIGH |
| ERRUI001 | MonthChipsCarousel build error | MEDIUM |
| ERRUI002 | Month navigation error | MEDIUM |
| ERRUI003 | Monthly content loading error | HIGH |
| ERRUI004 | Monthly insights card build error | MEDIUM |
| ERRUI005 | Habit analysis card error | MEDIUM |
| ERRCACHE001 | Monthly cache invalidation error | LOW |

---

## Phase 6: Risk Mitigation

### 6.1 Potential Risks

1. **Data Fetching Conflicts:**
   - **Risk:** Centralized system not available
   - **Mitigation:** Fallback to direct AnalyticsService calls
   - **Error Code:** ERRDATA207

2. **UI Performance:**
   - **Risk:** Too many months causing lag
   - **Mitigation:** Limit to 12 months, lazy loading
   - **Error Code:** ERRUI006

3. **Cache Staleness:**
   - **Risk:** Showing old data
   - **Mitigation:** 5-minute TTL, smart invalidation
   - **Error Code:** ERRCACHE002

4. **Missing Data:**
   - **Risk:** No insights for selected month
   - **Mitigation:** Show empty state, allow month selection
   - **Error Code:** ERRUI007

### 6.2 Backward Compatibility

- All existing weekly functionality remains unchanged
- Monthly provider uses same pattern as weekly
- No breaking changes to existing APIs
- Graceful degradation if centralized system unavailable

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create MonthMetadata model
- [ ] Add getMonthlyInsightsList() to AnalyticsService
- [ ] Add methods to DataFetchService
- [ ] Error logging in all methods

### Phase 2: Providers
- [ ] Create selectedMonthProvider
- [ ] Create monthlyInsightsListProvider
- [ ] Update monthlyAnalyticsProvider
- [ ] Error logging in all providers

### Phase 3: UI Components
- [ ] Create MonthChipsCarousel widget
- [ ] Add month navigation to analytics screen
- [ ] Enhance monthly content UI
- [ ] Enhance monthly AI insights card
- [ ] Add habit analysis card
- [ ] Error logging in all UI methods

### Phase 4: Cache
- [ ] Add cache invalidation on entry save
- [ ] Test cache behavior

### Phase 5: Testing
- [ ] Test all scenarios
- [ ] Verify error logging
- [ ] Performance testing
- [ ] UI/UX validation

---

## Success Metrics

1. **DB Call Reduction:** 70-80% fewer calls for monthly operations
2. **Cache Hit Rate:** >70% for repeated month selections
3. **Error Rate:** <1% with proper error handling
4. **User Experience:** Smooth navigation, professional UI
5. **Code Quality:** All errors logged, no crashes

---

## Timeline Estimate

- **Phase 1:** 2-3 hours
- **Phase 2:** 1-2 hours
- **Phase 3:** 4-5 hours
- **Phase 4:** 1 hour
- **Phase 5:** 2-3 hours

**Total:** 10-14 hours

---

## Notes

- All error logging uses ErrorLoggingService
- All providers follow same pattern as weekly providers
- UI components match weekly screen styling
- Cache TTL: 5 minutes (configurable)
- Month limit: 12 months (configurable)
- Default month: Last month (not current)

