import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorProfileImageUrl,
    required this.caption,
    required this.imageUrl,
    required this.imageUrls,
    required this.imageBase64List,
    required this.videoBase64,
    required this.videoThumbBase64,
    required this.recipeTitle,
    required this.cookingTime,
    required this.tags,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.repostOfPostId,
    required this.originalAuthorId,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfileImageUrl;
  final String caption;
  /// Legacy single image (still merged when loading old posts).
  final String? imageUrl;
  /// Network image URLs from Firebase Storage or elsewhere (legacy posts).
  final List<String> imageUrls;
  /// JPEG bytes as Base64, stored in Firestore for new posts (no Storage).
  final List<String> imageBase64List;
  /// MP4 bytes as Base64 (no Storage), optional video attachment.
  final String? videoBase64;
  /// JPEG thumbnail Base64 for video posts.
  final String? videoThumbBase64;
  final String? recipeTitle;
  final String? cookingTime;
  final List<String> tags;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final int repostCount;

  // Repost support
  final String? repostOfPostId;
  final String? originalAuthorId;

  bool get isRepost => repostOfPostId != null && repostOfPostId!.isNotEmpty;

  bool get hasPostImages =>
      imageUrls.isNotEmpty || imageBase64List.isNotEmpty;

  bool get hasPostVideo {
    final v = (videoBase64 ?? '').trim();
    return v.isNotEmpty;
  }

  /// Alias names aligned with product vocabulary (same underlying Firestore fields).
  String get userId => authorId;
  String get userName => authorName;
  String? get userAvatar => authorProfileImageUrl;
  String get text => caption;
  int get likesCount => likeCount;
  int get commentsCount => commentCount;

  static CommunityPost fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final tagsRaw = data['tags'];
    final tags = (tagsRaw is List)
        ? tagsRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final mergedUrls = _mergeImageUrlsFromDoc(data);
    final base64List = _readImageBase64List(data);
    final vid = (data['videoBase64'] as String?)?.trim();
    final vthumb = (data['videoThumbBase64'] as String?)?.trim();

    return CommunityPost(
      id: doc.id,
      authorId: (data['authorId'] as String?)?.trim() ?? '',
      authorName: (data['authorName'] as String?)?.trim() ?? 'User',
      authorProfileImageUrl: (data['authorProfileImageUrl'] as String?)?.trim(),
      caption: (data['caption'] as String?)?.trim() ?? '',
      imageUrl: mergedUrls.isNotEmpty ? mergedUrls.first : null,
      imageUrls: mergedUrls,
      imageBase64List: base64List,
      videoBase64: vid == null || vid.isEmpty ? null : vid,
      videoThumbBase64: vthumb == null || vthumb.isEmpty ? null : vthumb,
      recipeTitle: (data['recipeTitle'] as String?)?.trim(),
      cookingTime: (data['cookingTime'] as String?)?.trim(),
      tags: tags,
      createdAt: createdAt,
      likeCount: _readInt(data['likeCount']),
      commentCount: _readInt(data['commentCount']),
      repostCount: _readInt(data['repostCount']),
      repostOfPostId: (data['repostOfPostId'] as String?)?.trim(),
      originalAuthorId: (data['originalAuthorId'] as String?)?.trim(),
    );
  }

  static int _readInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  /// Prefer `imageUrls`; fall back to legacy `imageUrl`.
  static List<String> _mergeImageUrlsFromDoc(Map<String, dynamic> data) {
    final fromList = data['imageUrls'];
    final urls = <String>[];
    if (fromList is List) {
      for (final e in fromList) {
        if (e is String) {
          final u = e.trim();
          if (u.isNotEmpty) urls.add(u);
        }
      }
    }
    final legacy = (data['imageUrl'] as String?)?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      if (!urls.contains(legacy)) {
        urls.insert(0, legacy);
      }
    }
    return urls;
  }

  static List<String> _readImageBase64List(Map<String, dynamic> data) {
    final raw = data['imageBase64List'];
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
