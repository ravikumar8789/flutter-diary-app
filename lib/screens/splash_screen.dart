import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_data_service.dart';
import '../providers/user_data_provider.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

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
      setState(() {
        _loadingMessage = 'Checking authentication...';
      });
      await Future.delayed(const Duration(milliseconds: 500));

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        // User not authenticated, clear any stale data and go to login
        ref.read(userDataProvider.notifier).clearUserData();
        await _navigateToAuth();
        return;
      }

      // Step 2: Clear any stale user data first
      ref.read(userDataProvider.notifier).clearUserData();

      // Step 3: Fetch fresh user data
      setState(() {
        _loadingMessage = 'Loading your data...';
      });
      await Future.delayed(const Duration(milliseconds: 300));

      // Use the global provider to load user data
      print('🔄 SplashScreen: Loading user data...');
      await ref.read(userDataProvider.notifier).loadUserData();

      final userDataState = ref.read(userDataProvider);
      print(
        '🔄 SplashScreen: User data loaded - ${userDataState.userData?.displayName ?? "NULL"}',
      );
      print(
        '🔄 SplashScreen: User data email - ${userDataState.userData?.email ?? "NULL"}',
      );
      print(
        '🔄 SplashScreen: User data stats - ${userDataState.userData?.stats}',
      );

      if (userDataState.userData != null && !userDataState.isLoading) {
        setState(() {
          _userData = userDataState.userData;
          _loadingMessage = 'Welcome back, ${_userData!.displayName}';
        });

        // Wait a bit to show the welcome message
        await Future.delayed(const Duration(milliseconds: 800));

        // Navigate to home screen
        await _navigateToHome();
      } else if (userDataState.error != null) {
        // Error fetching user data, still go to home but with limited functionality
        setState(() {
          _loadingMessage = 'Setting up your journal...';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        await _navigateToHome();
      } else {
        // Still loading or no data, wait a bit more
        setState(() {
          _loadingMessage = 'Preparing your journal...';
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        await _navigateToHome();
      }
    } catch (e) {
      // Handle any errors gracefully
      print('Splash screen error: $e');
      setState(() {
        _loadingMessage = 'Something went wrong...';
      });
      await Future.delayed(const Duration(milliseconds: 1000));

      // Clear any stale data and go to auth
      ref.read(userDataProvider.notifier).clearUserData();
      await _navigateToAuth();
    }
  }

  Future<void> _navigateToAuth() async {
    if (mounted) {
      // Navigate directly to LoginScreen instead of AuthWrapper to avoid loading issues
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _navigateToHome() async {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E3A5F), // Soft dark blue
                    const Color(0xFF2D4A6B), // Muted blue-gray
                    const Color(0xFF3A5A7A), // Gentle blue
                  ]
                : [
                    const Color(0xFFE8F4FD), // Very light blue
                    const Color(0xFFF0F8FF), // Alice blue
                    const Color(0xFFF8FBFF), // Almost white with blue tint
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _BackgroundPatternPainter(isDark: isDark),
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
                                          width: 140,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: isDark
                                                  ? [
                                                      const Color(
                                                        0xFF7BB3F0,
                                                      ), // Soft blue
                                                      const Color(
                                                        0xFF5A9FD4,
                                                      ), // Gentle blue
                                                      const Color(
                                                        0xFF4A8BC2,
                                                      ), // Muted blue
                                                    ]
                                                  : [
                                                      const Color(
                                                        0xFFB8D4F0,
                                                      ), // Very light blue
                                                      const Color(
                                                        0xFF9BC5E8,
                                                      ), // Light blue
                                                      const Color(
                                                        0xFF7BB3F0,
                                                      ), // Soft blue
                                                    ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    (isDark
                                                            ? const Color(
                                                                0xFF7BB3F0,
                                                              )
                                                            : const Color(
                                                                0xFFB8D4F0,
                                                              ))
                                                        .withOpacity(0.4),
                                                blurRadius: 30,
                                                spreadRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.menu_book_rounded,
                                            size: 70,
                                            color: isDark
                                                ? const Color(0xFF2D4A6B)
                                                : const Color(0xFF4A8BC2),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 40),

                                  // App Name with gentle gradient
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: isDark
                                          ? [
                                              const Color(0xFF7BB3F0),
                                              const Color(0xFF5A9FD4),
                                            ]
                                          : [
                                              const Color(0xFF4A8BC2),
                                              const Color(0xFF2D4A6B),
                                            ],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Simple Journal',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white,
                                        letterSpacing: 2.0,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Tagline with soft styling
                                  Text(
                                    'Your thoughts, beautifully captured',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w300,
                                      color: isDark
                                          ? const Color(
                                              0xFF7BB3F0,
                                            ).withOpacity(0.8)
                                          : const Color(
                                              0xFF4A8BC2,
                                            ).withOpacity(0.7),
                                      letterSpacing: 1.0,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
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
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark
                                      ? const Color(0xFF7BB3F0).withOpacity(0.8)
                                      : const Color(
                                          0xFF4A8BC2,
                                        ).withOpacity(0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _loadingMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF7BB3F0).withOpacity(0.6)
                                    : const Color(0xFF4A8BC2).withOpacity(0.5),
                                fontWeight: FontWeight.w300,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 80),
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
  final bool isDark;

  _BackgroundPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? const Color(0xFF7BB3F0) : const Color(0xFFB8D4F0))
          .withOpacity(0.03)
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
