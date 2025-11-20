import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';
import '../screens/new_diary_screen.dart';

/// Full screen view of yesterday's insight
class YesterdayInsightScreen extends StatelessWidget {
  final DailyInsight insight;

  const YesterdayInsightScreen({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(yesterday);
    
    // Get sentiment color and label
    final sentimentColor = _getSentimentColor(insight.sentimentLabel);
    final sentimentLabel = _getSentimentLabel(insight.sentimentLabel);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Yesterday's Insight"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sentimentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sentimentColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: sentimentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: sentimentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sentimentLabel,
                                style: TextStyle(
                                  color: sentimentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Processed ${_formatRelativeTime(insight.processedAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Main Insight
            Text(
              'Insight',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                insight.insightText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
            ),
            const SizedBox(height: 24),

            // Structured Details
            if (insight.insightDetails != null && insight.insightDetails!.hasData) ...[
              Text(
                'Detailed Analysis',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              if (insight.insightDetails!.whatWentWell != null)
                _buildDetailCard(
                  context,
                  icon: Icons.star,
                  title: 'What went well',
                  content: insight.insightDetails!.whatWentWell!,
                  color: Colors.green,
                ),
              if (insight.insightDetails!.whatWentWell != null)
                const SizedBox(height: 12),
              if (insight.insightDetails!.progressArea != null)
                _buildDetailCard(
                  context,
                  icon: Icons.trending_up,
                  title: 'Progress area',
                  content: insight.insightDetails!.progressArea!,
                  color: Colors.blue,
                ),
              if (insight.insightDetails!.progressArea != null)
                const SizedBox(height: 12),
              if (insight.insightDetails!.selfCareBalance != null)
                _buildDetailCard(
                  context,
                  icon: Icons.favorite,
                  title: 'Self-care balance',
                  content: insight.insightDetails!.selfCareBalance!,
                  color: Colors.purple,
                ),
              if (insight.insightDetails!.selfCareBalance != null)
                const SizedBox(height: 12),
              if (insight.insightDetails!.emotionalPattern != null)
                _buildDetailCard(
                  context,
                  icon: Icons.psychology,
                  title: 'Emotional pattern',
                  content: insight.insightDetails!.emotionalPattern!,
                  color: Colors.orange,
                ),
              const SizedBox(height: 24),
            ],

            // View original entry button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to diary screen - user can manually navigate to yesterday's entry
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NewDiaryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.book),
                label: const Text('View Original Entry'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSentimentColor(String? sentimentLabel) {
    switch (sentimentLabel?.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'neutral':
      default:
        return Colors.blue;
    }
  }

  String _getSentimentLabel(String? sentimentLabel) {
    switch (sentimentLabel?.toLowerCase()) {
      case 'positive':
        return 'Positive';
      case 'negative':
        return 'Negative';
      case 'neutral':
      default:
        return 'Neutral';
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
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
}

