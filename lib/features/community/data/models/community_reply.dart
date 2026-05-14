import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityReply {
  const CommunityReply({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.createdAt,
    required this.likedBy,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final DateTime createdAt;
  final List<String> likedBy;

  int get likesCount => likedBy.length;

  bool isLikedBy(String? uid) =>
      uid != null && uid.isNotEmpty && likedBy.contains(uid);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likedBy': likedBy,
    };
  }

  CommunityReply copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? text,
    DateTime? createdAt,
    List<String>? likedBy,
  }) {
    return CommunityReply(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likedBy: likedBy ?? this.likedBy,
    );
  }

  static CommunityReply fromMap(Map<String, dynamic> raw) {
    final createdAtRaw = raw['createdAt'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final likedRaw = raw['likedBy'];
    final likedBy = <String>[];
    if (likedRaw is List) {
      for (final e in likedRaw) {
        if (e is String && e.trim().isNotEmpty) likedBy.add(e.trim());
      }
    }

    return CommunityReply(
      id: (raw['id'] as String?)?.trim() ?? '',
      userId: (raw['userId'] as String?)?.trim() ?? '',
      userName: (raw['userName'] as String?)?.trim() ?? 'User',
      userAvatar: (raw['userAvatar'] as String?)?.trim(),
      text: (raw['text'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      likedBy: likedBy,
    );
  }

  static List<CommunityReply> listFromField(dynamic field) {
    if (field is! List) return const [];
    final out = <CommunityReply>[];
    for (final item in field) {
      if (item is Map<String, dynamic>) {
        out.add(CommunityReply.fromMap(item));
      } else if (item is Map) {
        out.add(CommunityReply.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    return out;
  }
}
