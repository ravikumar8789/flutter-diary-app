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

class GratitudeReflectionScreen extends ConsumerStatefulWidget {
  const GratitudeReflectionScreen({super.key});

  @override
  ConsumerState<GratitudeReflectionScreen> createState() =>
      _GratitudeReflectionScreenState();
}

class _GratitudeReflectionScreenState
    extends ConsumerState<GratitudeReflectionScreen>
    with TickerProviderStateMixin {
  // Dynamic controllers instead of fixed lists
  List<TextEditingController> _gratitudeControllers = [];
  List<TextEditingController> _tomorrowControllers = [];

  // Animation controllers for smooth transitions
  late AnimationController _gratitudeAnimationController;
  late AnimationController _tomorrowAnimationController;

  // Local loading state since we're not using global provider
  bool _isLoading = true;

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

      // Load fresh data from database directly (bypass global provider)
      final entryService = EntryService();
      final entryData = await entryService.loadEntryForDate(
        userId,
        selectedDate,
      );

      // Clear existing controllers
      for (var controller in _gratitudeControllers) {
        controller.dispose();
      }
      for (var controller in _tomorrowControllers) {
        controller.dispose();
      }
      _gratitudeControllers.clear();
      _tomorrowControllers.clear();

      // Populate gratitude - if database has data, use it; otherwise use 2 defaults
      if (entryData?.gratitude != null &&
          entryData!.gratitude!.gratefulItems.isNotEmpty) {
        // Database has data - use it
        for (var item in entryData.gratitude!.gratefulItems) {
          final controller = TextEditingController(text: item.text);
          controller.addListener(() => _onGratitudeChanged());
          _gratitudeControllers.add(controller);
        }
      } else {
        // No data - create 2 default empty fields
        for (int i = 0; i < 2; i++) {
          final controller = TextEditingController();
          controller.addListener(() => _onGratitudeChanged());
          _gratitudeControllers.add(controller);
        }
      }

      // Populate tomorrow notes - if database has data, use it; otherwise use 2 defaults
      if (entryData?.tomorrowNotes != null &&
          entryData!.tomorrowNotes!.tomorrowNotes.isNotEmpty) {
        // Database has data - use it
        for (var item in entryData.tomorrowNotes!.tomorrowNotes) {
          final controller = TextEditingController(text: item.text);
          controller.addListener(() => _onTomorrowChanged());
          _tomorrowControllers.add(controller);
        }
      } else {
        // No data - create 2 default empty fields
        for (int i = 0; i < 2; i++) {
          final controller = TextEditingController();
          controller.addListener(() => _onTomorrowChanged());
          _tomorrowControllers.add(controller);
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupAnimations() {
    _gratitudeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tomorrowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    for (var controller in _gratitudeControllers) {
      controller.dispose();
    }
    for (var controller in _tomorrowControllers) {
      controller.dispose();
    }
    _gratitudeAnimationController.dispose();
    _tomorrowAnimationController.dispose();
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
        appBar: AppBar(title: const Text('Gratitude & Reflection')),
        drawer: const AppDrawer(currentRoute: 'gratitude'),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your gratitude data...'),
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
          title: const Text('Gratitude & Reflection'),
          actions: [
            // Sync status indicator
            _buildSyncStatusIcon(syncState),
          ],
        ),
        drawer: const AppDrawer(currentRoute: 'gratitude'),
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
                    // Gratitude Section
                    DynamicFieldSection(
                      title: 'What are you grateful for?',
                      subtitle: 'List things you\'re grateful for today',
                      icon: Icons.favorite,
                      accentColor: Colors.orange[600]!,
                      controllers: _gratitudeControllers,
                      onAddField: _addGratitudeField,
                      onRemoveField: _removeGratitudeField,
                      fieldHint: 'e.g., My family\'s support',
                      addButtonText: 'Add grateful item',
                      fieldLabelPrefix: 'Grateful',
                      maxFields: 8,
                      onSave: null, // Auto-save enabled
                      showProgressCounter: false,
                    ),
                    const SizedBox(height: 16),

                    // Tomorrow Notes Section
                    DynamicFieldSection(
                      title: 'Notes for Tomorrow',
                      subtitle: 'Plan ahead for tomorrow',
                      icon: Icons.schedule,
                      accentColor: Colors.blue[600]!,
                      controllers: _tomorrowControllers,
                      onAddField: _addTomorrowField,
                      onRemoveField: _removeTomorrowField,
                      fieldHint: 'e.g., Prepare for presentation',
                      addButtonText: 'Add tomorrow note',
                      fieldLabelPrefix: 'Note',
                      maxFields: 6,
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

  void _addGratitudeField() {
    final controller = TextEditingController();
    controller.addListener(() => _onGratitudeChanged());

    setState(() {
      _gratitudeControllers.add(controller);
    });

    // Reset animation to beginning before playing
    _gratitudeAnimationController.reset();
    _gratitudeAnimationController.forward().then((_) {
      // Focus on the new field
      FocusScope.of(context).requestFocus(FocusNode()..requestFocus());
    });
  }

  void _addTomorrowField() {
    final controller = TextEditingController();
    controller.addListener(() => _onTomorrowChanged());

    setState(() {
      _tomorrowControllers.add(controller);
    });

    // Reset animation to beginning before playing
    _tomorrowAnimationController.reset();
    _tomorrowAnimationController.forward().then((_) {
      // Focus on the new field
      FocusScope.of(context).requestFocus(FocusNode()..requestFocus());
    });
  }

  void _removeGratitudeField(int index) {
    final controller = _gratitudeControllers[index];
    controller.dispose();

    setState(() {
      _gratitudeControllers.removeAt(index);
    });

    // Trigger auto-save after removing field
    _onGratitudeChanged();

    // Reset animation to avoid index issues
    _gratitudeAnimationController.reset();
  }

  void _removeTomorrowField(int index) {
    final controller = _tomorrowControllers[index];
    controller.dispose();

    setState(() {
      _tomorrowControllers.removeAt(index);
    });

    // Trigger auto-save after removing field
    _onTomorrowChanged();

    // Reset animation to avoid index issues
    _tomorrowAnimationController.reset();
  }

  void _onGratitudeChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final selectedDate = ref.read(selectedDateProvider);

    if (userId == null) return;

    final gratitude = _gratitudeControllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.isNotEmpty)
        .map(
          (entry) => GratitudeItem(
            text: entry.value.text.trim(),
            order: entry.key + 1,
          ),
        )
        .toList();

    ref
        .read(entryProvider.notifier)
        .updateGratitude(userId, selectedDate, gratitude);
  }

  void _onTomorrowChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final selectedDate = ref.read(selectedDateProvider);

    if (userId == null) return;

    final tomorrowNotes = _tomorrowControllers
        .asMap()
        .entries
        .where((entry) => entry.value.text.isNotEmpty)
        .map(
          (entry) => TomorrowNoteItem(
            text: entry.value.text.trim(),
            order: entry.key + 1,
          ),
        )
        .toList();

    ref
        .read(entryProvider.notifier)
        .updateTomorrowNotes(userId, selectedDate, tomorrowNotes);
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
