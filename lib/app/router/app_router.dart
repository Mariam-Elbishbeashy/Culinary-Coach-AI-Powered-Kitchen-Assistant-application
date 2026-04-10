import 'package:culinary_coach_app/features/auth/presentation/screens/login_screen.dart';
import 'package:culinary_coach_app/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:culinary_coach_app/app/shell/presentation/screens/main_shell_screen.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static const String onboarding = '/';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String shell = '/shell';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute<void>(builder: (_) => const LoginScreen());
      case signUp:
        return MaterialPageRoute<void>(builder: (_) => const SignUpScreen());
      case shell:
        return MaterialPageRoute<void>(builder: (_) => const MainShellScreen());
      case onboarding:
      default:
        final initialPageArg = settings.arguments;
        final initialPage = initialPageArg is int ? initialPageArg : 0;
        return MaterialPageRoute<void>(
          builder: (_) => OnboardingScreen(initialPage: initialPage),
        );
    }
  }
}
