import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../providers/entry_provider.dart';
import '../providers/sync_status_provider.dart';
import '../models/entry_models.dart';
import '../services/entry_service.dart';
import '../services/error_logging_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dynamic_field_section.dart';
import '../utils/snackbar_utils.dart';
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
    final currentDate = DateTime.now();
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      setState(() {
        _isLoading = true;
      });

      // Load fresh data from database directly (bypass global provider)
      final entryService = EntryService();
      final entryData = await entryService.loadEntryForDate(
        userId,
        currentDate,
      );

      // Pooling: gratitude (min 2 fields)
      final List<String> gratitudeTexts = (entryData?.gratitude?.gratefulItems
                  .map((g) => g.text)
                  .toList() ??
              [])
          .toList();
      while (gratitudeTexts.length < 2) gratitudeTexts.add('');
      while (_gratitudeControllers.length < gratitudeTexts.length) {
        final c = TextEditingController();
        c.addListener(() => _onGratitudeChanged());
        _gratitudeControllers.add(c);
      }
      while (_gratitudeControllers.length > gratitudeTexts.length) {
        _gratitudeControllers.removeLast().dispose();
      }
      for (int i = 0; i < gratitudeTexts.length; i++) {
        _gratitudeControllers[i].text = gratitudeTexts[i];
      }

      // Pooling: tomorrow notes (min 2 fields)
      final List<String> tomorrowTexts = (entryData?.tomorrowNotes
                  ?.tomorrowNotes
                  .map((t) => t.text)
                  .toList() ??
              [])
          .toList();
      while (tomorrowTexts.length < 2) tomorrowTexts.add('');
      while (_tomorrowControllers.length < tomorrowTexts.length) {
        final c = TextEditingController();
        c.addListener(() => _onTomorrowChanged());
        _tomorrowControllers.add(c);
      }
      while (_tomorrowControllers.length > tomorrowTexts.length) {
        _tomorrowControllers.removeLast().dispose();
      }
      for (int i = 0; i < tomorrowTexts.length; i++) {
        _tomorrowControllers[i].text = tomorrowTexts[i];
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
              child: Center(
                child: Text(
                  'Today - ${DateFormat('MMM d, y').format(DateTime.now())}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
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

  void _onGratitudeChanged() async {
    try {
      final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
      final currentDate = DateTime.now();

      if (userId == null) {
        SnackbarUtils.showError(
          context,
          'User not authenticated (ERRUI041)',
          'ERRUI041',
        );
        return;
      }

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
          .updateGratitude(userId, currentDate, gratitude);

      // Cancel bedtime reminder after gratitude entry (bedtime entry completion)
      await NotificationService.instance.cancelBedtimeReminder();
    } catch (e) {
      // Log error to Supabase
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRUI041',
        errorMessage: 'Gratitude save failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'gratitude_items_count': _gratitudeControllers.length,
          'user_id': supabase.Supabase.instance.client.auth.currentUser?.id,
          'entry_date': DateTime.now().toIso8601String(),
          'save_method': 'gratitude_reflection',
        },
      );

      SnackbarUtils.showError(
        context,
        'Gratitude save failed (ERRUI041)',
        'ERRUI041',
      );
    }
  }

  void _onTomorrowChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final currentDate = DateTime.now();

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
        .updateTomorrowNotes(userId, currentDate, tomorrowNotes);
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
