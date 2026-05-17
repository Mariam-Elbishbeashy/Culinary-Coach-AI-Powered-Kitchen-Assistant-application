import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/create_post_screen.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_stories_strip.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/notifications_screen.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/user_search_screen.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_post_card.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _isNavigating = false;

  Future<void> _safePush(Widget page) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _CommunityHeader(
            onSearch:
                _isNavigating ? null : () => _safePush(const UserSearchScreen()),
            onNotifications: _isNavigating
                ? null
                : () => _safePush(const NotificationsScreen()),
            onCreatePost: currentUser == null || _isNavigating
                ? null
                : () => _safePush(const CreatePostScreen()),
          ),
          Expanded(
            child: currentUser == null
                ? const _CommunityEmptyState(
                    title: 'Sign in to use Community',
                    subtitle:
                        'Create posts, follow people, and share your cooking journey.',
                  )
                : StreamBuilder<List<String>>(
                    stream: repo.watchFollowingUids(currentUser.uid),
                    builder: (context, followSnap) {
                      if (followSnap.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Can’t load Community right now.\nCheck your internet connection and try again.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        );
                      }
                      final following = followSnap.data ?? const <String>[];
                      final hasFollowing = following.isNotEmpty;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                        children: [
                          _SuggestedUsersSection(
                            viewerUid: currentUser.uid,
                            repo: repo,
                          ),
                          const SizedBox(height: 14),
                          CommunityStoriesStrip(
                            viewerUid: currentUser.uid,
                            repo: repo,
                            onBusyChanged: (busy) {
                              if (mounted) setState(() => _isNavigating = busy);
                            },
                          ),
                          const SizedBox(height: 14),
                          _CreatePostComposerCard(
                            onTap: _isNavigating
                                ? null
                                : () => _safePush(const CreatePostScreen()),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Feed',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 10),
                          if (!hasFollowing)
                            const _InlineEmptyHint(
                              title: 'Your feed is empty',
                              subtitle: 'Follow users to see their posts here.',
                            ),
                          StreamBuilder(
                            stream: repo.watchFeedPosts(includeMyPosts: true),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: _InlineEmptyHint(
                                    title: 'Feed unavailable',
                                    subtitle:
                                        'Check your internet connection and try again.',
                                  ),
                                );
                              }
                              final posts = snapshot.data ?? const [];
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  posts.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primaryDeep,
                                    ),
                                  ),
                                );
                              }
                              if (posts.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: _InlineEmptyHint(
                                    title: 'No posts yet',
                                    subtitle:
                                        'Create your first post or follow users.',
                                  ),
                                );
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: posts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) =>
                                    CommunityPostCard(post: posts[index]),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostComposerCard extends StatelessWidget {
  const _CreatePostComposerCard({
    required this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFE0B2),
                Color(0xFFFFF3E0),
                Color(0xFFFFFAF4),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                CurrentUserAvatar(
                  size: 44,
                  backgroundColor: const Color(0xFFD28E18),
                  borderColor: Colors.white.withValues(alpha: 0.65),
                  borderWidth: 2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'What’s on your mind?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.18),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primaryDeep,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.onSearch,
    required this.onNotifications,
    required this.onCreatePost,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onCreatePost;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final repo = CommunityRepository();
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final isCompact = isLandscape;
    final heroTitleSize = isCompact ? 16.0 : 23.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + (isCompact ? 4 : 10),
        18,
        isCompact ? 8 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFCC7705),
            Color(0xFFDD8E1E),
            Color(0xFFF0A73A),
          ],
          stops: [0.0, 0.35, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CommunityHeroBackgroundPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          if (currentUser == null)
            Row(
              children: [
                Text(
                  'SmartChef',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                _CircleHeaderButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: onNotifications,
                ),
                const SizedBox(width: 10),
                _CircleHeaderButton(
                  icon: Icons.post_add_rounded,
                  onTap: onCreatePost,
                ),
              ],
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final firstName = (data?['firstName'] as String?)?.trim();
                final resolvedName = (firstName != null && firstName.isNotEmpty)
                    ? firstName
                    : (currentUser.displayName?.split(' ').first ??
                        currentUser.email?.split('@').first ??
                        'User');

                return Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      child: CurrentUserAvatar(
                        size: 40,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        backgroundColor: const Color(0xFFD28E18),
                        borderColor: Colors.white.withValues(alpha: 0.65),
                        borderWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Home Chef',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                          ),
                        ],
                      ),
                    ),
                    _CircleHeaderButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: onNotifications,
                      badgeStream: repo.watchUnreadNotificationsCount(),
                    ),
                    const SizedBox(width: 10),
                    _CircleHeaderButton(
                      icon: Icons.post_add_rounded,
                      onTap: onCreatePost,
                    ),
                  ],
                );
              },
            ),
          SizedBox(height: isCompact ? 6 : 26),
          Text(
            'Community',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: heroTitleSize,
                  height: 1.12,
                ),
          ),
          if (!isCompact) ...[
            const SizedBox(height: 4),
            Text(
              'Share recipes and discover ideas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: heroTitleSize,
                    height: 1.20,
                  ),
            ),
          ],
          SizedBox(height: isCompact ? 8 : 25),
          InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(27),
            child: Container(
              height: isCompact ? 40 : 50,
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF888888),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search users',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF888888),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryDeep,
                    ),
                  )
                ],
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  const _CircleHeaderButton({
    required this.icon,
    required this.onTap,
    this.badgeStream,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Stream<int>? badgeStream;

  @override
  Widget build(BuildContext context) {
    final base = SizedBox(
      height: 40,
      width: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF6C6C6C), size: 21),
          ),
        ),
      ),
    );

    if (badgeStream == null) return base;

    return StreamBuilder<int>(
      stream: badgeStream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            base,
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommunityHeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    ringPaint..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 34;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.92, size.height * 0.20), radius: size.height * 1.02),
      math.pi * 0.58,
      math.pi * 0.58,
      false,
      ringPaint,
    );
    ringPaint..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 20;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 1.02, size.height * 0.06), radius: size.height * 0.86),
      math.pi * 0.52,
      math.pi * 0.52,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.diversity_1_rounded,
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmptyHint extends StatelessWidget {
  const _InlineEmptyHint({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedUsersSection extends StatelessWidget {
  const _SuggestedUsersSection({
    required this.viewerUid,
    required this.repo,
  });

  final String viewerUid;
  final CommunityRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repo.watchSuggestedUsers(excludeUid: viewerUid, limit: 10),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const [];
        if (snapshot.hasError) return const SizedBox.shrink();
        if (snapshot.connectionState == ConnectionState.waiting &&
            users.isEmpty) {
          return const SizedBox.shrink();
        }
        if (users.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested Users',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final u = users[index];
                  return _SuggestedUserTile(
                    viewerUid: viewerUid,
                    userId: u.uid,
                    name: u.displayName,
                    badge: u.badge,
                    profileImageUrl: u.profileImageUrl,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SuggestedUserTile extends StatelessWidget {
  const _SuggestedUserTile({
    required this.viewerUid,
    required this.userId,
    required this.name,
    required this.badge,
    required this.profileImageUrl,
  });

  final String viewerUid;
  final String userId;
  final String name;
  final String badge;
  final String? profileImageUrl;

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(userId: userId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 230,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.outline),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            AppDefaultUserAvatarByUid(
              userId: userId,
              fallbackImageUrl: profileImageUrl,
              size: 46,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StreamBuilder<bool>(
              stream: repo.watchIsFollowing(viewerUid: viewerUid, targetUid: userId),
              builder: (context, snap) {
                final following = snap.data ?? false;
                return InkWell(
                  onTap: () async {
                    if (following) {
                      await repo.unfollowUser(targetUid: userId);
                    } else {
                      await repo.followUser(targetUid: userId);
                    }
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: following
                          ? AppColors.surfaceMuted
                          : AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          following ? Icons.check_rounded : Icons.person_add_alt_rounded,
                          size: 16,
                          color: following ? AppColors.textSecondary : AppColors.primaryDeep,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          following ? 'Following' : 'Follow',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

