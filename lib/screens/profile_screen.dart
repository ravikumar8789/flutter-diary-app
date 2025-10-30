import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_drawer.dart';
import '../widgets/streak_display_widget.dart';
import '../providers/auth_provider.dart';
import '../providers/user_data_provider.dart';
import '../utils/snackbar_utils.dart';
import '../services/error_logging_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final userDataState = ref.watch(userDataProvider);

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
        appBar: AppBar(title: const Text('Profile')),
        drawer: const AppDrawer(currentRoute: 'profile'),
        body: userDataState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : userDataState.error != null
            ? _buildErrorState(context, userDataState.error!, ref)
            : userDataState.userData == null
            ? _buildNoDataState(context, ref)
            : _buildProfileContent(
                context,
                userDataState.userData!,
                isTablet,
                ref,
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
    bool isTablet,
    WidgetRef ref,
  ) {
    // Calculate stats from user data
    final stats = userData.stats ?? {};
    final entriesCount = stats['total_entries'] ?? 0;
    final currentStreak = stats['current_streak'] ?? 0;
    final daysSinceJoined = DateTime.now()
        .difference(userData.createdAt)
        .inDays;

    // Format member since date
    final memberSince = _formatMemberSinceDate(userData.createdAt);

    // Get user preferences
    final preferences = userData.preferences ?? {};
    final theme = preferences['theme'] ?? 'System Default';
    final language = preferences['language'] ?? 'English';
    final timezone = preferences['timezone'] ?? 'UTC';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 32 : 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: isTablet ? 80 : 60,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.2),
                  backgroundImage: userData.avatarUrl != null
                      ? NetworkImage(userData.avatarUrl!)
                      : null,
                  child: userData.avatarUrl == null
                      ? Icon(
                          Icons.person,
                          size: isTablet ? 80 : 60,
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
            const SizedBox(height: 24),

            // Name
            Text(
              userData.displayName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),

            // Email
            Text(userData.email, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn(context, entriesCount.toString(), 'Entries'),
                Container(height: 50, width: 1, color: Colors.grey.shade300),
                _buildStreakColumn(context, currentStreak),
                Container(height: 50, width: 1, color: Colors.grey.shade300),
                _buildStatColumn(context, daysSinceJoined.toString(), 'Days'),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

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
            const SizedBox(height: 24),

            _buildInfoSection(context, 'Preferences', [
              _buildInfoTile(context, Icons.palette_outlined, 'Theme', theme),
              _buildInfoTile(context, Icons.public, 'Region', 'Auto-detected'),
              _buildInfoTile(context, Icons.schedule, 'Timezone', timezone),
            ]),
            const SizedBox(height: 24),

            _buildInfoSection(context, 'Account', [
              _buildActionTile(
                context,
                Icons.shield_outlined,
                'Privacy & Security',
                () {},
              ),
              _buildActionTile(
                context,
                Icons.download_outlined,
                'Export Data',
                () {},
              ),
              _buildActionTile(
                context,
                Icons.help_outline,
                'Help & Support',
                () {},
              ),
            ]),
            const SizedBox(height: 24),

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
            const SizedBox(height: 16),

            // Delete account
            TextButton(
              onPressed: () {
                _showDeleteAccountDialog(context);
              },
              child: Text(
                'Delete Account',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildStreakColumn(BuildContext context, int currentStreak) {
    return Column(
      children: [
        StreakDisplayWidget(currentStreak: currentStreak, isCompact: true),
        const SizedBox(height: 4),
        const Text('Streak', style: TextStyle(fontSize: 12)),
      ],
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
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      // Clear user data first
      ref.read(userDataProvider.notifier).clearUserData();

      // Then sign out from auth
      await ref.read(authControllerProvider).signOut();

      // FIXED: Navigate directly to LoginScreen to avoid AuthWrapper loading issues
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
      // Even if logout fails, clear user data and navigate
      ref.read(userDataProvider.notifier).clearUserData();

      // Log error to Supabase
      await ErrorLoggingService.logError(
        errorCode: 'ERRAUTH041',
        errorMessage: 'Logout failed: ${e.toString()}',
        stackTrace: StackTrace.current.toString(),
        severity: 'MEDIUM',
        errorContext: {
          'logout_attempt_time': DateTime.now().toIso8601String(),
          'user_id': Supabase.instance.client.auth.currentUser?.id,
        },
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

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
