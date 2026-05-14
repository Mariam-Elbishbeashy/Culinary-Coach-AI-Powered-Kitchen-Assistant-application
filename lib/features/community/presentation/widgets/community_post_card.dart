import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/models/community_comment.dart';
import 'package:culinary_coach_app/features/community/data/models/community_post.dart';
import 'package:culinary_coach_app/features/community/data/models/community_reply.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/comments_sheet.dart';
import 'package:culinary_coach_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({required this.post, super.key});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          _HeaderRow(
            authorId: post.authorId,
            authorName: post.authorName,
            authorProfileImageUrl: post.authorProfileImageUrl,
            createdAt: post.createdAt,
            onAuthorTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(userId: post.authorId),
                ),
              );
            },
          ),
          if (post.isRepost) ...[
            const SizedBox(height: 10),
            _RepostPill(),
          ],
          if (post.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.caption,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
          ],
          if ((post.recipeTitle ?? '').trim().isNotEmpty ||
              (post.cookingTime ?? '').trim().isNotEmpty ||
              post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((post.recipeTitle ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.receipt_long_rounded,
                    label: post.recipeTitle!.trim(),
                  ),
                if ((post.cookingTime ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: post.cookingTime!.trim(),
                  ),
                for (final tag in post.tags.take(4))
                  _MetaChip(icon: Icons.sell_rounded, label: tag),
              ],
            ),
          ],
          if (post.hasPostImages) ...[
            const SizedBox(height: 12),
            _PostMediaGallery(
              networkUrls: post.imageUrls,
              base64Images: post.imageBase64List,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: currentUid == null
                    ? _ActionPill(
                        icon: Icons.favorite_border_rounded,
                        label: _formatCount(post.likeCount),
                        onTap: null,
                      )
                    : StreamBuilder<bool>(
                        stream:
                            repo.watchHasLiked(postId: post.id, uid: currentUid),
                        builder: (context, snap) {
                          final hasLiked = snap.data ?? false;
                          return _ActionPill(
                            icon: hasLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor:
                                hasLiked ? const Color(0xFFB3261E) : null,
                            label: _formatCount(post.likeCount),
                            onTap: () => repo.toggleLike(postId: post.id),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: Icons.mode_comment_outlined,
                  label: _formatCount(post.commentCount),
                  onTap: () => CommentsSheet.show(
                    context,
                    postId: post.id,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: Icons.repeat_rounded,
                  label: _formatCount(post.repostCount),
                  onTap: currentUid == null
                      ? null
                      : () => repo.repost(original: post),
                ),
              ),
            ],
          ),
          _PostCommentPreview(post: post),
        ],
      ),
    );
  }

  static String _formatCount(int v) => v.toString();
}

class _PostCommentPreview extends StatelessWidget {
  const _PostCommentPreview({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    if (post.commentCount <= 0) return const SizedBox.shrink();

    final repo = CommunityRepository();
    return StreamBuilder<List<CommunityComment>>(
      stream: repo.watchCommentPreviewForPost(post.id),
      builder: (context, snap) {
        final comments = snap.data ?? const <CommunityComment>[];
        if (comments.isEmpty &&
            snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (comments.isEmpty) return const SizedBox.shrink();

        final moreComments = post.commentCount > comments.length;
        final moreReplies = comments.any((c) => c.replies.length > 2);
        final showViewMore = moreComments || moreReplies;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in comments) ...[
                  _PreviewCommentLine(comment: c),
                  for (final r in c.replies.take(2))
                    _PreviewReplyLine(reply: r),
                ],
                if (showViewMore)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          CommentsSheet.show(context, postId: post.id),
                      child: const Text('View more comments'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewCommentLine extends StatelessWidget {
  const _PreviewCommentLine({required this.comment});

  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.25,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDefaultUserAvatarByUid(
            userId: comment.uid,
            fallbackImageUrl: comment.profileImageUrl,
            size: 22,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${comment.name} ',
                    style: baseStyle?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: comment.text, style: baseStyle),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewReplyLine extends StatelessWidget {
  const _PreviewReplyLine({required this.reply});

  final CommunityReply reply;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.25,
        );
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDefaultUserAvatarByUid(
            userId: reply.userId,
            fallbackImageUrl: reply.userAvatar,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${reply.userName} ',
                    style: baseStyle?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: reply.text, style: baseStyle),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.authorId,
    required this.authorName,
    required this.authorProfileImageUrl,
    required this.createdAt,
    required this.onAuthorTap,
  });

  final String authorId;
  final String authorName;
  final String? authorProfileImageUrl;
  final DateTime createdAt;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onAuthorTap,
          borderRadius: BorderRadius.circular(999),
          child: AppDefaultUserAvatarByUid(
            userId: authorId,
            fallbackImageUrl: authorProfileImageUrl,
            size: 40,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeAgo(createdAt),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor ?? AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
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

class _RepostPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat_rounded, size: 16, color: AppColors.primaryDeep),
          const SizedBox(width: 6),
          Text(
            'Repost',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

Uint8List? _tryDecodeBase64PostImage(String raw) {
  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

class _PostMediaGallery extends StatelessWidget {
  const _PostMediaGallery({
    required this.networkUrls,
    required this.base64Images,
  });

  final List<String> networkUrls;
  final List<String> base64Images;

  int get _total => networkUrls.length + base64Images.length;

  @override
  Widget build(BuildContext context) {
    if (_total == 0) return const SizedBox.shrink();
    if (_total == 1) {
      final url = networkUrls.isNotEmpty ? networkUrls.first : null;
      final b64 = base64Images.isNotEmpty ? base64Images.first : null;
      return _SinglePostImage(networkUrl: url, base64: b64);
    }
    return _PostMediaCarousel(
      networkUrls: networkUrls,
      base64Images: base64Images,
    );
  }
}

class _SinglePostImage extends StatelessWidget {
  const _SinglePostImage({required this.networkUrl, required this.base64});

  final String? networkUrl;
  final String? base64;

  @override
  Widget build(BuildContext context) {
    final u = (networkUrl ?? '').trim();
    if (u.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CachedNetworkImage(
            imageUrl: u,
            fit: BoxFit.cover,
            placeholder: (context, _) => Container(
              color: AppColors.surfaceMuted,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryDeep),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.surfaceMuted,
              child: const Center(
                child: Icon(Icons.broken_image_rounded),
              ),
            ),
          ),
        ),
      );
    }
    final bytes = _tryDecodeBase64PostImage((base64 ?? '').trim());
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Icon(Icons.broken_image_rounded),
    );
  }
}

class _PostMediaCarousel extends StatefulWidget {
  const _PostMediaCarousel({
    required this.networkUrls,
    required this.base64Images,
  });

  final List<String> networkUrls;
  final List<String> base64Images;

  int get total => networkUrls.length + base64Images.length;

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: n,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              Widget child;
              if (i < widget.networkUrls.length) {
                child = CachedNetworkImage(
                  imageUrl: widget.networkUrls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  placeholder: (context, _) => Container(
                    color: AppColors.surfaceMuted,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryDeep),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceMuted,
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded),
                    ),
                  ),
                );
              } else {
                final bi = i - widget.networkUrls.length;
                final raw = bi < widget.base64Images.length ? widget.base64Images[bi] : '';
                final bytes = _tryDecodeBase64PostImage(raw);
                child = bytes != null && bytes.isNotEmpty
                    ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: 200)
                    : Container(
                        color: AppColors.surfaceMuted,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded),
                        ),
                      );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: child,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            n,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page == i ? 10 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _page == i ? AppColors.primaryDeep : AppColors.outline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

