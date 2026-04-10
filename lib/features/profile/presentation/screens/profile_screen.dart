import 'package:culinary_coach_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authController = AuthController();

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _authController.logout();
    if (!mounted) return;

    if (_authController.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authController.errorMessage!)));
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const OnboardingScreen(initialPage: 4),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: FilledButton.icon(
            onPressed: _authController.isLoading ? null : _logout,
            icon: _authController.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(
              _authController.isLoading ? 'Signing out...' : 'Logout',
            ),
          ),
        ),
      ),
    );
  }
}
