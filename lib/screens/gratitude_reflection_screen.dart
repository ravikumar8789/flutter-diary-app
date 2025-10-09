import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/date_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _setupAnimations();
  }

  void _initializeFields() {
    // Start with 2 fields for each section
    _gratitudeControllers = List.generate(2, (_) => TextEditingController());
    _tomorrowControllers = List.generate(2, (_) => TextEditingController());
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
        appBar: AppBar(title: const Text('Gratitude & Reflection')),
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
                      onSave: _saveGratitude,
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
                      onSave: _saveTomorrowNotes,
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
    setState(() {
      _gratitudeControllers.add(TextEditingController());
    });

    _gratitudeAnimationController.forward().then((_) {
      // Focus on the new field
      FocusScope.of(context).requestFocus(FocusNode()..requestFocus());
    });
  }

  void _addTomorrowField() {
    setState(() {
      _tomorrowControllers.add(TextEditingController());
    });

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

    _gratitudeAnimationController.reverse();
  }

  void _removeTomorrowField(int index) {
    final controller = _tomorrowControllers[index];
    controller.dispose();

    setState(() {
      _tomorrowControllers.removeAt(index);
    });

    _tomorrowAnimationController.reverse();
  }

  void _saveGratitude() {
    final gratefulItems = _gratitudeControllers
        .where((controller) => controller.text.isNotEmpty)
        .map(
          (controller) => {
            'text': controller.text.trim(),
            'order': _gratitudeControllers.indexOf(controller) + 1,
          },
        )
        .toList();

    print('Saving Grateful Items: $gratefulItems');
    // TODO: Save to Supabase with JSONB structure

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gratitude saved!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _saveTomorrowNotes() {
    final tomorrowNotes = _tomorrowControllers
        .where((controller) => controller.text.isNotEmpty)
        .map(
          (controller) => {
            'text': controller.text.trim(),
            'order': _tomorrowControllers.indexOf(controller) + 1,
          },
        )
        .toList();

    print('Saving Tomorrow Notes: $tomorrowNotes');
    // TODO: Save to Supabase with JSONB structure

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tomorrow notes saved!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
