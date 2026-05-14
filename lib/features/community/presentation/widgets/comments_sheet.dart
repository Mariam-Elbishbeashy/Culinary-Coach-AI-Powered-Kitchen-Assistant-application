import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/app_default_user_avatar.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/models/community_comment.dart';
import 'package:culinary_coach_app/features/community/data/models/community_reply.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_emoji_picker_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({required this.postId, super.key});

  final String postId;

  static Future<void> show(BuildContext context, {required String postId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  CommunityComment? _replyingTo;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startReply(CommunityComment c) {
    setState(() {
      _replyingTo = c;
      _controller.text = '@${c.name} ';
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _controller.clear();
    });
  }

  Future<void> _send(CommunityRepository repo) async {
    final raw = _controller.text;
    final text = raw.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      if (_replyingTo != null) {
        await repo.addReply(
          postId: widget.postId,
          commentId: _replyingTo!.id,
          text: raw,
        );
        _cancelReply();
      } else {
        await repo.addComment(postId: widget.postId, text: text);
        _controller.clear();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final repo = CommunityRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: Container(
          color: AppColors.background,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Row(
                    children: [
                      Text(
                        'Comments',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: StreamBuilder(
                    stream: repo.watchComments(widget.postId),
                    builder: (context, snapshot) {
                      final comments = snapshot.data ?? const [];
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          comments.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(18, 20, 18, 20),
                          child: Text(
                            'Be the first to comment.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final c = comments[i];
                          return _CommentBlock(
                            postId: widget.postId,
                            comment: c,
                            currentUid: currentUid,
                            repo: repo,
                            onReply: () => _startReply(c),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (currentUid != null) ...[
                  if (_replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply_rounded, size: 18, color: AppColors.primaryDeep),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Replying to ${_replyingTo!.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: _cancelReply,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.outline),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 4),
                            child: CurrentUserAvatar(
                              size: 32,
                              backgroundColor: const Color(0xFFD28E18),
                              borderColor:
                                  Colors.white.withValues(alpha: 0.65),
                              borderWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              cursorColor: AppColors.primaryDeep,
                              decoration: InputDecoration(
                                hintText: _replyingTo != null
                                    ? 'Write a reply...'
                                    : 'Write a comment...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: CommunityEmojiIconButton(
                              onPressed: _sending
                                  ? null
                                  : () => showCommunityEmojiPickerSheet(
                                        context,
                                        textController: _controller,
                                      ),
                            ),
                          ),
                          IconButton(
                            onPressed: _sending ? null : () => _send(repo),
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentBlock extends StatelessWidget {
  const _CommentBlock({
    required this.postId,
    required this.comment,
    required this.currentUid,
    required this.repo,
    required this.onReply,
  });

  final String postId;
  final CommunityComment comment;
  final String? currentUid;
  final CommunityRepository repo;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final c = comment;
    final liked = c.isLikedBy(currentUid);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDefaultUserAvatarByUid(
                userId: c.uid,
                fallbackImageUrl: c.profileImageUrl,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(c.createdAt),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        InkWell(
                          onTap: currentUid == null
                              ? null
                              : () => repo.toggleCommentLike(
                                    postId: postId,
                                    commentId: c.id,
                                  ),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 17,
                                  color: liked
                                      ? const Color(0xFFB3261E)
                                      : AppColors.textMuted,
                                ),
                                if (c.likesCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${c.likesCount}',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (currentUid != null)
                          InkWell(
                            onTap: onReply,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.reply_rounded,
                                    size: 17,
                                    color: AppColors.primaryDeep,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reply',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDeep,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...c.replies.map(
              (r) => _ReplyRow(
                postId: postId,
                commentId: c.id,
                reply: r,
                currentUid: currentUid,
                repo: repo,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyRow extends StatelessWidget {
  const _ReplyRow({
    required this.postId,
    required this.commentId,
    required this.reply,
    required this.currentUid,
    required this.repo,
  });

  final String postId;
  final String commentId;
  final CommunityReply reply;
  final String? currentUid;
  final CommunityRepository repo;

  @override
  Widget build(BuildContext context) {
    final r = reply;
    final liked = r.isLikedBy(currentUid);

    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDefaultUserAvatarByUid(
            userId: r.userId,
            fallbackImageUrl: r.userAvatar,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    Text(
                      _timeAgo(r.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: currentUid == null
                      ? null
                      : () => repo.toggleReplyLike(
                            postId: postId,
                            commentId: commentId,
                            replyId: r.id,
                          ),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 15,
                          color: liked ? const Color(0xFFB3261E) : AppColors.textMuted,
                        ),
                        if (r.likesCount > 0) ...[
                          const SizedBox(width: 3),
                          Text(
                            '${r.likesCount}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  return '${diff.inDays}d';
}
