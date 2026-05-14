import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/community/data/models/community_reply.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.uid,
    required this.name,
    required this.profileImageUrl,
    required this.text,
    required this.createdAt,
    required this.likedBy,
    required this.replies,
  });

  final String id;
  final String uid;
  final String name;
  final String? profileImageUrl;
  final String text;
  final DateTime createdAt;
  final List<String> likedBy;
  final List<CommunityReply> replies;

  int get likesCount => likedBy.length;

  bool isLikedBy(String? viewerUid) =>
      viewerUid != null && viewerUid.isNotEmpty && likedBy.contains(viewerUid);

  static CommunityComment fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final likedRaw = data['likedBy'];
    final likedBy = <String>[];
    if (likedRaw is List) {
      for (final e in likedRaw) {
        if (e is String && e.trim().isNotEmpty) likedBy.add(e.trim());
      }
    }

    return CommunityComment(
      id: doc.id,
      uid: (data['uid'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? 'User',
      profileImageUrl: (data['profileImageUrl'] as String?)?.trim(),
      text: (data['text'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      likedBy: likedBy,
      replies: CommunityReply.listFromField(data['replies']),
    );
  }
}
