import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_drawer.dart';
import 'home_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return WillPopScope(
      onWillPop: () async {
        // Clear entire stack and set Home as the only screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false, // Remove all previous routes
        );
        return false; // Don't exit app
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        drawer: const AppDrawer(currentRoute: 'analytics'),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              Text(
                'This Week',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = isTablet ? 4 : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isTablet ? 1.5 : 1.4,
                    children: [
                      _buildStatCard(
                        context,
                        'Entries',
                        '5/7',
                        Icons.edit_note,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        context,
                        'Avg Mood',
                        '4.2',
                        Icons.sentiment_satisfied,
                        Colors.green,
                      ),
                      _buildStatCard(
                        context,
                        'Water',
                        '6.5 cups',
                        Icons.water_drop,
                        Colors.cyan,
                      ),
                      _buildStatCard(
                        context,
                        'Self-Care',
                        '75%',
                        Icons.spa,
                        Colors.purple,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Mood chart
              Text(
                'Mood Trends',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    height: 250,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString());
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
                              getTitlesWidget: (value, meta) {
                                const days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ];
                                if (value.toInt() >= 0 &&
                                    value.toInt() < days.length) {
                                  return Text(days[value.toInt()]);
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: 5,
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 4),
                              FlSpot(1, 3.5),
                              FlSpot(2, 4.5),
                              FlSpot(3, 4),
                              FlSpot(4, 5),
                              FlSpot(5, 4.2),
                              FlSpot(6, 4.8),
                            ],
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
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
              ),
              const SizedBox(height: 32),

              // Self-care completion
              Text(
                'Self-Care Activities',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildProgressItem(context, 'Sleep', 0.85),
                      const SizedBox(height: 16),
                      _buildProgressItem(context, 'Exercise', 0.60),
                      const SizedBox(height: 16),
                      _buildProgressItem(context, 'Read Book', 0.45),
                      const SizedBox(height: 16),
                      _buildProgressItem(context, 'Hydrated', 0.90),
                      const SizedBox(height: 16),
                      _buildProgressItem(context, 'Fresh Air', 0.70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Topics/Tags cloud
              Text(
                'Common Topics',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildTopicChip(context, 'Work', 15),
                      _buildTopicChip(context, 'Family', 12),
                      _buildTopicChip(context, 'Health', 8),
                      _buildTopicChip(context, 'Goals', 10),
                      _buildTopicChip(context, 'Reflection', 7),
                      _buildTopicChip(context, 'Gratitude', 14),
                      _buildTopicChip(context, 'Challenges', 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(
    BuildContext context,
    String label,
    double progress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              '${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildTopicChip(BuildContext context, String label, int count) {
    return Chip(
      label: Text('$label ($count)'),
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
    );
  }
}
