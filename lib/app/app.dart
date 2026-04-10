import 'package:culinary_coach_app/app/router/app_router.dart';
import 'package:culinary_coach_app/app/theme/app_theme.dart';
import 'package:culinary_coach_app/features/auth/data/services/auth_service.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:culinary_coach_app/app/shell/presentation/screens/main_shell_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SmartChefApp extends StatelessWidget {
  const SmartChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartChef',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
