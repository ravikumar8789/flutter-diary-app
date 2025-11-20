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
import '../providers/home_summary_provider.dart';
import '../models/home_summary_models.dart';
import '../widgets/yesterday_insight_card.dart';

// Import aiInsightProvider from home_summary_provider

// Lightweight shimmer (no external deps)
class _SkeletonShimmer extends StatefulWidget {
  final Widget child;
  const _SkeletonShimmer({required this.child});

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 1100);
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _period)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Extra grey tones for stronger contrast against backgrounds
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade600 : Colors.grey.shade100;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = _controller.value; // 0..1
        final s1 = (v - 0.2).clamp(0.0, 1.0);
        final s2 = v.clamp(0.0, 1.0);
        final s3 = (v + 0.2).clamp(0.0, 1.0);
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [s1, s2, s3],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

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

  Widget _buildAiInsightCard(BuildContext context) {
    return const YesterdayInsightCard();
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
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick stats (two cards)
                Text(
                  'Quick Stats',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final summaryAsync = ref.watch(homeSummaryProvider);
                    return summaryAsync.when(
                      loading: () => _buildSummarySkeleton(isTablet, count: 2),
                      error: (e, st) => _buildSummaryError(context),
                      data: (summary) {
                        final crossAxisCount = isTablet ? 2 : 2;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: isTablet ? 1.8 : 1.4,
                          children: [
                            _buildStreakCard(
                              context,
                              (summary.streak?.current ??
                                      userStats?['current_streak'] ??
                                      0)
                                  as int,
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                final grace = ref.watch(graceSystemProvider);
                                // Derive tasks from piecesToday (0.5 per task)
                                int tasks = ((grace.piecesToday / 0.5).round())
                                    .clamp(0, 4);
                                bool wrote = tasks >= 1;
                                bool aff = tasks >= 2;
                                bool grat = tasks >= 3;
                                int selfCareCount = tasks >= 4 ? 1 : 0;

                                final todaySummary = TodayProgressSummary(
                                  wroteEntry: wrote,
                                  filledAffirmations: aff,
                                  filledGratitude: grat,
                                  selfCareCompletedCount: selfCareCount,
                                  gracePiecesEarned: grace.piecesToday,
                                  waterCups: summary.today?.waterCups ?? 0,
                                );
                                return _buildTodayProgressCard(
                                  context,
                                  todaySummary,
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),

                // AI Insight full-width card
                _buildAiInsightCard(context),
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

  // Removed generic stat card helper

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
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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

  Widget _buildSummarySkeleton(bool isTablet, {int count = 2}) {
    final cross = isTablet ? 2 : 2;
    final items = <Widget>[
      _skeletonStreakCard(context),
      _skeletonTodayCard(context),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cross,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: isTablet ? 1.8 : 1.4,
      children: items.take(count).toList(),
    );
  }

  Widget _buildSummaryError(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Could not load summary. Pull to refresh later.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Shimmer skeletons (no external deps) ----
  Widget _skeletonBase(
    BuildContext context, {
    double height = 12,
    double width = double.infinity,
    double radius = 8,
  }) {
    return _SkeletonShimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _skeletonStreakCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _skeletonBase(context, height: 22, width: 22, radius: 11),
                const SizedBox(width: 8),
                _skeletonBase(context, height: 20, width: 40, radius: 6),
              ],
            ),
            const SizedBox(height: 8),
            _skeletonBase(context, height: 10, width: 50, radius: 6),
          ],
        ),
      ),
    );
  }

  Widget _skeletonTodayCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _skeletonBase(context, height: 22, width: 22, radius: 11),
                const SizedBox(width: 8),
                _skeletonBase(context, height: 18, width: 60, radius: 6),
              ],
            ),
            const SizedBox(height: 8),
            _skeletonBase(context, height: 12, width: 80, radius: 6),
            const SizedBox(height: 8),
            _skeletonBase(context, height: 10, width: 70, radius: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayProgressCard(
    BuildContext context,
    TodayProgressSummary? today,
  ) {
    final tasks = today?.tasksCompletedCount ?? 0;
    final cups = today?.waterCups ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$tasks/4 tasks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  '$cups/8 cups',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Removed WeeklySnapshot card (replaced by AI Insight full-width card)

  // Removed Grace card (merged into Today Progress/AI insight layout)
  /*Widget _buildGraceCard(BuildContext context, HomeSummary summary) {
    final freeze = summary.streak?.freezeCredits ?? 0;
    final totalPieces = summary.streak?.gracePiecesTotal ?? 0.0;
    final towardNext = (totalPieces % 10);
    final todayPieces = summary.today?.gracePiecesEarned ?? 0.0;

    final progress = (towardNext / 10).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, color: Colors.blue[600], size: 22),
                const SizedBox(width: 6),
                Text(
                  'Grace Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Grace $freeze',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Today ${todayPieces.toStringAsFixed(1)}/2.0',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceVariant,
                  color: Colors.blue[600],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${towardNext.toStringAsFixed(1)}/10 to next grace day',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Earn 0.5 per completed task',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MorningRitualsScreen(),
                  ),
                );
              },
              child: const Text('Complete tasks'),
            ),
          ],
        ),
      ),
    );
  }*/

  // Chip helper removed (no longer needed)

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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
