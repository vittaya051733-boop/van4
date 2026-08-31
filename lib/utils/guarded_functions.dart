import 'package:cloud_functions/cloud_functions.dart';

import 'admin_callable_errors.dart';
import 'app_check_guard.dart';

class GuardedFunctions {
  GuardedFunctions._();

  static FirebaseFunctions get _region =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static Future<HttpsCallableResult<dynamic>> call(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await AppCheckGuard.ensureCallableReady();
      return await _region
          .httpsCallable(name)
          .call(parameters ?? <String, dynamic>{});
    } on FirebaseFunctionsException catch (error) {
      throw FirebaseFunctionsException(
        code: error.code,
        message: AdminCallableErrors.message(
          error,
          fallback: 'เรียก $name ไม่สำเร็จ',
        ),
        details: error.details,
      );
    }
  }

  /// Non-destructive ping: function exists if error is not `not-found`.
  static Future<AdminCallableProbeResult> probeCallable(String name) async {
    try {
      await AppCheckGuard.ensureCallableReady();
      await _region.httpsCallable(name).call(<String, dynamic>{});
      return AdminCallableProbeResult(name: name, reachable: true, detail: 'ตอบกลับแล้ว');
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        return AdminCallableProbeResult(
          name: name,
          reachable: false,
          detail: 'ไม่พบ function — ต้อง deploy จาก van2',
        );
      }
      return AdminCallableProbeResult(
        name: name,
        reachable: true,
        detail: 'พบ function (${error.code})',
      );
    } catch (error) {
      return AdminCallableProbeResult(
        name: name,
        reachable: false,
        detail: AdminCallableErrors.message(error),
      );
    }
  }
}

class AdminCallableProbeResult {
  const AdminCallableProbeResult({
    required this.name,
    required this.reachable,
    required this.detail,
  });

  final String name;
  final bool reachable;
  final String detail;
}
