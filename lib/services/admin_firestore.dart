import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Shared Firestore helpers for van4 admin (desktop gRPC can be flaky on cold start).
class AdminFirestore {
  AdminFirestore._();

  static final FirebaseFirestore instance = FirebaseFirestore.instance;

  static bool _warmedUp = false;

  /// Lightweight ping after login — establishes the Firestore channel early.
  static Future<void> warmUp() async {
    if (_warmedUp) {
      return;
    }
    try {
      await runWithRetry<void>(
        () async {
          await instance
              .collection('admins')
              .limit(1)
              .get(const GetOptions(source: Source.server));
        },
        attempts: 5,
        label: 'warmUp',
      );
      _warmedUp = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AdminFirestore warmUp failed: $error');
      }
    }
  }

  static Future<T> runWithRetry<T>(
    Future<T> Function() action, {
    int attempts = 5,
    String label = 'firestore',
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 400 * attempt * attempt),
        );
        try {
          await instance.enableNetwork();
        } catch (_) {}
      }

      try {
        return await action();
      } on FirebaseException catch (error) {
        lastError = error;
        if (!_isRetryable(error)) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint(
            'AdminFirestore retry ($label) attempt ${attempt + 1}/$attempts: ${error.code}',
          );
        }
      }
    }

    throw lastError ?? StateError('AdminFirestore $label failed');
  }

  static bool _isRetryable(FirebaseException error) {
    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'aborted' ||
        error.code == 'resource-exhausted';
  }

  static String userMessage(Object error, {String fallback = 'เชื่อมต่อ Firestore ไม่สำเร็จ'}) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable') {
        return '$fallback — บริการไม่พร้อม ลองใหม่อีกครั้ง';
      }
      if (error.code == 'permission-denied') {
        return '$fallback — ไม่มีสิทธิ์ (ตรวจ admins/{email} และการล็อกอิน)';
      }
      final detail = error.message?.trim();
      if (detail != null && detail.isNotEmpty) {
        return '$fallback ($detail)';
      }
      return '$fallback (${error.code})';
    }
    return '$fallback: $error';
  }
}
