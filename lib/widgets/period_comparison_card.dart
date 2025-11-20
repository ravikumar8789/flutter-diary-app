import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PeriodComparisonCard extends ConsumerWidget {
  final AnalyticsPeriod period;

  const PeriodComparisonCard({
    super.key,
    required this.period,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const Card(child: Center(child: Text('Please log in')));
    }

    final analyticsService = AnalyticsService();
    final comparisonFuture = analyticsService.getPeriodComparison(userId, period);

    return FutureBuilder<PeriodComparison>(
      future: comparisonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading comparison',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final comparison = snapshot.data!;
        return _buildComparisonCard(context, comparison);
      },
    );
  }

  Widget _buildComparisonCard(BuildContext context, PeriodComparison comparison) {
    final metrics = comparison.metrics;
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${period.label} Comparison',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildPeriodColumn(context, 'Current', comparison.current)),
                const SizedBox(width: 16),
                Expanded(child: _buildPeriodColumn(context, 'Previous', comparison.previous)),
              ],
            ),
            const Divider(height: 32),
            _buildMetricsRow(
              context,
              'Entries',
              comparison.current.entriesCount,
              comparison.previous.entriesCount,
              metrics.entriesChange.toDouble(),
            ),
            const SizedBox(height: 12),
            _buildMetricsRow(
              context,
              'Avg Mood',
              comparison.current.avgMood?.toStringAsFixed(1) ?? 'N/A',
              comparison.previous.avgMood?.toStringAsFixed(1) ?? 'N/A',
              metrics.moodChange,
            ),
            const SizedBox(height: 12),
            _buildMetricsRow(
              context,
              'Consistency',
              '${(comparison.current.consistencyScore * 100).toStringAsFixed(0)}%',
              '${(comparison.previous.consistencyScore * 100).toStringAsFixed(0)}%',
              metrics.consistencyChange * 100,
            ),
            const SizedBox(height: 12),
            _buildMetricsRow(
              context,
              'Self-Care',
              '${(comparison.current.selfCareRate * 100).toStringAsFixed(0)}%',
              '${(comparison.previous.selfCareRate * 100).toStringAsFixed(0)}%',
              metrics.selfCareChange * 100,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTrendColor(metrics.overallTrend).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTrendIcon(metrics.overallTrend),
                    color: _getTrendColor(metrics.overallTrend),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Trend: ${metrics.overallTrend.toUpperCase()}',
                    style: TextStyle(
                      color: _getTrendColor(metrics.overallTrend),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodColumn(BuildContext context, String label, PeriodData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text('Entries: ${data.entriesCount}'),
        Text('Mood: ${data.avgMood?.toStringAsFixed(1) ?? "N/A"}'),
        Text('Consistency: ${(data.consistencyScore * 100).toStringAsFixed(0)}%'),
        Text('Self-Care: ${(data.selfCareRate * 100).toStringAsFixed(0)}%'),
      ],
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    String label,
    dynamic current,
    dynamic previous,
    double change,
  ) {
    final changeColor = change > 0
        ? Colors.green
        : change < 0
            ? Colors.red
            : Colors.grey;
    final changeIcon = change > 0
        ? Icons.arrow_upward
        : change < 0
            ? Icons.arrow_downward
            : Icons.arrow_forward;
    final changeText = change > 0
        ? '+${change.toStringAsFixed(1)}'
        : change < 0
            ? change.toStringAsFixed(1)
            : '0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Row(
          children: [
            Text(
              '$current',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              'vs $previous',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(changeIcon, size: 16, color: changeColor),
                Text(
                  changeText,
                  style: TextStyle(color: changeColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Color _getTrendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'improving':
        return Colors.green;
      case 'declining':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'improving':
        return Icons.trending_up;
      case 'declining':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }
}

