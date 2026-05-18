import 'package:culinary_coach_app/app/router/app_router.dart';
import 'package:culinary_coach_app/app/theme/app_theme.dart';
import 'package:culinary_coach_app/features/auth/data/services/auth_service.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:culinary_coach_app/app/shell/presentation/screens/main_shell_screen.dart';
import 'package:culinary_coach_app/features/settings/data/services/app_settings_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ConsumerWidget is like StatelessWidget but with access to riverpod via ref
class SmartChefApp extends ConsumerWidget {
  const SmartChefApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch means this widget listens to provider value changes
    // when darkModeProvider changes, MaterialApp rebuilds with new themeMode
    final isDarkMode = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'SmartChef',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const _AuthSessionGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

class _AuthSessionGate extends StatelessWidget {
  const _AuthSessionGate();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != null) {
          // Backfill existing signed-in users into Firestore users collection.
          authService.ensureUserRecordForCurrentSession();
          return const MainShellScreen();
        }
        return const OnboardingScreen();
      },
    );
  }
}
