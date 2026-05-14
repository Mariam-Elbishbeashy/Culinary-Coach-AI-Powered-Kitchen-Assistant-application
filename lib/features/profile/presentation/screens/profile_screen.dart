import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:culinary_coach_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/models/community_post.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_post_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/change_password_screen.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/stories_archive_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/follow_connections_screen.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/user_posts_screen.dart';
import 'dart:typed_data';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});

  /// If provided and different from current user, shows the public profile view.
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authController = AuthController();
  int _reloadToken = 0;
  Uint8List? _localAvatarBytes;
  String? _localAvatarPath;
  bool _isAvatarUploading = false;

  Future<void> _onAvatarTap(User currentUser) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _localAvatarPath = picked.path;
      _localAvatarBytes = bytes;
      _isAvatarUploading = true;
    });

    final uid = currentUser.uid;
    final effectiveLocalPath = picked.path;

    try {
      final ref = FirebaseStorage.instance.ref('users/$uid/profile.jpg');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profileImageUrl': url,
        'profileImageLocalPath': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        await currentUser.updatePhotoURL(url);
      } catch (_) {
        // Non-blocking.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
      setState(() {
        _isAvatarUploading = false;
        _localAvatarBytes = null;
        _reloadToken++;
      });
      return;
    } catch (_) {
      // Firebase Storage not available or upload failed.
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'profileImageLocalPath': effectiveLocalPath,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved profile picture locally.')),
      );
      setState(() {
        _isAvatarUploading = false;
        _reloadToken++;
      });
    }
  }

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
    final targetUid = widget.userId ?? currentUser?.uid;
    final isPrivateView =
        (targetUid != null && currentUser != null && targetUid == currentUser.uid);

    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        if (currentUser == null || targetUid == null) {
          return _ProfileScaffold(
            authController: _authController,
            onLogout: _logout,
            user: null,
            userData: null,
            isPrivateView: true,
            viewerUid: null,
            targetUid: null,
            localAvatarBytes: null,
            localAvatarPath: null,
            isAvatarUploading: false,
            onAvatarTap: null,
            onEditProfileTap: null,
          );
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserDoc(targetUid),
          key: ValueKey('profile-userdoc-$targetUid-$_reloadToken'),
          builder: (context, snapshot) {
            return _ProfileScaffold(
              authController: _authController,
              onLogout: _logout,
              user: currentUser,
              userData: snapshot.data,
              isPrivateView: isPrivateView,
              viewerUid: currentUser.uid,
              targetUid: targetUid,
              localAvatarBytes: _localAvatarBytes,
              localAvatarPath: _localAvatarPath,
              isAvatarUploading: _isAvatarUploading,
              onAvatarTap: isPrivateView ? () => _onAvatarTap(currentUser) : null,
              onEditProfileTap: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => EditProfileScreen(
                      initialData: snapshot.data,
                    ),
                  ),
                );
                if (!mounted) return;
                if (result == true) {
                  setState(() => _reloadToken++);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _ProfilePostsSection extends StatelessWidget {
  const _ProfilePostsSection({
    required this.repo,
    required this.targetUid,
    required this.isPrivateView,
    required this.posterShortName,
  });

  final CommunityRepository repo;
  final String targetUid;
  final bool isPrivateView;
  final String posterShortName;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: isPrivateView ? 'My Posts' : 'Posts',
      child: StreamBuilder<List<CommunityPost>>(
        stream: repo.watchPostsForUser(targetUid),
        builder: (context, snap) {
          final posts = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting && posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AppColors.primaryDeep),
              ),
            );
          }
          if (posts.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.post_add_rounded,
                    size: 36,
                    color: AppColors.primaryDeep.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPrivateView
                        ? 'No posts yet — share a photo or thought with the community from the Community tab.'
                        : 'No posts yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            );
          }
          const previewCount = 2;
          final preview = posts.take(previewCount).toList();
          final hasMore = posts.length > previewCount;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: preview.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) => CommunityPostCard(post: preview[i]),
              ),
              if (hasMore) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => UserPostsScreen(
                            targetUid: targetUid,
                            posterDisplayName: posterShortName,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'View more posts',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDeep,
                          ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold({
    required this.authController,
    required this.onLogout,
    required this.user,
    required this.userData,
    required this.isPrivateView,
    required this.viewerUid,
    required this.targetUid,
    required this.localAvatarBytes,
    required this.localAvatarPath,
    required this.isAvatarUploading,
    required this.onAvatarTap,
    required this.onEditProfileTap,
  });

  final AuthController authController;
  final Future<void> Function() onLogout;
  final User? user;
  final Map<String, dynamic>? userData;
  final bool isPrivateView;
  final String? viewerUid;
  final String? targetUid;
  final Uint8List? localAvatarBytes;
  final String? localAvatarPath;
  final bool isAvatarUploading;
  final VoidCallback? onAvatarTap;
  final Future<void> Function()? onEditProfileTap;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    final resolvedEmail = isPrivateView ? (user?.email ?? '').trim() : '';

    final resolvedName = _resolveFullName(user: user, userData: userData);
    final posterShortName = () {
      final t = resolvedName.trim();
      if (t.isEmpty) return 'Chef';
      return t.split(RegExp(r'\s+')).first;
    }();
    final otherProfileUid =
        isPrivateView ? '' : ((targetUid ?? '').trim());
    final firestoreImageUrl = (userData?['profileImageUrl'] as String?)?.trim();

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
    final spiceTolerance =
        _readString(userData, keys: ['spiceTolerance']) ?? 'Mild';

    final availableCookingTime =
        _readString(userData, keys: ['availableCookingTime']) ?? '30 min';
    final servingSizePreference =
        _readString(userData, keys: ['servingSizePreference']) ?? '1 person';
    final kitchenEquipment =
        _readString(userData, keys: ['kitchenEquipment']) ?? 'Not set';
    final budgetPreference =
        _readString(userData, keys: ['budgetPreference']) ?? 'Medium';

    final nutritionGoal =
        _readString(userData, keys: ['nutritionGoal']) ?? 'Healthy eating';

    final memberSinceText = _formatMemberSince(user?.metadata.creationTime);

    final statsFavorites = _readInt(userData, keys: [
      'favoriteRecipesCount',
      'savedRecipes',
      'savedCount',
    ]);
    final statsMyRecipes = _readInt(userData, keys: ['myRecipes', 'recipesCount']);
    final statsPosts =
        _readInt(userData, keys: ['communityPosts', 'postsCount']);

    final followersCount = _readInt(userData, keys: ['followersCount']) ?? 0;
    final followingCount = _readInt(userData, keys: ['followingCount']) ?? 0;
    final likesCount = _readInt(userData, keys: ['likesCount']) ?? 0;

    final repo = CommunityRepository();

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
                          if (!isPrivateView &&
                              viewerUid != null &&
                              targetUid != null &&
                              viewerUid != targetUid)
                            StreamBuilder<bool>(
                              stream: repo.watchIsFollowing(
                                viewerUid: viewerUid!,
                                targetUid: targetUid!,
                              ),
                              builder: (context, snap) {
                                final following = snap.data ?? false;
                                return _HeaderActionButton(
                                  label: following ? 'Unfollow' : 'Follow',
                                  icon: following
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  onTap: () async {
                                    if (following) {
                                      await repo.unfollowUser(
                                        targetUid: targetUid!,
                                      );
                                    } else {
                                      await repo.followUser(targetUid: targetUid!);
                                    }
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          isPrivateView
                              ? CurrentUserAvatar(
                                  size: 62,
                                  onTap: onAvatarTap,
                                  isLoadingOverlay: isAvatarUploading,
                                  overrideImageBytes: localAvatarBytes,
                                  backgroundColor: const Color(0xFFD28E18),
                                  borderColor:
                                      Colors.white.withValues(alpha: 0.7),
                                  borderWidth: 2,
                                )
                              : otherProfileUid.isEmpty
                                  ? CircleAvatar(
                                      radius: 31,
                                      backgroundColor: const Color(0xFFD28E18),
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: Colors.white.withValues(alpha: 0.95),
                                        size: 34,
                                      ),
                                    )
                                  : AppDefaultUserAvatarByUid(
                                      userId: otherProfileUid,
                                      fallbackImageUrl: firestoreImageUrl,
                                      size: 62,
                                      borderColor:
                                          Colors.white.withValues(alpha: 0.7),
                                      borderWidth: 2,
                                      heroTag: 'profile-avatar-$otherProfileUid',
                                    ),
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
                        title: 'Social',
                        child: _InlineStatsRow(
                          items: [
                            _InlineStatItem(
                              icon: Icons.group_add_rounded,
                              value: _formatCount(followersCount),
                              label: 'Followers',
                              onTap: targetUid == null
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => FollowConnectionsScreen(
                                            targetUid: targetUid!,
                                            followers: true,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                            _InlineStatItem(
                              icon: Icons.how_to_reg_rounded,
                              value: _formatCount(followingCount),
                              label: 'Following',
                              onTap: targetUid == null
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => FollowConnectionsScreen(
                                            targetUid: targetUid!,
                                            followers: false,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                            _InlineStatItem(
                              icon: Icons.favorite_rounded,
                              value: _formatCount(likesCount),
                              label: 'Likes',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Activity',
                        child: _InlineStatsRow(
                          items: [
                            _InlineStatItem(
                              icon: Icons.star_rounded,
                              value: _formatCount(statsFavorites),
                              label: 'Favorites',
                            ),
                            _InlineStatItem(
                              icon: Icons.restaurant_menu_rounded,
                              value: _formatCount(statsMyRecipes),
                              label: 'My Recipes',
                            ),
                            _InlineStatItem(
                              icon: Icons.forum_rounded,
                              value: _formatCount(statsPosts),
                              label: 'Posts',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Core Cooking Preferences',
                        child: Column(
                          children: [
                            _InfoRow(
                              label: 'Cooking Level',
                              value: cookingLevel,
                              icon: Icons.emoji_events_rounded,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: 'Favorite Cuisine',
                              value: favoriteCuisine,
                              icon: Icons.public_rounded,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: 'Dietary Preference',
                              value: dietaryPreference,
                              icon: Icons.eco_rounded,
                            ),
                            if (isPrivateView) ...[
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: 'Allergies',
                                value: allergies,
                                icon: Icons.health_and_safety_rounded,
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: 'Spice Tolerance',
                                value: spiceTolerance,
                                icon: Icons.local_fire_department_rounded,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (!isPrivateView && targetUid != null) ...[
                        _ProfilePostsSection(
                          repo: repo,
                          targetUid: targetUid!,
                          isPrivateView: isPrivateView,
                          posterShortName: posterShortName,
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (isPrivateView) ...[
                        _SectionCard(
                          title: 'Practical Cooking Settings',
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Available Cooking Time',
                                value: availableCookingTime,
                                icon: Icons.schedule_rounded,
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: 'Serving Size Preference',
                                value: servingSizePreference,
                                icon: Icons.groups_rounded,
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: 'Kitchen Equipment',
                                value: kitchenEquipment,
                                icon: Icons.kitchen_rounded,
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: 'Budget Preference',
                                value: budgetPreference,
                                icon: Icons.payments_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 14),
                      if (isPrivateView) ...[
                        _SectionCard(
                          title: 'Nutrition Goals',
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Nutrition Goal',
                                value: nutritionGoal,
                                icon: Icons.monitor_heart_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Account Info',
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Member Since',
                                value: memberSinceText,
                                icon: Icons.calendar_today_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (targetUid != null)
                          _ProfilePostsSection(
                            repo: repo,
                            targetUid: targetUid!,
                            isPrivateView: isPrivateView,
                            posterShortName: posterShortName,
                          ),
                        if (targetUid != null) const SizedBox(height: 14),
                        if (targetUid != null)
                          _SectionCard(
                            title: 'Stories Archive',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const StoriesArchiveScreen(),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.45),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.auto_stories_rounded,
                                          color: AppColors.primaryDeep,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Stories Archive',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'All your stories, including ones older than 24 hours.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (targetUid != null) const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Account Settings',
                          child: Column(
                            children: [
                              _ActionRow(
                                icon: Icons.edit_rounded,
                                label: 'Edit Profile',
                                onTap: onEditProfileTap,
                              ),
                              const SizedBox(height: 6),
                              _ActionRow(
                                icon: Icons.lock_rounded,
                                label: 'Change Password',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ChangePasswordScreen(),
                                    ),
                                  );
                                },
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
                                onTap:
                                    authController.isLoading ? null : onLogout,
                              ),
                            ],
                          ),
                        ),
                      ],
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

  String _formatMemberSince(DateTime? createdAt) {
    if (createdAt == null) return 'Not available';
    final y = createdAt.year.toString().padLeft(4, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
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

class _InlineStatItem {
  const _InlineStatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
}

class _InlineStatsRow extends StatelessWidget {
  const _InlineStatsRow({required this.items});

  final List<_InlineStatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: _InlineStatsItemView(item: items[i])),
            if (i != items.length - 1)
              Container(
                width: 1,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _InlineStatsItemView extends StatelessWidget {
  const _InlineStatsItemView({required this.item});

  final _InlineStatItem item;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.14),
          ),
          child: Icon(item.icon, color: AppColors.primaryDeep, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          item.value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );

    if (item.onTap == null) return column;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: column,
        ),
      ),
    );
  }
}

// ignore: unused_element
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
  const _InfoRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

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
          _RowIcon(icon: icon),
          const SizedBox(width: 12),
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

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Icon(icon, color: AppColors.primaryDeep, size: 18),
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
