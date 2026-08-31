import 'package:cloud_functions/cloud_functions.dart';

import 'app_check_guard.dart';

/// Maps Cloud Functions / App Check failures to Thai messages for admin UI.
class AdminCallableErrors {
  AdminCallableErrors._();

  static String message(Object error, {String fallback = 'ดำเนินการไม่สำเร็จ'}) {
    if (error is FirebaseFunctionsException) {
      return _functionsMessage(error, fallback: fallback);
    }
    final text = error.toString();
    if (text.contains('App Check')) {
      return text;
    }
    return '$fallback: $text';
  }

  static String _functionsMessage(
    FirebaseFunctionsException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case 'not-found':
        return 'ไม่พบ Cloud Function "${error.message ?? ''}" — ต้อง deploy จาก van2 (asia-southeast1)';
      case 'unauthenticated':
        return 'ยังไม่ได้เข้าสู่ระบบ หรือ session หมดอายุ';
      case 'permission-denied':
        return 'ไม่มีสิทธิ์เรียก function นี้ — ตรวจ admins/{email} และ App Check';
      case 'failed-precondition':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'เงื่อนไขไม่ครบ (failed-precondition)';
      case 'invalid-argument':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'ข้อมูลไม่ถูกต้อง';
      case 'deadline-exceeded':
        return 'เซิร์ฟเวอร์ใช้เวลานานเกินไป กรุณาลองใหม่';
      case 'unavailable':
        return 'บริการ Cloud Functions ไม่พร้อมชั่วคราว';
      default:
        final detail = error.message?.trim();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
        return '$fallback (${error.code})';
    }
  }

  static String appCheckSetupHint() {
    if (AppCheckGuard.usesDebugProvider) {
      return 'ลงทะเบียน debug token ที่ Firebase Console → App Check → แอป Android van4.com '
          '(ไม่ใช่ Web) → ${AppCheckGuard.debugTokenHint} แล้วปิดเปิดแอปใหม่';
    }
    return 'แอป release ใช้ Play Integrity — ติดตั้ง APK ที่ build ด้วย APP_CHECK_DEBUG '
        'หรือลงทะเบียน SHA signing key ใน Firebase Console → App Check';
  }
}
