import 'package:flutter/material.dart';
import 'package:culinary_coach_app/features/settings/data/services/app_settings_controller.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/about_app_screen.dart';
import 'package:culinary_coach_app/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// we use ConsumerStatefulWidget because this screen has two kinds of state
// local state: switches like notifications, language dropdown, etc
// global state: dark mode from riverpod provider
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _autoPlayCookingVoice = true;
  bool _hapticFeedback = true;
  bool _dataSaver = false;
  String _selectedLanguage = 'English';
  String _selectedUnits = 'Metric';

  void _openAboutApp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutAppScreen()));
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // read current dark mode value from shared provider
    // using watch makes this screen rebuild when dark mode changes
    final isDarkMode = ref.watch(darkModeProvider);
    final background = isDarkMode
        ? const Color(0xFF141414)
        : const Color(0xFFFFFAF4);
    final cardColor = isDarkMode
        ? const Color(0xFF242424)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode
        ? const Color(0xFFF2F2F2)
        : const Color(0xFF24180E);
    final subtitleColor = isDarkMode
        ? const Color(0xFFB5B5B5)
        : const Color(0xFF756452);
    final borderColor = isDarkMode
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE8DCCF);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        foregroundColor: textColor,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _SectionCard(
            title: 'Appearance',
            titleColor: textColor,
            cardColor: cardColor,
            borderColor: borderColor,
            children: [
              SwitchListTile(
                value: isDarkMode,
                // this line writes the new value into the shared provider
                // because app.dart watches the same provider, theme changes globally
                onChanged: (value) =>
                    ref.read(darkModeProvider.notifier).state = value,
                title: Text(
                  'Dark mode',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Use darker colors across the app shell',
                  style: TextStyle(color: subtitleColor),
                ),
                activeThumbColor: const Color(0xFFE08B14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
                title: 'Notifications',
                titleColor: textColor,
                cardColor: cardColor,
                borderColor: borderColor,
                children: [
                  SwitchListTile(
                    value: _pushNotifications,
                    onChanged: (value) =>
                        setState(() => _pushNotifications = value),
                    title: Text(
                      'Push notifications',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Recipe updates and reminders',
                      style: TextStyle(color: subtitleColor),
                    ),
                    activeThumbColor: const Color(0xFFE08B14),
                  ),
                  SwitchListTile(
                    value: _emailNotifications,
                    onChanged: (value) =>
                        setState(() => _emailNotifications = value),
                    title: Text(
                      'Email notifications',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Weekly summaries and announcements',
                      style: TextStyle(color: subtitleColor),
                    ),
                    activeThumbColor: const Color(0xFFE08B14),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          _SectionCard(
                title: 'Cooking',
                titleColor: textColor,
                cardColor: cardColor,
                borderColor: borderColor,
                children: [
                  SwitchListTile(
                    value: _autoPlayCookingVoice,
                    onChanged: (value) =>
                        setState(() => _autoPlayCookingVoice = value),
                    title: Text(
                      'Auto-play cooking voice',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Speak steps automatically in start cooking',
                      style: TextStyle(color: subtitleColor),
                    ),
                    activeThumbColor: const Color(0xFFE08B14),
                  ),
                  ListTile(
                    title: Text(
                      'Measurement units',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _selectedUnits,
                      style: TextStyle(color: subtitleColor),
                    ),
                    trailing: DropdownButton<String>(
                      value: _selectedUnits,
                      items: const [
                        DropdownMenuItem(
                          value: 'Metric',
                          child: Text('Metric'),
                        ),
                        DropdownMenuItem(
                          value: 'Imperial',
                          child: Text('Imperial'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedUnits = value);
                      },
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          _SectionCard(
                title: 'General',
                titleColor: textColor,
                cardColor: cardColor,
                borderColor: borderColor,
                children: [
                  ListTile(
                    title: Text(
                      'Language',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _selectedLanguage,
                      style: TextStyle(color: subtitleColor),
                    ),
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      items: const [
                        DropdownMenuItem(
                          value: 'English',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'Arabic',
                          child: Text('Arabic'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedLanguage = value);
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Privacy policy',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'How we handle your data',
                      style: TextStyle(color: subtitleColor),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openPrivacyPolicy,
                  ),
                  ListTile(
                    title: Text(
                      'About app',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Version and app info',
                      style: TextStyle(color: subtitleColor),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _openAboutApp,
                  ),
                ],
              ),
          const SizedBox(height: 12),
          _SectionCard(
                title: 'Accessibility',
                titleColor: textColor,
                cardColor: cardColor,
                borderColor: borderColor,
                children: [
                  SwitchListTile(
                    value: _hapticFeedback,
                    onChanged: (value) =>
                        setState(() => _hapticFeedback = value),
                    title: Text(
                      'Haptic feedback',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Vibration feedback for taps and actions',
                      style: TextStyle(color: subtitleColor),
                    ),
                    activeThumbColor: const Color(0xFFE08B14),
                  ),
                  SwitchListTile(
                    value: _dataSaver,
                    onChanged: (value) => setState(() => _dataSaver = value),
                    title: Text(
                      'Data saver mode',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Reduce heavy media loading when possible',
                      style: TextStyle(color: subtitleColor),
                    ),
                    activeThumbColor: const Color(0xFFE08B14),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.titleColor,
    required this.cardColor,
    required this.borderColor,
    required this.children,
  });

  final String title;
  final Color titleColor;
  final Color cardColor;
  final Color borderColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
