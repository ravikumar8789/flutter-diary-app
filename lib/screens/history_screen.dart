import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../providers/history_provider.dart';
import '../models/history_entry_model.dart';
import '../models/entry_models.dart';
import '../services/history_service.dart';
import '../providers/data_providers.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';
import '../ui/responsive/responsive_wrap.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _viewMode = 'list';
  String? _selectedMood; // Only mood filter now

  // Cache variables for optimizations
  List<String>? _cachedSortedKeys;
  List<HistoryEntry>? _cachedEntries;
  Map<int, int>? _cachedMoodCounts;
  Map<String, int>? _cachedMoodMap;

  @override
  void initState() {
    super.initState();
    // Load list data (2 months) and calendar mood data in parallel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).loadCurrentMonth();
      ref.read(historyProvider.notifier).loadCalendarMoodData();
    });
  }

  // Get filtered entries from provider (mood filter only)
  List<HistoryEntry> get _filteredEntries {
    final historyState = ref.read(historyProvider);
    var entries = historyState.entries;

    // Apply mood filter only
    if (_selectedMood != null) {
      entries = entries
          .where((e) => e.entry.moodScore?.toString() == _selectedMood)
          .toList();
    }

    return entries;
  }

  // Calculate mood counts from moodMap (all entries, not just loaded)
  Map<int, int> get _moodCounts {
    final historyState = ref.read(historyProvider);
    final moodMap = historyState.moodMap; // Already has ALL mood data

    // Cache optimization: recalculate only if moodMap changed
    if (_cachedMoodMap != moodMap) {
      final counts = <int, int>{};
      for (var moodScore in moodMap.values) {
        counts[moodScore] = (counts[moodScore] ?? 0) + 1;
      }
      _cachedMoodCounts = counts;
      _cachedMoodMap = moodMap;
    }

    return _cachedMoodCounts ?? {};
  }

  // Group entries by month
  Map<String, List<HistoryEntry>> get _groupedEntries {
    final grouped = <String, List<HistoryEntry>>{};
    for (final entry in _filteredEntries) {
      final key = DateFormat('MMMM yyyy').format(entry.entry.entryDate);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    // Sort entries within each month (newest first)
    for (var monthKey in grouped.keys) {
      grouped[monthKey]!.sort(
        (a, b) => b.entry.entryDate.compareTo(a.entry.entryDate),
      );
    }

    return grouped;
  }

  // Get sorted month keys (newest first) - cached for performance
  List<String> get _sortedMonthKeys {
    final currentEntries = _filteredEntries;

    // Cache optimization: recalculate only if entries changed
    if (_cachedEntries != currentEntries) {
      final grouped = _groupedEntries;
      final monthKeys = grouped.keys.toList();

      // Sort by DateTime (newest first)
      monthKeys.sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA); // Descending order
      });

      _cachedSortedKeys = monthKeys;
      _cachedEntries = currentEntries;
    }

    return _cachedSortedKeys ?? [];
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

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);
    final info = ResponsiveInfo.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'History',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          // View mode toggle (List/Calendar)
          IconButton(
            icon: Icon(_viewMode == 'list' ? Icons.calendar_month : Icons.list),
            tooltip: _viewMode == 'list'
                ? 'Switch to Calendar'
                : 'Switch to List',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'list' ? 'calendar' : 'list';
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header with entry count (InnerGlow Style)
            if (_viewMode == 'list') _buildHeader(context, historyState, info),

            // Mood filter chips (only in list mode)
            if (_viewMode == 'list') _buildMoodChips(info),

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
                  ? _buildListView(info, historyState)
                  : _buildCalendarView(info, historyState),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          AppBottomNavigationBar.navigateToScreen(context, index);
        },
      ),
    );
  }

  /// Build header with entry count (InnerGlow Style)
  Widget _buildHeader(
    BuildContext context,
    HistoryState historyState,
    ResponsiveInfo info,
  ) {
    // Use moodMap.length for accurate total count (all entries, not just loaded)
    final totalCount = historyState.moodMap.length;
    final horizontalPadding = ResponsiveTokens.screenPaddingHorizontal(info);
    final verticalPadding = ResponsiveTokens.spacingM(info);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: ResponsiveWrapRow(
        info: info,
        rowMainAxisAlignment: MainAxisAlignment.spaceBetween,
        wrapAlignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            '$totalCount ${totalCount == 1 ? 'entry' : 'entries'}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (_selectedMood != null)
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedMood = null);
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear filter'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveTokens.spacingM(info),
                  vertical: ResponsiveTokens.spacingS(info),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build compact mood filter chips
  Widget _buildMoodChips(ResponsiveInfo info) {
    final moodCounts = _moodCounts;
    final totalCount = ref.read(historyProvider).moodMap.length; // All entries
    final spacingS = ResponsiveTokens.spacingS(info);
    final spacingM = ResponsiveTokens.spacingM(info);

    // Mood emojis and colors
    final moodData = [
      {'emoji': '😢', 'mood': 1, 'color': Colors.red},
      {'emoji': '😟', 'mood': 2, 'color': Colors.orange},
      {'emoji': '😐', 'mood': 3, 'color': Colors.amber},
      {'emoji': '😊', 'mood': 4, 'color': Colors.lightGreen},
      {'emoji': '😄', 'mood': 5, 'color': Colors.green},
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: spacingM,
        horizontal: ResponsiveTokens.screenPaddingHorizontal(info),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
      ),
      child: info.isCompact
          ? Wrap(
              spacing: spacingS,
              runSpacing: spacingS,
              children: [
                _buildMoodChip(
                  label: 'All',
                  count: totalCount,
                  isSelected: _selectedMood == null,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  onTap: () {
                    setState(() => _selectedMood = null);
                  },
                ),
                ...moodData.map((mood) {
                  final moodNum = mood['mood'] as int;
                  final count = moodCounts[moodNum] ?? 0;
                  return _buildMoodChip(
                    label: mood['emoji'] as String,
                    count: count,
                    isSelected: _selectedMood == moodNum.toString(),
                    color: mood['color'] as Color,
                    onTap: () {
                      setState(() {
                        _selectedMood = count > 0 ? moodNum.toString() : null;
                      });
                    },
                  );
                }),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // All chip
                Expanded(
                  child: _buildMoodChip(
                    label: 'All',
                    count: totalCount,
                    isSelected: _selectedMood == null,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onTap: () {
                      setState(() => _selectedMood = null);
                    },
                  ),
                ),
                SizedBox(width: spacingS),
                // Mood chips (1-5)
                ...moodData.map((mood) {
                  final moodNum = mood['mood'] as int;
                  final count = moodCounts[moodNum] ?? 0;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: spacingS * 0.5),
                      child: _buildMoodChip(
                        label: mood['emoji'] as String,
                        count: count,
                        isSelected: _selectedMood == moodNum.toString(),
                        color: mood['color'] as Color,
                        onTap: () {
                          setState(() {
                            _selectedMood = count > 0
                                ? moodNum.toString()
                                : null;
                          });
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  /// Build individual mood chip
  Widget _buildMoodChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.6) : Colors.transparent,
            width: isSelected ? 1.5 : 0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? _darkenColorForText(color)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _darkenColorForText(Color color) {
    // Darken the color for text readability
    return Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }

  Widget _buildListView(ResponsiveInfo info, HistoryState historyState) {
    final grouped = _groupedEntries;
    final sortedKeys = _sortedMonthKeys;

    if (grouped.isEmpty && !historyState.isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveTokens.screenPaddingHorizontal(info),
        vertical: ResponsiveTokens.spacingM(info),
      ),
      itemCount: sortedKeys.length + (_availableMonths.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Load more button at the end
        if (index == sortedKeys.length && _availableMonths.isNotEmpty) {
          return _buildLoadMoreButton(historyState);
        }
        final monthKey = sortedKeys[index];
        final entries = grouped[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header with gradient
            Padding(
              padding: EdgeInsets.only(
                bottom: ResponsiveTokens.spacingM(info),
                top: index == 0 ? 0 : ResponsiveTokens.spacingL(info),
              ),
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
                padding: EdgeInsets.only(
                  bottom: ResponsiveTokens.spacingM(info),
                ),
                child: _buildEntryCard(entry, info),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreButton(HistoryState historyState) {
    final loadedMonths = historyState.loadedMonths;
    final allMonths = historyState.monthsWithEntries;

    if (allMonths.isEmpty) {
      return const SizedBox.shrink();
    }

    String nextMonthKey;

    // Find next chronological month to load (handles gaps in data)
    if (loadedMonths.isNotEmpty) {
      // Convert loaded months to DateTime and find newest loaded
      final loadedMonthDates = loadedMonths.map((key) {
        final parts = key.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      }).toList()..sort((a, b) => b.compareTo(a)); // Sort newest first

      final newestLoadedMonth = loadedMonthDates.first;

      // Get all unloaded months as DateTime objects
      final unloadedMonths = allMonths
          .where((m) => !loadedMonths.contains(m))
          .map((key) {
            final parts = key.split('-');
            return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
          })
          .toList();

      if (unloadedMonths.isEmpty) {
        return const SizedBox.shrink();
      }

      // Find unloaded months that are before newest loaded month
      final validMonths = unloadedMonths
          .where((month) => month.isBefore(newestLoadedMonth))
          .toList();

      if (validMonths.isNotEmpty) {
        // Sort descending (newest first) and take closest to newest loaded
        validMonths.sort((a, b) => b.compareTo(a));
        final nextMonth = validMonths.first;
        nextMonthKey = DateFormat('yyyy-MM').format(nextMonth);
      } else {
        // No months before newest loaded - use oldest unloaded as fallback
        unloadedMonths.sort((a, b) => a.compareTo(b));
        final nextMonth = unloadedMonths.first;
        nextMonthKey = DateFormat('yyyy-MM').format(nextMonth);
      }
    } else {
      // No months loaded yet - shouldn't happen, but handle gracefully
      return const SizedBox.shrink();
    }

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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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

  Widget _buildEntryCard(HistoryEntry entry, ResponsiveInfo info) {
    final mood = entry.entry.moodScore ?? 3;
    final hasInsights = entry.hasInsights;
    final sentiment = entry.sentiment;
    final wordCount = entry.wordCount;
    final selfCareCount = entry.selfCareCount;
    final mealsCount = entry.mealsCount;
    final waterCups = entry.meals?.waterCups ?? 0;
    final cardPadding = ResponsiveTokens.spacingM(info);
    final previewFontSize = info.value(
      compact: 12.0,
      medium: 13.0,
      expanded: 14.0,
    );
    final colorScheme = Theme.of(context).colorScheme;

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
                  colorScheme.surface,
                  _getSentimentColor(context, sentiment).withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
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
                      fontSize: previewFontSize,
                      color: colorScheme.onSurfaceVariant,
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
    final emojis = ['😢', '😔', '😐', '😊', '😄'];
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
        color: colors[mood - 1].withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: colors[mood - 1].withOpacity(0.3), width: 2),
      ),
      child: Text(emojis[mood - 1], style: const TextStyle(fontSize: 24)),
    );
  }

  Color _getSentimentColor(BuildContext context, String sentiment) {
    switch (sentiment) {
      case 'positive':
        return Colors.green;
      case 'neutral':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case 'negative':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
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

  Widget _buildCalendarView(ResponsiveInfo info, HistoryState historyState) {
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
        horizontal: ResponsiveTokens.screenPaddingHorizontal(info),
        vertical: ResponsiveTokens.spacingM(info),
      ),
      itemCount: months.length,
      itemBuilder: (context, index) {
        return _buildMonthCalendar(months[index], info);
      },
    );
  }

  Widget _buildMonthCalendar(DateTime focusedDay, ResponsiveInfo info) {
    final firstDay = DateTime(focusedDay.year, focusedDay.month, 1);
    final lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final spacingM = ResponsiveTokens.spacingM(info);
    final spacingL = ResponsiveTokens.spacingL(info);
    final headerFontSize = info.value(
      compact: 18.0,
      medium: 20.0,
      expanded: 22.0,
    );
    final dayFontSize = info.value(compact: 12.0, medium: 14.0, expanded: 14.0);
    final dowFontSize = info.value(compact: 11.0, medium: 12.0, expanded: 12.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: spacingL),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
            padding: EdgeInsets.symmetric(
              vertical: spacingM,
              horizontal: spacingL,
            ),
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
                SizedBox(width: spacingM),
                Text(
                  DateFormat('MMMM yyyy').format(focusedDay),
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Calendar - disable internal gestures to let parent ListView scroll
          TableCalendar(
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: focusedDay,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.none,
            pageJumpingEnabled: false,
            pageAnimationEnabled: false,
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
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              defaultTextStyle: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: dayFontSize,
              ),
              todayDecoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.35),
                  width: 2,
                ),
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: dayFontSize,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.purple.shade300,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: dayFontSize,
              ),
              markerDecoration: const BoxDecoration(shape: BoxShape.circle),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: dowFontSize,
              ),
              weekendStyle: TextStyle(
                color: Colors.pink.shade400,
                fontWeight: FontWeight.bold,
                fontSize: dowFontSize,
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
    final info = ResponsiveInfo.of(context);
    final cellMargin = info.value(compact: 3.0, medium: 4.0, expanded: 4.0);
    final circleSize = info.value(compact: 30.0, medium: 36.0, expanded: 38.0);
    final fontSize = info.value(compact: 12.0, medium: 14.0, expanded: 14.0);
    final iconSize = info.value(compact: 8.0, medium: 10.0, expanded: 10.0);
    final colorScheme = Theme.of(context).colorScheme;
    // Use optimized mood lookup
    final moodNullable = _getMoodByDate(date);
    final hasEntry = moodNullable != null;
    final mood =
        moodNullable ?? 0; // Default value, won't be used if hasEntry is false

    return GestureDetector(
      onTap: () => _handleDateTap(date),
      child: Container(
        margin: EdgeInsets.all(cellMargin),
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
                width: circleSize,
                height: circleSize,
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
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? colorScheme.onPrimary
                    : isToday
                    ? colorScheme.primary
                    : hasEntry
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
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
                    size: iconSize,
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
    final info = ResponsiveInfo.of(context);
    final loadingHeightFactor = info.value(
      compact: 0.25,
      medium: 0.3,
      expanded: 0.35,
    );
    // Show loading bottom sheet immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          height: MediaQuery.of(context).size.height * loadingHeightFactor,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading entry...',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            initialChildSize: info.value(
              compact: 0.35,
              medium: 0.4,
              expanded: 0.45,
            ),
            maxChildSize: info.value(compact: 0.55, medium: 0.6, expanded: 0.7),
            minChildSize: info.value(
              compact: 0.25,
              medium: 0.3,
              expanded: 0.35,
            ),
            expand: false,
            builder: (context, scrollController) {
              final colorScheme = Theme.of(context).colorScheme;
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
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
                                    colorScheme.surfaceVariant,
                                    colorScheme.surface,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_note,
                                size: 48,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No entry for this date',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                'You haven\'t written an entry for ${DateFormat('MMMM d, y').format(date)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
          Icon(
            Icons.history,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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

  void _showEntryDetail(HistoryEntry entry) {
    final info = ResponsiveInfo.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: info.value(compact: 0.65, medium: 0.7, expanded: 0.8),
        maxChildSize: info.value(compact: 0.9, medium: 0.95, expanded: 0.98),
        minChildSize: info.value(compact: 0.45, medium: 0.5, expanded: 0.6),
        expand: false,
        builder: (context, scrollController) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.all(
                      ResponsiveTokens.spacingL(ResponsiveInfo.of(context)),
                    ),
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

                        // AI Insights (Expandable Card)
                        _buildExpandableInsightsCard(entry),

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
          );
        },
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

  /// Build expandable AI Insights card
  Widget _buildExpandableInsightsCard(HistoryEntry entry) {
    return _ExpandableInsightsCard(entryId: entry.entry.id);
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        color: Theme.of(context).colorScheme.surfaceVariant,
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Created: ${DateFormat('MMM d, y • h:mm a').format(entry.entry.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (isEdited)
            Text(
              'Updated: ${DateFormat('MMM d, y • h:mm a').format(entry.entry.updatedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          // Source is not stored in Entry model, skip for now
        ],
      ),
    );
  }
}

/// Expandable AI Insights Card Widget
class _ExpandableInsightsCard extends ConsumerStatefulWidget {
  final String entryId;

  const _ExpandableInsightsCard({required this.entryId});

  @override
  ConsumerState<_ExpandableInsightsCard> createState() =>
      _ExpandableInsightsCardState();
}

class _ExpandableInsightsCardState
    extends ConsumerState<_ExpandableInsightsCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isLoading = false;
  HistoryDailyInsight? _insight;
  late HistoryService _historyService;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize HistoryService with DataFetchService
    final dataFetchService = ref.read(dataFetchServiceProvider);
    _historyService = HistoryService(dataFetchService: dataFetchService);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpanded() async {
    if (!_isExpanded) {
      // Expanding - fetch insights
      setState(() {
        _isExpanded = true;
        _isLoading = true;
      });
      _animationController.forward();

      try {
        final insight = await _historyService.fetchInsightForEntry(
          widget.entryId,
        );
        setState(() {
          _insight = insight;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Collapsing
      setState(() {
        _isExpanded = false;
      });
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        children: [
          // Collapsed Header (Always Visible)
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade300,
                          Colors.purple.shade500,
                        ],
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: _isExpanded ? 20 : 0,
              ),
              child: _buildExpandedContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_insight == null) {
      return _buildEmptyState();
    }

    return _buildInsightsContent(_insight!);
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading insights...',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              size: 32,
              color: Colors.purple.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No AI Insights Available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Complete your daily affirmations and gratitude to unlock personalized AI insights about your day!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.purple.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI insights help you understand patterns, track progress, and discover meaningful connections in your journal entries.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade800,
                      height: 1.4,
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

  Widget _buildInsightsContent(HistoryDailyInsight insight) {
    final insightDetails = insight.insightDetails;
    final sentimentLabel = insight.sentimentLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sentiment Badge
        if (sentimentLabel != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getSentimentColor(sentimentLabel).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getSentimentColor(sentimentLabel).withOpacity(0.4),
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
          ),
          const SizedBox(height: 16),
        ],

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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildInsightDetailItem(
    IconData icon,
    String title,
    String content,
    Color color,
  ) {
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _darkenColor(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _darkenColor(Color color) {
    // Darken the color by reducing brightness
    return Color.fromRGBO(
      (color.red * 0.7).round().clamp(0, 255),
      (color.green * 0.7).round().clamp(0, 255),
      (color.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }
}
