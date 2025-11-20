import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_drawer.dart';
import '../widgets/daily_insights_timeline.dart';
import '../widgets/period_comparison_card.dart';
import '../models/analytics_models.dart';
import '../providers/analytics_provider.dart';
import '../providers/home_summary_provider.dart';
import '../services/analytics_service.dart';
import '../services/ai_service.dart';
import 'home_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final period = ref.watch(analyticsPeriodProvider);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
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
        drawer: const AppDrawer(currentRoute: 'analytics'),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period header with date range
              _buildPeriodHeader(context, period),
              const SizedBox(height: 16),

              // Summary Cards
              period == AnalyticsPeriod.weekly
                  ? _buildWeeklyContent(context, isTablet)
                  : _buildMonthlyContent(context, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodHeader(BuildContext context, AnalyticsPeriod period) {
    if (period == AnalyticsPeriod.weekly) {
      return Consumer(
        builder: (context, ref, _) {
          final weeklyAsync = ref.watch(weeklyAnalyticsProvider);
          return weeklyAsync.when(
            loading: () => Text(
              'This Week',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            error: (_, __) => Text(
              'This Week',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            data: (data) {
              final dateRange = AnalyticsService.formatDateRange(
                data.weekStart,
                data.weekEnd,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Week',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateRange,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            loading: () => Text(
              'This Month',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            error: (_, __) => Text(
              'This Month',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            data: (data) {
              final monthStr = AnalyticsService.formatMonth(data.monthStart);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Month',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    monthStr,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildWeeklyContent(BuildContext context, bool isTablet) {
    final weeklyAsync = ref.watch(weeklyAnalyticsProvider);

    return weeklyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading analytics: $e')),
      data: (data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _buildSummaryCards(context, isTablet, data),
            const SizedBox(height: 32),

            // Mood Trend Chart
            _buildSectionHeader(context, 'Mood Trends'),
            const SizedBox(height: 16),
            _buildMoodChart(context, data.moodTrendData, isWeekly: true),
            const SizedBox(height: 32),

            // AI Insights
            _buildSectionHeader(context, 'AI Insights'),
            const SizedBox(height: 16),
            _buildAiInsightsCard(context, data),
            const SizedBox(height: 32),

            // Yesterday's Insight Status
            _buildSectionHeader(context, "Yesterday's Insight"),
            const SizedBox(height: 16),
            _buildTodayInsightStatusCard(context),
            const SizedBox(height: 32),

            // Period Comparison
            PeriodComparisonCard(period: AnalyticsPeriod.weekly),
            const SizedBox(height: 32),

            // Daily Insights Timeline
            _buildSectionHeader(context, 'Daily Insights Timeline'),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: DailyInsightsTimeline(
                startDate: data.weekStart,
                endDate: data.weekEnd,
              ),
            ),
            const SizedBox(height: 32),

            // Habits & Consistency
            _buildSectionHeader(context, 'Habits & Consistency'),
            const SizedBox(height: 16),
            _buildHabitsConsistencyCard(context, data),
            const SizedBox(height: 32),

            // Topics
            _buildSectionHeader(context, 'Top Topics'),
            const SizedBox(height: 16),
            _buildTopicsCard(context, data.topTopics),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyContent(BuildContext context, bool isTablet) {
    final monthlyAsync = ref.watch(monthlyAnalyticsProvider);

    return monthlyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading analytics: $e')),
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

            // AI Insights
            _buildSectionHeader(context, 'AI Insights'),
            const SizedBox(height: 16),
            _buildAiInsightsCardMonthly(context, data),
            const SizedBox(height: 32),

            // Habits & Consistency
            _buildSectionHeader(context, 'Habits & Consistency'),
            const SizedBox(height: 16),
            _buildHabitsConsistencyCardMonthly(context, data),
            const SizedBox(height: 32),

            // Topics
            _buildSectionHeader(context, 'Top Topics'),
            const SizedBox(height: 16),
            _buildTopicsCard(context, data.combinedTopics),
          ],
        );
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
          '${(data.selfCareRate * 100).toInt()}%',
          'Completion rate',
          Icons.spa,
          Colors.purple,
        ),
      ],
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
                  'Weekly Insights Coming Soon',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your personalized weekly analysis will appear here once you\'ve completed more entries this week. Keep journaling to unlock insights about your patterns and growth!',
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
                        '${data.entriesCount} entries this week',
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
            // Key Insights
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
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
                ],
              ],
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

    if (monthlyInsight != null) {
      growthAreas = monthlyInsight.growthAreas;
      achievements = monthlyInsight.achievements.isNotEmpty
          ? monthlyInsight.achievements
          : data.keyInsights;
      nextMonthGoals = monthlyInsight.nextMonthGoals.isNotEmpty
          ? monthlyInsight.nextMonthGoals
          : data.recommendations;
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
            const SizedBox(height: 20),
            // Monthly Highlights
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Achievements
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
              ...achievements.map(
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
              const SizedBox(height: 20),
            ],
            // Growth Areas
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
              ...growthAreas.map(
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
              const SizedBox(height: 20),
            ],
            // Next Month Goals
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
                    ...nextMonthGoals.map(
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

  Widget _buildHabitsConsistencyCard(
    BuildContext context,
    WeeklyAnalyticsData data,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Consistency Score
            if (data.consistencyScore != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: data.consistencyScore,
                          strokeWidth: 12,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getConsistencyColor(data.consistencyScore!),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(data.consistencyScore! * 100).toInt()}%',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Consistency',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            // Entries Completion
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Entries Completion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${data.entriesCount}/7 days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: data.entriesCount / 7,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitsConsistencyCardMonthly(
    BuildContext context,
    MonthlyAnalyticsData data,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Consistency Score
            if (data.overallConsistency != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: data.overallConsistency,
                          strokeWidth: 12,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getConsistencyColor(data.overallConsistency!),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(data.overallConsistency! * 100).toInt()}%',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Consistency',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            // Entries Completion
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Entries Completion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${data.totalEntries} entries',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: data.totalEntries / 30, // Approximate month days
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getConsistencyColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTopicsCard(BuildContext context, List<String> topics) {
    if (topics.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No topics available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // Count topic frequency (simulate for now)
    final topicFrequency = <String, int>{};
    for (final topic in topics) {
      topicFrequency[topic] = (topicFrequency[topic] ?? 0) + 1;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: topicFrequency.entries.map((entry) {
            final count = entry.value;
            return Chip(
              label: Text('${entry.key} ($count)'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                fontSize: 13 + (count * 0.3),
                fontWeight: count > 5 ? FontWeight.bold : FontWeight.normal,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
        ),
      ),
    );
  }
}
