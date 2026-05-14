import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/features/community/data/models/community_comment.dart';
import 'package:culinary_coach_app/features/community/data/models/community_reply.dart';
import 'package:culinary_coach_app/features/community/data/models/community_notification.dart';
import 'package:culinary_coach_app/features/community/data/models/community_post.dart';
import 'package:culinary_coach_app/features/community/data/models/community_story.dart';
import 'package:culinary_coach_app/features/community/data/models/community_user.dart';
import 'package:culinary_coach_app/features/community/data/services/community_post_image_encoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class FollowListEntry {
  const FollowListEntry({
    required this.uid,
    required this.name,
    this.profileImageUrl,
  });

  final String uid;
  final String name;
  final String? profileImageUrl;
}

class CommunityRepository {
  CommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User get _requireUser {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('Not signed in');
    }
    return u;
  }

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> postsCol() =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> storiesCol() =>
      _firestore.collection('stories');

  CollectionReference<Map<String, dynamic>> followersCol(String uid) =>
      userDoc(uid).collection('followers');

  CollectionReference<Map<String, dynamic>> followingCol(String uid) =>
      userDoc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> notificationsCol(String uid) =>
      userDoc(uid).collection('notifications');

  Stream<List<String>> watchFollowingUids(String uid) {
    return followingCol(uid).snapshots().transform(
          StreamTransformer<QuerySnapshot<Map<String, dynamic>>, List<String>>.fromHandlers(
            handleData: (snap, sink) {
              try {
                final uids = snap.docs
                    .map((d) {
                      final data = d.data();
                      final fromField = (data['uid'] as String?)?.trim();
                      if (fromField != null && fromField.isNotEmpty) return fromField;
                      return d.id.trim();
                    })
                    .where((id) => id.isNotEmpty)
                    .toSet()
                    .toList();
                uids.sort();
                sink.add(uids);
              } catch (e, st) {
                developer.log(
                  'watchFollowingUids map failed',
                  name: 'CommunityRepository',
                  error: e,
                  stackTrace: st,
                );
                sink.add(const <String>[]);
              }
            },
            handleError: (Object e, StackTrace st, EventSink<List<String>> sink) {
              developer.log(
                'watchFollowingUids stream error',
                name: 'CommunityRepository',
                error: e,
                stackTrace: st,
              );
              sink.add(const <String>[]);
            },
          ),
        );
  }

  Stream<CommunityUser?> watchUser(String uid) {
    return userDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommunityUser.fromDoc(doc);
    });
  }

  Future<CommunityUser?> getUser(String uid) async {
    final doc = await userDoc(uid).get();
    if (!doc.exists) return null;
    return CommunityUser.fromDoc(doc);
  }

  Future<bool> isFollowing({
    required String viewerUid,
    required String targetUid,
  }) async {
    if (viewerUid == targetUid) return false;
    final doc = await followingCol(viewerUid).doc(targetUid).get();
    return doc.exists;
  }

  Stream<bool> watchIsFollowing({
    required String viewerUid,
    required String targetUid,
  }) {
    if (viewerUid == targetUid) return Stream.value(false);
    return followingCol(viewerUid).doc(targetUid).snapshots().map((d) => d.exists);
  }

  Future<void> followUser({
    required String targetUid,
  }) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    if (viewerUid == targetUid) return;

    final viewerData = await getUser(viewerUid);
    final targetData = await getUser(targetUid);
    if (targetData == null) return;

    final viewerName = viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final viewerProfileUrl = viewerData?.profileImageUrl ?? viewer.photoURL;
    final now = Timestamp.now();

    await _firestore.runTransaction((tx) async {
      final followingRef = followingCol(viewerUid).doc(targetUid);
      final followerRef = followersCol(targetUid).doc(viewerUid);

      final existing = await tx.get(followingRef);
      if (existing.exists) return;

      tx.set(
        followingRef,
        {
          'uid': targetUid,
          'name': targetData.displayName,
          'profileImageUrl': targetData.profileImageUrl,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );
      tx.set(
        followerRef,
        {
          'uid': viewerUid,
          'name': viewerName,
          'profileImageUrl': viewerProfileUrl,
          'createdAt': now,
        },
        SetOptions(merge: true),
      );

      tx.set(
        userDoc(targetUid),
        {'followersCount': FieldValue.increment(1), 'updatedAt': now},
        SetOptions(merge: true),
      );
      tx.set(
        userDoc(viewerUid),
        {'followingCount': FieldValue.increment(1), 'updatedAt': now},
        SetOptions(merge: true),
      );

      final notifRef = notificationsCol(targetUid).doc();
      tx.set(notifRef, {
        'type': 'follow',
        'fromUid': viewerUid,
        'fromName': viewerName,
        'fromProfileImageUrl': viewerProfileUrl,
        'message': '$viewerName started following you.',
        'createdAt': now,
        'read': false,
      });
    });
  }

  Future<void> unfollowUser({
    required String targetUid,
  }) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    if (viewerUid == targetUid) return;

    final now = Timestamp.now();
    await _firestore.runTransaction((tx) async {
      final followingRef = followingCol(viewerUid).doc(targetUid);
      final followerRef = followersCol(targetUid).doc(viewerUid);

      final existing = await tx.get(followingRef);
      if (!existing.exists) return;

      tx.delete(followingRef);
      tx.delete(followerRef);

      tx.set(
        userDoc(targetUid),
        {'followersCount': FieldValue.increment(-1), 'updatedAt': now},
        SetOptions(merge: true),
      );
      tx.set(
        userDoc(viewerUid),
        {'followingCount': FieldValue.increment(-1), 'updatedAt': now},
        SetOptions(merge: true),
      );
    });
  }

  Future<String> createPost({
    required String caption,
    String? recipeTitle,
    String? cookingTime,
    List<String>? tags,
    List<XFile> images = const [],
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final postRef = postsCol().doc();

    final now = Timestamp.now();
    final uid = viewer.uid;

    await viewer.getIdToken(true);

    var imageBase64List = <String>[];
    if (images.isNotEmpty) {
      developer.log(
        'createPost: encoding ${images.length} image(s) for Firestore (no Storage)',
        name: 'CommunityRepository',
      );
      try {
        imageBase64List = await encodeCommunityPostImagesForFirestore(images);
        developer.log(
          'createPost: encode OK count=${imageBase64List.length}',
          name: 'CommunityRepository',
        );
      } catch (e, st) {
        developer.log(
          'createPost: encode FAILED error=$e',
          name: 'CommunityRepository',
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }

    if (images.isNotEmpty && imageBase64List.isEmpty) {
      throw StateError(
        'Could not process the selected images. Try again or pick different photos.',
      );
    }

    final payload = <String, dynamic>{
      'authorId': uid,
      'authorName': viewerData?.displayName ?? (viewer.displayName ?? 'User'),
      'authorProfileImageUrl': viewerData?.profileImageUrl ?? viewer.photoURL,
      'caption': caption.trim(),
      'recipeTitle': recipeTitle?.trim().isEmpty ?? true ? null : recipeTitle!.trim(),
      'cookingTime': cookingTime?.trim().isEmpty ?? true ? null : cookingTime!.trim(),
      'tags': (tags ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'createdAt': now,
      'likeCount': 0,
      'commentCount': 0,
      'repostCount': 0,
    };
    if (imageBase64List.isNotEmpty) {
      payload['imageBase64List'] = imageBase64List;
    }

    await postRef.set(payload);

    await userDoc(viewer.uid).set(
      {'communityPosts': FieldValue.increment(1), 'updatedAt': now},
      SetOptions(merge: true),
    );

    return postRef.id;
  }

  Query<Map<String, dynamic>> queryPostsForUser(String uid) {
    // Avoid composite-index requirements (authorId + createdAt).
    // We'll sort client-side by createdAt for stability.
    return postsCol().where('authorId', isEqualTo: uid);
  }

  /// Returns a query for the first "page" of feed posts.
  /// Note: uses whereIn with chunking limit 30 internally by returning multiple queries,
  /// but for simplicity in UI we provide a single "combined stream" method.
  Stream<List<CommunityPost>> watchFeedPosts({bool includeMyPosts = true}) {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;

    late final StreamController<List<CommunityPost>> controller;
    StreamSubscription? followingSub;
    final postSubs = <StreamSubscription>[];
    var latest = <List<CommunityPost>>[];

    void cancelPostSubs() {
      for (final s in postSubs) {
        s.cancel();
      }
      postSubs.clear();
      latest = <List<CommunityPost>>[];
    }

    void emitMerged() {
      final merged = latest.expand((e) => e).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged);
    }

    controller = StreamController<List<CommunityPost>>(
      onListen: () {
        followingSub = watchFollowingUids(viewerUid).listen((followed) {
          cancelPostSubs();

          final authors = <String>{
            if (includeMyPosts) viewerUid,
            ...followed,
          }.toList();

          if (authors.isEmpty) {
            controller.add(const <CommunityPost>[]);
            return;
          }

          // Firestore whereIn supports up to 30 values.
          final chunks = <List<String>>[];
          for (var i = 0; i < authors.length; i += 30) {
            chunks.add(
              authors.sublist(
                i,
                i + 30 > authors.length ? authors.length : i + 30,
              ),
            );
          }

          latest = List<List<CommunityPost>>.generate(chunks.length, (_) => const []);

          for (var i = 0; i < chunks.length; i++) {
            final chunk = chunks[i];
            postSubs.add(
              postsCol()
                  .where('authorId', whereIn: chunk)
                  .limit(50)
                  .snapshots()
                  .listen((snap) {
                final list = snap.docs.map(CommunityPost.fromDoc).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                latest[i] = list;
                emitMerged();
              }),
            );
          }

          // Emit immediately for stable UI while snapshots load.
          controller.add(const <CommunityPost>[]);
        });
      },
      onCancel: () async {
        await followingSub?.cancel();
        cancelPostSubs();
      },
    );

    return controller.stream;
  }

  Stream<List<CommunityPost>> watchPostsForUser(String uid) {
    return queryPostsForUser(uid).limit(50).snapshots().map((snap) {
      final posts = snap.docs.map(CommunityPost.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Stream<List<FollowListEntry>> watchFollowList({
    required String targetUid,
    required bool followers,
  }) {
    final col = followers ? followersCol(targetUid) : followingCol(targetUid);
    return col.snapshots().map((snap) {
      final out = <FollowListEntry>[];
      for (final d in snap.docs) {
        final data = d.data();
        final rawUid = (data['uid'] as String?)?.trim();
        final uid = (rawUid != null && rawUid.isNotEmpty) ? rawUid : d.id;
        if (uid.isEmpty) continue;
        final rawName = (data['name'] as String?)?.trim();
        final rawPic = (data['profileImageUrl'] as String?)?.trim();
        out.add(
          FollowListEntry(
            uid: uid,
            name: (rawName != null && rawName.isNotEmpty) ? rawName : 'User',
            profileImageUrl:
                (rawPic != null && rawPic.isNotEmpty) ? rawPic : null,
          ),
        );
      }
      out.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return out;
    });
  }

  Stream<bool> watchHasLiked({
    required String postId,
    required String uid,
  }) {
    return postsCol()
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }

  Future<void> toggleLike({
    required String postId,
  }) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    final postRef = postsCol().doc(postId);
    final likeRef = postRef.collection('likes').doc(viewerUid);

    final viewerData = await getUser(viewerUid);
    final viewerName = viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final viewerProfileUrl = viewerData?.profileImageUrl ?? viewer.photoURL;
    final now = Timestamp.now();

    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;

      final authorId =
          (postSnap.data()!['authorId'] as String?)?.trim() ?? '';
      final likeNotifRef = (authorId.isNotEmpty && authorId != viewerUid)
          ? notificationsCol(authorId).doc('post_like_${postId}_$viewerUid')
          : null;

      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        if (authorId.isNotEmpty) {
          tx.set(
            userDoc(authorId),
            {'likesCount': FieldValue.increment(-1)},
            SetOptions(merge: true),
          );
        }
        if (likeNotifRef != null) {
          tx.delete(likeNotifRef);
        }
      } else {
        tx.set(likeRef, {'uid': viewerUid, 'createdAt': now});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        if (authorId.isNotEmpty) {
          tx.set(
            userDoc(authorId),
            {'likesCount': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
        if (likeNotifRef != null) {
          tx.set(likeNotifRef, {
            'type': 'post_like',
            'postId': postId,
            'fromUid': viewerUid,
            'fromName': viewerName,
            'fromProfileImageUrl': viewerProfileUrl,
            'message': '$viewerName liked your post',
            'createdAt': now,
            'read': false,
            'recipientUserId': authorId,
            'senderUserId': viewerUid,
          });
        }
      }
    });
  }

  Stream<List<CommunityComment>> watchComments(String postId) {
    return postsCol()
        .doc(postId)
        .collection('comments')
        .limit(100)
        .snapshots()
        .map((snap) {
      final comments = snap.docs.map(CommunityComment.fromDoc).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    });
  }

  /// First comments (chronological) for compact feed preview; avoids `orderBy`
  /// so older comment docs without indexes still work.
  Stream<List<CommunityComment>> watchCommentPreviewForPost(String postId) {
    return postsCol()
        .doc(postId)
        .collection('comments')
        .limit(30)
        .snapshots()
        .map((snap) {
      final comments = snap.docs.map(CommunityComment.fromDoc).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments.take(2).toList();
    });
  }

  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final postRef = postsCol().doc(postId);
    final commentRef = postRef.collection('comments').doc();

    final now = Timestamp.now();
    final senderName =
        viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final senderProfileUrl = viewerData?.profileImageUrl ?? viewer.photoURL;
    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      if (!postSnap.exists) return;
      final postAuthorId =
          (postSnap.data()!['authorId'] as String?)?.trim() ?? '';
      tx.set(commentRef, {
        'uid': viewer.uid,
        'name': senderName,
        'profileImageUrl': senderProfileUrl,
        'text': text.trim(),
        'createdAt': now,
        'likedBy': <String>[],
        'replies': <Map<String, dynamic>>[],
      });
      tx.update(postRef, {'commentCount': FieldValue.increment(1)});
      if (postAuthorId.isNotEmpty && postAuthorId != viewer.uid) {
        final notifRef = notificationsCol(postAuthorId).doc();
        tx.set(notifRef, {
          'type': 'comment',
          'recipientUserId': postAuthorId,
          'senderUserId': viewer.uid,
          'postId': postId,
          'fromUid': viewer.uid,
          'fromName': senderName,
          'fromProfileImageUrl': senderProfileUrl,
          'message': '$senderName commented on your post',
          'createdAt': now,
          'read': false,
        });
      }
    });
  }

  Future<void> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async {
    final viewer = _requireUser;
    final uid = viewer.uid;
    final ref = postsCol().doc(postId).collection('comments').doc(commentId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final likedRaw = data['likedBy'];
      var hasLike = false;
      if (likedRaw is List) {
        for (final e in likedRaw) {
          if (e == uid) {
            hasLike = true;
            break;
          }
        }
      }
      if (hasLike) {
        tx.update(ref, {'likedBy': FieldValue.arrayRemove([uid])});
      } else {
        tx.update(ref, {'likedBy': FieldValue.arrayUnion([uid])});
      }
    });
  }

  Future<void> addReply({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    final viewer = _requireUser;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final viewerData = await getUser(viewer.uid);
    final replyId = postsCol().doc().id;
    final reply = CommunityReply(
      id: replyId,
      userId: viewer.uid,
      userName: viewerData?.displayName ?? (viewer.displayName ?? 'User'),
      userAvatar: viewerData?.profileImageUrl ?? viewer.photoURL,
      text: trimmed,
      createdAt: DateTime.now(),
      likedBy: const [],
    );

    final postRef = postsCol().doc(postId);
    final ref = postRef.collection('comments').doc(commentId);
    final now = Timestamp.now();
    final senderName =
        viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final senderProfileUrl = viewerData?.profileImageUrl ?? viewer.photoURL;
    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      final snap = await tx.get(ref);
      if (!postSnap.exists || !snap.exists) return;
      final postAuthorId =
          (postSnap.data()!['authorId'] as String?)?.trim() ?? '';
      final data = snap.data() ?? {};
      final existing = CommunityReply.listFromField(data['replies']);
      final merged = [...existing, reply];
      tx.update(ref, {
        'replies': merged.map((e) => e.toFirestore()).toList(),
      });
      if (postAuthorId.isNotEmpty && postAuthorId != viewer.uid) {
        final notifRef = notificationsCol(postAuthorId).doc();
        tx.set(notifRef, {
          'type': 'reply',
          'recipientUserId': postAuthorId,
          'senderUserId': viewer.uid,
          'postId': postId,
          'fromUid': viewer.uid,
          'fromName': senderName,
          'fromProfileImageUrl': senderProfileUrl,
          'message': '$senderName replied to a comment on your post',
          'createdAt': now,
          'read': false,
        });
      }
    });
  }

  Future<void> toggleReplyLike({
    required String postId,
    required String commentId,
    required String replyId,
  }) async {
    final viewer = _requireUser;
    final uid = viewer.uid;
    final ref = postsCol().doc(postId).collection('comments').doc(commentId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final replies = CommunityReply.listFromField(data['replies']);
      final idx = replies.indexWhere((r) => r.id == replyId);
      if (idx < 0) return;

      final r = replies[idx];
      final liked = List<String>.from(r.likedBy);
      if (liked.contains(uid)) {
        liked.remove(uid);
      } else {
        liked.add(uid);
      }

      final updated = [...replies];
      updated[idx] = r.copyWith(likedBy: liked);
      tx.update(ref, {
        'replies': updated.map((e) => e.toFirestore()).toList(),
      });
    });
  }

  Future<void> repost({
    required CommunityPost original,
    String? caption,
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final postRef = postsCol().doc();

    final now = Timestamp.now();
    final reposterName =
        viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final reposterProfileUrl =
        viewerData?.profileImageUrl ?? viewer.photoURL;

    await _firestore.runTransaction((tx) async {
      final originalRef = postsCol().doc(original.id);
      final originalSnap = await tx.get(originalRef);
      if (!originalSnap.exists) return;

      final originalAuthorId =
          (originalSnap.data()!['authorId'] as String?)?.trim() ??
              original.authorId;

      tx.set(postRef, {
        'authorId': viewer.uid,
        'authorName': viewerData?.displayName ?? (viewer.displayName ?? 'User'),
        'authorProfileImageUrl': viewerData?.profileImageUrl ?? viewer.photoURL,
        'caption': (caption?.trim().isNotEmpty ?? false) ? caption!.trim() : original.caption,
        if (original.imageUrls.isNotEmpty) 'imageUrls': original.imageUrls,
        if (original.imageBase64List.isNotEmpty)
          'imageBase64List': original.imageBase64List,
        'recipeTitle': original.recipeTitle,
        'cookingTime': original.cookingTime,
        'tags': original.tags,
        'createdAt': now,
        'likeCount': 0,
        'commentCount': 0,
        'repostCount': 0,
        'repostOfPostId': original.id,
        'originalAuthorId': original.authorId,
      });
      tx.update(originalRef, {'repostCount': FieldValue.increment(1)});

      if (originalAuthorId.isNotEmpty && originalAuthorId != viewer.uid) {
        final notifRef = notificationsCol(originalAuthorId)
            .doc('post_repost_${original.id}_${viewer.uid}');
        tx.set(notifRef, {
          'type': 'post_repost',
          'postId': original.id,
          'fromUid': viewer.uid,
          'fromName': reposterName,
          'fromProfileImageUrl': reposterProfileUrl,
          'message': '$reposterName reposted your post',
          'createdAt': now,
          'read': false,
          'recipientUserId': originalAuthorId,
          'senderUserId': viewer.uid,
        });
      }
    });
  }

  Stream<List<CommunityUser>> watchAllUsers({int limit = 80}) {
    // Avoid relying on optional fields for ordering (some existing docs may not
    // have displayNameLower yet). Sort client-side for stability.
    return _firestore.collection('users').limit(limit).snapshots().map((snap) {
      final users = snap.docs.map(CommunityUser.fromDoc).toList();
      users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return users;
    });
  }

  Stream<List<CommunityUser>> watchSuggestedUsers({
    required String excludeUid,
    int limit = 10,
  }) {
    // Best-effort: show a stable list of recent users with displayNameLower present.
    // Exclude current user on the client side.
    return _firestore
        .collection('users')
        .orderBy('updatedAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snap) {
      final users = snap.docs.map(CommunityUser.fromDoc).toList();
      final filtered =
          users.where((u) => u.uid != excludeUid).take(limit).toList();
      return filtered;
    });
  }

  Stream<List<CommunityUser>> watchUserSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Stream.value(const <CommunityUser>[]);

    return _firestore
        .collection('users')
        .where('nameKeywords', arrayContains: q)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(CommunityUser.fromDoc).toList());
  }

  Stream<List<CommunityNotification>> watchNotifications() {
    final viewer = _requireUser;
    return notificationsCol(viewer.uid).limit(50).snapshots().map((snap) {
      final items = snap.docs.map(CommunityNotification.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Stream<int> watchUnreadNotificationsCount() {
    final viewer = _requireUser;
    return notificationsCol(viewer.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final viewer = _requireUser;
    await notificationsCol(viewer.uid).doc(notificationId).set(
      {'read': true},
      SetOptions(merge: true),
    );
  }

  Future<void> markAllNotificationsRead() async {
    final viewer = _requireUser;
    final snap = await notificationsCol(viewer.uid)
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.set(d.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Creates a story document (base64 image via [encodeCommunityPostImagesForFirestore]).
  Future<String> createStory({
    required XFile image,
    required String textOverlay,
  }) async {
    final viewer = _requireUser;
    final viewerData = await getUser(viewer.uid);
    final storyRef = storiesCol().doc();

    final encoded = await encodeCommunityPostImagesForFirestore([image]);
    if (encoded.isEmpty) {
      throw StateError(
        'Could not process the photo. Try again or pick a different image.',
      );
    }

    final created = DateTime.now();
    final expires = created.add(const Duration(hours: 24));
    final nowTs = Timestamp.fromDate(created);
    final expiresTs = Timestamp.fromDate(expires);

    await storyRef.set({
      'userId': viewer.uid.trim(),
      'userName': viewerData?.displayName ?? (viewer.displayName ?? 'User'),
      'userAvatar': viewerData?.profileImageUrl ?? viewer.photoURL,
      'imageBase64': encoded.first,
      'textOverlay': textOverlay,
      'createdAt': nowTs,
      'expiresAt': expiresTs,
      'likedBy': <String>[],
      'archived': true,
    });

    final preview = CommunityStory.fromDoc(await storyRef.get());
    developer.log(
      'createStory: id=${storyRef.id} userId=${preview.userId} createdAt=${preview.createdAt.toIso8601String()} '
      'expiresAt=${preview.expiresAt.toIso8601String()} resolvedExpiresAt=${preview.resolvedExpiresAt.toIso8601String()}',
      name: 'CommunityRepository',
    );

    return storyRef.id;
  }

  Stream<CommunityStory?> watchStory(String storyId) {
    return storiesCol().doc(storyId).snapshots().map((d) {
      if (!d.exists) return null;
      return CommunityStory.fromDoc(d);
    });
  }

  /// All stories authored by [uid] (including expired), newest first.
  Stream<List<CommunityStory>> watchMyStoriesArchive(String uid) {
    return storiesCol()
        .where('userId', isEqualTo: uid)
        .limit(200)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(CommunityStory.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Active stories for the viewer and people they follow (grouped per user).
  Stream<List<CommunityStoryRing>> watchActiveStoryRings({
    required String viewerUid,
  }) {
    final viewer = viewerUid.trim();
    late final StreamController<List<CommunityStoryRing>> controller;
    StreamSubscription<DateTime>? tickSub;
    StreamSubscription<List<String>>? followingSub;
    final storySubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    Map<String, List<CommunityStory>> latestByUid = {};

    void cancelStorySubs() {
      for (final s in storySubs) {
        s.cancel();
      }
      storySubs.clear();
      latestByUid = {};
    }

    void emitMerged() {
      if (controller.isClosed) return;
      final batchLists = latestByUid.values.toList();
      controller.add(
        _buildStoryRingsFromBatches(
          batchLists,
          DateTime.now(),
          viewer,
        ),
      );
    }

    controller = StreamController<List<CommunityStoryRing>>(
      onListen: () {
        tickSub = Stream<DateTime>.periodic(
          const Duration(seconds: 30),
          (_) => DateTime.now(),
        ).listen((_) => emitMerged());

        followingSub = watchFollowingUids(viewer).listen((followed) {
          cancelStorySubs();

          final followedTrimmed =
              followed.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          developer.log(
            'watchActiveStoryRings: currentUserId=$viewer followingCount=${followedTrimmed.length} '
            'followingUids=$followedTrimmed',
            name: 'CommunityRepository',
          );

          final authors = <String>{
            viewer,
            ...followedTrimmed,
          }.toList()
            ..sort();

          latestByUid = {
            for (final uid in authors) uid: const <CommunityStory>[],
          };

          for (final uid in authors) {
            final captured = uid.trim();
            if (captured.isEmpty) continue;
            storySubs.add(
              storiesCol()
                  .where('userId', isEqualTo: captured)
                  .limit(200)
                  .snapshots()
                  .listen(
                    (snap) {
                      latestByUid[captured] =
                          snap.docs.map(CommunityStory.fromDoc).toList();
                      emitMerged();
                    },
                    onError: (Object e, StackTrace st) {
                      developer.log(
                        'watchActiveStoryRings stories query error uid=$captured',
                        name: 'CommunityRepository',
                        error: e,
                        stackTrace: st,
                      );
                      latestByUid[captured] = const <CommunityStory>[];
                      emitMerged();
                    },
                  ),
            );
          }

          emitMerged();
        });
      },
      onCancel: () async {
        await tickSub?.cancel();
        await followingSub?.cancel();
        cancelStorySubs();
      },
    );

    return controller.stream;
  }

  Future<void> toggleStoryLike({required String storyId}) async {
    final viewer = _requireUser;
    final viewerUid = viewer.uid;
    final storyRef = storiesCol().doc(storyId);

    final viewerData = await getUser(viewerUid);
    final viewerName = viewerData?.displayName ?? (viewer.displayName ?? 'User');
    final viewerProfileUrl = viewerData?.profileImageUrl ?? viewer.photoURL;
    final now = Timestamp.now();

    await _firestore.runTransaction((tx) async {
      final storySnap = await tx.get(storyRef);
      if (!storySnap.exists) return;

      final data = storySnap.data() ?? const <String, dynamic>{};
      final ownerId = (data['userId'] as String?)?.trim() ?? '';
      final likedRaw = data['likedBy'];
      var liked = false;
      if (likedRaw is List) {
        for (final e in likedRaw) {
          if (e == viewerUid) {
            liked = true;
            break;
          }
        }
      }

      final likeNotifRef = (ownerId.isNotEmpty && ownerId != viewerUid)
          ? notificationsCol(ownerId).doc('story_like_${storyId}_$viewerUid')
          : null;

      if (liked) {
        tx.update(storyRef, {'likedBy': FieldValue.arrayRemove([viewerUid])});
        if (likeNotifRef != null) {
          tx.delete(likeNotifRef);
        }
      } else {
        tx.update(storyRef, {'likedBy': FieldValue.arrayUnion([viewerUid])});
        if (likeNotifRef != null) {
          tx.set(likeNotifRef, {
            'type': 'story_like',
            'storyId': storyId,
            'storyOwnerId': ownerId,
            'likerUserId': viewerUid,
            'likerName': viewerName,
            'fromUid': viewerUid,
            'fromName': viewerName,
            'fromProfileImageUrl': viewerProfileUrl,
            'message': '$viewerName liked your story',
            'createdAt': now,
            'timestamp': now,
            'read': false,
            'recipientUserId': ownerId,
            'senderUserId': viewerUid,
          });
        }
      }
    });
  }
}

List<CommunityStoryRing> _buildStoryRingsFromBatches(
  List<List<CommunityStory>> latest,
  DateTime now,
  String viewerUid,
) {
  final viewer = viewerUid.trim();
  final merged = latest
      .expand((e) => e)
      .where((s) => s.userId.trim().isNotEmpty && s.isActiveAt(now))
      .toList();

  developer.log(
    'storyRings: currentUserId=$viewer activeStories=${merged.length} now=${now.toIso8601String()}',
    name: 'CommunityRepository',
  );
  if (merged.isNotEmpty) {
    final s = merged.first;
    developer.log(
      'storyRings sample: userId=${s.userId} resolvedExpiresAt=${s.resolvedExpiresAt.toIso8601String()} '
      'isActive=${s.isActiveAt(now)}',
      name: 'CommunityRepository',
    );
  }

  final byUser = <String, List<CommunityStory>>{};
  for (final s in merged) {
    final uid = s.userId.trim();
    if (uid.isEmpty) continue;
    byUser.putIfAbsent(uid, () => []).add(s);
  }
  for (final list in byUser.values) {
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  final rings = byUser.entries
      .map((e) {
        final first = e.value.first;
        return CommunityStoryRing(
          userId: e.key,
          userName: first.userName,
          userAvatar: first.userAvatar,
          stories: List<CommunityStory>.from(e.value),
        );
      })
      .toList();
  rings.sort((a, b) {
    if (a.userId.trim() == viewer) return -1;
    if (b.userId.trim() == viewer) return 1;
    return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
  });
  developer.log(
    'storyRings: ringsBuilt=${rings.length}',
    name: 'CommunityRepository',
  );
  return rings;
}

