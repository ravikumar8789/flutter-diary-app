import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../providers/auth_provider.dart';
import '../providers/user_data_provider.dart';
import '../utils/snackbar_utils.dart';
import '../services/error_logging_service.dart';
import '../models/error_models.dart';
import '../services/data_sync_flag_service.dart';
import '../services/database/user_data_cleanup_service.dart';
import 'login_screen.dart';
import 'help_support_screen.dart';
import 'settings_screen.dart';
import '../providers/privacy_lock_provider.dart';
import 'pin_setup_screen.dart';
import '../ui/responsive/responsive_body.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ResponsiveInfo.of(context);
    final userDataState = ref.watch(userDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.person,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'Profile',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: userDataState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : userDataState.error != null
            ? _buildErrorState(context, userDataState.error!, ref)
            : userDataState.userData == null
            ? _buildNoDataState(context, ref)
            : Column(
                children: [
                  Expanded(
                    child: _buildProfileContent(
                      context,
                      userDataState.userData!,
                      info,
                      ref,
                    ),
                  ),
                  // Bottom Navigation Bar
                  AppBottomNavigationBar(
                    currentIndex: 3,
                    onTap: (index) {
                      AppBottomNavigationBar.navigateToScreen(context, index);
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(userDataProvider.notifier).refreshUserData(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No profile data found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Please refresh to load your profile',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(userDataProvider.notifier).refreshUserData(),
            icon: const Icon(Icons.refresh),
            label: const Text('Load Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    userData,
    ResponsiveInfo info,
    WidgetRef ref,
  ) {
    // Calculate stats from user data
    final stats = userData.stats ?? {};
    final entriesCount = stats['entries_count'] ?? 0;
    final currentStreak = stats['current_streak'] ?? 0;

    // Format member since date
    final memberSince = _formatMemberSinceDate(userData.createdAt);

    // Get user preferences
    final preferences = userData.preferences ?? {};
    final theme = preferences['theme'] ?? 'System Default';
    final language = preferences['language'] ?? 'English';
    final timezone = userData.timezone ?? 'UTC';

    final spacingM = ResponsiveTokens.spacingM(info);
    final spacingL = ResponsiveTokens.spacingL(info);
    final avatarRadius = info.value(
      compact: 60.0,
      medium: 70.0,
      expanded: 80.0,
    );
    final avatarIconSize = info.value(
      compact: 60.0,
      medium: 70.0,
      expanded: 80.0,
    );

    return ResponsiveBody(
      useSafeArea: false,
      useScrollView: true,
      child: Column(
        children: [
          SizedBox(height: spacingL),

          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.2),
                backgroundImage: userData.avatarUrl != null
                    ? NetworkImage(userData.avatarUrl!)
                    : null,
                child: userData.avatarUrl == null
                    ? Icon(
                        Icons.person,
                        size: avatarIconSize,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacingL),

          // Name
          Text(
            userData.displayName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: spacingM),

          // Email
          Text(userData.email, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: spacingL),

          // Stats cards (InnerGlow Style)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  entriesCount.toString(),
                  'Total Entries',
                  Icons.book,
                ),
              ),
              SizedBox(width: spacingM),
              Expanded(
                child: _buildStatCard(
                  context,
                  currentStreak.toString(),
                  'Current Streak',
                  Icons.local_fire_department,
                ),
              ),
            ],
          ),
          SizedBox(height: spacingM),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  stats['longest_streak']?.toString() ?? '0',
                  'Longest Streak',
                  Icons.emoji_events,
                ),
              ),
              SizedBox(width: spacingM),
              Expanded(
                child: _buildStatCard(
                  context,
                  stats['grace_pieces']?.toString() ?? '0',
                  'Grace Pieces',
                  Icons.favorite,
                ),
              ),
            ],
          ),
          SizedBox(height: spacingL),
          const Divider(),
          SizedBox(height: spacingM),

          // Profile information
          _buildInfoSection(context, 'Personal Information', [
            _buildInfoTile(
              context,
              Icons.person_outline,
              'Display Name',
              userData.displayName,
            ),
            _buildInfoTile(
              context,
              Icons.email_outlined,
              'Email',
              userData.email,
            ),
            _buildInfoTile(
              context,
              Icons.calendar_today,
              'Member Since',
              memberSince,
            ),
            _buildInfoTile(context, Icons.language, 'Language', language),
          ]),
          SizedBox(height: spacingL),

          _buildInfoSection(context, 'Preferences', [
            _buildInfoTile(context, Icons.palette_outlined, 'Theme', theme),
            _buildInfoTile(context, Icons.public, 'Region', 'Auto-detected'),
            _buildInfoTile(context, Icons.schedule, 'Timezone', timezone),
          ]),
          SizedBox(height: spacingL),

          // Settings & Actions (InnerGlow Style)
          _buildInfoSection(context, 'Settings & Actions', [
            _buildActionTile(context, Icons.settings_outlined, 'Settings', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }),
            Consumer(
              builder: (context, ref, child) {
                final privacyLockData = ref.watch(privacyLockProvider);

                return SwitchListTile(
                  title: const Text('Privacy Lock'),
                  subtitle: Text(
                    privacyLockData.isEnabled
                        ? 'Secure your diary with 4-digit PIN'
                        : 'Require authentication to open app',
                  ),
                  secondary: Icon(
                    Icons.lock_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  value: privacyLockData.isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Navigate to PIN setup first (don't enable lock yet)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PinSetupScreen(),
                        ),
                      );
                    } else {
                      // Disable privacy lock
                      final success = await ref
                          .read(privacyLockProvider.notifier)
                          .disablePrivacyLock();

                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to disable privacy lock'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            ),
            _buildActionTile(context, Icons.help_outline, 'Help & Support', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpSupportScreen(),
                ),
              );
            }),
          ]),
          SizedBox(height: spacingL),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _showLogoutDialog(context, ref);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          SizedBox(height: spacingM),

          // Version number (InnerGlow Style)
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacingL),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatMemberSinceDate(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _performLogout(ref);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _performLogout(WidgetRef ref) async {
    try {
      // Show blocking progress while logging out
      if (ref.context.mounted) {
        showDialog(
          context: ref.context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Get user ID before clearing (needed for DB cleanup)
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // Step 1: Clear all user data from local database
      if (userId != null) {
        try {
          await UserDataCleanupService.clearUserData(userId);
        } catch (e) {
          // Log error but continue with logout
          await ErrorLoggingService.logError(
            ErrorContext.fromException(
              errorCode: 'ERRSYS168',
              severity: ErrorSeverity.medium,
              exception: e,
              stackTrace: StackTrace.current,
              errorContext: {
                'user_id': userId,
                'operation': 'logout_data_cleanup',
              },
            ),
          );
        }
      }

      // Step 2: Set flag to indicate data fetch is needed on next login
      try {
        await DataSyncFlagService.setNeedsDataFetch(true);
      } catch (e) {
        // Log error but continue with logout
        await ErrorLoggingService.logError(
          ErrorContext.fromException(
            errorCode: 'ERRSYS169',
            severity: ErrorSeverity.low,
            exception: e,
            stackTrace: StackTrace.current,
            errorContext: {'user_id': userId, 'operation': 'logout_set_flag'},
          ),
        );
      }

      // Step 3: Clear user data (provider state)
      ref.read(userDataProvider.notifier).clearUserData();

      // Step 4: Clear privacy lock (disable and clear all PIN data)
      await ref.read(privacyLockProvider.notifier).disablePrivacyLock();

      // Step 5: Sign out from auth
      await ref.read(authControllerProvider).signOut();

      // Step 6: Navigate directly to LoginScreen
      Future.microtask(() {
        final context = ref.context;
        if (context.mounted) {
          // Dismiss progress dialog if shown
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    } catch (e) {
      // Even if logout fails, try to clear data and set flag
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        try {
          await UserDataCleanupService.clearUserData(userId);
        } catch (_) {
          // Ignore errors in error handler
        }

        try {
          await DataSyncFlagService.setNeedsDataFetch(true);
        } catch (_) {
          // Ignore errors in error handler
        }
      }

      // Clear user data and privacy lock
      ref.read(userDataProvider.notifier).clearUserData();
      await ref.read(privacyLockProvider.notifier).disablePrivacyLock();

      // Log error to Supabase
      await ErrorLoggingService.logError(
        ErrorContext.fromException(
          errorCode: 'ERRAUTH041',
          severity: ErrorSeverity.medium,
          exception: e,
          stackTrace: StackTrace.current,
          errorContext: {
            'logout_attempt_time': DateTime.now().toIso8601String(),
            'user_id': userId,
          },
        ),
      );

      // Show error with code
      if (ref.context.mounted) {
        SnackbarUtils.showError(
          ref.context,
          'Logout failed (ERRAUTH041)',
          'ERRAUTH041',
        );
      }

      Future.microtask(() {
        final context = ref.context;
        if (context.mounted) {
          // Dismiss progress dialog if shown
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    }
  }
}
