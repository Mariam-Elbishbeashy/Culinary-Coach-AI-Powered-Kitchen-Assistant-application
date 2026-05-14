import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/app_primary_button.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final viewerUid = FirebaseAuth.instance.currentUser?.uid;
    final q = _query.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Search Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      cursorColor: AppColors.primaryDeep,
                      decoration: const InputDecoration(
                        hintText: 'Search users',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() {
                        _controller.clear();
                        _query = '';
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: repo.watchAllUsers(limit: 120),
              builder: (context, snapshot) {
                var users = snapshot.data ?? const [];
                debugPrint('Loaded users count: ${users.length}');
                debugPrint('Current uid: $viewerUid');
                if (snapshot.hasError) {
                  debugPrint('User query error: ${snapshot.error}');
                }
                if (viewerUid != null) {
                  users = users.where((u) => u.uid != viewerUid).toList();
                }
                if (q.isNotEmpty) {
                  users = users
                      .where(
                        (u) => u.displayName.toLowerCase().contains(q),
                      )
                      .toList();
                }
                debugPrint('Filtered users count: ${users.length}');

                if (snapshot.hasError) {
                  return const _HintEmpty(
                    title: 'Couldn’t load users',
                    subtitle: 'Please check your connection and try again.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    users.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDeep,
                    ),
                  );
                }
                if (users.isEmpty) {
                  if (q.isEmpty) {
                    return const _HintEmpty(
                      title: 'No other users yet',
                      subtitle: 'Invite friends to join SmartChef Community.',
                    );
                  }
                  return const _HintEmpty(
                    title: 'No users found',
                    subtitle: 'Try a different name.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(userId: u.uid),
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
                              color:
                                  AppColors.textPrimary.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AppDefaultUserAvatarByUid(
                              userId: u.uid,
                              fallbackImageUrl: u.profileImageUrl,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    u.badge,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (viewerUid == null)
                              const _SmallPill(
                                icon: Icons.person_rounded,
                                label: 'User',
                              )
                            else
                              StreamBuilder<bool>(
                                stream: repo.watchIsFollowing(
                                  viewerUid: viewerUid,
                                  targetUid: u.uid,
                                ),
                                builder: (context, snap) {
                                  final following = snap.data ?? false;
                                  return SizedBox(
                                    height: 40,
                                    width: 140,
                                    child: AppPrimaryButton(
                                      label: following ? 'Following' : 'Follow',
                                      isOutlined: following,
                                      icon: following
                                          ? Icons.check_rounded
                                          : Icons.person_add_alt_rounded,
                                      onPressed: () async {
                                        if (following) {
                                          await repo.unfollowUser(
                                            targetUid: u.uid,
                                          );
                                        } else {
                                          await repo.followUser(targetUid: u.uid);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    return Container(
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
    );
  }
}

class _HintEmpty extends StatelessWidget {
  const _HintEmpty({
    this.title = 'Search users',
    this.subtitle = 'Type a name like “Sara” or “Ahmed”.',
  });

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
                  Icons.search_rounded,
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

