import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/daily_insights_timeline.dart';
import '../widgets/week_chips_carousel.dart';
import '../widgets/month_chips_carousel.dart';
import '../widgets/mini_calendar_widget.dart';
import '../services/error_logging_service.dart';
import '../widgets/habit_correlations_card.dart';
import '../widgets/interactive_bar_chart.dart';
import '../widgets/day_details_bottom_sheet.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_provider.dart';
import '../providers/home_summary_provider.dart';
import '../services/analytics_service.dart';
import '../services/ai_service.dart';
import 'yesterday_insight_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final period = ref.watch(analyticsPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.analytics,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'Analytics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SegmentedButton<AnalyticsPeriod>(
              segments: [
                ButtonSegment<AnalyticsPeriod>(
                  value: AnalyticsPeriod.weekly,
                  label: const Text('Weekly'),
                  icon: const Icon(Icons.calendar_view_week, size: 18),
                ),
                ButtonSegment<AnalyticsPeriod>(
                  value: AnalyticsPeriod.monthly,
                  label: const Text('Monthly'),
                  icon: const Icon(Icons.calendar_month, size: 18),
                ),
              ],
              selected: {period},
              onSelectionChanged: (Set<AnalyticsPeriod> newSelection) {
                ref
                    .read(analyticsPeriodProvider.notifier)
                    .setPeriod(newSelection.first);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period header with date range (InnerGlow Style)
                    _buildPeriodHeader(context, period),
                    const SizedBox(height: 24),

                    // Week Navigation (only for weekly)
                    if (period == AnalyticsPeriod.weekly)
                      _buildWeekNavigation(context),

                    // Month Navigation (only for monthly)
                    if (period == AnalyticsPeriod.monthly)
                      _buildMonthNavigation(context),

                    // Summary Cards
                    period == AnalyticsPeriod.weekly
                        ? _buildWeeklyContentWithSwipe(context, isTablet)
                        : _buildMonthlyContent(context, isTablet),
                  ],
                ),
              ),
            ),
            // Bottom Navigation Bar
            AppBottomNavigationBar(
              currentIndex: 2,
              onTap: (index) {
                AppBottomNavigationBar.navigateToScreen(context, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekNavigation(BuildContext context) {
    final weeksListAsync = ref.watch(weeklyInsightsListProvider);
    final selectedWeek = ref.watch(selectedWeekProvider);

    return weeksListAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (weeks) {
        if (weeks.isEmpty) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Week chips carousel
            WeekChipsCarousel(
              weeks: weeks,
              selectedWeek: selectedWeek,
              onWeekSelected: (weekStart) {
                ref.read(selectedWeekProvider.notifier).setWeek(weekStart);
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
                    showDialog(
                      context: context,
                      builder: (context) => MiniCalendarWidget(
                        selectedWeek: selectedWeek,
                        onWeekSelected: (weekStart) {
                          ref
                              .read(selectedWeekProvider.notifier)
                              .setWeek(weekStart);
                          HapticFeedback.selectionClick();
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Select Week'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Month picker coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
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

  Widget _buildPeriodHeader(BuildContext context, AnalyticsPeriod period) {
    if (period == AnalyticsPeriod.weekly) {
      return Consumer(
        builder: (context, ref, _) {
          final weeklyAsync = ref.watch(weeklyAnalyticsProvider);
          return weeklyAsync.when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your wellness journey',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This Week',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            error: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your wellness journey',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This Week',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            data: (data) {
              final dateRange = AnalyticsService.formatDateRange(
                data.weekStart,
                data.weekEnd,
              );
              final isCurrentWeek = data.isCurrentWeek;
              final weekLabel = isCurrentWeek ? 'This Week' : 'Week of';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track your wellness journey',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weekLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateRange,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      return Consumer(
        builder: (context, ref, _) {
          final monthlyAsync = ref.watch(monthlyAnalyticsProvider);
          return monthlyAsync.when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your wellness journey',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This Month',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            error: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your wellness journey',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This Month',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            data: (data) {
              final monthStr = AnalyticsService.formatMonth(data.monthStart);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track your wellness journey',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This Month',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monthStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  Widget _buildWeeklyContentWithSwipe(BuildContext context, bool isTablet) {
    final weeklyAsync = ref.watch(weeklyAnalyticsProvider);
    final weeksListAsync = ref.watch(weeklyInsightsListProvider);

    return weeklyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading analytics: $e')),
      data: (data) {
        return weeksListAsync.when(
          loading: () => _buildWeeklyContent(context, isTablet, data),
          error: (_, __) => _buildWeeklyContent(context, isTablet, data),
          data: (weeks) {
            final selectedWeek = ref.read(selectedWeekProvider);
            // Note: weeks list is sorted descending (newest first) from service
            // WeekChipsCarousel reverses it for display (oldest to newest)
            // This index calculation uses original order, so it's correct
            final currentIndex = weeks.indexWhere(
              (w) =>
                  w.weekStart.year == selectedWeek.year &&
                  w.weekStart.month == selectedWeek.month &&
                  w.weekStart.day == selectedWeek.day,
            );

            if (currentIndex == -1 || weeks.length <= 1) {
              return _buildWeeklyContent(context, isTablet, data);
            }

            // Reset page controller if needed
            if (_currentPageIndex != currentIndex &&
                _pageController.hasClients) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients &&
                    currentIndex >= 0 &&
                    currentIndex < weeks.length) {
                  _pageController.jumpToPage(currentIndex);
                  _currentPageIndex = currentIndex;
                }
              });
            }

            // Don't use PageView if only one week or current week not found
            if (currentIndex == -1 || weeks.length <= 1) {
              return _buildWeeklyContent(context, isTablet, data);
            }

            // Don't use PageView inside SingleChildScrollView - it causes unbounded height issues
            // Just show current week content instead
            return _buildWeeklyContent(context, isTablet, data);

            // PageView removed - causes unbounded height error in SingleChildScrollView
            // If swipe between weeks is needed, consider using a different approach
            // return SizedBox(
            //   height: MediaQuery.of(context).size.height * 0.7,
            //   child: PageView.builder(
            //     controller: _pageController,
            //     physics: const PageScrollPhysics(),
            //     onPageChanged: (index) {
            //       if (index >= 0 && index < weeks.length && index != _currentPageIndex) {
            //         final weekStart = weeks[index].weekStart;
            //         _currentPageIndex = index;
            //         Future.microtask(() {
            //           ref.read(selectedWeekProvider.notifier).setWeek(weekStart);
            //           HapticFeedback.selectionClick();
            //         });
            //       }
            //     },
            //     itemCount: weeks.length,
            //     itemBuilder: (context, index) {
            //       if (index == currentIndex) {
            //         return _buildWeeklyContent(context, isTablet, data);
            //       } else {
            //         return const Center(child: CircularProgressIndicator());
            //       }
            //     },
            //   ),
            // );
          },
        );
      },
    );
  }

  Widget _buildWeeklyContent(
    BuildContext context,
    bool isTablet,
    WeeklyAnalyticsData data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        _buildSummaryCards(context, isTablet, data),
        const SizedBox(height: 32),

        // Interactive Bar Chart (replaces mood line chart)
        _buildSectionHeader(context, 'Daily Progress'),
        const SizedBox(height: 16),
        InteractiveBarChart(
          dailyData: data.dailyProgress,
          onBarTap: (date) =>
              _showDayDetails(context, date, data.dailyProgress),
        ),
        const SizedBox(height: 32),

        // AI Insights
        _buildSectionHeader(context, 'AI Insights'),
        const SizedBox(height: 16),
        _buildAiInsightsCard(context, data),
        const SizedBox(height: 32),

        // Habit Correlations
        if (data.habitCorrelations != null &&
            data.habitCorrelations!.isNotEmpty) ...[
          _buildSectionHeader(context, 'Habit Correlations'),
          const SizedBox(height: 16),
          HabitCorrelationsCard(correlations: data.habitCorrelations),
          const SizedBox(height: 32),
        ],

        // Yesterday's Insight Status
        _buildSectionHeader(context, "Yesterday's Insight"),
        const SizedBox(height: 16),
        _buildTodayInsightStatusCard(context),
        const SizedBox(height: 32),

        // Daily Insights Timeline
        _buildSectionHeader(context, 'Daily Insights Timeline'),
        const SizedBox(height: 16),
        DailyInsightsTimeline(startDate: data.weekStart, endDate: data.weekEnd),
        const SizedBox(height: 32),
      ],
    );
  }

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
              Text(
                'Error loading analytics: $error',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
      data: (data) {
        try {
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

              // AI Insights
              _buildSectionHeader(context, 'AI Insights'),
              const SizedBox(height: 16),
              _buildAiInsightsCardMonthly(context, data),
              const SizedBox(height: 32),

            ],
          );
        } catch (e) {
          ErrorLoggingService.logError(
            errorCode: 'ERRUI003',
            errorMessage: 'Failed to build monthly content: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            severity: 'HIGH',
            errorContext: {'operation': 'build_monthly_content'},
          );
          return Center(
            child: Text(
              'Error building content: $e',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    bool isTablet,
    WeeklyAnalyticsData data,
  ) {
    final crossAxisCount = isTablet ? 4 : 2;
    final cards = [
      _buildSummaryCard(
        context,
        'Entries',
        '${data.entriesCount}/7',
        '${data.entriesCount} days this week',
        Icons.edit_note,
        Colors.blue,
      ),
      _buildSummaryCard(
        context,
        'Avg Mood',
        data.moodAvg != null ? data.moodAvg!.toStringAsFixed(1) : '—',
        _getMoodTrendText(data.moodTrend),
        Icons.sentiment_satisfied,
        _getMoodColor(data.moodAvg ?? 0),
      ),
      _buildSummaryCard(
        context,
        'Water',
        '${data.cupsAvg.toStringAsFixed(1)} cups',
        'Daily average',
        Icons.water_drop,
        Colors.cyan,
      ),
      _buildSummaryCard(
        context,
        'Self-Care',
        '${data.selfCareRate.toInt()}%',
        'Completion rate',
        Icons.spa,
        Colors.purple,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isTablet ? 1.8 : 1.6,
      children: cards,
    );
  }

  Widget _buildSummaryCardsMonthly(
    BuildContext context,
    bool isTablet,
    MonthlyAnalyticsData data,
  ) {
    final crossAxisCount = isTablet ? 4 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isTablet ? 1.8 : 1.6,
      children: [
        _buildSummaryCard(
          context,
          'Entries',
          '${data.totalEntries}',
          'Across 4 weeks',
          Icons.edit_note,
          Colors.blue,
        ),
        _buildSummaryCard(
          context,
          'Avg Mood',
          data.avgMood.toStringAsFixed(1),
          _getMoodTrendText(data.overallMoodTrend),
          Icons.sentiment_satisfied,
          _getMoodColor(data.avgMood),
        ),
        _buildSummaryCard(
          context,
          'Water',
          '${data.avgCups.toStringAsFixed(1)} cups',
          'Daily average',
          Icons.water_drop,
          Colors.cyan,
        ),
        _buildSummaryCard(
          context,
          'Self-Care',
          '${(data.avgSelfCareRate * 100).toInt()}%',
          'Completion rate',
          Icons.spa,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(double mood) {
    if (mood >= 4) return Colors.green;
    if (mood >= 3) return Colors.orange;
    return Colors.red;
  }

  String _getMoodTrendText(String? trend) {
    switch (trend) {
      case 'improving':
        return '↑ Improving';
      case 'declining':
        return '↓ Declining';
      case 'volatile':
        return '~ Volatile';
      case 'stable':
        return '→ Stable';
      default:
        return '—';
    }
  }

  Widget _buildMoodChart(
    BuildContext context,
    List<MoodDataPoint> data, {
    required bool isWeekly,
  }) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No mood data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.moodScore);
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          value.toInt().toString(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < data.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[value.toInt()].label ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (data.length - 1).toDouble(),
              minY: 1,
              maxY: 5,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsightsCard(BuildContext context, WeeklyAnalyticsData data) {
    // Check if AI insight is available
    final hasAiInsight =
        data.weeklyInsight != null &&
        data.highlights != null &&
        data.highlights!.isNotEmpty;

    // Access WeeklyInsight fields safely
    final weeklyInsight = data.weeklyInsight as WeeklyInsight?;
    final keyInsights = weeklyInsight?.keyInsights ?? data.keyInsights;
    final recommendations =
        weeklyInsight?.recommendations ?? data.recommendations;
    final topTopics = weeklyInsight?.topTopics ?? data.topTopics;

    if (!hasAiInsight) {
      // Enhanced empty state with week-specific message
      final weekRange = AnalyticsService.formatDateRange(
        data.weekStart,
        data.weekEnd,
      );
      final isCurrentWeek = data.isCurrentWeek;

      return Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.primary.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  isCurrentWeek
                      ? 'Weekly Insights Coming Soon'
                      : 'No Insight Available for Last Week',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    weekRange,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isCurrentWeek
                      ? 'Your personalized weekly analysis will appear here once you\'ve completed more entries this week. Keep journaling to unlock insights about your patterns and growth!'
                      : 'Please fill entries for detailed weekly analysis and track your progress. Weekly insights are generated every Sunday at midnight.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data.entriesCount} entries',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // AI insight is available - show beautiful insights
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
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
                    'AI Weekly Insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (data.moodTrend != null)
                  _buildTrendBadge(context, data.moodTrend!),
              ],
            ),
            const SizedBox(height: 20),
            // Weekly Highlights
            if (data.highlights != null && data.highlights!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Week Overview',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.highlights!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Key Insights (standalone section below Week Overview)
            if (keyInsights.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.lightbulb, size: 20, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Key Insights',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...keyInsights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          insight,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Top Topics
            if (topTopics.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.label, size: 20, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Top Topics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topTopics
                    .map(
                      (topic) => Chip(
                        label: Text(
                          topic,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            // Recommendations
            if (recommendations.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, size: 20, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Recommendations',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...recommendations.map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rec,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayInsightStatusCard(BuildContext context) {
    final yesterdayInsightAsync = ref.watch(yesterdayInsightProvider);

    return yesterdayInsightAsync.when(
      data: (insight) {
        final IconData icon;
        final Color color;
        final String title;
        final String message;

        if (insight != null) {
          icon = Icons.check_circle;
          color = Colors.green;
          title = "Yesterday's Insight Available";
          message = 'Your daily insight is ready to view.';
        } else {
          icon = Icons.info_outline;
          color = Colors.grey;
          title = "Yesterday's Insight";
          message =
              'No insight available for yesterday. Insights are generated each morning for the previous day.';
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: insight != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            YesterdayInsightScreen(insight: insight),
                      ),
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                      if (insight != null) ...[
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                  if (insight != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      "Yesterday's Insight:",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_right,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              insight.insightText,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to view full analysis',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Card(
        elevation: 2,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Error loading insight: $error',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsightsCardMonthly(
    BuildContext context,
    MonthlyAnalyticsData data,
  ) {
    // Check if AI insight is available
    final hasAiInsight =
        data.monthlyInsight != null && data.combinedHighlights.isNotEmpty;

    // Access MonthlyInsight fields safely
    final monthlyInsight = data.monthlyInsight as MonthlyInsight?;
    List<String> growthAreas = [];
    List<String> achievements = data.keyInsights;
    List<String> nextMonthGoals = data.recommendations;
    List<String> strengths = [];
    List<String> keyMoments = [];
    List<String> reflectionQuestions = [];
    List<String> habitAnalysisPoints = [];
    List<String> topTopics = [];
    int? wordCountTotal;
    double? consistencyScore;

    if (monthlyInsight != null) {
      growthAreas = monthlyInsight.growthAreas;
      achievements = monthlyInsight.achievements.isNotEmpty
          ? monthlyInsight.achievements
          : data.keyInsights;
      nextMonthGoals = monthlyInsight.nextMonthGoals.isNotEmpty
          ? monthlyInsight.nextMonthGoals
          : data.recommendations;
      strengths = monthlyInsight.strengths;
      keyMoments = monthlyInsight.keyMoments;
      reflectionQuestions = monthlyInsight.reflectionQuestions;
      topTopics = monthlyInsight.topTopics;
      wordCountTotal = monthlyInsight.wordCountTotal;
      consistencyScore = monthlyInsight.consistencyScore;

      // Extract habit analysis points from habit_analysis.analysis_points
      if (monthlyInsight.habitAnalysis != null) {
        final analysisPoints = monthlyInsight.habitAnalysis!['analysis_points'];
        if (analysisPoints is List) {
          habitAnalysisPoints = analysisPoints.cast<String>();
        }
      }
    }

    if (!hasAiInsight) {
      // Beautiful fallback message when AI insight is not available
      return Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.primary.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Monthly Insights Coming Soon',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your personalized monthly analysis will appear here once you\'ve completed more entries this month. Keep journaling to unlock deep insights about your journey!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data.totalEntries} entries this month',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // AI insight is available - show comprehensive insights
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
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
              wordCount: wordCountTotal ?? 0,
              consistencyScore:
                  consistencyScore ?? data.overallConsistency ?? 0,
            ),
            const SizedBox(height: 24),

            // 10-12 Line Monthly Highlights
            if (data.combinedHighlights.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Monthly Overview',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.combinedHighlights,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.7,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Top Topics (5-7)
            if (topTopics.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.label, size: 20, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Top Topics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topTopics.take(7).map((topic) {
                  return Chip(
                    label: Text(topic, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.purple[50],
                    side: BorderSide(color: Colors.purple[200]!),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Strengths (3-4)
            if (strengths.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars, size: 20, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Your Strengths',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...strengths
                        .take(4)
                        .map(
                          (strength) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    strength,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Achievements (4-6)
            if (achievements.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.emoji_events, size: 20, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Achievements',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...achievements
                  .take(6)
                  .map(
                    (achievement) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.amber[700],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              achievement,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
            ],

            // Growth Areas (4-6)
            if (growthAreas.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.trending_up, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Growth Areas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...growthAreas
                  .take(6)
                  .map(
                    (area) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              area,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
            ],

            // Habit Analysis (4-6 points)
            if (habitAnalysisPoints.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 20,
                          color: Colors.teal[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Habit Analysis',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...habitAnalysisPoints
                        .take(6)
                        .map(
                          (point) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.insights,
                                  size: 18,
                                  color: Colors.teal[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Key Moments
            if (keyMoments.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.pink.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.pink.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 20,
                          color: Colors.pink[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Key Moments',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...keyMoments.map(
                      (moment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.pink[700],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                moment,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Next Month Goals (4-6)
            if (nextMonthGoals.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, size: 20, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Next Month Goals',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...nextMonthGoals
                        .take(6)
                        .map(
                          (goal) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    goal,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Reflection Questions (3-4)
            if (reflectionQuestions.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 20,
                          color: Colors.indigo[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reflection Questions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...reflectionQuestions
                        .take(4)
                        .map(
                          (question) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.question_mark,
                                  size: 18,
                                  color: Colors.indigo[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    question,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatsRow(
    BuildContext context, {
    required double moodAvg,
    required int entriesCount,
    required int wordCount,
    required double consistencyScore,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            icon: Icons.sentiment_satisfied,
            label: 'Mood',
            value: moodAvg.toStringAsFixed(1),
            color: _getMoodColor(moodAvg),
          ),
          _buildStatItem(
            context,
            icon: Icons.edit_note,
            label: 'Entries',
            value: entriesCount.toString(),
            color: Colors.blue,
          ),
          _buildStatItem(
            context,
            icon: Icons.text_fields,
            label: 'Words',
            value: _formatWordCount(wordCount),
            color: Colors.purple,
          ),
          _buildStatItem(
            context,
            icon: Icons.trending_up,
            label: 'Consistency',
            value: '${consistencyScore.toStringAsFixed(0)}%',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  String _formatWordCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _buildTrendBadge(BuildContext context, String trend) {
    Color color;
    String label;
    IconData icon;

    switch (trend) {
      case 'improving':
        color = Colors.green;
        label = 'Improving';
        icon = Icons.trending_up;
        break;
      case 'declining':
        color = Colors.red;
        label = 'Declining';
        icon = Icons.trending_down;
        break;
      case 'volatile':
        color = Colors.orange;
        label = 'Volatile';
        icon = Icons.trending_flat;
        break;
      case 'stable':
      default:
        color = Colors.grey;
        label = 'Stable';
        icon = Icons.trending_flat;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDayDetails(
    BuildContext context,
    DateTime date,
    List<DailyProgress> dailyProgress,
  ) {
    final day = dailyProgress.firstWhere(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
      orElse: () => DailyProgress(
        date: date,
        dayLabel: DateFormat('EEE').format(date),
        hasEntry: false,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => DayDetailsBottomSheet(
          day: day,
          onViewFullEntry: () {
            // Navigate to entry detail screen if needed
            // This can be implemented based on your navigation structure
          },
        ),
      ),
    );
  }
}
