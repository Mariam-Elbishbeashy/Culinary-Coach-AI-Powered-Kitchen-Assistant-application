import 'package:culinary_coach_app/app/router/app_router.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/constants/app_assets.dart';
import 'package:culinary_coach_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// google_fonts still used by story slides and sign-up CTA

// ─── Root ─────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingScreen> {
  // page controller drives onboarding slide navigation programmatically
  late final PageController _pageController;
  // auth controller is used here for google sign in from final onboarding slide
  final AuthController _authController = AuthController();
  int _currentPage = 0;

  // Indices: 0 = splash, 1-3 = story slides, 4 = sign-up
  static const List<_SlideData> _stories = [
    _SlideData(
      title: 'Scan Your\nIngredients',
      description:
          'Use camera scanning or manual selection to detect what is in your kitchen and unlock recipe ideas instantly.',
      imagePath: AppAssets.scanPic,
      blobColor: Color(0xFFCB6B2E),
    ),
    _SlideData(
      title: 'Cook Step\nby Step',
      description:
          'Start cooking mode with voice guidance, visual cues, and timers so you can pause, resume, skip, or extend any step.',
      imagePath: AppAssets.cookingPic,
      blobColor: Color(0xFF5A9A44),
    ),
    _SlideData(
      title: 'Join the\nFood Community',
      description:
          'Share your dishes, post history, and engage with other cooks through likes, comments, follows, and inspiration.',
      imagePath: AppAssets.communityPic,
      blobColor: Color(0xFFB85C28),
    ),
  ];

  void _next() {
    // pages 0..4 are handled inside onboarding
    // once flow ends, user moves to dedicated sign-up screen route
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pushNamed(context, AppRouter.signUp);
    }
  }

  @override
  void initState() {
    super.initState();
    final initialPage = widget.initialPage.clamp(0, 4);
    _pageController = PageController(initialPage: initialPage);
    _currentPage = initialPage;
  }

  void _back() {
    // used by final slide back button to return to previous onboarding page
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _continueWithGoogle() async {
    // this allows immediate auth from onboarding without filling email form
    final ok = await _authController.signInWithGoogle();
    if (!mounted) return;

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.shell, (_) => false);
      return;
    }

    final msg = _authController.errorMessage;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // rebuilds when auth loading/error changes during google sign in
      animation: _authController,
      builder: (context, _) => Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 5,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              if (index == 0) return _SplashSlide(onNext: _next);
              if (index == 4) {
                return _SignUpSlide(
                  isLoading: _authController.isLoading,
                  onBack: _back,
                  onEmail: () => Navigator.pushNamed(context, AppRouter.signUp),
                  onLogin: () => Navigator.pushNamed(context, AppRouter.login),
                  onGoogle: _continueWithGoogle,
                );
              }
              return _StorySlide(
                data: _stories[index - 1],
                storyIndex: index - 1,
                onNext: _next,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Constants ────────────────────────────────────────────────────────────────

const Color _kBg = Color(0xFFF3E8DF);

// ─── Splash ───────────────────────────────────────────────────────────────────

class _SplashSlide extends StatelessWidget {
  const _SplashSlide({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onNext,
      child: Stack(
        children: [
          // Decorative scattered dots
          const Positioned(
            top: 148,
            right: 64,
            child: _Dot(size: 7, color: Color(0xFF4AADA3)),
          ),
          const Positioned(
            top: 212,
            right: 124,
            child: _Dot(size: 5, color: Color(0xFFD45050)),
          ),
          const Positioned(
            top: 290,
            right: 52,
            child: _Dot(size: 6, color: Color(0xFF5070D8)),
          ),
          const Positioned(
            top: 370,
            right: 96,
            child: _Dot(size: 4, color: Color(0xFFD45050)),
          ),
          const Positioned(
            top: 178,
            left: 108,
            child: _Dot(size: 4, color: Color(0xFF5070D8)),
          ),
          const Positioned(
            top: 440,
            right: 80,
            child: _Dot(size: 5, color: Color(0xFF4AADA3)),
          ),

          // Centered logo + name
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppAssets.smartChefLogo, height: 200, width: 200),
                Text(
                  'SmartChef',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A2214),
                  ),
                ),
              ],
            ),
          ),

          // Tap hint at bottom right
          Positioned(
            bottom: 28,
            right: 150,
            child: Text(
              'Tap to continue',
              style: TextStyle(
                color: const Color(0xFF8A6A56).withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Story slide ──────────────────────────────────────────────────────────────

class _StorySlide extends StatelessWidget {
  const _StorySlide({
    required this.data,
    required this.storyIndex,
    required this.onNext,
  });

  final _SlideData data;
  final int storyIndex; // 0, 1, or 2
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Stack(
        children: [
          // ── Full-screen card ────────────────────────────────────────────
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  // Food photo simulation (dark atmospheric gradient)
                  Positioned.fill(child: _FoodPhoto(data: data)),

                  // Text legibility gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 320,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // App name at top center
                  Positioned(
                    top: 22,
                    left: 0,
                    right: 0,
                    child: Text(
                      'SmartChef',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Title + description
                  Positioned(
                    bottom: 58,
                    left: 28,
                    right: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.title,
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.06,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress indicator lines — bottom left
                  Positioned(
                    bottom: 24,
                    left: 28,
                    child: Row(
                      children: List.generate(3, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          height: 3.5,
                          width: i == storyIndex ? 34 : 18,
                          decoration: BoxDecoration(
                            color: i == storyIndex
                                ? data.blobColor
                                : Colors.white.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Cream notch at bottom-right ─────────────────────────────────
          // Large circle in background colour bites into the card corner
          Positioned(
            right: -38,
            bottom: -38,
            child: Container(
              width: 114,
              height: 114,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kBg,
              ),
            ),
          ),

          // ── Arrow chevron ───────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: onNext,
              child: Text(
                '>',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sign-up slide ────────────────────────────────────────────────────────────

class _SignUpSlide extends StatelessWidget {
  const _SignUpSlide({
    required this.isLoading,
    required this.onBack,
    required this.onEmail,
    required this.onLogin,
    required this.onGoogle,
  });

  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onEmail;
  final VoidCallback onLogin;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
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
                  onTap: onBack,
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
            const SizedBox(height: 24),
            Text(
              'Create an\nAccount',
              style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Join a growing community of home cooks. Start scanning, cooking, and sharing today.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                height: 1.5,
              ),
            ),
            const Spacer(),

            // Email register button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onEmail,
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Register using email'),
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
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
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
            const SizedBox(height: 12),

            // Google only
            _SocialButton(
              label: isLoading ? 'Please wait...' : 'G  Continue with Google',
              onTap: isLoading ? null : onGoogle,
            ),
            const SizedBox(height: 10),

            Center(
              child: GestureDetector(
                onTap: onLogin,
                child: RichText(
                  text: TextSpan(
                    text: 'Have an account?  ',
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
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

/// Dark, atmospheric gradient that simulates a moody food photograph.
class _FoodPhoto extends StatelessWidget {
  const _FoodPhoto({required this.data});
  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Image.asset(data.imagePath, fit: BoxFit.cover)),
        Positioned(
          top: -30,
          right: 20,
          child: _Blob(
            size: 220,
            color: data.blobColor.withValues(alpha: 0.22),
          ),
        ),
        Positioned(
          top: 90,
          left: -40,
          child: _Blob(
            size: 170,
            color: data.blobColor.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          top: 50,
          left: 80,
          child: _Blob(
            size: 260,
            color: data.blobColor.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: 40,
          right: -20,
          child: _Blob(size: 150, color: Colors.white.withValues(alpha: 0.03)),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _SlideData {
  const _SlideData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.blobColor,
  });

  final String title;
  final String description;
  final String imagePath;
  final Color blobColor;
}
