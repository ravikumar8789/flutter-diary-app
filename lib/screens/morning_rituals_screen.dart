import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../providers/date_provider.dart';
import '../providers/entry_provider.dart';
import '../providers/sync_status_provider.dart';
import '../models/entry_models.dart';
import '../services/entry_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dynamic_field_section.dart';
import 'home_screen.dart';

class MorningRitualsScreen extends ConsumerStatefulWidget {
  const MorningRitualsScreen({super.key});

  @override
  ConsumerState<MorningRitualsScreen> createState() =>
      _MorningRitualsScreenState();
}

class _MorningRitualsScreenState extends ConsumerState<MorningRitualsScreen>
    with TickerProviderStateMixin {
  // Dynamic controllers instead of fixed lists
  List<TextEditingController> _affirmationControllers = [];
  List<TextEditingController> _priorityControllers = [];

  // Animation controllers for smooth transitions
  late AnimationController _affirmationAnimationController;
  late AnimationController _priorityAnimationController;

  // Local loading state since we're not using global provider
  bool _isLoading = true;

  int _selectedMood = 3; // 1-5 scale

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Load entry data when screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntryData();
    });
  }

  Future<void> _loadEntryData() async {
    final selectedDate = ref.read(selectedDateProvider);
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      setState(() {
        _isLoading = true;
      });

      // Clear existing controllers first
      for (var controller in _affirmationControllers) {
        controller.dispose();
      }
      for (var controller in _priorityControllers) {
        controller.dispose();
      }
      _affirmationControllers.clear();
      _priorityControllers.clear();

      // Load fresh data from database directly (bypass global provider)
      final entryService = EntryService();
      final entryData = await entryService.loadEntryForDate(
        userId,
        selectedDate,
      );

      // Populate affirmations - if database has data, use it; otherwise use 2 defaults
      if (entryData?.affirmations != null &&
          entryData!.affirmations!.affirmations.isNotEmpty) {
        // Database has data - use it
        for (var item in entryData.affirmations!.affirmations) {
          final controller = TextEditingController(text: item.text);
          controller.addListener(() => _onAffirmationChanged());
          _affirmationControllers.add(controller);
        }
      } else {
        // No data - create 2 default empty fields
        for (int i = 0; i < 2; i++) {
          final controller = TextEditingController();
          controller.addListener(() => _onAffirmationChanged());
          _affirmationControllers.add(controller);
        }
      }

      // Populate priorities - if database has data, use it; otherwise use 2 defaults
      if (entryData?.priorities != null &&
          entryData!.priorities!.priorities.isNotEmpty) {
        // Database has data - use it
        for (var item in entryData.priorities!.priorities) {
          final controller = TextEditingController(text: item.text);
          controller.addListener(() => _onPriorityChanged());
          _priorityControllers.add(controller);
        }
      } else {
        // No data - create 2 default empty fields
        for (int i = 0; i < 2; i++) {
          final controller = TextEditingController();
          controller.addListener(() => _onPriorityChanged());
          _priorityControllers.add(controller);
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
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
  }

  @override
  void dispose() {
    for (var controller in _affirmationControllers) {
      controller.dispose();
    }
    for (var controller in _priorityControllers) {
      controller.dispose();
    }
    _affirmationAnimationController.dispose();
    _priorityAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final syncState = ref.watch(syncStatusProvider);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    // Show loading state while entry data is being fetched
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Morning Rituals')),
        drawer: const AppDrawer(currentRoute: 'morning'),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your morning rituals...'),
            ],
          ),
        ),
      );
    }

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
          title: const Text('Morning Rituals'),
          actions: [
            // Sync status indicator
            _buildSyncStatusIcon(syncState),
          ],
        ),
        drawer: const AppDrawer(currentRoute: 'morning'),
        body: Column(
          children: [
            // Compact Date Selector
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: () {
                      ref
                          .read(selectedDateProvider.notifier)
                          .updateDate(
                            selectedDate.subtract(const Duration(days: 1)),
                          );
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      DateFormat('MMM d, y').format(selectedDate),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color:
                          selectedDate.isBefore(
                            DateTime.now().subtract(const Duration(days: 1)),
                          )
                          ? Colors.grey[600]
                          : Colors.grey[300],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed:
                        selectedDate.isBefore(
                          DateTime.now().subtract(const Duration(days: 1)),
                        )
                        ? () {
                            ref
                                .read(selectedDateProvider.notifier)
                                .updateDate(
                                  selectedDate.add(const Duration(days: 1)),
                                );
                          }
                        : null,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 16,
                  8, // Reduced top padding
                  isTablet ? 20 : 16,
                  isTablet ? 20 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mood Selector
                    _buildMoodSection(context),
                    const SizedBox(height: 16),

                    // Affirmations Section
                    DynamicFieldSection(
                      title: 'Daily Affirmations',
                      subtitle: 'Write positive affirmations to start your day',
                      icon: Icons.auto_awesome,
                      accentColor: Colors.purple[600]!,
                      controllers: _affirmationControllers,
                      onAddField: _addAffirmationField,
                      onRemoveField: _removeAffirmationField,
                      fieldHint: 'e.g., I am capable and strong',
                      addButtonText: 'Add affirmation',
                      fieldLabelPrefix: 'Affirmation',
                      maxFields: 8,
                      onSave: null, // Auto-save enabled
                      showProgressCounter: false,
                    ),
                    const SizedBox(height: 16),

                    // Priorities Section
                    DynamicFieldSection(
                      title: 'Today\'s Priorities',
                      subtitle: 'List your priorities for today',
                      icon: Icons.flag,
                      accentColor: Colors.orange[600]!,
                      controllers: _priorityControllers,
                      onAddField: _addPriorityField,
                      onRemoveField: _removePriorityField,
                      fieldHint: 'e.g., Complete project proposal',
                      addButtonText: 'Add priority',
                      fieldLabelPrefix: 'Priority',
                      maxFields: 10,
                      onSave: null, // Auto-save enabled
                      showProgressCounter: false,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sentiment_satisfied_alt,
                    color: Colors.green[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How are you feeling?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final mood = index + 1;
                  final isSelected = _selectedMood == mood;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMood = mood;
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getMoodColor(mood).withOpacity(0.2)
                            : Colors.white.withOpacity(0.7),
                        border: Border.all(
                          color: isSelected
                              ? _getMoodColor(mood)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _getMoodColor(mood).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getMoodEmoji(mood),
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getMoodLabel(mood),
                            style: TextStyle(
                              fontSize: 8,
                              color: isSelected
                                  ? _getMoodColor(mood)
                                  : Colors.grey[600],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMoodEmoji(int mood) {
    switch (mood) {
      case 1:
        return '😢';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }

  String _getMoodLabel(int mood) {
    switch (mood) {
      case 1:
        return 'Bad';
      case 2:
        return 'Poor';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return 'Okay';
    }
  }

  Color _getMoodColor(int mood) {
    switch (mood) {
      case 1:
        return Colors.red[400]!;
      case 2:
        return Colors.orange[400]!;
      case 3:
        return Colors.yellow[600]!;
      case 4:
        return Colors.lightGreen[400]!;
      case 5:
        return Colors.green[500]!;
      default:
        return Colors.grey[400]!;
    }
  }

  void _addAffirmationField() {
    final controller = TextEditingController();
    controller.addListener(() => _onAffirmationChanged());

    setState(() {
      _affirmationControllers.add(controller);
    });

    // Reset animation to beginning before playing
    _affirmationAnimationController.reset();
    _affirmationAnimationController.forward().then((_) {
      // Focus on the new field
      FocusScope.of(context).requestFocus(FocusNode()..requestFocus());
    });
  }

  void _addPriorityField() {
    final controller = TextEditingController();
    controller.addListener(() => _onPriorityChanged());

    setState(() {
      _priorityControllers.add(controller);
    });

    // Reset animation to beginning before playing
    _priorityAnimationController.reset();
    _priorityAnimationController.forward().then((_) {
      // Focus on the new field
      FocusScope.of(context).requestFocus(FocusNode()..requestFocus());
    });
  }

  void _removeAffirmationField(int index) {
    final controller = _affirmationControllers[index];
    controller.dispose();

    setState(() {
      _affirmationControllers.removeAt(index);
    });

    // Trigger auto-save after removing field
    _onAffirmationChanged();

    // Reset animation to avoid index issues
    _affirmationAnimationController.reset();
  }

  void _removePriorityField(int index) {
    final controller = _priorityControllers[index];
    controller.dispose();

    setState(() {
      _priorityControllers.removeAt(index);
    });

    // Trigger auto-save after removing field
    _onPriorityChanged();

    // Reset animation to avoid index issues
    _priorityAnimationController.reset();
  }

  void _onAffirmationChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final selectedDate = ref.read(selectedDateProvider);

    if (userId == null) return;

    final affirmations = _affirmationControllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.isNotEmpty)
        .map(
          (entry) => AffirmationItem(
            text: entry.value.text.trim(),
            order: entry.key + 1,
          ),
        )
        .toList();

    ref
        .read(entryProvider.notifier)
        .updateAffirmations(userId, selectedDate, affirmations);
  }

  void _onPriorityChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final selectedDate = ref.read(selectedDateProvider);

    if (userId == null) return;

    final priorities = _priorityControllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.isNotEmpty)
        .map(
          (entry) =>
              PriorityItem(text: entry.value.text.trim(), order: entry.key + 1),
        )
        .toList();

    ref
        .read(entryProvider.notifier)
        .updatePriorities(userId, selectedDate, priorities);
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
}
