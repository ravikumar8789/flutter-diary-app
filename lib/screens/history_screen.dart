import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_drawer.dart';
import 'home_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _viewMode = 'list'; // list or calendar
  String _filterTag = 'All';

  final List<Map<String, dynamic>> _mockEntries = [
    {
      'date': DateTime.now(),
      'mood': 5,
      'preview':
          'Today was amazing! I finally completed my project and felt incredibly proud...',
      'tags': ['Work', 'Achievement'],
    },
    {
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'mood': 4,
      'preview':
          'Had a peaceful day. Spent time with family and felt grateful for the little things...',
      'tags': ['Family', 'Gratitude'],
    },
    {
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'mood': 3,
      'preview': 'Feeling neutral today. Just going through the motions...',
      'tags': ['Reflection'],
    },
    {
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'mood': 4,
      'preview':
          'Went for a morning walk. The fresh air really helped clear my mind...',
      'tags': ['Health', 'Self-Care'],
    },
    {
      'date': DateTime.now().subtract(const Duration(days: 4)),
      'mood': 5,
      'preview': 'Best day of the week! Everything just clicked...',
      'tags': ['Goals', 'Gratitude'],
    },
  ];

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
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(
              icon: Icon(
                _viewMode == 'list' ? Icons.calendar_month : Icons.list,
              ),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == 'list' ? 'calendar' : 'list';
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: Implement search
              },
            ),
          ],
        ),
        drawer: const AppDrawer(currentRoute: 'history'),
        body: Column(
          children: [
            // Filter chips
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Work'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Family'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Health'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Goals'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Gratitude'),
                  ],
                ),
              ),
            ),

            // Entries list
            Expanded(
              child: _viewMode == 'list'
                  ? _buildListView(isTablet)
                  : _buildCalendarView(isTablet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return FilterChip(
      label: Text(label),
      selected: _filterTag == label,
      onSelected: (selected) {
        setState(() {
          _filterTag = selected ? label : 'All';
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildListView(bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 32 : 16),
      itemCount: _mockEntries.length,
      itemBuilder: (context, index) {
        final entry = _mockEntries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: InkWell(
              onTap: () {
                _showEntryDetail(entry);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d').format(entry['date']),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        _buildMoodIcon(entry['mood']),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry['preview'],
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (entry['tags'] as List<String>).map((tag) {
                        return Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Calendar view coming soon',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'View your entries in a calendar format',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMoodIcon(int mood) {
    final icons = [
      Icons.sentiment_very_dissatisfied,
      Icons.sentiment_dissatisfied,
      Icons.sentiment_neutral,
      Icons.sentiment_satisfied,
      Icons.sentiment_very_satisfied,
    ];
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.lightGreen,
      Colors.green,
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors[mood - 1].withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icons[mood - 1], color: colors[mood - 1], size: 24),
    );
  }

  void _showEntryDetail(Map<String, dynamic> entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM d, y').format(entry['date']),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  _buildMoodIcon(entry['mood']),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                entry['preview'],
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (entry['tags'] as List<String>).map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Navigate to edit
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement delete
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
