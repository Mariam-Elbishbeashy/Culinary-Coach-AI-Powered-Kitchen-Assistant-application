import 'package:culinary_coach_app/core/widgets/user_avatar_by_uid.dart';
import 'package:flutter/material.dart';

/// Default avatar styling aligned with the Home header (gold fill, white icon,
/// soft light ring). Use for community lists, comments, and post cards.
class AppDefaultUserAvatarByUid extends StatelessWidget {
  const AppDefaultUserAvatarByUid({
    super.key,
    required this.userId,
    this.fallbackImageUrl,
    this.size = 40,
    this.onTap,
    this.borderColor,
    this.borderWidth = 2,
    this.heroTag,
  });

  final String userId;
  final String? fallbackImageUrl;
  final double size;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  /// Optional stable hero tag (e.g. `profile-avatar-$userId`) for navigation transitions.
  final String? heroTag;

  static const Color fill = Color(0xFFD28E18);

  static Color get defaultBorder => Colors.white.withValues(alpha: 0.65);

  @override
  Widget build(BuildContext context) {
    return UserAvatarByUid(
      userId: userId,
      fallbackImageUrl: fallbackImageUrl,
      size: size,
      onTap: onTap,
      borderColor: borderColor ?? defaultBorder,
      borderWidth: borderWidth,
      backgroundColor: fill,
      iconColor: Colors.white,
      heroTag: heroTag,
    );
  }
}
