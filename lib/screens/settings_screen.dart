import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_drawer.dart';
import '../services/notification_service.dart';
import '../providers/theme_provider.dart';
import '../providers/paper_style_provider.dart';
import '../providers/font_size_provider.dart';
import '../providers/privacy_lock_provider.dart';
import '../providers/grace_system_provider.dart';
import '../widgets/grace_system_info_card.dart';
import '../providers/auth_provider.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/privacy_policy_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  // Remove _theme variable as we'll use the provider
  // Remove _fontSize variable as we'll use the provider
  // Remove _paperStyle variable as we'll use the provider
  // Remove _privacyLock variable as we'll use the provider

  List<bool> _reminderDays = [true, true, true, true, true, true, true];
  final List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final settings = await NotificationService.instance
          .getNotificationSettings();
      setState(() {
        _reminderEnabled = settings.notificationsEnabled;
        _reminderTime = settings.morningTime;
        _reminderDays = List.generate(
          7,
          (index) => settings.activeDays.contains(index + 1),
        );
      });
    } catch (e) {
      // Use default values if loading fails
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final activeDays = <int>[];
      for (int i = 0; i < _reminderDays.length; i++) {
        if (_reminderDays[i]) {
          activeDays.add(i + 1);
        }
      }

      final settings = NotificationSettings(
        morningTime: _reminderTime,
        activeDays: activeDays,
        notificationsEnabled: _reminderEnabled,
      );

      await NotificationService.instance.updateNotificationSettings(settings);
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(currentRoute: 'settings'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 32 : 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 800 : double.infinity,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notifications
              _buildSectionTitle(context, 'Notifications'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Daily Reminder'),
                      subtitle: const Text('Get reminded to write your entry'),
                      value: _reminderEnabled,
                      onChanged: (value) {
                        setState(() => _reminderEnabled = value);
                        _saveNotificationSettings();
                      },
                    ),
                    if (_reminderEnabled) ...[
                      ListTile(
                        title: const Text('Reminder Time'),
                        subtitle: Text(_reminderTime.format(context)),
                        leading: const Icon(Icons.access_time),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _reminderTime,
                          );
                          if (time != null) {
                            setState(() => _reminderTime = time);
                            _saveNotificationSettings();
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reminder Days',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: List.generate(7, (index) {
                                return FilterChip(
                                  label: Text(_dayLabels[index]),
                                  selected: _reminderDays[index],
                                  onSelected: (value) {
                                    setState(
                                      () => _reminderDays[index] = value,
                                    );
                                    _saveNotificationSettings();
                                  },
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Appearance
              _buildSectionTitle(context, 'Appearance'),
              Card(
                child: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final themeNotifier = ref.watch(themeProvider.notifier);

                        return ListTile(
                          title: const Text('Theme'),
                          subtitle: Text(themeNotifier.currentThemeDisplayName),
                          leading: const Icon(Icons.palette_outlined),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _showThemeDialog(ref);
                          },
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final fontSizeNotifier = ref.watch(
                          fontSizeProvider.notifier,
                        );

                        return ListTile(
                          title: const Text('Font Size'),
                          subtitle: Text(
                            fontSizeNotifier.currentFontSizeDisplayName,
                          ),
                          leading: const Icon(Icons.text_fields),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _showFontSizeDialog(ref);
                          },
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final paperStyleNotifier = ref.watch(
                          paperStyleProvider.notifier,
                        );

                        return ListTile(
                          title: const Text('Paper Style'),
                          subtitle: Text(
                            paperStyleNotifier.currentPaperStyleDisplayName,
                          ),
                          leading: const Icon(Icons.note_outlined),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _showPaperStyleDialog(ref);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy & Security
              _buildSectionTitle(context, 'Privacy & Security'),
              Card(
                child: Column(
                  children: [
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
                          value: privacyLockData.isEnabled,
                          onChanged: (value) async {
                            if (value) {
                              // Navigate to PIN setup first (don't enable lock yet)
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PinSetupScreen(),
                                ),
                              );
                            } else {
                              // Disable privacy lock
                              final success = await ref
                                  .read(privacyLockProvider.notifier)
                                  .disablePrivacyLock();

                              if (!success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to disable privacy lock',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final privacyLockData = ref.watch(privacyLockProvider);

                        if (!privacyLockData.isEnabled) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          title: const Text('Change PIN'),
                          subtitle: const Text('Update your 4-digit PIN'),
                          leading: const Icon(Icons.lock_outline),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _showChangePinDialog(ref);
                          },
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final privacyLockData = ref.watch(privacyLockProvider);

                        if (!privacyLockData.isEnabled) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          title: const Text('Auto-Lock Timeout'),
                          subtitle: Text(
                            '${privacyLockData.autoLockTimeout} minutes',
                          ),
                          leading: const Icon(Icons.timer_outlined),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _showAutoLockDialog(ref);
                          },
                        );
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final privacyLockData = ref.watch(privacyLockProvider);

                        if (!privacyLockData.isEnabled) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          title: const Text('Security Questions'),
                          subtitle: const Text('For PIN recovery'),
                          leading: const Icon(Icons.help_outline),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            _showSecurityQuestionsDialog(ref);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Journaling
              _buildSectionTitle(context, 'Journaling'),
              _buildGraceSystemSection(context),
              const SizedBox(height: 24),

              // About
              _buildSectionTitle(context, 'About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Version'),
                      subtitle: const Text('1.0.0'),
                      leading: const Icon(Icons.info_outline),
                    ),
                    ListTile(
                      title: const Text('Terms of Service'),
                      leading: const Icon(Icons.description_outlined),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Privacy Policy'),
                      leading: const Icon(Icons.privacy_tip_outlined),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildGraceSystemSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final graceState = ref.watch(graceSystemProvider);
        final authRepo = ref.watch(authRepositoryProvider);
        final currentUser = authRepo.currentUser;

        // Initialize grace system provider when user data is available
        if (currentUser != null &&
            !graceState.isLoading &&
            graceState.graceDaysAvailable == 0 &&
            graceState.gracePiecesTotal == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(graceSystemProvider.notifier).initialize(currentUser.id);
          });
        }

        return Card(
          child: Column(
            children: [
              // Header with info button
              ListTile(
                title: const Text('Grace Days System'),
                subtitle: const Text('Earn protection for your streak'),
                leading: const Icon(Icons.favorite, color: Colors.blue),
                trailing: const GraceSystemInfoButton(),
              ),

              const Divider(height: 1),

              // Grace Days Available
              ListTile(
                title: const Text('Grace Days Available'),
                subtitle: Text(
                  graceState.graceDaysAvailable > 0
                      ? '${graceState.graceDaysAvailable} grace days earned'
                      : 'Complete daily tasks to earn grace days',
                ),
                leading: Icon(
                  Icons.shield,
                  color: graceState.graceDaysAvailable > 0
                      ? Colors.green
                      : Colors.grey,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: graceState.graceDaysAvailable > 0
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${graceState.graceDaysAvailable}',
                    style: TextStyle(
                      color: graceState.graceDaysAvailable > 0
                          ? Colors.green.shade800
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Today's Progress
              ListTile(
                title: const Text('Today\'s Progress'),
                subtitle: Text(
                  '${graceState.tasksCompletedToday}/4 tasks completed',
                ),
                leading: const Icon(Icons.today, color: Colors.orange),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${graceState.piecesToday.toStringAsFixed(1)}/2.0 pieces',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        value: graceState.progressPercentage / 100.0,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          graceState.progressPercentage >= 100
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Total Progress
              ListTile(
                title: const Text('Total Earned'),
                subtitle: Text(
                  '${graceState.gracePiecesTotal.toStringAsFixed(1)} pieces total',
                ),
                leading: const Icon(Icons.trending_up, color: Colors.purple),
                trailing: Text(
                  '${(graceState.gracePiecesTotal / 10).floor()} grace days',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),

              // Error handling
              if (graceState.error != null) ...[
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    'Error: ${graceState.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(graceSystemProvider.notifier).clearError();
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showThemeDialog(WidgetRef ref) {
    final currentTheme = ref.read(themeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setThemeMode(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setThemeMode(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setThemeMode(value);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog(WidgetRef ref) {
    final currentFontSize = ref.read(fontSizeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<FontSize>(
              title: const Text('Small'),
              value: FontSize.small,
              groupValue: currentFontSize,
              onChanged: (value) {
                if (value != null) {
                  ref.read(fontSizeProvider.notifier).setFontSize(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<FontSize>(
              title: const Text('Medium'),
              value: FontSize.medium,
              groupValue: currentFontSize,
              onChanged: (value) {
                if (value != null) {
                  ref.read(fontSizeProvider.notifier).setFontSize(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<FontSize>(
              title: const Text('Large'),
              value: FontSize.large,
              groupValue: currentFontSize,
              onChanged: (value) {
                if (value != null) {
                  ref.read(fontSizeProvider.notifier).setFontSize(value);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaperStyleDialog(WidgetRef ref) {
    final currentPaperStyle = ref.read(paperStyleProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Paper Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<PaperStyle>(
              title: const Text('Plain'),
              value: PaperStyle.plain,
              groupValue: currentPaperStyle,
              onChanged: (value) {
                if (value != null) {
                  ref.read(paperStyleProvider.notifier).setPaperStyle(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<PaperStyle>(
              title: const Text('Ruled'),
              value: PaperStyle.ruled,
              groupValue: currentPaperStyle,
              onChanged: (value) {
                if (value != null) {
                  ref.read(paperStyleProvider.notifier).setPaperStyle(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<PaperStyle>(
              title: const Text('Grid'),
              value: PaperStyle.grid,
              groupValue: currentPaperStyle,
              onChanged: (value) {
                if (value != null) {
                  ref.read(paperStyleProvider.notifier).setPaperStyle(value);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change PIN'),
        content: const Text(
          'To change your PIN, you need to enter your current PIN first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to change PIN screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Change PIN feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showAutoLockDialog(WidgetRef ref) {
    final currentTimeout = ref.read(privacyLockProvider).autoLockTimeout;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Lock Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('Never'),
              value: 0,
              groupValue: currentTimeout,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(privacyLockProvider.notifier)
                      .setAutoLockTimeout(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('1 minute'),
              value: 1,
              groupValue: currentTimeout,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(privacyLockProvider.notifier)
                      .setAutoLockTimeout(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('5 minutes'),
              value: 5,
              groupValue: currentTimeout,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(privacyLockProvider.notifier)
                      .setAutoLockTimeout(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('15 minutes'),
              value: 15,
              groupValue: currentTimeout,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(privacyLockProvider.notifier)
                      .setAutoLockTimeout(value);
                }
                Navigator.pop(context);
              },
            ),
            RadioListTile<int>(
              title: const Text('30 minutes'),
              value: 30,
              groupValue: currentTimeout,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(privacyLockProvider.notifier)
                      .setAutoLockTimeout(value);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityQuestionsDialog(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Questions'),
        content: const Text(
          'Set up security questions to recover your PIN if you forget it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to security questions screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Security questions feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Set Up'),
          ),
        ],
      ),
    );
  }
}
