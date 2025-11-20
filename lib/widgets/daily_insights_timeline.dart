import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_models.dart';
import '../services/ai_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyInsightsTimeline extends ConsumerStatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DailyInsightsTimeline({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  ConsumerState<DailyInsightsTimeline> createState() => _DailyInsightsTimelineState();
}

class _DailyInsightsTimelineState extends ConsumerState<DailyInsightsTimeline> {
  String? _selectedSentiment;

  Color _getSentimentColor(String? sentiment) {
    switch (sentiment?.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }


  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const Center(child: Text('Please log in'));
    }

    final aiService = AIService();
    final insightsFuture = aiService.getDailyInsightsTimeline(
      userId,
      widget.startDate,
      widget.endDate,
    );

    return FutureBuilder<List<DailyInsightWithMood>>(
      future: insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading insights',
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
          );
        }

        final insights = snapshot.data ?? [];

        final filteredInsights = _selectedSentiment == null
            ? insights
            : insights.where((i) => i.insight.sentimentLabel == _selectedSentiment).toList();

        if (filteredInsights.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            _buildFilterChips(context),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredInsights.length,
                itemBuilder: (context, index) {
                  return _buildTimelineItem(context, filteredInsights[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip(context, 'All', null),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Positive', 'positive'),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Neutral', 'neutral'),
          const SizedBox(width: 8),
          _buildFilterChip(context, 'Negative', 'negative'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String? sentiment) {
    final isSelected = _selectedSentiment == sentiment;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedSentiment = selected ? sentiment : null;
        });
      },
    );
  }

  Widget _buildTimelineItem(BuildContext context, DailyInsightWithMood item) {
    final sentimentColor = _getSentimentColor(item.insight.sentimentLabel);
    final dateStr = '${item.entryDate.day}/${item.entryDate.month}/${item.entryDate.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📅 ${item.dayLabel}, $dateStr',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (item.moodScore != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Mood: ${item.moodScore!.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: sentimentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Sentiment badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.insight.sentimentLabel?.toUpperCase() ?? 'NEUTRAL',
                  style: TextStyle(
                    fontSize: 11,
                    color: sentimentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: sentimentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(
                item.insight.insightText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    item.insight.insightText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No insights for this period',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Write diary entries to see insights here',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

