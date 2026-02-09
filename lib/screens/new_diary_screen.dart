import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../providers/entry_provider.dart';
import '../providers/sync_status_provider.dart';
import '../services/entry_service.dart';
import '../models/entry_models.dart';
import '../ui/responsive/responsive_body.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

class NewDiaryScreen extends ConsumerStatefulWidget {
  const NewDiaryScreen({super.key});

  @override
  ConsumerState<NewDiaryScreen> createState() => _NewDiaryScreenState();
}

class _NewDiaryScreenState extends ConsumerState<NewDiaryScreen>
    with TickerProviderStateMixin {
  // Diary text
  final TextEditingController _diaryController = TextEditingController();
  final FocusNode _diaryFocusNode = FocusNode();

  // Mood
  int _selectedMood = 3;

  // Morning Rituals - Affirmations & Priorities
  List<TextEditingController> _affirmationControllers = [];
  List<TextEditingController> _priorityControllers = [];
  late AnimationController _affirmationAnimationController;
  late AnimationController _priorityAnimationController;

  // Wellness - Self-Care, Water, Meals
  final Map<String, bool> _selfCare = {
    'sleep': false,
    'get_up_early': false,
    'fresh_air': false,
    'learn_new': false,
    'balanced_diet': false,
    'podcast': false,
    'me_moment': false,
    'hydrated': false,
    'read_book': false,
    'exercise': false,
  };
  int _waterCups = 0;
  final TextEditingController _breakfastController = TextEditingController();
  final TextEditingController _lunchController = TextEditingController();
  final TextEditingController _dinnerController = TextEditingController();

  // Gratitude & Tomorrow Notes
  List<TextEditingController> _gratitudeControllers = [];
  List<TextEditingController> _tomorrowControllers = [];
  late AnimationController _gratitudeAnimationController;
  late AnimationController _tomorrowAnimationController;

  bool _isInitialized = false;
  bool _isLoading = true;
  String? _userId; // Cached userId to avoid repeated Supabase calls

  @override
  void initState() {
    super.initState();
    // Get userId once at initialization
    _userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    _setupAnimations();
    _setupAutoSaveListeners();
    // Load entry data when screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntryData();
    });
  }

  void _setupAnimations() {
    _affirmationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _priorityAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _gratitudeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tomorrowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _setupAutoSaveListeners() {
    _diaryController.addListener(() => _onDiaryTextChanged());
    _breakfastController.addListener(() => _onMealsChanged());
    _lunchController.addListener(() => _onMealsChanged());
    _dinnerController.addListener(() => _onMealsChanged());
  }

  @override
  void dispose() {
    _diaryController.dispose();
    _diaryFocusNode.dispose();
    for (var controller in _affirmationControllers) {
      controller.dispose();
    }
    for (var controller in _priorityControllers) {
      controller.dispose();
    }
    for (var controller in _gratitudeControllers) {
      controller.dispose();
    }
    for (var controller in _tomorrowControllers) {
      controller.dispose();
    }
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _affirmationAnimationController.dispose();
    _priorityAnimationController.dispose();
    _gratitudeAnimationController.dispose();
    _tomorrowAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadEntryData() async {
    // Use LOCAL device date for querying (entry_date is just a date, no time)
    // This matches what the user sees on their device
    final currentDateLocal = DateTime.now();
    final currentDateLocalOnly = DateTime(currentDateLocal.year, currentDateLocal.month, currentDateLocal.day);
    print('🔍 DIARY DEBUG: Using local date: ${currentDateLocalOnly.toIso8601String().split('T')[0]}');
    print('🔍 DIARY DEBUG: Local timezone: ${currentDateLocal.timeZoneName}, UTC offset: ${currentDateLocal.timeZoneOffset}');

    if (_userId != null && !_isInitialized) {
      _isInitialized = true;
      setState(() => _isLoading = true);

      // Load entry data from service (includes all related data)
      // Use LOCAL date for querying (entry_date is stored as date only)
      final entryService = EntryService();
      final entryData = await entryService.loadEntryForDate(
        _userId!,
        currentDateLocalOnly, // Use local date (what user sees)
      );

      // Also load via provider for sync status (use local date)
      await ref.read(entryProvider.notifier).loadEntry(_userId!, currentDateLocalOnly);

      if (entryData != null) {
        // Load diary text
        _diaryController.text = entryData.entry.diaryText ?? '';

        // Load mood
        _selectedMood = entryData.entry.moodScore ?? 3;

        // Load affirmations
        _loadAffirmations(entryData.affirmations);

        // Load priorities
        _loadPriorities(entryData.priorities);

        // Load meals
        if (entryData.meals != null) {
          // Set water FIRST before setting controller text (which triggers auto-save)
          _waterCups = entryData.meals!.waterCups;
          _breakfastController.text = entryData.meals!.breakfast ?? '';
          _lunchController.text = entryData.meals!.lunch ?? '';
          _dinnerController.text = entryData.meals!.dinner ?? '';
        }

        // Load self-care
        if (entryData.selfCare != null) {
          _selfCare['sleep'] = entryData.selfCare!.sleep;
          _selfCare['get_up_early'] = entryData.selfCare!.getUpEarly;
          _selfCare['fresh_air'] = entryData.selfCare!.freshAir;
          _selfCare['learn_new'] = entryData.selfCare!.learnNew;
          _selfCare['balanced_diet'] = entryData.selfCare!.balancedDiet;
          _selfCare['podcast'] = entryData.selfCare!.podcast;
          _selfCare['me_moment'] = entryData.selfCare!.meMoment;
          _selfCare['hydrated'] = entryData.selfCare!.hydrated;
          _selfCare['read_book'] = entryData.selfCare!.readBook;
          _selfCare['exercise'] = entryData.selfCare!.exercise;
        }

        // Load gratitude
        _loadGratitude(entryData.gratitude);

        // Load tomorrow notes
        _loadTomorrowNotes(entryData.tomorrowNotes);
      }

      setState(() => _isLoading = false);
    }
  }

  void _loadAffirmations(EntryAffirmations? affirmations) {
    final texts = affirmations?.affirmations.map((a) => a.text).toList() ?? [];
    while (texts.length < 2) texts.add('');

    while (_affirmationControllers.length < texts.length) {
      final c = TextEditingController();
      c.addListener(() => _onAffirmationChanged());
      _affirmationControllers.add(c);
    }
    while (_affirmationControllers.length > texts.length) {
      _affirmationControllers.removeLast().dispose();
    }
    for (int i = 0; i < texts.length; i++) {
      _affirmationControllers[i].text = texts[i];
    }
  }

  void _loadPriorities(EntryPriorities? priorities) {
    final texts = priorities?.priorities.map((p) => p.text).toList() ?? [];
    while (texts.length < 2) texts.add('');

    while (_priorityControllers.length < texts.length) {
      final c = TextEditingController();
      c.addListener(() => _onPriorityChanged());
      _priorityControllers.add(c);
    }
    while (_priorityControllers.length > texts.length) {
      _priorityControllers.removeLast().dispose();
    }
    for (int i = 0; i < texts.length; i++) {
      _priorityControllers[i].text = texts[i];
    }
  }

  void _loadGratitude(EntryGratitude? gratitude) {
    final texts = gratitude?.gratefulItems.map((g) => g.text).toList() ?? [];
    while (texts.length < 2) texts.add('');

    while (_gratitudeControllers.length < texts.length) {
      final c = TextEditingController();
      c.addListener(() => _onGratitudeChanged());
      _gratitudeControllers.add(c);
    }
    while (_gratitudeControllers.length > texts.length) {
      _gratitudeControllers.removeLast().dispose();
    }
    for (int i = 0; i < texts.length; i++) {
      _gratitudeControllers[i].text = texts[i];
    }
  }

  void _loadTomorrowNotes(EntryTomorrowNotes? tomorrowNotes) {
    final texts =
        tomorrowNotes?.tomorrowNotes.map((t) => t.text).toList() ?? [];
    while (texts.length < 2) texts.add('');

    while (_tomorrowControllers.length < texts.length) {
      final c = TextEditingController();
      c.addListener(() => _onTomorrowChanged());
      _tomorrowControllers.add(c);
    }
    while (_tomorrowControllers.length > texts.length) {
      _tomorrowControllers.removeLast().dispose();
    }
    for (int i = 0; i < texts.length; i++) {
      _tomorrowControllers[i].text = texts[i];
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStatusProvider);
    final info = ResponsiveInfo.of(context);
    final spacingL = ResponsiveTokens.spacingL(info);

    // Show loading state while entry data is being fetched
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your entry...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          // Sync status indicator (top right)
          _buildSyncStatusIcon(syncState),
        ],
      ),
      body: ResponsiveBody(
        useSafeArea: false,
        useScrollView: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood Selector (InnerGlow Style)
            _buildMoodSection(context),
            SizedBox(height: spacingL),

            // "What's on your mind?" Diary Text Area (InnerGlow Style)
            _buildDiaryTextSection(context),
            SizedBox(height: spacingL),

            // Morning Rituals Section (InnerGlow Style)
            _buildMorningRitualsSection(context),
            SizedBox(height: spacingL),

            // Self-Care Checklist Section (InnerGlow Style)
            _buildSelfCareSection(context),
            SizedBox(height: spacingL),

            // Water Intake Section (InnerGlow Style)
            _buildWaterIntakeSection(context),
            SizedBox(height: spacingL),

            // Meals Section (InnerGlow Style)
            _buildMealsSection(context),
            SizedBox(height: spacingL),

            // Gratitude Section (InnerGlow Style)
            _buildGratitudeSection(context),
            SizedBox(height: spacingL),

            // Notes for Tomorrow Section (InnerGlow Style)
            _buildTomorrowNotesSection(context),
            SizedBox(height: spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusIcon(SyncState syncState) {
    switch (syncState.status) {
      case SyncStatus.syncing:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case SyncStatus.saved:
        return Icon(Icons.cloud_done, color: Colors.green[600]);
      case SyncStatus.error:
        return Icon(Icons.cloud_off, color: Colors.red[600]);
      default:
        return const SizedBox.shrink();
    }
  }

  // InnerGlow Design Builder Methods

  Widget _buildMoodSection(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    final spacingM = ResponsiveTokens.spacingM(info);
    final spacingS = ResponsiveTokens.spacingS(info);
    final moodSize = info.value(compact: 48.0, medium: 56.0, expanded: 60.0);
    final emojiSize = info.value(compact: 22.0, medium: 28.0, expanded: 30.0);
    final moodTiles = List.generate(5, (index) {
      final mood = index + 1;
      final emojis = ['😢', '😔', '😐', '😊', '😄'];
      final isSelected = _selectedMood == mood;
      return GestureDetector(
        onTap: () {
          setState(() => _selectedMood = mood);
          _onMoodChanged(mood);
        },
        child: Container(
          width: moodSize,
          height: moodSize,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              emojis[index],
              style: TextStyle(fontSize: emojiSize),
            ),
          ),
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.mood,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'How are you feeling today?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: spacingM),
        info.isCompact
            ? Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: spacingS,
                runSpacing: spacingS,
                children: moodTiles,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: moodTiles,
              ),
      ],
    );
  }

  Widget _buildDiaryTextSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'What\'s on your mind?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: TextField(
            controller: _diaryController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Write about your day, thoughts, feelings...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMorningRitualsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.wb_sunny,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Morning Rituals',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Affirmations Subsection
        _buildSubsection(
          context,
          'Affirmations',
          Icons.auto_awesome,
          _affirmationControllers,
          'I am...',
          _addAffirmationField,
          _removeAffirmationField,
        ),
        const SizedBox(height: 16),
        // Priorities Subsection
        _buildSubsection(
          context,
          'Today\'s Priorities',
          Icons.flag,
          _priorityControllers,
          'My priority is...',
          _addPriorityField,
          _removePriorityField,
        ),
      ],
    );
  }

  Widget _buildSubsection(
    BuildContext context,
    String title,
    IconData icon,
    List<TextEditingController> controllers,
    String hint,
    VoidCallback onAdd,
    Function(int) onRemove,
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
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...controllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: hint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    if (controllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => onRemove(index),
                        color: Theme.of(context).colorScheme.error,
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfCareSection(BuildContext context) {
    final completedCount = _selfCare.values.where((v) => v).length;
    final selfCareItems = [
      {'key': 'sleep', 'label': '😴 Sleep well', 'icon': Icons.bedtime},
      {
        'key': 'get_up_early',
        'label': '🌅 Get up early',
        'icon': Icons.wb_sunny,
      },
      {'key': 'fresh_air', 'label': '🍃 Fresh air', 'icon': Icons.air},
      {'key': 'learn_new', 'label': '📚 Learn something', 'icon': Icons.school},
      {
        'key': 'balanced_diet',
        'label': '🥗 Balanced diet',
        'icon': Icons.restaurant,
      },
      {'key': 'podcast', 'label': '🎧 Podcast', 'icon': Icons.headphones},
      {
        'key': 'me_moment',
        'label': '🧘 Me moment',
        'icon': Icons.self_improvement,
      },
      {
        'key': 'hydrated',
        'label': '💧 Stay hydrated',
        'icon': Icons.water_drop,
      },
      {'key': 'read_book', 'label': '📖 Read a book', 'icon': Icons.menu_book},
      {'key': 'exercise', 'label': '🏃 Exercise', 'icon': Icons.fitness_center},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Self-Care Checklist',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Text(
              '$completedCount/10 completed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selfCareItems.map((item) {
            final key = item['key'] as String;
            final isChecked = _selfCare[key] ?? false;
            return FilterChip(
              selected: isChecked,
              label: Text(item['label'] as String),
              onSelected: (selected) {
                setState(() => _selfCare[key] = selected);
                _onSelfCareChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWaterIntakeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.water_drop,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Water Intake',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_waterCups / 8 cups',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Row(
              children: List.generate(8, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _waterCups = index + 1);
                    _onWaterChanged();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      index < _waterCups
                          ? Icons.water_drop
                          : Icons.water_drop_outlined,
                      color: index < _waterCups
                          ? Colors.blue[400]
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meals',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _breakfastController,
          decoration: InputDecoration(
            labelText: 'Breakfast',
            hintText: 'What did you have?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lunchController,
          decoration: InputDecoration(
            labelText: 'Lunch',
            hintText: 'What did you have?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dinnerController,
          decoration: InputDecoration(
            labelText: 'Dinner',
            hintText: 'What did you have?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildGratitudeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.favorite_border,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Gratitude',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSubsection(
          context,
          'Gratitude',
          Icons.favorite,
          _gratitudeControllers,
          'I\'m grateful for...',
          _addGratitudeField,
          _removeGratitudeField,
        ),
      ],
    );
  }

  Widget _buildTomorrowNotesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.note_add,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Notes for Tomorrow',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSubsection(
          context,
          'Tomorrow Notes',
          Icons.note,
          _tomorrowControllers,
          'Remember to...',
          _addTomorrowField,
          _removeTomorrowField,
        ),
      ],
    );
  }

  // Auto-save Methods

  void _onDiaryTextChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      ref
          .read(entryProvider.notifier)
          .updateDiaryText(_userId!, currentDate, _diaryController.text);
    }
  }

  void _onMoodChanged(int mood) {
    final currentDate = DateTime.now();
    if (_userId != null) {
      ref
          .read(entryProvider.notifier)
          .updateMoodScore(_userId!, currentDate, mood);
    }
  }

  void _addAffirmationField() {
    final controller = TextEditingController();
    controller.addListener(() => _onAffirmationChanged());
    setState(() => _affirmationControllers.add(controller));
  }

  void _removeAffirmationField(int index) {
    _affirmationControllers[index].dispose();
    setState(() => _affirmationControllers.removeAt(index));
    _onAffirmationChanged();
  }

  void _onAffirmationChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      final affirmations = _affirmationControllers
          .asMap()
          .entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => AffirmationItem(text: e.value.text.trim(), order: e.key))
          .toList();
      ref
          .read(entryProvider.notifier)
          .updateAffirmations(_userId!, currentDate, affirmations);
    }
  }

  void _addPriorityField() {
    final controller = TextEditingController();
    controller.addListener(() => _onPriorityChanged());
    setState(() => _priorityControllers.add(controller));
  }

  void _removePriorityField(int index) {
    _priorityControllers[index].dispose();
    setState(() => _priorityControllers.removeAt(index));
    _onPriorityChanged();
  }

  void _onPriorityChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      final priorities = _priorityControllers
          .asMap()
          .entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => PriorityItem(text: e.value.text.trim(), order: e.key))
          .toList();
      ref
          .read(entryProvider.notifier)
          .updatePriorities(_userId!, currentDate, priorities);
    }
  }

  void _onSelfCareChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      ref
          .read(entryProvider.notifier)
          .updateSelfCare(
            _userId!,
            currentDate,
            EntrySelfCare(
              entryId: '', // Will be set by provider
              sleep: _selfCare['sleep'] ?? false,
              getUpEarly: _selfCare['get_up_early'] ?? false,
              freshAir: _selfCare['fresh_air'] ?? false,
              learnNew: _selfCare['learn_new'] ?? false,
              balancedDiet: _selfCare['balanced_diet'] ?? false,
              podcast: _selfCare['podcast'] ?? false,
              meMoment: _selfCare['me_moment'] ?? false,
              hydrated: _selfCare['hydrated'] ?? false,
              readBook: _selfCare['read_book'] ?? false,
              exercise: _selfCare['exercise'] ?? false,
            ),
          );
    }
  }

  void _onWaterChanged() async {
    _onMealsChanged(); // Water is part of meals
  }

  void _onMealsChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      ref
          .read(entryProvider.notifier)
          .updateMeals(
            _userId!,
            currentDate,
            _breakfastController.text.trim().isEmpty
                ? null
                : _breakfastController.text.trim(),
            _lunchController.text.trim().isEmpty
                ? null
                : _lunchController.text.trim(),
            _dinnerController.text.trim().isEmpty
                ? null
                : _dinnerController.text.trim(),
            _waterCups,
          );
    }
  }

  void _addGratitudeField() {
    final controller = TextEditingController();
    controller.addListener(() => _onGratitudeChanged());
    setState(() => _gratitudeControllers.add(controller));
  }

  void _removeGratitudeField(int index) {
    _gratitudeControllers[index].dispose();
    setState(() => _gratitudeControllers.removeAt(index));
    _onGratitudeChanged();
  }

  void _onGratitudeChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      final gratitudeItems = _gratitudeControllers
          .asMap()
          .entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => GratitudeItem(text: e.value.text.trim(), order: e.key))
          .toList();
      ref
          .read(entryProvider.notifier)
          .updateGratitude(_userId!, currentDate, gratitudeItems);
    }
  }

  void _addTomorrowField() {
    final controller = TextEditingController();
    controller.addListener(() => _onTomorrowChanged());
    setState(() => _tomorrowControllers.add(controller));
  }

  void _removeTomorrowField(int index) {
    _tomorrowControllers[index].dispose();
    setState(() => _tomorrowControllers.removeAt(index));
    _onTomorrowChanged();
  }

  void _onTomorrowChanged() {
    final currentDate = DateTime.now();
    if (_userId != null) {
      final tomorrowNotes = _tomorrowControllers
          .asMap()
          .entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => TomorrowNoteItem(text: e.value.text.trim(), order: e.key))
          .toList();
      ref
          .read(entryProvider.notifier)
          .updateTomorrowNotes(_userId!, currentDate, tomorrowNotes);
    }
  }
}
