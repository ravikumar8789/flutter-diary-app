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
  String _viewMode = 'list';
  String _filterTag = 'All';
  String? _selectedMood;
  String? _selectedSentiment;
  bool _hasInsightsOnly = false;
  String? _completionFilter;

  // Enhanced mock data with all fields
  late final List<Map<String, dynamic>> _mockEntries;

  @override
  void initState() {
    super.initState();
    _mockEntries = _generateMockEntries();
  }

  List<Map<String, dynamic>> _generateMockEntries() {
    final now = DateTime.now();
    final entries = <Map<String, dynamic>>[];

    // Generate entries for last 4 months
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final mood = (i % 5) + 1;
      final hasInsights = i % 3 != 0; // 66% have insights
      final sentiment = mood >= 4
          ? 'positive'
          : (mood == 3 ? 'neutral' : 'negative');

      final diaryText = _generateDiaryText(i);
      entries.add({
        'id': 'entry_$i',
        'date': date,
        'mood': mood,
        'diaryText': diaryText,
        'preview': diaryText.length > 100
            ? diaryText.substring(0, 100) + '...'
            : diaryText,
        'tags': _generateTags(i),
        'wordCount': _generateDiaryText(i).split(' ').length,
        'hasInsights': hasInsights,
        'sentiment': sentiment,
        'insights': hasInsights
            ? {
                'summary':
                    'A reflective day with moments of clarity and growth.',
                'sentimentLabel': sentiment,
                'sentimentScore': mood >= 4 ? 0.8 : (mood == 3 ? 0.5 : 0.3),
                'topics': ['Reflection', 'Growth', 'Mindfulness'],
                'insightText':
                    'Today showed progress in your wellness journey. Keep nurturing these positive patterns.',
              }
            : null,
        'completion': {
          'hasAffirmations': i % 2 == 0,
          'hasGratitude': i % 3 != 0,
          'selfCareCount': (i % 11),
          'hasMeals': i % 4 != 0,
          'waterCups': (i % 9),
        },
        'stats': {
          'selfCareCount': (i % 11),
          'waterCups': (i % 9),
          'mealsLogged': i % 4 != 0 ? 2 : 0,
        },
        'affirmations': i % 2 == 0
            ? [
                'I am capable of achieving my goals',
                'Today is a fresh start',
                'I choose to focus on the positive',
              ]
            : [],
        'gratitude': i % 3 != 0
            ? ['Family support', 'Beautiful weather', 'Good health']
            : [],
        'priorities': ['Complete project', 'Exercise', 'Read for 30 minutes'],
        'meals': {
          'breakfast': i % 4 != 0 ? 'Oatmeal with fruits' : null,
          'lunch': i % 4 != 0 ? 'Salad and soup' : null,
          'dinner': null,
        },
        'selfCare': {
          'sleep': i % 2 == 0,
          'exercise': i % 3 == 0,
          'freshAir': i % 2 != 0,
          'learnNew': i % 4 == 0,
          'balancedDiet': i % 3 != 0,
          'podcast': i % 5 == 0,
          'meMoment': i % 2 == 0,
          'hydrated': i % 3 != 0,
          'readBook': i % 4 == 0,
          'getUpEarly': i % 3 == 0,
        },
        'createdAt': date,
        'updatedAt': i % 5 == 0 ? date.add(Duration(hours: 2)) : date,
        'isEdited': i % 5 == 0,
        'source': 'mobile',
      });
    }

    return entries;
  }

  String _generateDiaryText(int index) {
    final texts = [
      'Today was amazing! I finally completed my project and felt incredibly proud of the progress I\'ve made. The sense of accomplishment is truly rewarding.',
      'Had a peaceful day. Spent time with family and felt grateful for the little things in life. Sometimes the simplest moments bring the most joy.',
      'Feeling neutral today. Just going through the motions and trying to stay present. Some days are like that, and that\'s okay.',
      'Went for a morning walk. The fresh air really helped clear my mind and set a positive tone for the day. Nature has a way of grounding us.',
      'Best day of the week! Everything just clicked and I felt in flow. These moments remind me why I keep pushing forward.',
      'Reflected on my goals today. Realized I\'ve come further than I thought. Progress isn\'t always linear, but it\'s happening.',
      'Challenging day, but I learned a lot. Sometimes difficulties teach us the most valuable lessons about ourselves.',
      'Practiced mindfulness and felt more centered. Taking time for myself is becoming a priority, and I can feel the difference.',
      'Had a great conversation with a friend. Connection and support mean everything, especially during busy times.',
      'Focused on self-care today. Sometimes we need to slow down to speed up. Rest is productive too.',
    ];
    return texts[index % texts.length];
  }

  List<String> _generateTags(int index) {
    final tagSets = [
      ['Work', 'Achievement'],
      ['Family', 'Gratitude'],
      ['Reflection'],
      ['Health', 'Self-Care'],
      ['Goals', 'Gratitude'],
      ['Growth', 'Learning'],
      ['Challenge', 'Resilience'],
      ['Mindfulness', 'Wellness'],
      ['Connection', 'Friendship'],
      ['Self-Care', 'Rest'],
    ];
    return tagSets[index % tagSets.length];
  }

  List<Map<String, dynamic>> get _filteredEntries {
    var entries = _mockEntries;

    if (_filterTag != 'All') {
      entries = entries
          .where((e) => (e['tags'] as List).contains(_filterTag))
          .toList();
    }

    if (_selectedMood != null) {
      entries = entries
          .where((e) => e['mood'].toString() == _selectedMood)
          .toList();
    }

    if (_selectedSentiment != null) {
      entries = entries
          .where((e) => e['sentiment'] == _selectedSentiment)
          .toList();
    }

    if (_hasInsightsOnly) {
      entries = entries.where((e) => e['hasInsights'] == true).toList();
    }

    if (_completionFilter == 'complete') {
      entries = entries.where((e) {
        final c = e['completion'] as Map;
        return c['hasAffirmations'] &&
            c['hasGratitude'] &&
            c['selfCareCount'] >= 7;
      }).toList();
    } else if (_completionFilter == 'incomplete') {
      entries = entries.where((e) {
        final c = e['completion'] as Map;
        return !c['hasAffirmations'] ||
            !c['hasGratitude'] ||
            c['selfCareCount'] < 5;
      }).toList();
    }

    return entries;
  }

  Map<String, List<Map<String, dynamic>>> get _groupedEntries {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in _filteredEntries) {
      final date = entry['date'] as DateTime;
      final key = DateFormat('MMMM yyyy').format(date);
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  List<String> get _uniqueTags {
    final tags = <String>{};
    for (final entry in _mockEntries) {
      tags.addAll((entry['tags'] as List<String>));
    }
    return tags.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
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
                    _buildFilterChip('All', Colors.blue),
                    const SizedBox(width: 8),
                    ..._uniqueTags.map(
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
              child: _viewMode == 'list'
                  ? _buildListView(isTablet)
                  : _buildCalendarView(isTablet),
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

  Widget _buildListView(bool isTablet) {
    final grouped = _groupedEntries;
    if (grouped.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 32 : 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
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

  Widget _buildEntryCard(Map<String, dynamic> entry, bool isTablet) {
    final mood = entry['mood'] as int;
    final hasInsights = entry['hasInsights'] as bool;
    final sentiment = entry['sentiment'] as String;
    final wordCount = entry['wordCount'] as int;
    final completion = entry['completion'] as Map;
    final stats = entry['stats'] as Map;
    final isEdited = entry['isEdited'] as bool;

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
              padding: const EdgeInsets.all(20),
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
                              ).format(entry['date']),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isEdited) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edited ${_getTimeAgo(entry['updatedAt'])}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (hasInsights)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(6),
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
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          _buildMoodIcon(mood),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Preview text
                  Text(
                    entry['preview'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Quick stats row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatChip(
                        Icons.text_fields,
                        '$wordCount words',
                        Colors.blue,
                      ),
                      if (stats['selfCareCount'] > 0)
                        _buildStatChip(
                          Icons.favorite,
                          '${stats['selfCareCount']}/10 self-care',
                          Colors.pink,
                        ),
                      if (stats['waterCups'] > 0)
                        _buildStatChip(
                          Icons.water_drop,
                          '${stats['waterCups']} cups',
                          Colors.cyan,
                        ),
                      if (stats['mealsLogged'] > 0)
                        _buildStatChip(
                          Icons.restaurant,
                          '${stats['mealsLogged']} meals',
                          Colors.orange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Completion indicators
                  Row(
                    children: [
                      if (completion['hasAffirmations'])
                        _buildCompletionIcon(
                          Icons.volunteer_activism,
                          Colors.purple,
                        ),
                      if (completion['hasGratitude'])
                        _buildCompletionIcon(Icons.favorite, Colors.red),
                      if (completion['selfCareCount'] >= 7)
                        _buildCompletionIcon(Icons.spa, Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  if ((entry['tags'] as List).isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (entry['tags'] as List<String>).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getTagColor(tag).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getTagColor(tag).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionIcon(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: color),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[mood - 1], colors[mood - 1].withOpacity(0.7)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors[mood - 1].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icons[mood - 1], color: Colors.white, size: 24),
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

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
  }

  Widget _buildCalendarView(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Calendar view coming soon',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'View your entries in a beautiful calendar format',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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

  void _showEntryDetail(Map<String, dynamic> entry) {
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
                                  ).format(entry['date']),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (entry['isEdited'] as bool) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Edited ${_getTimeAgo(entry['updatedAt'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _buildMoodIcon(entry['mood']),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Full diary text
                      _buildSection(
                        'Diary Entry',
                        Icons.book,
                        Colors.blue,
                        Text(
                          entry['diaryText'],
                          style: const TextStyle(fontSize: 16, height: 1.6),
                        ),
                      ),

                      // AI Insights
                      if (entry['hasInsights'] && entry['insights'] != null)
                        _buildInsightsSection(entry['insights'] as Map),

                      // Affirmations
                      _buildAffirmationsSection(entry['affirmations'] as List),

                      // Gratitude
                      _buildGratitudeSection(entry['gratitude'] as List),

                      // Priorities
                      _buildPrioritiesSection(entry['priorities'] as List),

                      // Meals
                      _buildMealsSection(entry['meals'] as Map),

                      // Self-Care
                      _buildSelfCareSection(entry['selfCare'] as Map),

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

  Widget _buildInsightsSection(Map insights) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade50,
            Colors.purple.shade100.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const Text(
                'AI Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insights['insightText'] ?? insights['summary'],
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          if (insights['topics'] != null &&
              (insights['topics'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: (insights['topics'] as List<String>).map((topic) {
                return Chip(
                  label: Text(topic),
                  backgroundColor: Colors.purple.shade100,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAffirmationsSection(List affirmations) {
    if (affirmations.isEmpty) {
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
        children: affirmations.map((affirmation) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: Colors.purple, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    affirmation,
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

  Widget _buildGratitudeSection(List gratitude) {
    if (gratitude.isEmpty) {
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
        children: gratitude.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
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

  Widget _buildPrioritiesSection(List priorities) {
    return _buildSection(
      'Priorities',
      Icons.flag,
      Colors.orange,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: priorities.map((priority) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: Colors.orange, size: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    priority,
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

  Widget _buildMealsSection(Map meals) {
    final hasMeals =
        meals['breakfast'] != null ||
        meals['lunch'] != null ||
        meals['dinner'] != null;

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
          if (meals['breakfast'] != null)
            _buildMealItem('Breakfast', meals['breakfast']),
          if (meals['lunch'] != null) _buildMealItem('Lunch', meals['lunch']),
          if (meals['dinner'] != null)
            _buildMealItem('Dinner', meals['dinner']),
          if (meals['waterCups'] != null && meals['waterCups'] > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${meals['waterCups']} cups of water',
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

  Widget _buildSelfCareSection(Map selfCare) {
    final items = [
      {'key': 'sleep', 'label': 'Sleep', 'icon': Icons.bedtime},
      {'key': 'getUpEarly', 'label': 'Got up early', 'icon': Icons.wb_sunny},
      {'key': 'freshAir', 'label': 'Fresh air', 'icon': Icons.air},
      {
        'key': 'learnNew',
        'label': 'Learned something new',
        'icon': Icons.school,
      },
      {
        'key': 'balancedDiet',
        'label': 'Balanced diet',
        'icon': Icons.restaurant_menu,
      },
      {'key': 'podcast', 'label': 'Podcast', 'icon': Icons.headphones},
      {'key': 'meMoment', 'label': 'Me moment', 'icon': Icons.self_improvement},
      {'key': 'hydrated', 'label': 'Hydrated', 'icon': Icons.water_drop},
      {'key': 'readBook', 'label': 'Read book', 'icon': Icons.menu_book},
      {'key': 'exercise', 'label': 'Exercise', 'icon': Icons.fitness_center},
    ];

    final completed = items
        .where((item) => selfCare[item['key']] == true)
        .toList();

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

  Widget _buildMetadataSection(Map<String, dynamic> entry) {
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
            'Created: ${DateFormat('MMM d, y • h:mm a').format(entry['createdAt'])}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (entry['isEdited'])
            Text(
              'Updated: ${DateFormat('MMM d, y • h:mm a').format(entry['updatedAt'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          Text(
            'Source: ${entry['source']}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
