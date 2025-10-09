import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/app_drawer.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDate = DateTime.now();

  // Affirmation controllers
  final List<TextEditingController> _affirmationControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  // Diary controllers
  final _diaryController = TextEditingController();
  int _selectedMood = 3;

  // Priorities controllers
  final List<TextEditingController> _priorityControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  // Meals controllers
  final _breakfastController = TextEditingController();
  final _lunchController = TextEditingController();
  final _dinnerController = TextEditingController();
  int _waterCups = 4;

  // Gratitude controllers
  final List<TextEditingController> _gratitudeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  // Self-care checkboxes
  final Map<String, bool> _selfCare = {
    'Sleep': false,
    'Get up early': false,
    'Fresh air': false,
    'Learn new': false,
    'Balanced diet': false,
    'Podcast': false,
    'Me moment': false,
    'Hydrated': false,
    'Read book': false,
    'Exercise': false,
  };

  // Tomorrow notes controllers
  final List<TextEditingController> _tomorrowControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    for (var controller in _affirmationControllers) {
      controller.dispose();
    }
    _diaryController.dispose();
    for (var controller in _priorityControllers) {
      controller.dispose();
    }
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    for (var controller in _gratitudeControllers) {
      controller.dispose();
    }
    for (var controller in _tomorrowControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Entry')),
      drawer: const AppDrawer(currentRoute: 'diary'),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 16 : 10,
              vertical: isTablet ? 10 : 8,
            ),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                  },
                ),
                Flexible(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Text(
                        DateFormat('EEE, MMM d, y').format(_selectedDate),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed:
                      _selectedDate.isBefore(
                        DateTime.now().subtract(const Duration(days: 1)),
                      )
                      ? () {
                          setState(() {
                            _selectedDate = _selectedDate.add(
                              const Duration(days: 1),
                            );
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),

          // Single scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 800 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Diary Entry - Always visible
                    _buildDiarySection(context),
                    const SizedBox(height: 8),

                    // Mood Check - Always visible
                    _buildMoodSection(context),
                    const SizedBox(height: 8),

                    // Collapsible sections
                    _buildMorningRitualsSection(context),
                    const SizedBox(height: 6),

                    _buildWellnessSection(context),
                    const SizedBox(height: 6),

                    _buildGratitudeSection(context),
                    const SizedBox(height: 65), // Space for FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Entry saved!')));
        },
        icon: const Icon(Icons.save),
        label: const Text('Save'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  // Main Diary Section - Always visible
  Widget _buildDiarySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Write Your Thoughts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _diaryController,
              decoration: const InputDecoration(
                hintText: 'Dear diary...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
              maxLines: 10,
              style: const TextStyle(height: 1.4, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Mood Section - Always visible
  Widget _buildMoodSection(BuildContext context) {
    final icons = [
      Icons.sentiment_very_dissatisfied,
      Icons.sentiment_dissatisfied,
      Icons.sentiment_neutral,
      Icons.sentiment_satisfied,
      Icons.sentiment_very_satisfied,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mood,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'How are you feeling?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final mood = index + 1;
                return InkWell(
                  onTap: () => setState(() => _selectedMood = mood),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedMood == mood
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedMood == mood
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      icons[index],
                      size: 26,
                      color: _selectedMood == mood
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Morning Rituals - Collapsible
  Widget _buildMorningRitualsSection(BuildContext context) {
    int filledCount =
        _affirmationControllers.where((c) => c.text.isNotEmpty).length +
        _priorityControllers.where((c) => c.text.isNotEmpty).length;
    int totalCount = 11; // 5 affirmations + 6 priorities

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.wb_sunny_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        title: Text(
          'Morning Rituals',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          'Affirmations & Priorities ($filledCount/$totalCount)',
          style: const TextStyle(fontSize: 12),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Affirmations',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List.generate(
                5,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _affirmationControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Affirmation ${index + 1}',
                      prefixIcon: const Icon(Icons.favorite_border, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                    maxLength: index == 0 ? 80 : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                'Today\'s Priorities',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List.generate(
                6,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _priorityControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Priority ${index + 1}',
                      prefixIcon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Wellness Section - Collapsible
  Widget _buildWellnessSection(BuildContext context) {
    int mealsFilled = [
      _breakfastController,
      _lunchController,
      _dinnerController,
    ].where((c) => c.text.isNotEmpty).length;
    int selfCareCount = _selfCare.values.where((v) => v).length;
    int totalItems = 13; // 3 meals + 10 self-care

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.spa_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        title: Text(
          'Wellness Tracker',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          'Meals, Water & Self-Care (${mealsFilled + selfCareCount}/$totalItems)',
          style: const TextStyle(fontSize: 12),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What did you eat?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _breakfastController,
                decoration: const InputDecoration(
                  labelText: 'Breakfast',
                  prefixIcon: Icon(Icons.free_breakfast, size: 18),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lunchController,
                decoration: const InputDecoration(
                  labelText: 'Lunch',
                  prefixIcon: Icon(Icons.lunch_dining, size: 18),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dinnerController,
                decoration: const InputDecoration(
                  labelText: 'Dinner',
                  prefixIcon: Icon(Icons.dinner_dining, size: 18),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.water_drop, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Water: $_waterCups/8 cups',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              Slider(
                value: _waterCups.toDouble(),
                min: 0,
                max: 8,
                divisions: 8,
                label: '$_waterCups cups',
                onChanged: (value) =>
                    setState(() => _waterCups = value.toInt()),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                'Self-Care Checklist',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selfCare.keys.map((key) {
                  return FilterChip(
                    label: Text(key, style: const TextStyle(fontSize: 12)),
                    selected: _selfCare[key]!,
                    onSelected: (value) {
                      setState(() => _selfCare[key] = value);
                    },
                    selectedColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Gratitude & Reflection - Collapsible
  Widget _buildGratitudeSection(BuildContext context) {
    int gratitudeFilled = _gratitudeControllers
        .where((c) => c.text.isNotEmpty)
        .length;
    int tomorrowFilled = _tomorrowControllers
        .where((c) => c.text.isNotEmpty)
        .length;
    int totalCount = 10; // 6 gratitude + 4 tomorrow notes

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.auto_awesome_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        title: Text(
          'Gratitude & Reflection',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          'What matters most (${gratitudeFilled + tomorrowFilled}/$totalCount)',
          style: const TextStyle(fontSize: 12),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you grateful for?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List.generate(
                6,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _gratitudeControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Gratitude ${index + 1}',
                      prefixIcon: const Icon(
                        Icons.emoji_emotions_outlined,
                        size: 18,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                'Notes for Tomorrow',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    controller: _tomorrowControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Note ${index + 1}',
                      prefixIcon: const Icon(Icons.note_outlined, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
