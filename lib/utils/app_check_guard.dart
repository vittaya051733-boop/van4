import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'feature_flags.dart';

/// Ensures App Check token is available before protected admin callables.
class AppCheckGuard {
  const AppCheckGuard._();

  static const String debugTokenHint =
      'a3f9c2e1-4b8d-4a6f-9e2c-1d7b5e8f0a42';

  static bool get usesDebugProvider => !kReleaseMode || kAppCheckForceDebug;

  static Future<void> ensureCallableReady() async {
    await _ensureToken(
      releaseMessage:
          'ไม่สามารถยืนยันความปลอดภัยของอุปกรณ์ได้ กรุณาอัปเดตแอปแล้วลองใหม่',
      requiredInDebug: true,
    );
  }

  static Future<void> _ensureToken({
    required String releaseMessage,
    bool requiredInDebug = false,
  }) async {
    Object? lastError;
    for (final forceRefresh in [false, true]) {
      try {
        final token = await FirebaseAppCheck.instance
            .getToken(forceRefresh)
            .timeout(const Duration(seconds: 8));
        if (token != null && token.trim().isNotEmpty) {
          return;
        }
        lastError = StateError('App Check token ว่าง');
      } catch (error) {
        lastError = error;
      }
    }

    if (kReleaseMode || requiredInDebug) {
      if (requiredInDebug && usesDebugProvider) {
        throw Exception(
          'App Check ยังไม่พร้อม — ลงทะเบียน debug token ที่ App Check → แอป Android van4.com แล้วปิดเปิดแอปใหม่: $debugTokenHint',
        );
      }
      if (requiredInDebug && kReleaseMode && !usesDebugProvider) {
        throw Exception(
          'App Check release ใช้ Play Integrity — debug token ใช้ไม่ได้ '
          'ติดตั้ง APK ที่ build ด้วย APP_CHECK_DEBUG หรือลงทะเบียน SHA ใน Firebase Console',
        );
      }
      throw Exception(releaseMessage);
    }
    if (kDebugMode && lastError != null) {
      debugPrint('App Check token unavailable (debug): $lastError');
    }
  }
}
