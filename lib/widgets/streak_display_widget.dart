import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/grace_system_provider.dart';

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
    final graceState = ref.watch(graceSystemProvider);

    if (isCompact) {
      return _buildCompactStreak(context, graceState);
    } else if (showDetails) {
      return _buildDetailedStreak(context, graceState);
    } else {
      return _buildBasicStreak(context, graceState);
    }
  }

  Widget _buildBasicStreak(BuildContext context, GraceSystemState graceState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          graceState.graceDaysAvailable > 0
              ? Icons.shield
              : Icons.local_fire_department,
          color: graceState.graceDaysAvailable > 0
              ? Colors.blue
              : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$currentStreak days',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (graceState.graceDaysAvailable > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${graceState.graceDaysAvailable} grace',
              style: const TextStyle(
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
    GraceSystemState graceState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: graceState.graceDaysAvailable > 0
            ? Colors.blue.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            graceState.graceDaysAvailable > 0
                ? Icons.shield
                : Icons.local_fire_department,
            color: graceState.graceDaysAvailable > 0
                ? Colors.blue
                : Colors.orange,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '$currentStreak days',
            style: TextStyle(
              color: graceState.graceDaysAvailable > 0
                  ? Colors.blue
                  : Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStreak(
    BuildContext context,
    GraceSystemState graceState,
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
                  graceState.graceDaysAvailable > 0
                      ? Icons.shield
                      : Icons.local_fire_department,
                  color: graceState.graceDaysAvailable > 0
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
                color: graceState.graceDaysAvailable > 0
                    ? Colors.blue
                    : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${graceState.graceDaysAvailable} grace days available',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${graceState.piecesToday.toStringAsFixed(1)}/10 pieces today',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (graceState.graceDaysAvailable > 0) ...[
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
                        'Your streak is protected by grace days',
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
    final graceState = ref.watch(graceSystemProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: graceState.graceDaysAvailable > 0
            ? Colors.blue.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            graceState.graceDaysAvailable > 0 ? '🛡️' : '🔥',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '$currentStreak days',
            style: TextStyle(
              color: graceState.graceDaysAvailable > 0
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
