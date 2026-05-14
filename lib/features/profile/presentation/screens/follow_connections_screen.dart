import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/app_primary_button.dart';
import 'package:culinary_coach_app/features/community/data/models/community_user.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Followers or following list for [targetUid], using the same row style as [UserSearchScreen].
class FollowConnectionsScreen extends StatelessWidget {
  const FollowConnectionsScreen({
    super.key,
    required this.targetUid,
    required this.followers,
  });

  final String targetUid;
  final bool followers;

  static String _displayName(CommunityUser? u, FollowListEntry e) {
    final fromUser = u?.displayName.trim();
    if (fromUser != null && fromUser.isNotEmpty) return fromUser;
    final fromEntry = e.name.trim();
    if (fromEntry.isNotEmpty) return fromEntry;
    return 'User';
  }

  static String _subtitle(CommunityUser? u) {
    final b = u?.badge.trim();
    if (b != null && b.isNotEmpty) return b;
    return 'Home Chef';
  }

  @override
  Widget build(BuildContext context) {
    final viewerUid = FirebaseAuth.instance.currentUser?.uid;
    final repo = CommunityRepository();
    final title = followers ? 'Followers' : 'Following';
    final ownerUid = targetUid.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        centerTitle: true,
      ),
      body: ownerUid.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not open this list.'),
              ),
            )
          : StreamBuilder<List<FollowListEntry>>(
              stream: repo.watchFollowList(targetUid: ownerUid, followers: followers),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load this list.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                }
                final list = snap.data ?? const <FollowListEntry>[];
                if (snap.connectionState == ConnectionState.waiting && list.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryDeep),
                  );
                }
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        followers ? 'No followers yet' : 'Not following anyone yet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final rowUid = e.uid.trim();
                    if (rowUid.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _FollowUserRow(
                      entry: e,
                      rowUid: rowUid,
                      viewerUid: viewerUid,
                      repo: repo,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FollowUserRow extends StatelessWidget {
  const _FollowUserRow({
    required this.entry,
    required this.rowUid,
    required this.viewerUid,
    required this.repo,
  });

  final FollowListEntry entry;
  final String rowUid;
  final String? viewerUid;
  final CommunityRepository repo;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(userId: rowUid),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              userId: rowUid,
              fallbackImageUrl: entry.profileImageUrl,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<CommunityUser?>(
                stream: repo.watchUser(rowUid),
                builder: (context, userSnap) {
                  final u = userSnap.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FollowConnectionsScreen._displayName(u, entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FollowConnectionsScreen._subtitle(u),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            ...() {
              final cu = viewerUid;
              if (cu != null && cu != rowUid) {
                return [
                  SizedBox(
                    width: 140,
                    height: 40,
                    child: StreamBuilder<bool>(
                      stream: repo.watchIsFollowing(
                        viewerUid: cu,
                        targetUid: rowUid,
                      ),
                      builder: (context, snap) {
                        final following = snap.data ?? false;
                        return AppPrimaryButton(
                          label: following ? 'Following' : 'Follow',
                          isOutlined: following,
                          icon: following
                              ? Icons.check_rounded
                              : Icons.person_add_alt_rounded,
                          onPressed: () async {
                            if (following) {
                              await repo.unfollowUser(targetUid: rowUid);
                            } else {
                              await repo.followUser(targetUid: rowUid);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ];
              }
              if (cu == null) {
                return [
                  const _SmallPill(
                    icon: Icons.person_rounded,
                    label: 'User',
                  ),
                ];
              }
              return [
                const _SmallPill(
                  icon: Icons.person_rounded,
                  label: 'You',
                ),
              ];
            }(),
          ],
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 40,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primaryDeep),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
