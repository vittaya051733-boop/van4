import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../admin_internal_chat_repository.dart';
import '../models/admin_peer_chat_message.dart';

/// Local disk cache for admin chat messages and images (van4 only).
class AdminChatCacheService {
  AdminChatCacheService._();

  static final AdminChatCacheService instance = AdminChatCacheService._();

  static const int _maxImageFiles = 200;
  static const String _internalScope = 'internal';
  static const String _peerScope = 'peer';

  Directory? _rootDir;
  final Map<String, Future<File?>> _imageDownloads = <String, Future<File?>>{};

  Future<Directory> _root() async {
    if (_rootDir != null) {
      return _rootDir!;
    }
    final docs = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${docs.path}/van4_chat_cache');
    if (!_rootDir!.existsSync()) {
      await _rootDir!.create(recursive: true);
    }
    return _rootDir!;
  }

  Future<File> _messagesFile(String scope, String threadId) async {
    final dir = Directory('${(await _root()).path}/messages/$scope');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$threadId.json');
  }

  String _imageKey(String url) {
    final digest = sha256.convert(utf8.encode(url.trim()));
    return digest.toString();
  }

  Future<File> _imageFile(String url) async {
    final dir = Directory('${(await _root()).path}/images');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/${_imageKey(url)}.bin');
  }

  Future<List<AdminInternalMessage>> readInternalMessages(String threadId) async {
    try {
      final file = await _messagesFile(_internalScope, threadId);
      if (!file.existsSync()) {
        return const <AdminInternalMessage>[];
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const <AdminInternalMessage>[];
      }
      final raw = decoded['messages'];
      if (raw is! List) {
        return const <AdminInternalMessage>[];
      }
      return raw
          .whereType<Map>()
          .map((item) => _internalMessageFromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (error, stack) {
      debugPrint('AdminChatCache readInternalMessages failed: $error\n$stack');
      return const <AdminInternalMessage>[];
    }
  }

  Future<void> writeInternalMessages(
    String threadId,
    List<AdminInternalMessage> messages,
  ) async {
    try {
      final file = await _messagesFile(_internalScope, threadId);
      final payload = <String, dynamic>{
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': messages.map(_internalMessageToJson).toList(growable: false),
      };
      await file.writeAsString(jsonEncode(payload));
      unawaited(_prefetchInternalImages(messages));
    } catch (error, stack) {
      debugPrint('AdminChatCache writeInternalMessages failed: $error\n$stack');
    }
  }

  Future<List<AdminPeerChatMessage>> readPeerMessages(String chatId) async {
    try {
      final file = await _messagesFile(_peerScope, chatId);
      if (!file.existsSync()) {
        return const <AdminPeerChatMessage>[];
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const <AdminPeerChatMessage>[];
      }
      final raw = decoded['messages'];
      if (raw is! List) {
        return const <AdminPeerChatMessage>[];
      }
      return raw
          .whereType<Map>()
          .map((item) => _peerMessageFromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (error, stack) {
      debugPrint('AdminChatCache readPeerMessages failed: $error\n$stack');
      return const <AdminPeerChatMessage>[];
    }
  }

  Future<void> writePeerMessages(
    String chatId,
    List<AdminPeerChatMessage> messages,
  ) async {
    try {
      final file = await _messagesFile(_peerScope, chatId);
      final payload = <String, dynamic>{
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'messages': messages.map(_peerMessageToJson).toList(growable: false),
      };
      await file.writeAsString(jsonEncode(payload));
      unawaited(_prefetchPeerImages(messages));
    } catch (error, stack) {
      debugPrint('AdminChatCache writePeerMessages failed: $error\n$stack');
    }
  }

  Future<File?> cachedImageFile(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final file = await _imageFile(trimmed);
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    return null;
  }

  Future<File?> fetchAndCacheImage(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return Future<File?>.value(null);
    }
    return _imageDownloads.putIfAbsent(trimmed, () async {
      try {
        final existing = await cachedImageFile(trimmed);
        if (existing != null) {
          return existing;
        }

        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(trimmed));
          final response = await request.close();
          if (response.statusCode != 200) {
            return null;
          }
          final bytes = await consolidateHttpClientResponseBytes(response);
          if (bytes.isEmpty) {
            return null;
          }
          final file = await _imageFile(trimmed);
          await file.writeAsBytes(bytes, flush: true);
          await _trimImageCacheIfNeeded();
          return file;
        } finally {
          client.close(force: true);
        }
      } catch (error, stack) {
        debugPrint('AdminChatCache fetchAndCacheImage failed: $error\n$stack');
        return null;
      } finally {
        _imageDownloads.remove(trimmed);
      }
    });
  }

  Future<void> _prefetchInternalImages(List<AdminInternalMessage> messages) async {
    for (final message in messages) {
      for (final url in message.imageUrls) {
        unawaited(fetchAndCacheImage(url));
      }
      for (final attachment in message.attachments) {
        if (attachment.isImage) {
          unawaited(fetchAndCacheImage(attachment.url));
        }
      }
    }
  }

  Future<void> _prefetchPeerImages(List<AdminPeerChatMessage> messages) async {
    for (final message in messages) {
      final url = message.mediaUrl;
      if (message.type == 'image' && url != null && url.trim().isNotEmpty) {
        unawaited(fetchAndCacheImage(url));
      }
    }
  }

  Future<void> _trimImageCacheIfNeeded() async {
    try {
      final dir = Directory('${(await _root()).path}/images');
      if (!dir.existsSync()) {
        return;
      }
      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.lengthSync() > 0)
          .toList(growable: false);
      if (files.length <= _maxImageFiles) {
        return;
      }
      files.sort(
        (left, right) =>
            left.lastModifiedSync().compareTo(right.lastModifiedSync()),
      );
      final removeCount = files.length - _maxImageFiles;
      for (var index = 0; index < removeCount; index++) {
        await files[index].delete();
      }
    } catch (error, stack) {
      debugPrint('AdminChatCache trim images failed: $error\n$stack');
    }
  }

  static Map<String, dynamic> _internalMessageToJson(AdminInternalMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'senderUid': message.senderUid,
      'senderName': message.senderName,
      'message': message.message,
      'imageUrls': message.imageUrls,
      'attachments': message.attachments
          .map(
            (item) => <String, dynamic>{
              'name': item.name,
              'url': item.url,
              'mimeType': item.mimeType,
            },
          )
          .toList(growable: false),
      'createdAt': message.createdAt?.toIso8601String(),
    };
  }

  static AdminInternalMessage _internalMessageFromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    return AdminInternalMessage(
      id: (json['id'] as String?) ?? '',
      senderUid: (json['senderUid'] as String?) ?? '',
      senderName: (json['senderName'] as String?) ?? 'แอดมิน',
      message: (json['message'] as String?) ?? '',
      imageUrls: ((json['imageUrls'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false),
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map>()
              .map(
                (item) => AdminInternalAttachment.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.url.isNotEmpty)
              .toList(growable: false)
          : const <AdminInternalAttachment>[],
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static Map<String, dynamic> _peerMessageToJson(AdminPeerChatMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'senderId': message.senderId,
      'type': message.type,
      'text': message.text,
      'mediaUrl': message.mediaUrl,
      'fileName': message.fileName,
      'createdAt': message.createdAt?.toIso8601String(),
    };
  }

  static AdminPeerChatMessage _peerMessageFromJson(Map<String, dynamic> json) {
    return AdminPeerChatMessage(
      id: (json['id'] as String?) ?? '',
      senderId: (json['senderId'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'text',
      text: json['text'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      fileName: json['fileName'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
