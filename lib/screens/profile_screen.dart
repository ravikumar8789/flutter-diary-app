import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_drawer.dart';
import '../providers/auth_provider.dart';
import '../providers/user_data_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Navigate to edit profile
              },
            ),
          ],
        ),
        drawer: const AppDrawer(currentRoute: 'profile'),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32 : 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 800 : double.infinity,
            ),
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
                      child: Icon(
                        Icons.person,
                        size: isTablet ? 80 : 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
                  'John Doe',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Email
                Text(
                  'john.doe@example.com',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(context, '42', 'Entries'),
                    Container(
                      height: 50,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildStatColumn(context, '7', 'Streak'),
                    Container(
                      height: 50,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildStatColumn(context, '30', 'Days'),
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
                    'John Doe',
                  ),
                  _buildInfoTile(
                    context,
                    Icons.email_outlined,
                    'Email',
                    'john.doe@example.com',
                  ),
                  _buildInfoTile(
                    context,
                    Icons.calendar_today,
                    'Member Since',
                    'January 2024',
                  ),
                  _buildInfoTile(
                    context,
                    Icons.language,
                    'Language',
                    'English',
                  ),
                ]),
                const SizedBox(height: 24),

                _buildInfoSection(context, 'Preferences', [
                  _buildInfoTile(
                    context,
                    Icons.palette_outlined,
                    'Theme',
                    'System Default',
                  ),
                  _buildInfoTile(
                    context,
                    Icons.public,
                    'Region',
                    'United States',
                  ),
                  _buildInfoTile(
                    context,
                    Icons.schedule,
                    'Timezone',
                    'EST (UTC-5)',
                  ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
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
      print('Starting logout...');

      // Clear user data first
      ref.read(userDataProvider.notifier).clearUserData();

      // Then sign out from auth
      await ref.read(authControllerProvider).signOut();
      print('Logout completed - navigating to AuthWrapper');

      // FIXED: Navigate directly to LoginScreen to avoid AuthWrapper loading issues
      Future.microtask(() {
        final context = ref.context;
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
    } catch (e) {
      print('Logout error: $e');
      // Even if logout fails, clear user data and navigate
      ref.read(userDataProvider.notifier).clearUserData();
      Future.microtask(() {
        final context = ref.context;
        if (context.mounted) {
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
