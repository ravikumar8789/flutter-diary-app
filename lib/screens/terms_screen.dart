import 'package:flutter/material.dart';
import '../ui/responsive/responsive_body.dart';
import '../ui/responsive/responsive_info.dart';
import '../ui/responsive/responsive_tokens.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    final spacingM = ResponsiveTokens.spacingM(info);
    final spacingL = ResponsiveTokens.spacingL(info);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              'Welcome to Diary App',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: ResponsiveTokens.spacingS(info)),
            Text(
              'These terms govern your use of the app. By using it, you agree to them.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: spacingL),

            _Section(
              title: 'Purpose',
              body:
                  'This is a journaling and wellness app. It is not medical or mental‑health advice.',
            ),
            _Section(
              title: 'Account & Eligibility',
              body:
                  'Provide accurate info and keep credentials secure. You must meet the digital consent age in your region.',
            ),
            _Section(
              title: 'Your Content',
              body:
                  'You own your entries. You grant us a limited license to store and process them to operate features like sync, reminders, and analytics.',
            ),
            _Section(
              title: 'Privacy',
              body:
                  'See the Privacy Policy for how we collect, use, and protect data. We use trusted infrastructure and best practices, but no system is 100% secure.',
            ),
            _Section(
              title: 'Payments',
              body:
                  'If paid features exist, pricing, renewals, trials, and refunds are described at purchase time.',
            ),
            _Section(
              title: 'Acceptable Use',
              body:
                  'No illegal content, abuse, scraping, or reverse engineering. Respect others and the platform.',
            ),
            _Section(
              title: 'Availability & Changes',
              body:
                  'The service may change, pause, or end. Backups and retention are best‑effort and may be limited.',
            ),
            _Section(
              title: 'Intellectual Property',
              body:
                  'App branding, code, and materials are owned by us or our licensors. Your content remains yours.',
            ),
            _Section(
              title: 'Disclaimers & Liability',
              body:
                  'The app is provided “as is” without warranties. Our liability is limited to the maximum allowed by law.',
            ),
            _Section(
              title: 'Governing Law',
              body:
                  'These terms are governed by applicable local law. Disputes are resolved in the designated venue.',
            ),
            _Section(
              title: 'Updates',
              body:
                  'We may update these terms. Continued use after changes means you accept the new terms.',
            ),
            _Section(
              title: 'Contact',
              body:
                  'Questions? Contact support at support@example.com.',
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
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveTokens.spacingM(info)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: ResponsiveTokens.spacingS(info)),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}


