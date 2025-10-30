import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../providers/entry_provider.dart';
import '../providers/sync_status_provider.dart';
import '../models/entry_models.dart';
import '../services/error_logging_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/saveable_section.dart';
import '../utils/snackbar_utils.dart';
import 'home_screen.dart';

class WellnessTrackerScreen extends ConsumerStatefulWidget {
  const WellnessTrackerScreen({super.key});

  @override
  ConsumerState<WellnessTrackerScreen> createState() =>
      _WellnessTrackerScreenState();
}

class _WellnessTrackerScreenState extends ConsumerState<WellnessTrackerScreen> {
  final _breakfastController = TextEditingController();
  final _lunchController = TextEditingController();
  final _dinnerController = TextEditingController();
  int _waterCups = 0; // 0-8
  final _showerNoteController = TextEditingController();

  // Self-care checkboxes (10 items from DB)
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

  bool _tookShower = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAutoSaveListeners();
    // Load entry data when screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntryData();
    });
  }

  void _setupAutoSaveListeners() {
    _breakfastController.addListener(() => _onMealsChanged());
    _lunchController.addListener(() => _onMealsChanged());
    _dinnerController.addListener(() => _onMealsChanged());
    _showerNoteController.addListener(() => _onShowerChanged());
  }

  Future<void> _loadEntryData() async {
    final currentDate = DateTime.now();
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    if (userId != null && !_isInitialized) {
      _isInitialized = true;
      await ref.read(entryProvider.notifier).loadEntry(userId, currentDate);

      // Populate meals
      final entryState = ref.read(entryProvider);
      if (entryState.meals != null) {
        _breakfastController.text = entryState.meals!.breakfast ?? '';
        _lunchController.text = entryState.meals!.lunch ?? '';
        _dinnerController.text = entryState.meals!.dinner ?? '';
        _waterCups = entryState.meals!.waterCups;
      }

      // Populate self-care
      if (entryState.selfCare != null) {
        _selfCare['sleep'] = entryState.selfCare!.sleep;
        _selfCare['get_up_early'] = entryState.selfCare!.getUpEarly;
        _selfCare['fresh_air'] = entryState.selfCare!.freshAir;
        _selfCare['learn_new'] = entryState.selfCare!.learnNew;
        _selfCare['balanced_diet'] = entryState.selfCare!.balancedDiet;
        _selfCare['podcast'] = entryState.selfCare!.podcast;
        _selfCare['me_moment'] = entryState.selfCare!.meMoment;
        _selfCare['hydrated'] = entryState.selfCare!.hydrated;
        _selfCare['read_book'] = entryState.selfCare!.readBook;
        _selfCare['exercise'] = entryState.selfCare!.exercise;
      }

      // Populate shower data
      if (entryState.showerBath != null) {
        _tookShower = entryState.showerBath!.tookShower;
        _showerNoteController.text = entryState.showerBath!.note ?? '';
      }

      setState(() {});
    }
  }

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    _showerNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryState = ref.watch(entryProvider);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    // Show loading state while entry data is being fetched
    if (entryState.isLoading && entryState.entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wellness Tracker')),
        drawer: const AppDrawer(currentRoute: 'wellness'),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your wellness data...'),
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
          title: const Text('Wellness Tracker'),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final syncState = ref.watch(syncStatusProvider);
                return _buildSyncStatusIcon(syncState);
              },
            ),
          ],
        ),
        drawer: const AppDrawer(currentRoute: 'wellness'),
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
                    // Meals Section
                    SaveableSection(
                      title: 'Meals',
                      subtitle: 'Track your daily meals',
                      icon: Icons.restaurant,
                      accentColor: Colors.orange[600]!,
                      onSave: null, // Auto-save enabled
                      child: _buildMealsContent(context),
                    ),
                    const SizedBox(height: 16),

                    // Water Intake Section
                    SaveableSection(
                      title: 'Water Intake',
                      subtitle: 'Track your daily water consumption',
                      icon: Icons.water_drop,
                      accentColor: Colors.blue[600]!,
                      onSave: null, // Auto-save enabled
                      child: _buildWaterIntakeContent(context),
                    ),
                    const SizedBox(height: 16),

                    // Self-Care Checklist
                    SaveableSection(
                      title: 'Self-Care Checklist',
                      subtitle: 'Track your daily self-care activities',
                      icon: Icons.favorite,
                      accentColor: Colors.pink[600]!,
                      onSave: null, // Auto-save enabled
                      child: _buildSelfCareContent(context),
                    ),
                    const SizedBox(height: 16),

                    // Hygiene Section
                    _buildHygieneSection(context),

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

  Widget _buildMealsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            childAspectRatio: 4.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 3,
          itemBuilder: (context, index) {
            final controllers = [
              _breakfastController,
              _lunchController,
              _dinnerController,
            ];
            final labels = ['Breakfast', 'Lunch', 'Dinner'];
            final hints = [
              'What did you have for breakfast?',
              'What did you have for lunch?',
              'What did you have for dinner?',
            ];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange[100]!,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controllers[index],
                decoration: InputDecoration(
                  labelText: labels[index],
                  hintText: hints[index],
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelStyle: TextStyle(
                    color: Colors.orange[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: Colors.orange[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                maxLines: 2,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWaterIntakeContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blue[100]!,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Glasses of water',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$_waterCups / 8',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filled(
                      onPressed: _waterCups > 0
                          ? () {
                              setState(() {
                                _waterCups--;
                              });
                              _onWaterChanged();
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        children: List.generate(
                          8,
                          (index) => Icon(
                            index < _waterCups
                                ? Icons.water_drop
                                : Icons.water_drop_outlined,
                            color: index < _waterCups
                                ? Colors.blue[400]
                                : Colors.grey[300],
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _waterCups < 8
                          ? () {
                              setState(() {
                                _waterCups++;
                              });
                              _onWaterChanged();
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelfCareContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[200]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purple[100]!,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildCheckboxTile('Enough sleep', 'sleep'),
                _buildCheckboxTile('Got up early', 'get_up_early'),
                _buildCheckboxTile('Fresh air', 'fresh_air'),
                _buildCheckboxTile('Learned something new', 'learn_new'),
                _buildCheckboxTile('Balanced diet', 'balanced_diet'),
                _buildCheckboxTile('Listened to podcast', 'podcast'),
                _buildCheckboxTile('Had a "me" moment', 'me_moment'),
                _buildCheckboxTile('Stayed hydrated', 'hydrated'),
                _buildCheckboxTile('Read a book', 'read_book'),
                _buildCheckboxTile('Exercise', 'exercise'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHygieneSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
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
                  Icon(Icons.bathtub, color: Colors.green[600], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Hygiene',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Track your hygiene routine',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green[100]!,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Took a shower/bath'),
                        value: _tookShower,
                        onChanged: (value) {
                          setState(() {
                            _tookShower = value ?? false;
                          });
                          _onShowerChanged();
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.green[600],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _showerNoteController,
                        decoration: InputDecoration(
                          labelText: 'Note (optional)',
                          hintText: 'Any special products or routine?',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          labelStyle: TextStyle(
                            color: Colors.green[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: Colors.green[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
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

  Widget _buildCheckboxTile(String title, String key) {
    return CheckboxListTile(
      title: Text(
        title,
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      value: _selfCare[key],
      onChanged: (value) {
        setState(() {
          _selfCare[key] = value ?? false;
        });
        _onSelfCareChanged();
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: Colors.purple[600],
      checkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  void _onMealsChanged() async {
    try {
      final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
      final currentDate = DateTime.now();

      if (userId == null) {
        SnackbarUtils.showError(
          context,
          'User not authenticated (ERRUI031)',
          'ERRUI031',
        );
        return;
      }

      ref
          .read(entryProvider.notifier)
          .updateMeals(
            userId,
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
    } catch (e) {
      // Log error to Supabase
      await ErrorLoggingService.logMediumError(
        errorCode: 'ERRUI031',
        errorMessage: 'Meals save failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'breakfast': _breakfastController.text,
          'lunch': _lunchController.text,
          'dinner': _dinnerController.text,
          'water_cups': _waterCups,
          'user_id': supabase.Supabase.instance.client.auth.currentUser?.id,
          'entry_date': DateTime.now().toIso8601String(),
          'save_method': 'wellness_tracker',
        },
      );

      SnackbarUtils.showError(
        context,
        'Meals save failed (ERRUI031)',
        'ERRUI031',
      );
    }
  }

  void _onWaterChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    // Water intake is stored in the meals table as a separate field
    // For now, we'll handle this in the meals update
    _onMealsChanged();
  }

  void _onSelfCareChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final currentDate = DateTime.now();

    if (userId == null) return;

    final entryState = ref.read(entryProvider);
    final selfCare = EntrySelfCare(
      entryId: entryState.entry?.id ?? '',
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
    );

    ref
        .read(entryProvider.notifier)
        .updateSelfCare(userId, currentDate, selfCare);
  }

  void _onShowerChanged() {
    final userId = supabase.Supabase.instance.client.auth.currentUser?.id;
    final currentDate = DateTime.now();

    if (userId == null) return;

    ref
        .read(entryProvider.notifier)
        .updateShowerBath(
          userId,
          currentDate,
          _tookShower,
          _showerNoteController.text.trim().isEmpty
              ? null
              : _showerNoteController.text.trim(),
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
}
