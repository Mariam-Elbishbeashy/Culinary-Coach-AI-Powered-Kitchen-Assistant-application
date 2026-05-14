import 'package:cloud_firestore/cloud_firestore.dart';

/// Community story stored in Firestore (base64 image, no Firebase Storage).
/// Legacy docs may still contain `videoBase64` / `videoThumbBase64` / `mediaType`;
/// the app ignores video playback but keeps parsing non-breaking.
class CommunityStory {
  const CommunityStory({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.imageBase64,
    required this.textOverlay,
    required this.createdAt,
    required this.expiresAt,
    required this.likedBy,
    required this.archived,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String imageBase64;
  final String textOverlay;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> likedBy;
  final bool archived;

  int get likeCount => likedBy.length;

  /// Effective expiry for "active" UI: use [expiresAt] when it is valid and not before
  /// [createdAt]; otherwise treat as missing/invalid and use [createdAt] + 24h.
  DateTime get resolvedExpiresAt {
    final c = createdAt;
    final fallback = c.millisecondsSinceEpoch > 0
        ? c.add(const Duration(hours: 24))
        : DateTime.fromMillisecondsSinceEpoch(0);
    final ex = expiresAt;
    if (ex.millisecondsSinceEpoch <= 0) return fallback;
    if (c.millisecondsSinceEpoch > 0 && ex.isBefore(c)) return fallback;
    return ex;
  }

  bool isActiveAt(DateTime when) => when.isBefore(resolvedExpiresAt);

  bool likedByUid(String? uid) {
    final u = uid?.trim();
    if (u == null || u.isEmpty) return false;
    for (final e in likedBy) {
      if (e.trim() == u) return true;
    }
    return false;
  }

  /// Archive list thumbnail (image only; legacy video-only stories may be empty).
  String get archiveThumbBase64 => imageBase64;

  static CommunityStory fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final created = _readTime(data['createdAt']);
    final expires = _readTime(data['expiresAt']);
    final likedRaw = data['likedBy'];
    final liked = <String>[];
    if (likedRaw is List) {
      for (final e in likedRaw) {
        if (e is String && e.trim().isNotEmpty) liked.add(e.trim());
      }
    }
    final b64 = _readImageBase64(data);
    return CommunityStory(
      id: doc.id,
      userId: (data['userId'] as String?)?.trim() ?? '',
      userName: (data['userName'] as String?)?.trim() ?? 'User',
      userAvatar: () {
        final u = (data['userAvatar'] as String?)?.trim();
        if (u == null || u.isEmpty) return null;
        return u;
      }(),
      imageBase64: b64,
      textOverlay: (data['textOverlay'] as String?) ?? '',
      createdAt: created,
      expiresAt: expires,
      likedBy: liked,
      archived: (data['archived'] as bool?) ?? true,
    );
  }

  static String _readImageBase64(Map<String, dynamic> data) {
    final direct = (data['imageBase64'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final list = data['imageBase64List'];
    if (list is List && list.isNotEmpty) {
      final first = list.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    return '';
  }

  static DateTime _readTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      if (raw <= 0) return DateTime.fromMillisecondsSinceEpoch(0);
      // Heuristic: seconds vs millis
      if (raw < 20000000000) return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) return _readTime(raw.toInt());
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
      final asInt = int.tryParse(t);
      if (asInt != null) return _readTime(asInt);
      final parsed = DateTime.tryParse(t);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// Active stories for one user (for the stories strip / viewer), newest last for paging.
class CommunityStoryRing {
  const CommunityStoryRing({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.stories,
  });

  final String userId;
  final String userName;
  final String? userAvatar;
  final List<CommunityStory> stories;
}
