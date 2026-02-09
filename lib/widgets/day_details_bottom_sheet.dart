import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics_models.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

/// Bottom sheet showing detailed day information
class DayDetailsBottomSheet extends StatelessWidget {
  final DailyProgress day;
  final ScrollController? scrollController;

  const DayDetailsBottomSheet({
    super.key,
    required this.day,
    this.scrollController,
  });

  Color _getMoodColor(ColorScheme colorScheme, double? moodScore) {
    if (moodScore == null) return colorScheme.onSurfaceVariant;
    if (moodScore >= 4) return Colors.green;
    if (moodScore >= 3) return Colors.orange;
    return Colors.red;
  }

  String _getMoodLabel(double? moodScore) {
    if (moodScore == null) return 'Not recorded';
    if (moodScore >= 4.5) return 'Excellent';
    if (moodScore >= 4) return 'Great';
    if (moodScore >= 3.5) return 'Good';
    if (moodScore >= 3) return 'Okay';
    if (moodScore >= 2) return 'Not great';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final dayName = dateFormat.format(day.date);
    final info = ResponsiveInfo.of(context);
    final padding = ResponsiveTokens.screenPaddingHorizontal(info);
    final spacingM = ResponsiveTokens.spacingM(info);
    final spacingL = ResponsiveTokens.spacingL(info);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (day.hasEntry)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Entry recorded',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.green[700],
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  SizedBox(height: spacingL),

                  // Metrics grid
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.sentiment_satisfied,
                          label: 'Mood',
                          value: day.moodScore != null
                              ? day.moodScore!.toStringAsFixed(1)
                              : '—',
                          subtitle: _getMoodLabel(day.moodScore),
                          color: _getMoodColor(colorScheme, day.moodScore),
                        ),
                      ),
                      SizedBox(width: spacingM),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.water_drop,
                          label: 'Water',
                          value: '${day.waterCups} cups',
                          subtitle: '${(day.waterCups / 8.0 * 100).toStringAsFixed(0)}% of goal',
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: spacingM),
                      Expanded(
                        child: _MetricCard(
                          icon: Icons.spa,
                          label: 'Self-Care',
                          value: '${(day.selfCareCompletion * 100).toStringAsFixed(0)}%',
                          subtitle: 'Completion rate',
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),

                  // Entry (full text)
                  if (day.entryPreview != null && day.entryPreview!.isNotEmpty) ...[
                    SizedBox(height: spacingL),
                    const Divider(),
                    SizedBox(height: spacingM),
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: ResponsiveTokens.spacingS(info)),
                        Text(
                          'Entry',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacingM),
                    Container(
                      padding: EdgeInsets.all(spacingM),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        day.entryPreview!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                      ),
                    ),
                  ] else if (!day.hasEntry) ...[
                    SizedBox(height: spacingL),
                    const Divider(),
                    SizedBox(height: spacingM),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.edit_note_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: spacingM),
                          Text(
                            'No entry for this day',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: spacingL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

