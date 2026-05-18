import 'package:flutter/material.dart';
import 'package:culinary_coach_app/features/settings/data/services/app_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// this screen does not need setState, it only reads provider values
// so ConsumerWidget is enough
class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // get dark mode from shared provider
    // watch keeps this page in sync if user changes dark mode in settings
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
          'About App',
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
            'SmartChef',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your cooking assistant for pantry matching, shopping, and guided recipes',
            style: TextStyle(
              color: subtitleColor,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _InfoTile(
            title: 'Version',
            value: '1.0.0',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _InfoTile(
            title: 'Main features',
            value:
                'Recipe matching, start cooking voice guidance, community feed, grocery shopping, and pantry tracking',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _InfoTile(
            title: 'Built with',
            value: 'Flutter + Firebase',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _InfoTile(
            title: 'Support',
            value:
                'For questions or support, contact your project team admin',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.value,
    required this.textColor,
    required this.subtitleColor,
  });

  final String title;
  final String value;
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
            value,
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
