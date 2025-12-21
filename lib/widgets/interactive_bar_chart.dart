import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/analytics_models.dart';

/// Interactive bar chart for daily progress (mood, water, self-care)
class InteractiveBarChart extends StatelessWidget {
  final List<DailyProgress> dailyData;
  final Function(DateTime) onBarTap;

  const InteractiveBarChart({
    super.key,
    required this.dailyData,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No daily data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Daily Progress',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap any bar to see day details',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            // Chart area
            SizedBox(
              height: 180,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive sizing to avoid overflow on small screens
                  final availableWidth = constraints.maxWidth;
                  final items = dailyData.length.clamp(1, 14);
                  // Calculate width per day group, keep bars thin on narrow screens
                  final groupWidth = availableWidth / items;
                  final barWidth =
                      groupWidth / 4.0; // 3 bars + small gaps ≈ group width
                  final clampedBarWidth =
                      barWidth.clamp(6.0, 12.0); // responsive bounds
                  final maxHeight =
                      (constraints.maxHeight * 0.65).clamp(110.0, 150.0);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: dailyData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final day = entry.value;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _DayBar(
                            day: day,
                            index: index,
                            maxHeight: maxHeight,
                            barWidth: clampedBarWidth,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onBarTap(day.date);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(
                  color: Colors.green,
                  label: 'Mood',
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  color: Colors.blue,
                  label: 'Water',
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  color: Colors.purple,
                  label: 'Self-Care',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final DailyProgress day;
  final int index;
  final VoidCallback onTap;
  final double maxHeight;
  final double barWidth;

  const _DayBar({
    required this.day,
    required this.index,
    required this.onTap,
    required this.maxHeight,
    required this.barWidth,
  });

  Color _getMoodColor(double? moodScore) {
    // Use a single consistent color for mood to match the legend
    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bar heights (normalized to 0-1, then scaled)
    final moodHeight = day.moodScore != null
        ? (day.moodScore! / 5.0) * maxHeight
        : 0.0;
    final waterHeight = (day.waterCups / 8.0) * maxHeight;
    final selfCareHeight = day.selfCareCompletion * maxHeight;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bars (stacked or grouped)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mood bar
              Container(
                  width: barWidth,
                height: moodHeight.clamp(0, maxHeight),
                decoration: BoxDecoration(
                  color: _getMoodColor(day.moodScore),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
                const SizedBox(width: 1.5),
              // Water bar
              Container(
                  width: barWidth,
                height: waterHeight.clamp(0, maxHeight),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
                const SizedBox(width: 1.5),
              // Self-care bar
              Container(
                  width: barWidth,
                height: selfCareHeight.clamp(0, maxHeight),
                decoration: BoxDecoration(
                  color: Colors.purple.shade400,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Day label
          Text(
            day.dayLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          // Entry indicator
          if (day.hasEntry)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

