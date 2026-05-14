import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/core/utils/platform_file.dart';
import 'package:flutter/material.dart';

/// Avatar that follows the latest profile image from the `users/{userId}` doc,
/// falling back to [fallbackImageUrl] (e.g. stale post/comment snapshot) when needed.
class UserAvatarByUid extends StatelessWidget {
  const UserAvatarByUid({
    super.key,
    required this.userId,
    this.fallbackImageUrl,
    this.size = 40,
    this.onTap,
    this.borderColor,
    this.borderWidth = 2,
    this.backgroundColor = const Color(0xFFD28E18),
    this.iconColor = Colors.white,
    this.heroTag,
  });

  final String userId;
  final String? fallbackImageUrl;
  final double size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final Color backgroundColor;
  final Color iconColor;

  /// When set, wraps the avatar so hero flights are unique per user (e.g. `profile-avatar-$userId`).
  final String? heroTag;

  static String? _readUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    String? rs(String k) {
      final v = data[k];
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return rs('profileImageUrl') ??
        rs('photoUrl') ??
        rs('photoURL') ??
        rs('avatarUrl');
  }

  static String? _readLocal(Map<String, dynamic>? data) {
    final v = data?['profileImageLocalPath'];
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final uid = userId.trim();
    final effectiveBorder =
        borderColor ?? Colors.white.withValues(alpha: 0.65);

    Widget wrapHero(Widget child) {
      final tag = heroTag?.trim();
      if (tag == null || tag.isEmpty) return child;
      return Hero(tag: tag, child: Material(type: MaterialType.transparency, child: child));
    }

    Widget shell(Widget child) {
      final content = Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(color: effectiveBorder, width: borderWidth),
        ),
        child: ClipOval(child: child),
      );
      if (onTap == null) return content;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      );
    }

    if (uid.isEmpty) {
      final fb = (fallbackImageUrl ?? '').trim();
      if (fb.isNotEmpty) {
        return wrapHero(
          shell(
            CachedNetworkImage(
              imageUrl: fb,
              fit: BoxFit.cover,
              placeholder: (context, progress) => _placeholderIcon(),
              errorWidget: (context, url, error) => _placeholderIcon(),
            ),
          ),
        );
      }
      return wrapHero(shell(_placeholderIcon()));
    }

    return wrapHero(
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final liveLocal = _readLocal(data);
          final liveUrl = _readUrl(data);
          final fb = (fallbackImageUrl ?? '').trim();

          final file = liveLocal != null ? platformFileFromPath(liveLocal) : null;
          if (file != null) {
            return shell(Image.file(file, fit: BoxFit.cover));
          }

          final url = (liveUrl != null && liveUrl.isNotEmpty)
              ? liveUrl
              : (fb.isNotEmpty ? fb : null);

          if (url != null && url.isNotEmpty) {
            return shell(
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, progress) => _placeholderIcon(),
                errorWidget: (context, url, error) => _placeholderIcon(),
              ),
            );
          }

          return shell(_placeholderIcon());
        },
      ),
    );
  }

  Widget _placeholderIcon() {
    return Icon(
      Icons.person,
      color: iconColor,
      size: size * 0.55,
    );
  }
}
