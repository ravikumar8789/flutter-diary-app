import 'package:flutter/material.dart';

/// Habit correlations card displaying AI-analyzed correlations
class HabitCorrelationsCard extends StatefulWidget {
  final Map<String, dynamic>? correlations;

  const HabitCorrelationsCard({
    super.key,
    this.correlations,
  });

  @override
  State<HabitCorrelationsCard> createState() => _HabitCorrelationsCardState();
}

class _HabitCorrelationsCardState extends State<HabitCorrelationsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.correlations == null || widget.correlations!.isEmpty) {
      return const SizedBox.shrink();
    }

    final correlations = widget.correlations!;

    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.insights,
                      color: Colors.teal[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Habit Correlations',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'AI-analyzed patterns and connections',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),

                  // Mood vs Entries
                  if (correlations['mood_vs_entries'] != null)
                    _buildCorrelationItem(
                      context,
                      icon: Icons.mood,
                      label: 'Mood vs Entries',
                      value: correlations['mood_vs_entries'],
                      format: (v) => v is num ? v.toStringAsFixed(2) : v.toString(),
                    ),

                  // Self-care completion
                  if (correlations['self_care_completion'] != null)
                    _buildCorrelationItem(
                      context,
                      icon: Icons.spa,
                      label: 'Self-Care Completion',
                      value: correlations['self_care_completion'],
                      format: (v) => v is num ? '${v.toInt()}%' : v.toString(),
                    ),

                  // Mood vs Gratitude
                  if (correlations['mood_vs_gratitude'] != null)
                    _buildCorrelationItem(
                      context,
                      icon: Icons.favorite,
                      label: 'Mood vs Gratitude',
                      value: correlations['mood_vs_gratitude'],
                      format: (v) => v is num ? v.toStringAsFixed(2) : v.toString(),
                    ),

                  // Mood vs Affirmations
                  if (correlations['mood_vs_affirmations'] != null)
                    _buildCorrelationItem(
                      context,
                      icon: Icons.auto_awesome,
                      label: 'Mood vs Affirmations',
                      value: correlations['mood_vs_affirmations'],
                      format: (v) => v is num ? v.toStringAsFixed(2) : v.toString(),
                    ),

                  // Sentiment distribution
                  if (correlations['sentiment_distribution'] != null)
                    _buildSentimentDistribution(
                      context,
                      correlations['sentiment_distribution'] as Map<String, dynamic>,
                    ),

                  // Consistency impact
                  if (correlations['consistency_impact'] != null)
                    _buildConsistencyImpact(
                      context,
                      correlations['consistency_impact'] as String,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorrelationItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required dynamic value,
    required String Function(dynamic) format,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.3)),
            ),
            child: Text(
              format(value),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.teal[700],
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentDistribution(
    BuildContext context,
    Map<String, dynamic> distribution,
  ) {
    final positive = distribution['positive'] as int? ?? 0;
    final neutral = distribution['neutral'] as int? ?? 0;
    final negative = distribution['negative'] as int? ?? 0;
    final total = positive + neutral + negative;

    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sentiment_satisfied, size: 20, color: Colors.teal[700]),
              const SizedBox(width: 12),
              Text(
                'Sentiment Distribution',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSentimentBar(
                  context,
                  label: 'Positive',
                  count: positive,
                  total: total,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSentimentBar(
                  context,
                  label: 'Neutral',
                  count: neutral,
                  total: total,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSentimentBar(
                  context,
                  label: 'Negative',
                  count: negative,
                  total: total,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentBar(
    BuildContext context, {
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildConsistencyImpact(
    BuildContext context,
    String impact,
  ) {
    Color impactColor;
    IconData impactIcon;
    String impactLabel;

    switch (impact.toLowerCase()) {
      case 'high':
        impactColor = Colors.green;
        impactIcon = Icons.trending_up;
        impactLabel = 'High Impact';
        break;
      case 'medium':
        impactColor = Colors.orange;
        impactIcon = Icons.trending_flat;
        impactLabel = 'Medium Impact';
        break;
      case 'low':
        impactColor = Colors.grey;
        impactIcon = Icons.trending_down;
        impactLabel = 'Low Impact';
        break;
      default:
        impactColor = Colors.grey;
        impactIcon = Icons.info;
        impactLabel = impact;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: impactColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: impactColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(impactIcon, size: 20, color: impactColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consistency Impact',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
                Text(
                  impactLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: impactColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

