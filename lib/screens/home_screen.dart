import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'morning_rituals_screen.dart';
import 'wellness_tracker_screen.dart';
import 'gratitude_reflection_screen.dart';
import 'new_diary_screen.dart';
import '../widgets/app_drawer.dart';
import '../providers/user_data_provider.dart';
import '../providers/grace_system_provider.dart';
import '../widgets/grace_system_info_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasLoadedUserData = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Load user data when HomeScreen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (!_hasLoadedUserData) {
      _hasLoadedUserData = true;
      await ref.read(userDataProvider.notifier).loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    final user = supabase.Supabase.instance.client.auth.currentUser;
    final userDataState = ref.watch(userDataProvider);
    final userData = userDataState.userData;
    final userStats = ref.watch(userStatsProvider);
    final isLoading = userDataState.isLoading;

    // Show loading state while user data is being fetched
    if (isLoading && userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Diary')),
        drawer: const AppDrawer(currentRoute: 'home'),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your data...'),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Home screen - allow app to close
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Diary'),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ],
        ),
        drawer: const AppDrawer(currentRoute: 'home'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 32 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.waving_hand,
                          color: Colors.amber[700],
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back, ${userData?.displayName ?? user?.userMetadata?['display_name'] ?? user?.email?.split('@')[0] ?? 'User'}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ready to journal today?',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick stats
                Text(
                  'Quick Stats',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = isTablet ? 4 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: isTablet ? 1.5 : 1.4,
                      children: [
                        _buildStreakCard(
                          context,
                          userStats?['current_streak'] ?? 0,
                        ),
                        _buildStatCard(
                          context,
                          'Entries',
                          '${userStats?['entries_count'] ?? 0}',
                          Icons.edit_note,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          context,
                          'Mood',
                          'Happy',
                          Icons.sentiment_satisfied_alt,
                          Colors.green,
                        ),
                        _buildStatCard(
                          context,
                          'Days Active',
                          '${userStats?['days_active'] ?? 0}',
                          Icons.calendar_today,
                          Colors.purple,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Journal Categories
                Text(
                  'Today\'s Journal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                _buildCategoryCard(
                  context,
                  '🌅 Morning Rituals',
                  'Affirmations & priorities',
                  const Color(0xFFFFF8E7),
                  const Color(0xFFFFA726),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MorningRitualsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildCategoryCard(
                  context,
                  '💪 Wellness Tracker',
                  'Track health & habits',
                  const Color(0xFFE8F5E9),
                  const Color(0xFF66BB6A),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WellnessTrackerScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildCategoryCard(
                  context,
                  '✨ Gratitude & Reflection',
                  'Appreciate & plan ahead',
                  const Color(0xFFF3E5F5),
                  const Color(0xFFAB47BC),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GratitudeReflectionScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildCategoryCard(
                  context,
                  '📝 Daily Diary',
                  'Write your thoughts freely',
                  const Color(0xFFE3F2FD),
                  const Color(0xFF42A5F5),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewDiaryScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, int currentStreak) {
    return Consumer(
      builder: (context, ref, child) {
        final graceState = ref.watch(graceSystemProvider);
        final user = supabase.Supabase.instance.client.auth.currentUser;

        // Initialize grace system if user is available and not already initialized
        if (user != null) {
          if (_currentUserId == null || _currentUserId != user.id) {
            _currentUserId = user.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(graceSystemProvider.notifier).initialize(user.id);
            });
          }
        }

        return Card(
          child: InkWell(
            onTap: () => _showStreakDetails(context, currentStreak, graceState),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: Icon and number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        graceState.graceDaysAvailable > 0
                            ? Icons.shield
                            : Icons.local_fire_department,
                        color: graceState.graceDaysAvailable > 0
                            ? Colors.blue
                            : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentStreak',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Streak label
                  Text(
                    'Streak',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  // Bottom row: Grace days indicator - only show if not loading
                  if (!graceState.isLoading) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 12,
                          color: graceState.graceDaysAvailable > 0
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          graceState.graceDaysAvailable > 0
                              ? '${graceState.graceDaysAvailable} grace'
                              : '${graceState.piecesToday.toStringAsFixed(1)}/2.0',
                          style: TextStyle(
                            fontSize: 10,
                            color: graceState.graceDaysAvailable > 0
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showStreakDetails(
                            context,
                            currentStreak,
                            graceState,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStreakDetails(
    BuildContext context,
    int currentStreak,
    GraceSystemState graceState,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const GraceSystemInfoCard(),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String title,
    String subtitle,
    Color bgColor,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: bgColor),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: accentColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
