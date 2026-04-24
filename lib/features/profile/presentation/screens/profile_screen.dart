import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authController = AuthController();

  Future<Map<String, dynamic>?> _getUserDoc(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

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
    final currentUser = FirebaseAuth.instance.currentUser;

    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        if (currentUser == null) {
          return _ProfileScaffold(
            authController: _authController,
            onLogout: _logout,
            user: null,
            userData: null,
          );
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserDoc(currentUser.uid),
          builder: (context, snapshot) => _ProfileScaffold(
            authController: _authController,
            onLogout: _logout,
            user: currentUser,
            userData: snapshot.data,
          ),
        );
      },
    );
  }
}

class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold({
    required this.authController,
    required this.onLogout,
    required this.user,
    required this.userData,
  });

  final AuthController authController;
  final Future<void> Function() onLogout;
  final User? user;
  final Map<String, dynamic>? userData;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    final resolvedEmail =
        (userData?['email'] as String?)?.trim().isNotEmpty == true
            ? (userData?['email'] as String).trim()
            : (user?.email ?? '').trim();

    final resolvedName = _resolveFullName(user: user, userData: userData);

    final cookingLevel =
        _readString(userData, keys: ['cookingLevel', 'level', 'skillLevel']) ??
        'Beginner';
    final favoriteCuisine =
        _readString(userData, keys: ['favoriteCuisine', 'cuisine']) ?? 'Not set';
    final dietaryPreference =
        _readString(userData, keys: ['dietaryPreference', 'diet']) ??
        'None';
    final allergiesRaw = userData?['allergies'];
    final allergies = _resolveAllergies(allergiesRaw) ?? 'None';

    final statsSaved = _readInt(userData, keys: ['savedRecipes', 'savedCount']);
    final statsMyRecipes = _readInt(userData, keys: ['myRecipes', 'recipesCount']);
    final statsPosts =
        _readInt(userData, keys: ['communityPosts', 'postsCount']);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: AppColors.background),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFCC7705),
                        Color(0xFFDD8E1E),
                        Color(0xFFF0A73A),
                      ],
                      stops: [0.0, 0.35, 1.0],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _ProfileAvatar(photoUrl: user?.photoURL),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resolvedName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  resolvedEmail.isEmpty
                                      ? 'Signed in'
                                      : resolvedEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                _BadgePill(
                                  label: 'Home Chef',
                                  icon: Icons.verified_rounded,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'Activity',
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                label: 'Saved Recipes',
                                value: _formatCount(statsSaved),
                                icon: Icons.bookmark_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatTile(
                                label: 'My Recipes',
                                value: _formatCount(statsMyRecipes),
                                icon: Icons.restaurant_menu_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatTile(
                                label: 'Community Posts',
                                value: _formatCount(statsPosts),
                                icon: Icons.forum_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Cooking Preferences',
                        child: Column(
                          children: [
                            _InfoRow(
                              label: 'Cooking Level',
                              value: cookingLevel,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: 'Favorite Cuisine',
                              value: favoriteCuisine,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: 'Dietary Preference',
                              value: dietaryPreference,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(label: 'Allergies', value: allergies),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Account Settings',
                        child: Column(
                          children: [
                            _ActionRow(
                              icon: Icons.edit_rounded,
                              label: 'Edit Profile',
                              onTap: () => _comingSoon(context),
                            ),
                            const SizedBox(height: 6),
                            _ActionRow(
                              icon: Icons.lock_rounded,
                              label: 'Change Password',
                              onTap: () => _comingSoon(context),
                            ),
                            const SizedBox(height: 6),
                            _ActionRow(
                              icon: Icons.logout_rounded,
                              label: authController.isLoading
                                  ? 'Signing out...'
                                  : 'Logout',
                              isDestructive: true,
                              trailing: authController.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                              onTap: authController.isLoading ? null : onLogout,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveFullName({
    required User? user,
    required Map<String, dynamic>? userData,
  }) {
    final firstName = (userData?['firstName'] as String?)?.trim();
    final lastName = (userData?['lastName'] as String?)?.trim();
    final fromParts = [
      if (firstName != null && firstName.isNotEmpty) firstName,
      if (lastName != null && lastName.isNotEmpty) lastName,
    ].join(' ').trim();
    if (fromParts.isNotEmpty) return fromParts;

    final displayName = (user?.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (user?.email ?? '').trim();
    if (email.isNotEmpty) {
      final local = email.split('@').first.trim();
      return local.isEmpty ? 'Chef' : local;
    }

    return 'Chef';
  }

  String? _readString(Map<String, dynamic>? data, {required List<String> keys}) {
    if (data == null) return null;
    for (final key in keys) {
      final v = data[key];
      if (v is String) {
        final value = v.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic>? data, {required List<String> keys}) {
    if (data == null) return null;
    for (final key in keys) {
      final v = data[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String? _resolveAllergies(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return null;
      return value;
    }
    if (raw is List) {
      final parts = raw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      return parts.join(', ');
    }
    return null;
  }

  String _formatCount(int? value) => (value ?? 0).toString();

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon.')),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF6C6C6C), size: 22),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();

    return Container(
      height: 62,
      width: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD28E18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? const Icon(Icons.person, color: Colors.white, size: 32)
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
            child: Icon(icon, color: AppColors.primaryDeep, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive ? const Color(0xFFB3261E) : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDestructive
                        ? const Color(0xFFB3261E)
                        : AppColors.primaryDeep)
                    .withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: fg, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
          ],
        ),
      ),
    );
  }
}
