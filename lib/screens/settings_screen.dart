import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _streakCompassion = true;
  bool _privacyLock = false;
  String _theme = 'system';
  String _fontSize = 'medium';
  String _paperStyle = 'ruled';

  final List<bool> _reminderDays = [true, true, true, true, true, true, true];
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
                    ListTile(
                      title: const Text('Theme'),
                      subtitle: Text(
                        _theme == 'system'
                            ? 'System Default'
                            : _theme == 'light'
                            ? 'Light'
                            : 'Dark',
                      ),
                      leading: const Icon(Icons.palette_outlined),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showThemeDialog();
                      },
                    ),
                    ListTile(
                      title: const Text('Font Size'),
                      subtitle: Text(
                        _fontSize[0].toUpperCase() + _fontSize.substring(1),
                      ),
                      leading: const Icon(Icons.text_fields),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showFontSizeDialog();
                      },
                    ),
                    ListTile(
                      title: const Text('Paper Style'),
                      subtitle: Text(
                        _paperStyle[0].toUpperCase() + _paperStyle.substring(1),
                      ),
                      leading: const Icon(Icons.note_outlined),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showPaperStyleDialog();
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
                    SwitchListTile(
                      title: const Text('Privacy Lock'),
                      subtitle: const Text(
                        'Require authentication to open app',
                      ),
                      value: _privacyLock,
                      onChanged: (value) {
                        setState(() => _privacyLock = value);
                      },
                    ),
                    ListTile(
                      title: const Text('Change Password'),
                      leading: const Icon(Icons.lock_outline),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Implement change password
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Journaling
              _buildSectionTitle(context, 'Journaling'),
              Card(
                child: SwitchListTile(
                  title: const Text('Streak Compassion'),
                  subtitle: const Text('Allow grace period for missed days'),
                  value: _streakCompassion,
                  onChanged: (value) {
                    setState(() => _streakCompassion = value);
                  },
                ),
              ),
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
                        // TODO: Open terms
                      },
                    ),
                    ListTile(
                      title: const Text('Privacy Policy'),
                      leading: const Icon(Icons.privacy_tip_outlined),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Open privacy policy
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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('System Default'),
              value: 'system',
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'light',
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'dark',
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Small'),
              value: 'small',
              groupValue: _fontSize,
              onChanged: (value) {
                setState(() => _fontSize = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Medium'),
              value: 'medium',
              groupValue: _fontSize,
              onChanged: (value) {
                setState(() => _fontSize = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Large'),
              value: 'large',
              groupValue: _fontSize,
              onChanged: (value) {
                setState(() => _fontSize = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaperStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Paper Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Plain'),
              value: 'plain',
              groupValue: _paperStyle,
              onChanged: (value) {
                setState(() => _paperStyle = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Ruled'),
              value: 'ruled',
              groupValue: _paperStyle,
              onChanged: (value) {
                setState(() => _paperStyle = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Grid'),
              value: 'grid',
              groupValue: _paperStyle,
              onChanged: (value) {
                setState(() => _paperStyle = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
