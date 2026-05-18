import 'package:culinary_coach_app/app/router/app_router.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // these controllers keep all sign-up form values in memory until submit
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // auth controller performs validation + firebase auth + error/loading updates
  final _authController = AuthController();
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    // sign up request includes identity fields + password confirmation
    final ok = await _authController.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
    );

    if (!mounted) return;
    if (ok) {
      // on success user goes directly to app shell
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.shell, (_) => false);
    }
  }

  Future<void> _continueWithGoogle() async {
    // optional auth path using google sign in
    final ok = await _authController.signInWithGoogle();
    if (!mounted) return;

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.shell, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      // listens to auth controller so button/loading/error update automatically
      animation: _authController,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF3E8DF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2210),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconCircleButton(
                        onTap: () => Navigator.pop(context),
                        icon: Icons.arrow_back_ios_new_rounded,
                      ),
                      const Spacer(),
                      Text(
                        'SmartChef',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 36),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create an\nAccount',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Start your SmartChef journey with AI ingredient scanning, guided cooking mode, and a social food community.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DarkAuthTextField(
                          controller: _firstNameController,
                          enabled: !_authController.isLoading,
                          label: 'First name',
                          hintText: 'First name',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DarkAuthTextField(
                          controller: _lastNameController,
                          enabled: !_authController.isLoading,
                          label: 'Last name',
                          hintText: 'Last name',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  _DarkAuthTextField(
                    controller: _emailController,
                    enabled: !_authController.isLoading,
                    label: 'Email address',
                    hintText: 'example@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 13),
                  _DarkAuthTextField(
                    controller: _passwordController,
                    enabled: !_authController.isLoading,
                    label: 'Password',
                    hintText: 'Create a secure password',
                    obscureText: _isPasswordObscured,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _isPasswordObscured = !_isPasswordObscured;
                        });
                      },
                      icon: Icon(
                        _isPasswordObscured
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  _DarkAuthTextField(
                    controller: _confirmPasswordController,
                    enabled: !_authController.isLoading,
                    label: 'Confirm password',
                    hintText: 'Re-enter your password',
                    obscureText: _isConfirmPasswordObscured,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordObscured =
                              !_isConfirmPasswordObscured;
                        });
                      },
                      icon: Icon(
                        _isConfirmPasswordObscured
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  if (_authController.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _authController.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFFB3B3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _authController.isLoading ? null : _signUp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _authController.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.25),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'or',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.25),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  _SocialButton(
                    label: 'G  Continue with Google',
                    onTap: _authController.isLoading
                        ? null
                        : _continueWithGoogle,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRouter.login,
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account?  ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.52),
                          ),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkAuthTextField extends StatelessWidget {
  const _DarkAuthTextField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white54),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          color: Colors.white.withValues(alpha: onTap == null ? 0.03 : 0.06),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
