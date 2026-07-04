import 'package:cloud_firestore/cloud_firestore.dart';

class SocialAccountRecord {
  const SocialAccountRecord({
    required this.id,
    required this.platform,
    required this.displayName,
    this.externalPageId,
    this.igUsername,
    this.thumbnailUrl,
    this.connectedAt,
  });

  final String id;
  final String platform;
  final String displayName;
  final String? externalPageId;
  final String? igUsername;
  final String? thumbnailUrl;
  final DateTime? connectedAt;

  factory SocialAccountRecord.fromMap(String id, Map<String, dynamic> data) {
    return SocialAccountRecord(
      id: id,
      platform: data['platform']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      externalPageId: data['externalPageId']?.toString(),
      igUsername: data['igUsername']?.toString(),
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      connectedAt: _toDateTime(data['connectedAt']),
    );
  }
}

abstract final class SocialPlatformKey {
  static const String meta = 'meta';
  static const String youtube = 'youtube';
  static const String tiktok = 'tiktok';
}

abstract final class SocialPlatformTarget {
  static const String metaFb = 'meta_fb';
  static const String metaIg = 'meta_ig';
  static const String youtube = 'youtube';
  static const String tiktok = 'tiktok';

  static const List<String> all = <String>[
    metaFb,
    metaIg,
    youtube,
    tiktok,
  ];

  static String label(String target) {
    switch (target) {
      case metaFb:
        return 'Facebook';
      case metaIg:
        return 'Instagram Reels';
      case youtube:
        return 'YouTube Shorts';
      case tiktok:
        return 'TikTok';
      default:
        return target;
    }
  }
}

abstract final class SocialPostStatus {
  static const String draft = 'draft';
  static const String publishing = 'publishing';
  static const String published = 'published';
  static const String partialFailed = 'partial_failed';
  static const String failed = 'failed';

  static String label(String status) {
    switch (status) {
      case draft:
        return 'แบบร่าง';
      case publishing:
        return 'กำลังโพสต์';
      case published:
        return 'โพสต์แล้ว';
      case partialFailed:
        return 'สำเร็จบางแพลตฟอร์ม';
      case failed:
        return 'ล้มเหลว';
      default:
        return status;
    }
  }
}

class SocialPlatformResult {
  const SocialPlatformResult({
    required this.status,
    this.externalPostId,
    this.url,
    this.error,
  });

  final String status;
  final String? externalPostId;
  final String? url;
  final String? error;

  factory SocialPlatformResult.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const SocialPlatformResult(status: 'pending');
    }
    return SocialPlatformResult(
      status: data['status']?.toString() ?? 'pending',
      externalPostId: data['externalPostId']?.toString(),
      url: data['url']?.toString(),
      error: data['error']?.toString(),
    );
  }
}

class SocialPostRecord {
  const SocialPostRecord({
    required this.id,
    required this.caption,
    required this.selectedPlatforms,
    required this.status,
    required this.platformResults,
    this.sourceVideoPath,
    this.thumbnailPath,
    this.hashtags = const <String>[],
    this.createdAt,
    this.publishedAt,
    this.error,
  });

  final String id;
  final String caption;
  final List<String> selectedPlatforms;
  final String status;
  final Map<String, SocialPlatformResult> platformResults;
  final String? sourceVideoPath;
  final String? thumbnailPath;
  final List<String> hashtags;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final String? error;

  factory SocialPostRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawPlatforms = data['selectedPlatforms'];
    final platforms = rawPlatforms is List
        ? rawPlatforms.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    final rawHashtags = data['hashtags'];
    final hashtags = rawHashtags is List
        ? rawHashtags.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    final rawResults = data['platformResults'];
    final results = <String, SocialPlatformResult>{};
    if (rawResults is Map) {
      for (final entry in rawResults.entries) {
        final value = entry.value;
        results[entry.key.toString()] = SocialPlatformResult.fromMap(
          value is Map<String, dynamic>
              ? value
              : Map<String, dynamic>.from(value as Map),
        );
      }
    }

    return SocialPostRecord(
      id: doc.id,
      caption: data['caption']?.toString() ?? '',
      selectedPlatforms: platforms,
      status: data['status']?.toString() ?? SocialPostStatus.draft,
      platformResults: results,
      sourceVideoPath: data['sourceVideoPath']?.toString(),
      thumbnailPath: data['thumbnailPath']?.toString(),
      hashtags: hashtags,
      createdAt: _toDateTime(data['createdAt']),
      publishedAt: _toDateTime(data['publishedAt']),
      error: data['error']?.toString(),
    );
  }
}

class SocialCommentRecord {
  const SocialCommentRecord({
    required this.id,
    required this.postId,
    required this.platform,
    required this.text,
    required this.replyStatus,
    this.authorName,
    this.authorAvatarUrl,
    this.ourReply,
    this.createdAt,
    this.repliedAt,
  });

  final String id;
  final String postId;
  final String platform;
  final String text;
  final String replyStatus;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? ourReply;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  factory SocialCommentRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return SocialCommentRecord(
      id: doc.id,
      postId: data['postId']?.toString() ?? '',
      platform: data['platform']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      replyStatus: data['replyStatus']?.toString() ?? 'open',
      authorName: data['authorName']?.toString(),
      authorAvatarUrl: data['authorAvatarUrl']?.toString(),
      ourReply: data['ourReply']?.toString(),
      createdAt: _toDateTime(data['createdAt']),
      repliedAt: _toDateTime(data['repliedAt']),
    );
  }
}

DateTime? _toDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return null;
}
