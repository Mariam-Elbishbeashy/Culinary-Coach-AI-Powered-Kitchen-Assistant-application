import 'dart:convert';
import 'dart:typed_data';

import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/models/community_story.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Padding above progress track + track area (matches slide top inset).
const double _kStoryProgressPaddingTop = 4;
const double _kStoryProgressStripHeight = 18;
const double _kStoryProgressUnderSafe =
    _kStoryProgressPaddingTop + _kStoryProgressStripHeight;

/// Full-screen story viewer with likes, live updates, auto-advance, and
/// Instagram-style segmented progress + left/right tap navigation.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<CommunityStory> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  static const Duration _kStoryDuration = Duration(seconds: 5);
  static const Duration _kPageAnim = Duration(milliseconds: 280);

  late final PageController _pageController;
  late final AnimationController _progress;
  final _repo = CommunityRepository();

  late int _currentIndex;
  int _lastNavAtMs = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.stories.length;
    final safe = n == 0 ? 0 : widget.initialIndex.clamp(0, n - 1);
    _currentIndex = safe;
    _pageController = PageController(initialPage: safe);
    _progress = AnimationController(vsync: this, duration: _kStoryDuration)
      ..addStatusListener(_onProgressStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.stories.isNotEmpty) {
        _restartProgress();
      }
    });
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      _goNext(fromTimer: true);
    }
  }

  void _restartProgress() {
    if (!mounted || widget.stories.isEmpty) return;
    _progress
      ..stop()
      ..reset()
      ..forward();
  }

  bool _tryConsumeNavTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNavAtMs < 380) return false;
    _lastNavAtMs = now;
    return true;
  }

  Future<void> _goNext({bool fromTimer = false}) async {
    if (!mounted) return;
    if (!fromTimer && !_tryConsumeNavTap()) return;

    if (_currentIndex >= widget.stories.length - 1) {
      _progress.stop();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    _progress.stop();
    if (!_pageController.hasClients) return;
    await _pageController.nextPage(
      duration: _kPageAnim,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goPrevious() async {
    if (!mounted) return;
    if (!_tryConsumeNavTap()) return;
    if (_currentIndex <= 0) {
      _restartProgress();
      return;
    }
    _progress.stop();
    if (!_pageController.hasClients) return;
    await _pageController.previousPage(
      duration: _kPageAnim,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _restartProgress();
  }

  @override
  void dispose() {
    _progress.removeStatusListener(_onProgressStatus);
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }

    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        alignment: AlignmentDirectional.topStart,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.stories.length,
            itemBuilder: (context, index) {
              final seed = widget.stories[index];
              return _StorySlide(
                key: ValueKey<String>(seed.id),
                repo: _repo,
                storyId: seed.id,
                seed: seed,
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  10,
                  _kStoryProgressPaddingTop,
                  10,
                  0,
                ),
                child: SizedBox(
                  height: _kStoryProgressStripHeight,
                  child: _SegmentedStoryProgress(
                    storyCount: widget.stories.length,
                    currentIndex: _currentIndex,
                    progress: _progress,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                topPad + _kStoryProgressUnderSafe + 44,
                0,
                150,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _goPrevious,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _goNext(fromTimer: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedStoryProgress extends StatelessWidget {
  const _SegmentedStoryProgress({
    required this.storyCount,
    required this.currentIndex,
    required this.progress,
  });

  final int storyCount;
  final int currentIndex;
  final AnimationController progress;

  @override
  Widget build(BuildContext context) {
    if (storyCount <= 0) return const SizedBox.shrink();
    return Row(
      children: List<Widget>.generate(storyCount, (i) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Colors.white.withValues(alpha: 0.28)),
                    if (i < currentIndex)
                      const ColoredBox(color: Colors.white)
                    else if (i == currentIndex)
                      AnimatedBuilder(
                        animation: progress,
                        builder: (context, _) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress.value.clamp(0.0, 1.0),
                              heightFactor: 1,
                              child: const ColoredBox(color: Colors.white),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StorySlide extends StatelessWidget {
  const _StorySlide({
    super.key,
    required this.repo,
    required this.storyId,
    required this.seed,
  });

  final CommunityRepository repo;
  final String storyId;
  final CommunityStory seed;

  Uint8List? _decode(String raw) {
    try {
      final b = base64Decode(raw.trim());
      if (b.isEmpty) return null;
      return b;
    } catch (_) {
      return null;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final viewer = FirebaseAuth.instance.currentUser;

    return StreamBuilder<CommunityStory?>(
      stream: repo.watchStory(storyId),
      initialData: seed,
      builder: (context, snap) {
        final story = snap.data;
        if (story == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Story unavailable',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        final bytes = _decode(story.imageBase64);
        final liked = story.likedByUid(viewer?.uid);
        final count = story.likeCount;
        final isOwner = (viewer?.uid ?? '').trim() == story.userId.trim();

        return Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              Container(color: AppColors.darkPanel),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, _kStoryProgressUnderSafe, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                        const Spacer(),
                      ],
                    ),
                    Row(
                      children: [
                        AppDefaultUserAvatarByUid(
                          userId: story.userId,
                          fallbackImageUrl: story.userAvatar,
                          size: 44,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                story.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _timeAgo(story.createdAt),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (story.textOverlay.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          story.textOverlay,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 8,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: viewer == null
                                ? null
                                : () async {
                                    try {
                                      await repo.toggleStoryLike(storyId: story.id);
                                    } catch (_) {}
                                  },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Icon(
                                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: liked ? const Color(0xFFFF6B6B) : Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        if (count > 0 || isOwner) ...[
                          const SizedBox(width: 12),
                          Text(
                            isOwner
                                ? '$count ${count == 1 ? 'like' : 'likes'}'
                                : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
