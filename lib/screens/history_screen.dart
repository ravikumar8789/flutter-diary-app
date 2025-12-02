import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/app_drawer.dart';
import 'home_screen.dart';
import '../providers/history_provider.dart';
import '../models/history_entry_model.dart';
import '../models/entry_models.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _viewMode = 'list';
  String _filterTag = 'All';
  String? _selectedMood;
  String? _selectedSentiment;
  bool _hasInsightsOnly = false;
  String? _completionFilter;

  @override
  void initState() {
    super.initState();
    // Load list data (2 months) and calendar mood data in parallel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).loadCurrentMonth();
      ref.read(historyProvider.notifier).loadCalendarMoodData();
    });
  }

  // Get filtered entries from provider
  List<HistoryEntry> get _filteredEntries {
    final historyState = ref.read(historyProvider);
    var entries = historyState.entries;

    // Apply filters
    if (_filterTag != 'All') {
      entries = entries.where((e) => e.tags.contains(_filterTag)).toList();
    }

    if (_selectedMood != null) {
      entries = entries
          .where((e) => e.entry.moodScore?.toString() == _selectedMood)
          .toList();
    }

    if (_selectedSentiment != null) {
      entries = entries
          .where((e) => e.sentiment == _selectedSentiment)
          .toList();
    }

    if (_hasInsightsOnly) {
      entries = entries.where((e) => e.hasInsights).toList();
    }

    if (_completionFilter == 'complete') {
      entries = entries.where((e) {
        final hasAffirmations =
            e.affirmations?.affirmations.isNotEmpty ?? false;
        final hasGratitude = e.gratitude?.gratefulItems.isNotEmpty ?? false;
        final selfCareCount = e.selfCareCount;
        return hasAffirmations && hasGratitude && selfCareCount >= 7;
      }).toList();
    } else if (_completionFilter == 'incomplete') {
      entries = entries.where((e) {
        final hasAffirmations =
            e.affirmations?.affirmations.isNotEmpty ?? false;
        final hasGratitude = e.gratitude?.gratefulItems.isNotEmpty ?? false;
        final selfCareCount = e.selfCareCount;
        return !hasAffirmations || !hasGratitude || selfCareCount < 5;
      }).toList();
    }

    return entries;
  }

  // Group entries by month
  Map<String, List<HistoryEntry>> get _groupedEntries {
    final grouped = <String, List<HistoryEntry>>{};
    for (final entry in _filteredEntries) {
      final key = DateFormat('MMMM yyyy').format(entry.entry.entryDate);
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  // Get available months for pagination
  // Uses monthsWithEntries from provider state (queried from database)
  List<String> get _availableMonths {
    final historyState = ref.read(historyProvider);
    final loadedMonths = historyState.loadedMonths;
    final allMonthsWithEntries = historyState.monthsWithEntries;

    // Return months that have entries but aren't loaded yet, sorted (oldest first)
    final unloaded = allMonthsWithEntries
        .where((monthKey) => !loadedMonths.contains(monthKey))
        .toList();
    // Already sorted oldest first from database query
    return unloaded;
  }

  // Fixed tags for filter (as discussed)
  static const List<String> _fixedTags = [
    'All',
    'Work',
    'Family',
    'Health',
    'Goals',
    'Gratitude',
    'Reflection',
    'Self-Care',
    'Growth',
    'Challenge',
  ];

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        return false;
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
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(),
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
            // Enhanced filter chips with colors
            Container(
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 16 : 12,
                horizontal: isTablet ? 20 : 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._fixedTags.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(tag, _getTagColor(tag)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Entries list
            Expanded(
              child: historyState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : historyState.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error: ${historyState.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(historyProvider.notifier).clearError();
                              ref
                                  .read(historyProvider.notifier)
                                  .loadCurrentMonth();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _viewMode == 'list'
                  ? _buildListView(isTablet, historyState)
                  : _buildCalendarView(isTablet, historyState),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTagColor(String tag) {
    final colors = {
      'Work': Colors.blue,
      'Achievement': Colors.amber,
      'Family': Colors.pink,
      'Gratitude': Colors.purple,
      'Health': Colors.green,
      'Self-Care': Colors.teal,
      'Goals': Colors.orange,
      'Reflection': Colors.indigo,
      'Growth': Colors.cyan,
      'Learning': Colors.deepPurple,
      'Challenge': Colors.red,
      'Resilience': Colors.deepOrange,
      'Mindfulness': Colors.lightBlue,
      'Wellness': Colors.lightGreen,
      'Connection': Colors.pinkAccent,
      'Friendship': Colors.blueAccent,
      'Rest': Colors.grey,
    };
    return colors[tag] ?? Colors.grey;
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = _filterTag == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterTag = selected ? label : 'All';
        });
      },
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildListView(bool isTablet, HistoryState historyState) {
    final grouped = _groupedEntries;
    if (grouped.isEmpty && !historyState.isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 32 : 16),
      itemCount: grouped.length + (_availableMonths.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Load more button at the end
        if (index == grouped.length && _availableMonths.isNotEmpty) {
          return _buildLoadMoreButton(historyState);
        }
        final monthKey = grouped.keys.toList()[index];
        final entries = grouped[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header with gradient
            Padding(
              padding: EdgeInsets.only(bottom: 16, top: index == 0 ? 0 : 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      monthKey,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Entries for this month
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildEntryCard(entry, isTablet),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreButton(HistoryState historyState) {
    final availableMonths = _availableMonths;
    if (availableMonths.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the oldest unloaded month (load backwards chronologically)
    // availableMonths is already sorted (oldest first)
    final nextMonthKey = availableMonths.first;

    // Parse month key to get display name
    final parts = nextMonthKey.split('-');
    final month = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    final monthDisplayName = DateFormat('MMMM yyyy').format(month);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: historyState.isLoadingMore
              ? null
              : () => ref
                    .read(historyProvider.notifier)
                    .loadPreviousMonth(nextMonthKey),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
              ),
            ),
            child: historyState.isLoadingMore
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.expand_more,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          Text(
                            'Load $monthDisplayName',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Load more entries',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(HistoryEntry entry, bool isTablet) {
    final mood = entry.entry.moodScore ?? 3;
    final hasInsights = entry.hasInsights;
    final sentiment = entry.sentiment;
    final wordCount = entry.wordCount;
    final selfCareCount = entry.selfCareCount;
    final mealsCount = entry.mealsCount;
    final waterCups = entry.meals?.waterCups ?? 0;
    final tags = entry.tags;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: () => _showEntryDetail(entry),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  _getSentimentColor(sentiment).withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, y',
                              ).format(entry.entry.entryDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Removed "Edited" text - will show in metadata
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (hasInsights)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade300,
                                    Colors.purple.shade500,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          _buildMoodIcon(mood),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Preview text
                  Text(
                    entry.preview,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Quick stats row - ALWAYS show all chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildStatChip(
                        Icons.text_fields,
                        '$wordCount words',
                        Colors.blue,
                      ),
                      _buildStatChip(
                        Icons.favorite,
                        '$selfCareCount/10 self-care',
                        Colors.pink,
                      ),
                      _buildStatChip(
                        Icons.water_drop,
                        '$waterCups cups',
                        Colors.cyan,
                      ),
                      _buildStatChip(
                        Icons.restaurant,
                        '$mealsCount/3 meals',
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tags
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTagColor(tag).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _getTagColor(tag).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getTagColor(tag),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
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
        gradient: LinearGradient(
          colors: [colors[mood - 1], colors[mood - 1].withOpacity(0.7)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors[mood - 1].withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icons[mood - 1], color: Colors.white, size: 20),
    );
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment) {
      case 'positive':
        return Colors.green;
      case 'neutral':
        return Colors.grey;
      case 'negative':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper to get mood by date (from provider)
  int? _getMoodByDate(DateTime date) {
    final historyState = ref.read(historyProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return historyState.moodMap[dateStr];
  }

  // Get mood color
  Color _getMoodColor(int mood) {
    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.yellow.shade600,
      Colors.lightGreen.shade400,
      Colors.green.shade400,
    ];
    return colors[mood - 1];
  }

  // Get mood icon
  IconData _getMoodIcon(int mood) {
    final icons = [
      Icons.sentiment_very_dissatisfied,
      Icons.sentiment_dissatisfied,
      Icons.sentiment_neutral,
      Icons.sentiment_satisfied,
      Icons.sentiment_very_satisfied,
    ];
    return icons[mood - 1];
  }

  Widget _buildCalendarView(bool isTablet, HistoryState historyState) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - 5, 1); // 6 months back
    final endDate = DateTime(now.year, now.month + 1, 0); // Current month end

    // Generate list of months to display
    final months = <DateTime>[];
    var current = DateTime(startDate.year, startDate.month, 1);
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      months.add(DateTime(current.year, current.month, 1));
      current = DateTime(current.year, current.month + 1, 1);
    }

    // Reverse list so current month appears at top (newest first)
    months.sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: 16,
      ),
      itemCount: months.length,
      itemBuilder: (context, index) {
        return _buildMonthCalendar(months[index], isTablet);
      },
    );
  }

  Widget _buildMonthCalendar(DateTime focusedDay, bool isTablet) {
    final firstDay = DateTime(focusedDay.year, focusedDay.month, 1);
    final lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month header with gradient
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.pink.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMMM yyyy').format(focusedDay),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Calendar
          TableCalendar(
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: focusedDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerVisible: false,
            daysOfWeekVisible: true,
            weekendDays: const [DateTime.saturday, DateTime.sunday],
            eventLoader: (date) {
              // Return list if entry exists for this date
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final hasEntry = ref
                  .read(historyProvider)
                  .moodMap
                  .containsKey(dateStr);
              return hasEntry ? [date] : [];
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              defaultTextStyle: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade400, width: 2),
              ),
              todayTextStyle: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.purple.shade300,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              markerDecoration: const BoxDecoration(shape: BoxShape.circle),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              weekendStyle: TextStyle(
                color: Colors.pink.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, focusedDay) {
                return _buildDateCell(context, date, isToday: false);
              },
              todayBuilder: (context, date, focusedDay) {
                return _buildDateCell(context, date, isToday: true);
              },
              selectedBuilder: (context, date, focusedDay) {
                return _buildDateCell(context, date, isSelected: true);
              },
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 2,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              _handleDateTap(selectedDay);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime date, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    // Use optimized mood lookup
    final moodNullable = _getMoodByDate(date);
    final hasEntry = moodNullable != null;
    final mood =
        moodNullable ?? 0; // Default value, won't be used if hasEntry is false

    return GestureDetector(
      onTap: () => _handleDateTap(date),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? Colors.purple.shade300
              : isToday
              ? Colors.blue.shade100
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Mood background circle
            if (hasEntry)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _getMoodColor(mood).withOpacity(0.3),
                      _getMoodColor(mood).withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            // Date number
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isToday
                    ? Colors.blue.shade700
                    : hasEntry
                    ? Colors.grey.shade800
                    : Colors.grey.shade500,
              ),
            ),
            // Mood icon overlay (small, top-right)
            if (hasEntry)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _getMoodColor(mood),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getMoodColor(mood).withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getMoodIcon(mood),
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleDateTap(DateTime date) async {
    // Show loading bottom sheet immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.3,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
              SizedBox(height: 16),
              Text(
                'Loading entry...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    // Fetch entry from provider
    final entry = await ref.read(historyProvider.notifier).getEntryByDate(date);

    // Close loading sheet
    if (context.mounted) Navigator.pop(context);

    if (context.mounted) {
      if (entry != null) {
        // Show entry detail
        _showEntryDetail(entry);
      } else {
        // Show empty state
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.4,
            maxChildSize: 0.6,
            minChildSize: 0.3,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade100,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_note,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No entry for this date',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'You haven\'t written an entry for ${DateFormat('MMMM d, y').format(date)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
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
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'No entries found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Entries'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mood filter
              const Text('Mood', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption('All', _selectedMood == null, () {
                    setState(() => _selectedMood = null);
                    Navigator.pop(context);
                  }),
                  for (int i = 1; i <= 5; i++)
                    _buildFilterOption('$i', _selectedMood == i.toString(), () {
                      setState(() => _selectedMood = i.toString());
                      Navigator.pop(context);
                    }),
                ],
              ),
              const SizedBox(height: 16),

              // Sentiment filter
              const Text(
                'Sentiment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption('All', _selectedSentiment == null, () {
                    setState(() => _selectedSentiment = null);
                    Navigator.pop(context);
                  }),
                  _buildFilterOption(
                    'Positive',
                    _selectedSentiment == 'positive',
                    () {
                      setState(() => _selectedSentiment = 'positive');
                      Navigator.pop(context);
                    },
                  ),
                  _buildFilterOption(
                    'Neutral',
                    _selectedSentiment == 'neutral',
                    () {
                      setState(() => _selectedSentiment = 'neutral');
                      Navigator.pop(context);
                    },
                  ),
                  _buildFilterOption(
                    'Negative',
                    _selectedSentiment == 'negative',
                    () {
                      setState(() => _selectedSentiment = 'negative');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Has insights filter
              SwitchListTile(
                title: const Text('Has AI Insights'),
                value: _hasInsightsOnly,
                onChanged: (value) {
                  setState(() => _hasInsightsOnly = value);
                  Navigator.pop(context);
                },
              ),

              // Completion filter
              const Text(
                'Completion',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterOption('All', _completionFilter == null, () {
                    setState(() => _completionFilter = null);
                    Navigator.pop(context);
                  }),
                  _buildFilterOption(
                    'Complete',
                    _completionFilter == 'complete',
                    () {
                      setState(() => _completionFilter = 'complete');
                      Navigator.pop(context);
                    },
                  ),
                  _buildFilterOption(
                    'Incomplete',
                    _completionFilter == 'incomplete',
                    () {
                      setState(() => _completionFilter = 'incomplete');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedMood = null;
                _selectedSentiment = null;
                _hasInsightsOnly = false;
                _completionFilter = null;
                _filterTag = 'All';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
    );
  }

  void _showEntryDetail(HistoryEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
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
                                  DateFormat(
                                    'EEEE, MMMM d, y',
                                  ).format(entry.entry.entryDate),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Removed "Edited" text - will show in metadata
                              ],
                            ),
                          ),
                          _buildMoodIcon(entry.entry.moodScore ?? 3),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Full diary text
                      _buildSection(
                        'Diary Entry',
                        Icons.book,
                        Colors.blue,
                        Text(
                          entry.entry.diaryText ?? 'No diary text',
                          style: const TextStyle(fontSize: 16, height: 1.6),
                        ),
                      ),

                      // AI Insights (Enhanced with all details)
                      if (entry.hasInsights && entry.insight != null)
                        _buildEnhancedInsightsSection(entry.insight!),

                      // Affirmations
                      _buildAffirmationsSection(entry.affirmations),

                      // Gratitude
                      _buildGratitudeSection(entry.gratitude),

                      // Priorities
                      _buildPrioritiesSection(entry.priorities),

                      // Meals
                      _buildMealsSection(entry.meals),

                      // Self-Care
                      _buildSelfCareSection(entry.selfCare),

                      // Tomorrow Notes
                      _buildTomorrowNotesSection(entry.tomorrowNotes),

                      // Metadata
                      _buildMetadataSection(entry),

                      const SizedBox(height: 24),
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

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildEnhancedInsightsSection(HistoryDailyInsight insight) {
    final insightDetails = insight.insightDetails;
    final sentimentLabel = insight.sentimentLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.purple.shade100.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sentiment badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade500],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (sentimentLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getSentimentColor(sentimentLabel).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getSentimentColor(
                        sentimentLabel,
                      ).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getSentimentColor(sentimentLabel),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sentimentLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getSentimentColor(sentimentLabel),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Insight Text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              insight.insightText,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Structured Details
          if (insightDetails != null) ...[
            const SizedBox(height: 20),
            if (insightDetails.whatWentWell != null) ...[
              _buildInsightDetailItem(
                Icons.thumb_up,
                'What Went Well',
                insightDetails.whatWentWell!,
                Colors.green,
              ),
              const SizedBox(height: 12),
            ],
            if (insightDetails.progressArea != null) ...[
              _buildInsightDetailItem(
                Icons.trending_up,
                'Progress Area',
                insightDetails.progressArea!,
                Colors.blue,
              ),
              const SizedBox(height: 12),
            ],
            if (insightDetails.selfCareBalance != null) ...[
              _buildInsightDetailItem(
                Icons.spa,
                'Self-Care Balance',
                insightDetails.selfCareBalance!,
                Colors.teal,
              ),
              const SizedBox(height: 12),
            ],
            if (insightDetails.emotionalPattern != null)
              _buildInsightDetailItem(
                Icons.psychology,
                'Emotional Pattern',
                insightDetails.emotionalPattern!,
                Colors.orange,
              ),
          ],

          // Topics
          if (insight.topics.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Topics',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insight.topics.map((topic) {
                return Chip(
                  label: Text(topic),
                  backgroundColor: Colors.purple.shade100,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightDetailItem(
    IconData icon,
    String title,
    String? content,
    Color color,
  ) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffirmationsSection(EntryAffirmations? affirmations) {
    if (affirmations == null || affirmations.affirmations.isEmpty) {
      return _buildEmptySection(
        'Affirmations',
        Icons.volunteer_activism,
        Colors.purple,
        'Start your day with positive affirmations! ✨\n\nAffirmations help set a positive tone and remind you of your strength and capabilities.',
      );
    }

    return _buildSection(
      'Affirmations',
      Icons.volunteer_activism,
      Colors.purple,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: affirmations.affirmations.map((affirmation) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: Colors.purple, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    affirmation.text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGratitudeSection(EntryGratitude? gratitude) {
    if (gratitude == null || gratitude.gratefulItems.isEmpty) {
      return _buildEmptySection(
        'Gratitude',
        Icons.favorite,
        Colors.red,
        'What are you grateful for today? 🙏\n\nPracticing gratitude helps shift your focus to the positive aspects of life and boosts your overall well-being.',
      );
    }

    return _buildSection(
      'Gratitude',
      Icons.favorite,
      Colors.red,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: gratitude.gratefulItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrioritiesSection(EntryPriorities? priorities) {
    if (priorities == null || priorities.priorities.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      'Priorities',
      Icons.flag,
      Colors.orange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: priorities.priorities.map((priority) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: Colors.orange, size: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    priority.text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealsSection(EntryMeals? meals) {
    final hasMeals =
        meals != null &&
        (meals.breakfast?.isNotEmpty == true ||
            meals.lunch?.isNotEmpty == true ||
            meals.dinner?.isNotEmpty == true);

    if (!hasMeals) {
      return _buildEmptySection(
        'Meals',
        Icons.restaurant,
        Colors.orange,
        'Track your meals to understand your nutrition patterns! 🍽️',
      );
    }

    return _buildSection(
      'Meals',
      Icons.restaurant,
      Colors.orange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meals.breakfast?.isNotEmpty == true)
            _buildMealItem('Breakfast', meals.breakfast!),
          if (meals.lunch?.isNotEmpty == true)
            _buildMealItem('Lunch', meals.lunch!),
          if (meals.dinner?.isNotEmpty == true)
            _buildMealItem('Dinner', meals.dinner!),
          if (meals.waterCups > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${meals.waterCups} cups of water',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealItem(String meal, String food) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$meal:',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(food, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Widget _buildSelfCareSection(EntrySelfCare? selfCare) {
    if (selfCare == null) {
      return _buildSection(
        'Self-Care',
        Icons.spa,
        Colors.teal,
        Text(
          'Take care of yourself! Every small act of self-care matters. 💫',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final items = [
      {
        'key': 'sleep',
        'label': 'Sleep',
        'icon': Icons.bedtime,
        'value': selfCare.sleep,
      },
      {
        'key': 'getUpEarly',
        'label': 'Got up early',
        'icon': Icons.wb_sunny,
        'value': selfCare.getUpEarly,
      },
      {
        'key': 'freshAir',
        'label': 'Fresh air',
        'icon': Icons.air,
        'value': selfCare.freshAir,
      },
      {
        'key': 'learnNew',
        'label': 'Learned something new',
        'icon': Icons.school,
        'value': selfCare.learnNew,
      },
      {
        'key': 'balancedDiet',
        'label': 'Balanced diet',
        'icon': Icons.restaurant_menu,
        'value': selfCare.balancedDiet,
      },
      {
        'key': 'podcast',
        'label': 'Podcast',
        'icon': Icons.headphones,
        'value': selfCare.podcast,
      },
      {
        'key': 'meMoment',
        'label': 'Me moment',
        'icon': Icons.self_improvement,
        'value': selfCare.meMoment,
      },
      {
        'key': 'hydrated',
        'label': 'Hydrated',
        'icon': Icons.water_drop,
        'value': selfCare.hydrated,
      },
      {
        'key': 'readBook',
        'label': 'Read book',
        'icon': Icons.menu_book,
        'value': selfCare.readBook,
      },
      {
        'key': 'exercise',
        'label': 'Exercise',
        'icon': Icons.fitness_center,
        'value': selfCare.exercise,
      },
    ];

    final completed = items.where((item) => item['value'] == true).toList();

    return _buildSection(
      'Self-Care',
      Icons.spa,
      Colors.teal,
      completed.isEmpty
          ? Text(
              'Take care of yourself! Every small act of self-care matters. 💫',
              style: TextStyle(color: Colors.grey.shade600),
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: completed.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item['label'] as String,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEmptySection(
    String title,
    IconData icon,
    Color color,
    String message,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTomorrowNotesSection(EntryTomorrowNotes? tomorrowNotes) {
    if (tomorrowNotes == null || tomorrowNotes.tomorrowNotes.isEmpty) {
      return _buildEmptySection(
        'Tomorrow\'s Notes',
        Icons.calendar_today,
        Colors.indigo,
        'Plan ahead for tomorrow! 📅\n\nSetting intentions for the next day helps you stay organized and focused.',
      );
    }

    return _buildSection(
      'Tomorrow\'s Notes',
      Icons.calendar_today,
      Colors.indigo,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tomorrowNotes.tomorrowNotes.map((note) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: Colors.indigo, size: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    note.text,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetadataSection(HistoryEntry entry) {
    final isEdited = entry.entry.updatedAt.isAfter(
      entry.entry.createdAt.add(const Duration(seconds: 1)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metadata',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${DateFormat('MMM d, y • h:mm a').format(entry.entry.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (isEdited)
            Text(
              'Updated: ${DateFormat('MMM d, y • h:mm a').format(entry.entry.updatedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          // Source is not stored in Entry model, skip for now
        ],
      ),
    );
  }
}
