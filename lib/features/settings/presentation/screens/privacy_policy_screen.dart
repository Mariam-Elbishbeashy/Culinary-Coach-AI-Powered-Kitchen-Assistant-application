import 'package:flutter/material.dart';
import 'package:culinary_coach_app/features/settings/data/services/app_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// this page only needs to read dark mode from riverpod
// no local setState is needed, so ConsumerWidget is enough
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // read dark mode from shared provider
    // watch makes the page update automatically if mode changes
    final isDarkMode = ref.watch(darkModeProvider);
    final background = isDarkMode
        ? const Color(0xFF141414)
        : const Color(0xFFFFFAF4);
    final textColor = isDarkMode
        ? const Color(0xFFF2F2F2)
        : const Color(0xFF24180E);
    final subtitleColor = isDarkMode
        ? const Color(0xFFB5B5B5)
        : const Color(0xFF756452);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text(
            'Your privacy matters to us',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 23,
            ),
          ),
          const SizedBox(height: 8),
          _PolicySection(
            title: 'Information we collect',
            body:
                'We may collect account details, pantry selections, recipe history, and app usage actions to provide the SmartChef experience.',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _PolicySection(
            title: 'How data is used',
            body:
                'Your data is used to personalize recipe matching, improve shopping suggestions, and store your app settings and preferences.',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _PolicySection(
            title: 'Data storage',
            body:
                'App data is stored in your project backend (Firebase services configured in this app). Access is limited to authorized app flows.',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _PolicySection(
            title: 'Your control',
            body:
                'You can edit your profile, remove recipe history items, adjust settings, and request account data handling according to your project policy.',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _PolicySection(
            title: 'Policy updates',
            body:
                'This policy may be updated in future app versions. Major changes should be announced inside the app.',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.body,
    required this.textColor,
    required this.subtitleColor,
  });

  final String title;
  final String body;
  final Color textColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: subtitleColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              color: subtitleColor,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
