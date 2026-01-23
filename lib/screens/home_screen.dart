import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:intl/intl.dart';
import 'new_diary_screen.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../providers/user_data_provider.dart';
import '../providers/grace_system_provider.dart';
import '../widgets/grace_system_info_card.dart';
import '../providers/data_providers.dart'; // Use new cached providers (homeSummaryProvider)
import '../models/home_summary_models.dart';
import '../widgets/yesterday_insight_card.dart';
import '../providers/recent_entries_provider.dart';
import '../models/history_entry_model.dart';
import '../services/streak_motivation_service.dart';
import '../services/data_sync_flag_service.dart';
import '../services/data_prefetch_service.dart';
import '../services/error_logging_service.dart';

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
  bool _hasCheckedPrefetch = false;
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

  /// Handle prefetch after login (7 days data only)
  /// Called when HomeScreen shows loading state after login
  Future<void> _handlePrefetchAfterLogin(String userId) async {
    try {
      // Check if data fetch is needed
      final needsFetch = await DataSyncFlagService.needsDataFetch();
      
      if (needsFetch) {
        try {
          final dataFetchService = ref.read(dataFetchServiceProvider);
          
          // Fetch 7 days data (includes today, so no need for separate today fetch)
          await DataPrefetchService.prefetch7DaysData(
            userId,
            dataFetchService,
          );
          
          // Set flag to false after successful fetch
          await DataSyncFlagService.clearNeedsDataFetch();
          
          // Invalidate home summary cache and provider to refresh week stats
          dataFetchService.invalidateHomeSummaryCache(userId);
          ref.invalidate(homeSummaryProvider);
          
        } catch (e) {
          // Log error but continue - data will be fetched on-demand
          await ErrorLoggingService.logHighError(
            errorCode: 'ERRSYS184',
            errorMessage: 'Prefetch failed in HomeScreen after login: ${e.toString()}',
            stackTrace: StackTrace.current.toString(),
            errorContext: {
              'user_id': userId,
              'operation': 'home_prefetch_after_login',
            },
          );
          // Keep flag as true so it retries next time
        }
      }
    } catch (e) {
      await ErrorLoggingService.logHighError(
        errorCode: 'ERRSYS185',
        errorMessage: 'Failed to check prefetch flag in HomeScreen: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        errorContext: {
          'user_id': userId,
          'operation': 'home_check_prefetch',
        },
      );
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
      // Check if prefetch is needed (after login or fresh install)
      if (user != null && !_hasCheckedPrefetch) {
        _hasCheckedPrefetch = true;
        _handlePrefetchAfterLogin(user.id);
      }
      
      return Scaffold(
        appBar: null,
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
          title: const Text('Home'),
        ),
        // drawer removed - using bottom navigation
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and Greeting Header (InnerGlow Style)
                      _buildDateAndGreeting(context, userData, user),
                      const SizedBox(height: 24),
                      
                      // Streak Cards (InnerGlow Style)
                      _buildStreakSection(context, userStats, user),
                      const SizedBox(height: 24),
                      
                      // Start Today's Entry Button (InnerGlow Style)
                      _buildStartEntryButton(context),
                      const SizedBox(height: 24),
                      
                      // Yesterday's Insight Card
                      _buildAiInsightCard(context),
                      const SizedBox(height: 24),
                      
                      // This Week Metrics (InnerGlow Style)
                      _buildThisWeekSection(context),
                      const SizedBox(height: 24),
                      
                      // Recent Entries Section (InnerGlow Style)
                      _buildRecentEntriesSection(context),
                    ],
                  ),
                ),
              ),
              // Bottom Navigation Bar
              AppBottomNavigationBar(
                currentIndex: 0,
                onTap: (index) {
                  AppBottomNavigationBar.navigateToScreen(context, index);
                },
              ),
            ],
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

  // InnerGlow Design Builder Methods
  
  Widget _buildDateAndGreeting(
    BuildContext context,
    userData,
    user,
  ) {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d').format(now);
    final name = userData?.displayName ?? 
                 user?.userMetadata?['display_name'] ?? 
                 user?.email?.split('@')[0] ?? 
                 'User';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateFormat,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hello, $name 👋',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStreakSection(
    BuildContext context,
    userStats,
    user,
  ) {
    final currentStreak = userStats?['current_streak'] ?? 0;
    final bestStreak = userStats?['longest_streak'] ?? currentStreak;
    
    return Consumer(
      builder: (context, ref, _) {
        final summaryAsync = ref.watch(homeSummaryProvider);
        final currentStreakValue = summaryAsync.value?.streak?.current ?? currentStreak;
        final bestStreakValue = summaryAsync.value?.streak?.longest ?? bestStreak;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Single card containing both streaks
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Current Streak (left side)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Streak',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$currentStreakValue days',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      width: 1,
                      height: 40,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    const SizedBox(width: 20),
                    // Best Streak (right side)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Best',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$bestStreakValue days',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Motivational message OUTSIDE the card
            const SizedBox(height: 12),
            Text(
              StreakMotivationService.getMotivationalMessage(currentStreakValue),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildStartEntryButton(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewDiaryScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Today\'s Entry',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How are you feeling today?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildThisWeekSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final summaryAsync = ref.watch(homeSummaryProvider);
        
        return summaryAsync.when(
          loading: () => const SizedBox(height: 200),
          error: (_, __) => const SizedBox.shrink(),
          data: (summary) {
            final weekly = summary.weekly;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Week',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildWeekMetricCard(
                            context, 
                            weekly?.moodAvg?.toStringAsFixed(1) ?? '0.0', 
                            'Avg Mood', 
                            'out of 5', 
                            Icons.mood,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildWeekMetricCard(
                            context, 
                            weekly?.cupsAvg?.toStringAsFixed(1) ?? '0.0', 
                            'Water', 
                            'Avg cups/day', 
                            Icons.water_drop,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildWeekMetricCard(
                            context, 
                            '${((weekly?.selfCareRate ?? 0) * 100).toStringAsFixed(0)}%', 
                            'Self-Care', 
                            'Avg completion', 
                            Icons.favorite,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildWeekMetricCard(
                            context, 
                            '${((weekly?.consistency ?? 0) * 100).toStringAsFixed(0)}%', 
                            'Consistency', 
                            'this week', 
                            Icons.check_circle,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildWeekMetricCard(BuildContext context, String value, String label, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentEntriesSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final recentEntriesAsync = ref.watch(recentEntriesProvider);
        
        return recentEntriesAsync.when(
          loading: () => const SizedBox(height: 200),
          error: (_, __) => const SizedBox.shrink(),
          data: (entries) {
            if (entries.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Entries',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        AppBottomNavigationBar.navigateToScreen(context, 1);
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length > 3 ? 3 : entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildEntryCard(context, entries[index]);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildEntryCard(BuildContext context, HistoryEntry entry) {
    final dateFormat = DateFormat('EEEE, MMMM d').format(entry.entry.entryDate);
    final moodEmoji = _getMoodEmoji(entry.entry.moodScore ?? 3);
    final preview = entry.preview.length > 100 
        ? '${entry.preview.substring(0, 100)}...' 
        : entry.preview;
    final selfCareScore = entry.selfCareCount;
    
    return Card(
      child: InkWell(
        onTap: () {
          // Navigate to entry details or history
          AppBottomNavigationBar.navigateToScreen(context, 1);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(moodEmoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(
                    dateFormat,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (selfCareScore > 0)
                    Text(
                      '$selfCareScore/10 self-care',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (entry.hasInsights) ...[
                    if (selfCareScore > 0) const SizedBox(width: 8),
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Insight',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
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
        return '😔';
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

}
