import 'package:flutter/material.dart';
import '../ui/responsive/responsive_body.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    final spacingM = ResponsiveTokens.spacingM(info);
    final spacingL = ResponsiveTokens.spacingL(info);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: ResponsiveBody(
        useSafeArea: true,
        useScrollView: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effective: October 30, 2025',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacingM),
            Text(
              'Your Privacy Matters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: ResponsiveTokens.spacingS(info)),
            Text(
              'This policy explains what we collect, why, and how we protect it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: spacingL),

            _Section(
              title: 'What We Collect',
              bullets: const [
                'Account: email, user ID (via Supabase Auth).',
                'Content: your diary entries, affirmations, gratitude, wellness data.',
                'Preferences: reminders (time/days), theme, paper style, font, privacy lock.',
                'Diagnostics: error codes/logs, app version, platform (no diary text).',
                'Notifications: device token (if enabled) to deliver reminders.',
              ],
            ),
            _Section(
              title: 'How We Use It',
              bullets: const [
                'Provide app features: create, store, and sync your content.',
                'Schedule reminders based on your preferences.',
                'Reliability and support: diagnose issues and improve performance.',
                'Required communications: account verification, password reset.',
              ],
            ),
            _Section(
              title: 'Where It’s Stored',
              bullets: const [
                'Cloud: Supabase (Postgres) for account, content, and selected preferences.',
                'Device: on‑device storage for notification/appearance settings.',
              ],
            ),
            _Section(
              title: 'Retention',
              bullets: const [
                'Your content remains until you delete it or delete your account.',
                'Diagnostics are kept for limited periods to improve reliability.',
              ],
            ),
            _Section(
              title: 'Security',
              bullets: const [
                'Authentication and row‑level security protect your data in Supabase.',
                'Encryption in transit/at rest (per platform). No system is 100% secure.',
              ],
            ),
            _Section(
              title: 'Sharing',
              bullets: const [
                'We do not sell your data or serve third‑party ads.',
                'We share data only with processors needed to run the app (e.g., Supabase).',
                'We may disclose if required by law or to prevent harm.',
              ],
            ),
            _Section(
              title: 'Your Rights',
              bullets: const [
                'Access/Export your data; request correction or deletion.',
                'Disable reminders anytime; uninstall to stop local processing.',
                'GDPR/CCPA: exercise regional rights where applicable.',
              ],
            ),
            _Section(
              title: 'Children',
              bullets: const [
                'Not for users below the digital consent age in your region.',
              ],
            ),
            _Section(
              title: 'International Transfers',
              bullets: const [
                'Data may be processed in other countries subject to legal safeguards.',
              ],
            ),
            _Section(
              title: 'Updates & Contact',
              bullets: const [
                'We may update this policy and will post the effective date.',
                'Questions? Contact support@example.com.',
              ],
            ),

            SizedBox(height: spacingL),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> bullets;
  const _Section({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      b,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


