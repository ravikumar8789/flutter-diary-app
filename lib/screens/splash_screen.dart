import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/connectivity_service.dart';
import '../services/user_data_service.dart';
import '../providers/user_data_provider.dart';
import '../providers/data_providers.dart';
import '../providers/home_summary_provider.dart';
import '../services/data_sync_flag_service.dart';
import '../services/data_prefetch_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../ui/responsive/responsive_info.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  String _loadingMessage = 'Preparing your journal...';
  UserData? _userData;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _scaleController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    try {
      // Step 1: Check authentication
      if (mounted && !_isDisposed) {
        setState(() {
          _loadingMessage = 'Checking authentication...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));

      if (_isDisposed) return;

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        // User not authenticated, clear any stale data and go to login
        ref.read(userDataProvider.notifier).clearUserData();
        if (mounted && !_isDisposed) {
          await _navigateToAuth();
        }
        return;
      }

      // Step 2: Clear any stale user data first
      ref.read(userDataProvider.notifier).clearUserData();

      // Step 3: Check connectivity
      final connectivityService = ConnectivityService();
      final isOnline = await connectivityService.isOnline();

      // Offline path: zero network calls, read from SQLite only
      if (!isOnline) {
        if (mounted && !_isDisposed) {
          setState(() => _loadingMessage = 'Loading your journal...');
        }
        await Future.delayed(const Duration(milliseconds: 200));
        if (_isDisposed) return;

        await ref.read(userDataProvider.notifier).loadUserData(useLocalOnly: true);
        if (_isDisposed) return;

        await _navigateToHomeOrAuthBasedOnUserData();
        return;
      }

      // Online path
      final dataFetchService = ref.read(dataFetchServiceProvider);
      if (mounted && !_isDisposed) {
        setState(() => _loadingMessage = 'Syncing your journal...');
      }
      await Future.delayed(const Duration(milliseconds: 200));
      if (_isDisposed) return;

      final lastFetchDate = await DataSyncFlagService.getLastFetchDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sixtyDaysAgo = today.subtract(const Duration(days: 60));

      final DateTime fetchStart;
      if (lastFetchDate == null) {
        fetchStart = sixtyDaysAgo;
      } else {
        final startDate = lastFetchDate.isBefore(sixtyDaysAgo)
            ? sixtyDaysAgo
            : lastFetchDate;
        fetchStart = DateTime(startDate.year, startDate.month, startDate.day);
      }

      await Future.wait([
        DataPrefetchService.fetchAndMergeUserProfile(user.id, dataFetchService),
        DataPrefetchService.fetchAndMergeUserSettings(user.id, dataFetchService),
        DataPrefetchService.fetchAndMergeStreaks(user.id, dataFetchService),
        DataPrefetchService.fetchAndMergeEntriesWithJoins(
          user.id,
          fetchStart,
          today,
          dataFetchService,
        ),
        DataPrefetchService.fetchAndStoreYesterdayInsight(
          user.id,
          dataFetchService,
        ),
      ]);

      await DataPrefetchService.ensureHabitsDailyFromEntries(user.id);

      await DataSyncFlagService.setLastFetchDate(today);
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(yesterdayInsightProvider);

      // Step 4: Load user data (reads from local — data now in SQLite)
      await ref.read(userDataProvider.notifier).loadUserData();

      await _navigateToHomeOrAuthBasedOnUserData();
    } catch (e) {
      // Handle any errors gracefully
      if (mounted && !_isDisposed) {
        setState(() {
          _loadingMessage = 'Something went wrong...';
        });
      }
      await Future.delayed(const Duration(milliseconds: 1000));

      if (_isDisposed) return;

      // Clear any stale data and go to auth
      ref.read(userDataProvider.notifier).clearUserData();
      if (mounted && !_isDisposed) {
        await _navigateToAuth();
      }
    }
  }

  Future<void> _navigateToHomeOrAuthBasedOnUserData() async {
    if (!mounted || _isDisposed) return;
    final userDataState = ref.read(userDataProvider);

    if (userDataState.userData != null && !userDataState.isLoading) {
      if (mounted && !_isDisposed) {
        setState(() {
          _userData = userDataState.userData;
          _loadingMessage = 'Welcome back, ${_userData!.displayName}';
        });
      }
      await Future.delayed(const Duration(milliseconds: 800));
      if (_isDisposed) return;
      await _navigateToHome();
    } else if (userDataState.error != null) {
      if (mounted && !_isDisposed) {
        setState(() => _loadingMessage = 'Setting up your journal...');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isDisposed) return;
      await _navigateToHome();
    } else {
      if (mounted && !_isDisposed) {
        setState(() => _loadingMessage = 'Preparing your journal...');
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      if (_isDisposed) return;
      await _navigateToHome();
    }
  }

  Future<void> _navigateToAuth() async {
    if (mounted && !_isDisposed) {
      // Navigate directly to LoginScreen instead of AuthWrapper to avoid loading issues
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _navigateToHome() async {
    if (mounted && !_isDisposed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final info = ResponsiveInfo.of(context);
    final logoSize = info.value(compact: 110.0, medium: 130.0, expanded: 140.0);
    final iconSize = info.value(compact: 56.0, medium: 64.0, expanded: 70.0);
    final titleSize = info.value(compact: 28.0, medium: 32.0, expanded: 36.0);
    final taglineSize = info.value(compact: 14.0, medium: 15.0, expanded: 16.0);
    final loaderSize = info.value(compact: 28.0, medium: 30.0, expanded: 32.0);
    final gapLogoToTitle =
        info.value(compact: 28.0, medium: 34.0, expanded: 40.0);
    final gapTitleToTagline =
        info.value(compact: 12.0, medium: 16.0, expanded: 20.0);
    final gapLoaderToText =
        info.value(compact: 16.0, medium: 20.0, expanded: 24.0);
    final bottomGap = info.value(compact: 48.0, medium: 64.0, expanded: 80.0);
    final textMaxWidth =
        info.value(compact: double.infinity, medium: 420.0, expanded: 480.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // InnerGlow Style: Soft gradient background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    colorScheme.surfaceContainer,
                  ]
                : [
                    colorScheme.surface,
                    colorScheme.primaryContainer.withOpacity(0.1),
                    colorScheme.surfaceContainerLowest,
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _BackgroundPatternPainter(
                    primaryColor: colorScheme.primary,
                  ),
                ),
              ),

              Column(
                children: [
                  const Spacer(flex: 2),

                  // Main Logo Section
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _fadeAnimation.value,
                              child: Column(
                                children: [
                                  // Journal Icon with gentle pulse
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                colorScheme.primary,
                                                colorScheme.primaryContainer,
                                                colorScheme.secondary,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colorScheme.primary
                                                    .withOpacity(0.3),
                                                blurRadius: 30,
                                                spreadRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            size: iconSize,
                                            color: colorScheme.onPrimary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  SizedBox(height: gapLogoToTitle),

                                  // App Name with gentle gradient
                                  ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: textMaxWidth),
                                    child: ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [
                                          colorScheme.primary,
                                          colorScheme.secondary,
                                        ],
                                      ).createShader(bounds),
                                      child: Text(
                                        'Simple Journal',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: titleSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: gapTitleToTagline),

                                  // Tagline with soft styling
                                  ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: textMaxWidth),
                                    child: Text(
                                      'Your thoughts, beautifully captured',
                                      style: TextStyle(
                                        fontSize: taglineSize,
                                        fontWeight: FontWeight.w400,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.5,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // Loading Indicator with gentle animation
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Column(
                          children: [
                            SizedBox(
                              width: loaderSize,
                              height: loaderSize,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                            SizedBox(height: gapLoaderToText),
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxWidth: textMaxWidth),
                              child: Text(
                                _loadingMessage,
                                style: TextStyle(
                                  fontSize: info.value(
                                    compact: 12.0,
                                    medium: 13.0,
                                    expanded: 14.0,
                                  ),
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  SizedBox(height: bottomGap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  final Color primaryColor;

  _BackgroundPatternPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Draw subtle circles
    for (int i = 0; i < 8; i++) {
      final x = (size.width / 8) * (i + 1);
      final y = (size.height / 6) * (i % 3 + 1);
      final radius = 20.0 + (i * 5.0);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
