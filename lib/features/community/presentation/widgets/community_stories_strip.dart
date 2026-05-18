import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/models/community_story.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/create_story_screen.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/story_viewer_screen.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

const double _kStoryAvatar = 64;
const double _kStoryRing = 4;

/// Instagram-style ring gradient while keeping warm tones.
const List<Color> _kStoryRingGradient = [
  Color(0xFFC13584),
  Color(0xFFE08B14),
  Color(0xFFF4A32D),
  Color(0xFFFFE0B2),
];

/// Stories row for Community: "Your story" + active rings for followed users.
class CommunityStoriesStrip extends StatelessWidget {
  const CommunityStoriesStrip({
    super.key,
    required this.viewerUid,
    required this.repo,
    required this.onBusyChanged,
  });

  final String viewerUid;
  final CommunityRepository repo;
  final ValueChanged<bool> onBusyChanged;

  @override
  Widget build(BuildContext context) {
    final trimmedViewer = viewerUid.trim();
    return StreamBuilder<List<CommunityStoryRing>>(
      stream: repo.watchActiveStoryRings(viewerUid: trimmedViewer),
      builder: (context, snap) {
        if (snap.hasError) {
          assert(() {
            debugPrint('CommunityStoriesStrip: ${snap.error}');
            return true;
          }());
        }
        final rings = snap.data ?? const <CommunityStoryRing>[];
        CommunityStoryRing? ownRing;
        final others = <CommunityStoryRing>[];
        for (final r in rings) {
          if (r.userId.trim() == trimmedViewer) {
            ownRing = r;
          } else {
            others.add(r);
          }
        }

        assert(() {
          developer.log(
            'CommunityStoriesStrip: viewer=$trimmedViewer rings=${rings.length} '
            'ownActiveCount=${ownRing?.stories.length ?? 0}',
            name: 'CommunityStoriesStrip',
          );
          return true;
        }());

        return SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 8),
            children: [
              _YourStoryTile(
                ownRing: ownRing,
                onBusyChanged: onBusyChanged,
              ),
              ...others.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _PeerStoryRing(
                    ring: r,
                    onTap: () {
                      onBusyChanged(true);
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute<void>(
                          builder: (_) => StoryViewerScreen(
                            stories: r.stories,
                            initialIndex: 0,
                          ),
                        ),
                      )
                          .whenComplete(() => onBusyChanged(false));
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _YourStoryTile extends StatelessWidget {
  const _YourStoryTile({
    required this.ownRing,
    required this.onBusyChanged,
  });

  final CommunityStoryRing? ownRing;
  final ValueChanged<bool> onBusyChanged;

  Future<void> _openCreate(BuildContext context) async {
    onBusyChanged(true);
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const CreateStoryScreen(),
        ),
      );
    } finally {
      onBusyChanged(false);
    }
  }

  void _openOwnStories(BuildContext context) {
    final ring = ownRing;
    if (ring == null || ring.stories.isEmpty) return;
    onBusyChanged(true);
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => StoryViewerScreen(
          stories: ring.stories,
          initialIndex: 0,
        ),
      ),
    )
        .whenComplete(() => onBusyChanged(false));
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = ownRing?.stories.isNotEmpty ?? false;
    final outer = _kStoryAvatar + _kStoryRing * 2;

    return SizedBox(
      width: 86,
      child: Column(
        children: [
          SizedBox(
            height: outer,
            width: outer,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (hasActive) {
                        showModalBottomSheet<void>(
                          context: context,
                          useRootNavigator: true,
                          showDragHandle: true,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          builder: (ctx) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: AppColors.primaryDeep,
                                    ),
                                    title: Text(
                                      'View Story',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _openOwnStories(context);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: AppColors.primaryDeep,
                                    ),
                                    title: Text(
                                      'Add Another Story',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _openCreate(context);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      } else {
                        _openCreate(context);
                      }
                    },
                    child: Container(
                      width: outer,
                      height: outer,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasActive
                            ? const LinearGradient(
                                begin: Alignment.bottomLeft,
                                end: Alignment.topRight,
                                colors: _kStoryRingGradient,
                              )
                            : null,
                        border: hasActive
                            ? null
                            : Border.all(color: AppColors.outline, width: 2),
                        color: hasActive
                            ? null
                            : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2C2C2C)
                                : Colors.white),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CurrentUserAvatar(
                        size: _kStoryAvatar,
                        backgroundColor: const Color(0xFFD28E18),
                        borderColor: Colors.white,
                        borderWidth: 2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: AppColors.primaryDeep,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openCreate(context),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your Story',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF2F2F2)
                      : AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeerStoryRing extends StatelessWidget {
  const _PeerStoryRing({
    required this.ring,
    required this.onTap,
  });

  final CommunityStoryRing ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outer = _kStoryAvatar + _kStoryRing * 2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Column(
        children: [
          Container(
            width: outer,
            height: outer,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: _kStoryRingGradient,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: AppDefaultUserAvatarByUid(
              userId: ring.userId,
              fallbackImageUrl: ring.userAvatar,
              size: _kStoryAvatar,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 88,
            child: Text(
              ring.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFF2F2F2)
                        : AppColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
