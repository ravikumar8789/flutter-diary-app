import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_compassion_provider.dart';

class StreakDisplayWidget extends ConsumerWidget {
  final int currentStreak;
  final bool showDetails;
  final bool isCompact;

  const StreakDisplayWidget({
    super.key,
    required this.currentStreak,
    this.showDetails = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compassionState = ref.watch(streakCompassionProvider);

    if (isCompact) {
      return _buildCompactStreak(context, compassionState);
    } else if (showDetails) {
      return _buildDetailedStreak(context, compassionState);
    } else {
      return _buildBasicStreak(context, compassionState);
    }
  }

  Widget _buildBasicStreak(
    BuildContext context,
    StreakCompassionState compassionState,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          compassionState.gracePeriodActive
              ? Icons.shield
              : Icons.local_fire_department,
          color: compassionState.gracePeriodActive
              ? Colors.blue
              : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$currentStreak days',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (compassionState.gracePeriodActive) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Protected',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactStreak(
    BuildContext context,
    StreakCompassionState compassionState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: compassionState.gracePeriodActive
            ? Colors.blue.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            compassionState.gracePeriodActive
                ? Icons.shield
                : Icons.local_fire_department,
            color: compassionState.gracePeriodActive
                ? Colors.blue
                : Colors.orange,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$currentStreak days',
            style: TextStyle(
              color: compassionState.gracePeriodActive
                  ? Colors.blue
                  : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStreak(
    BuildContext context,
    StreakCompassionState compassionState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  compassionState.gracePeriodActive
                      ? Icons.shield
                      : Icons.local_fire_department,
                  color: compassionState.gracePeriodActive
                      ? Colors.blue
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Streak',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$currentStreak days',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: compassionState.gracePeriodActive
                    ? Colors.blue
                    : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (compassionState.compassionEnabled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.favorite, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${compassionState.freezeCreditsRemaining} grace periods remaining',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (compassionState.gracePeriodActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your streak is currently protected by grace period',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class StreakBadgeWidget extends ConsumerWidget {
  final int currentStreak;

  const StreakBadgeWidget({super.key, required this.currentStreak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compassionState = ref.watch(streakCompassionProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: compassionState.gracePeriodActive
            ? Colors.blue.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            compassionState.gracePeriodActive ? '🛡️' : '🔥',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '$currentStreak days',
            style: TextStyle(
              color: compassionState.gracePeriodActive
                  ? Colors.blue
                  : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
