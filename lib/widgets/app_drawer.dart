import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home_screen.dart';
import '../screens/morning_rituals_screen.dart';
import '../screens/wellness_tracker_screen.dart';
import '../screens/gratitude_reflection_screen.dart';
import '../screens/new_diary_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/notification_test_screen.dart';
import '../providers/user_data_provider.dart';
import '../widgets/streak_display_widget.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataState = ref.watch(userDataProvider);
    final userData = userDataState.userData;
    final userStats = ref.watch(userStatsProvider);
    final isLoading = userDataState.isLoading;

    // Debug prints to see what data we're getting

    return Drawer(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage: userData?.avatarUrl != null
                        ? NetworkImage(userData!.avatarUrl!)
                        : null,
                    child: userData?.avatarUrl == null
                        ? Icon(
                            Icons.person,
                            size: 35,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // User Name
                  if (isLoading && userData == null)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _getDisplayName(userData),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),

                  // User Email
                  if (isLoading && userData == null)
                    const Text(
                      'Please wait...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    )
                  else
                    Text(
                      _getDisplayEmail(userData),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),

                  // Stats Row
                  if (isLoading && userData == null)
                    const Text(
                      'Loading stats...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StreakBadgeWidget(
                          currentStreak: userStats?['current_streak'] ?? 0,
                        ),
                        _buildStatBadge(
                          context,
                          '📝',
                          '${userStats?['entries_count'] ?? 0} entries',
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    title: 'Home',
                    route: 'home',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'home') {
                        // Clear entire stack and set Home as the only screen
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false, // Remove all previous routes
                        );
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.wb_sunny_outlined,
                    selectedIcon: Icons.wb_sunny,
                    title: 'Morning Rituals',
                    route: 'morning',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'morning') {
                        if (currentRoute == 'home') {
                          // Home → Any Main Screen (PUSH - keeps Home in stack)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MorningRitualsScreen(),
                            ),
                          );
                        } else {
                          // Any Main Screen → Any Main Screen (PUSHREPLACEMENT - replaces current, keeps Home)
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MorningRitualsScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.favorite_outline,
                    selectedIcon: Icons.favorite,
                    title: 'Wellness Tracker',
                    route: 'wellness',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'wellness') {
                        if (currentRoute == 'home') {
                          // Home → Any Main Screen (PUSH - keeps Home in stack)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WellnessTrackerScreen(),
                            ),
                          );
                        } else {
                          // Any Main Screen → Any Main Screen (PUSHREPLACEMENT - replaces current, keeps Home)
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WellnessTrackerScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.auto_awesome_outlined,
                    selectedIcon: Icons.auto_awesome,
                    title: 'Gratitude',
                    route: 'gratitude',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'gratitude') {
                        if (currentRoute == 'home') {
                          // Home → Any Main Screen (PUSH - keeps Home in stack)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GratitudeReflectionScreen(),
                            ),
                          );
                        } else {
                          // Any Main Screen → Any Main Screen (PUSHREPLACEMENT - replaces current, keeps Home)
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const GratitudeReflectionScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.edit_note_outlined,
                    selectedIcon: Icons.edit_note,
                    title: 'Daily Diary',
                    route: 'diary',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'diary') {
                        // Modal Screen - always use PUSH (stacks on current)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewDiaryScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _buildDrawerItem(
                    context,
                    icon: Icons.analytics_outlined,
                    selectedIcon: Icons.analytics,
                    title: 'Analytics',
                    route: 'analytics',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'analytics') {
                        if (currentRoute == 'home') {
                          // Home → Any Main Screen (PUSH - keeps Home in stack)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AnalyticsScreen(),
                            ),
                          );
                        } else {
                          // Any Main Screen → Any Main Screen (PUSHREPLACEMENT - replaces current, keeps Home)
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AnalyticsScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history,
                    title: 'History',
                    route: 'history',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'history') {
                        if (currentRoute == 'home') {
                          // Home → Any Main Screen (PUSH - keeps Home in stack)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        } else {
                          // Any Main Screen → Any Main Screen (PUSHREPLACEMENT - replaces current, keeps Home)
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    title: 'Profile',
                    route: 'profile',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'profile') {
                        if (currentRoute == 'home') {
                          // Home → Any Main Screen (PUSH - keeps Home in stack)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        } else {
                          // Any Main Screen → Any Main Screen (PUSHREPLACEMENT - replaces current, keeps Home)
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 24, indent: 16, endIndent: 16),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    title: 'Settings',
                    route: 'settings',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'settings') {
                        // Modal Screen - always use PUSH (stacks on current)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.notifications_outlined,
                    selectedIcon: Icons.notifications,
                    title: 'Notification Test',
                    route: 'notification_test',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != 'notification_test') {
                        // Modal Screen - always use PUSH (stacks on current)
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationTestScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // App Version
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Diary App v1.0.0',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(BuildContext context, String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required String route,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isSelected = currentRoute == route;
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).textTheme.bodyLarge?.color;

    return ListTile(
      leading: Icon(isSelected ? selectedIcon : icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
    );
  }

  String _getDisplayName(userData) {
    if (userData?.displayName != null && userData!.displayName.isNotEmpty) {
      return userData.displayName;
    } else if (userData?.email != null && userData!.email.isNotEmpty) {
      return userData.email.split('@')[0];
    }
    return 'User';
  }

  String _getDisplayEmail(userData) {
    if (userData?.email != null && userData!.email.isNotEmpty) {
      return userData.email;
    }
    return 'No email available';
  }
}
