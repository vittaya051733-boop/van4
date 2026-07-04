import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/social_models.dart';
import 'admin_social_firestore.dart';

class AdminSocialService {
  AdminSocialService._();

  static final AdminSocialService instance = AdminSocialService._();

  static const String _postsCollection = 'social_posts';
  static const String _commentsCollection = 'social_comments';
  static const String _accountsCollection = 'social_accounts';

  FirebaseFirestore get _db => AdminSocialFirestore.instance;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      );

  Stream<List<SocialPostRecord>> streamPosts({int limit = 40}) {
    return _db
        .collection(_postsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SocialPostRecord.fromSnapshot)
              .toList(growable: false),
        );
  }

  Stream<List<SocialCommentRecord>> streamComments({
    String? replyStatus,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection(_commentsCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (replyStatus != null && replyStatus.isNotEmpty) {
      query = _db
          .collection(_commentsCollection)
          .where('replyStatus', isEqualTo: replyStatus)
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(SocialCommentRecord.fromSnapshot)
              .toList(growable: false),
        );
  }

  Stream<List<SocialAccountRecord>> streamAccounts() {
    return _db.collection(_accountsCollection).snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['active'] != false)
          .map(
            (doc) => SocialAccountRecord.fromMap(doc.id, doc.data()),
          )
          .toList(growable: false);
    });
  }

  Future<String> uploadSocialVideo({
    required String postId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final sanitized = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'social_media/$postId/source_$sanitized';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'video/mp4'),
    );
    return path;
  }

  Future<String> getSocialOAuthUrl({
    required String platform,
    required String returnUrl,
  }) async {
    final callable = _functions.httpsCallable('getSocialOAuthUrl');
    final response = await callable.call(<String, dynamic>{
      'platform': platform,
      'returnUrl': returnUrl,
    });
    final data = response.data;
    if (data is! Map) {
      throw StateError('OAuth URL response ไม่ถูกต้อง');
    }
    final url = data['url']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw StateError('ไม่ได้รับ OAuth URL');
    }
    return url;
  }

  Future<List<SocialAccountRecord>> fetchAccounts() async {
    final callable = _functions.httpsCallable('listSocialAccounts');
    final response = await callable.call();
    final data = response.data;
    if (data is! Map) {
      return const <SocialAccountRecord>[];
    }
    final raw = data['accounts'];
    if (raw is! List) {
      return const <SocialAccountRecord>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => SocialAccountRecord(
            id: item['id']?.toString() ?? '',
            platform: item['platform']?.toString() ?? '',
            displayName: item['displayName']?.toString() ?? '',
            externalPageId: item['externalPageId']?.toString(),
            igUsername: item['igUsername']?.toString(),
            thumbnailUrl: item['thumbnailUrl']?.toString(),
            connectedAt: item['connectedAt'] != null
                ? DateTime.tryParse(item['connectedAt'].toString())
                : null,
          ),
        )
        .toList(growable: false);
  }

  Future<void> disconnectAccount(String accountId) async {
    final callable = _functions.httpsCallable('disconnectSocialAccount');
    await callable.call(<String, dynamic>{'accountId': accountId});
  }

  Future<void> createPost({
    required String postId,
    required String caption,
    required String sourceVideoPath,
    required List<String> selectedPlatforms,
    List<String> hashtags = const <String>[],
    String? thumbnailPath,
  }) async {
    final callable = _functions.httpsCallable('createSocialPost');
    await callable.call(<String, dynamic>{
      'postId': postId,
      'caption': caption,
      'sourceVideoPath': sourceVideoPath,
      if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
      'selectedPlatforms': selectedPlatforms,
      'hashtags': hashtags,
    });
  }

  Future<void> retryPlatform({
    required String postId,
    required String platformTarget,
  }) async {
    final callable = _functions.httpsCallable('retrySocialPostPlatform');
    await callable.call(<String, dynamic>{
      'postId': postId,
      'platformTarget': platformTarget,
    });
  }

  Future<void> replyComment({
    required String commentId,
    required String message,
  }) async {
    final callable = _functions.httpsCallable('replySocialComment');
    await callable.call(<String, dynamic>{
      'commentId': commentId,
      'message': message,
    });
  }
}
