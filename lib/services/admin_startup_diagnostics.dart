import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import '../admin_repository.dart';
import '../utils/app_check_guard.dart';

enum AdminDiagnosticStatus { ok, warn, fail }

class AdminDiagnosticResult {
  const AdminDiagnosticResult({
    required this.id,
    required this.label,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final AdminDiagnosticStatus status;
  final String detail;

  bool get isOk => status == AdminDiagnosticStatus.ok;
}

/// Lightweight health checks after admin login (Level 0 smoke).
class AdminStartupDiagnostics {
  AdminStartupDiagnostics._();

  static Future<List<AdminDiagnosticResult>> run() async {
    final results = <AdminDiagnosticResult>[];

    results.add(await _checkAdminRegistry());
    results.add(await _checkAppCheck());
    results.add(await _checkFirestoreRead(
      id: 'orders',
      label: 'อ่านออเดอร์ (orders)',
      query: FirebaseFirestore.instance.collection('orders').limit(1),
    ));
    results.add(await _checkFirestoreRead(
      id: 'withdraw',
      label: 'อ่านคิวถอนเงิน (withdraw_requests)',
      query: FirebaseFirestore.instance.collection('withdraw_requests').limit(1),
    ));
    results.add(await _checkFirestoreRead(
      id: 'products',
      label: 'อ่านสินค้า (products)',
      query: FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .limit(1),
    ));
    results.add(await _checkFirestoreRead(
      id: 'pricing',
      label: 'อ่านตั้งค่าราคา (pricing_config)',
      query: FirebaseFirestore.instance.collection('pricing_config').limit(1),
    ));

    return results;
  }

  static Future<AdminDiagnosticResult> _checkAdminRegistry() async {
    try {
      final access = await AdminRepository.checkAdminAccess();
      if (access.allowed) {
        return AdminDiagnosticResult(
          id: 'admin_registry',
          label: 'สิทธิ์แอดมิน (admins/{email})',
          status: AdminDiagnosticStatus.ok,
          detail: access.email ?? 'อนุมัติแล้ว',
        );
      }
      return AdminDiagnosticResult(
        id: 'admin_registry',
        label: 'สิทธิ์แอดมิน (admins/{email})',
        status: AdminDiagnosticStatus.fail,
        detail: access.reason ?? 'ไม่ได้รับอนุญาต',
      );
    } catch (error) {
      return AdminDiagnosticResult(
        id: 'admin_registry',
        label: 'สิทธิ์แอดมิน (admins/{email})',
        status: AdminDiagnosticStatus.fail,
        detail: '$error',
      );
    }
  }

  static Future<AdminDiagnosticResult> _checkAppCheck() async {
    try {
      final token = await FirebaseAppCheck.instance
          .getToken(false)
          .timeout(const Duration(seconds: 8));
      if (token == null || token.trim().isEmpty) {
        throw StateError('token ว่าง');
      }
      return const AdminDiagnosticResult(
        id: 'app_check',
        label: 'App Check token',
        status: AdminDiagnosticStatus.ok,
        detail: 'พร้อมเรียก Cloud Functions',
      );
    } catch (error) {
      final hint = AppCheckGuard.usesDebugProvider
          ? 'ลงทะเบียน debug token ที่ App Check → Android van4.com แล้วปิดเปิดแอป: ${AppCheckGuard.debugTokenHint}'
          : 'release ใช้ Play Integrity — build ใหม่ด้วย APP_CHECK_DEBUG หรือลงทะเบียน SHA';
      return AdminDiagnosticResult(
        id: 'app_check',
        label: 'App Check token',
        status: AdminDiagnosticStatus.fail,
        detail: 'App Check ไม่พร้อม — $hint',
      );
    }
  }

  static Future<AdminDiagnosticResult> _checkFirestoreRead({
    required String id,
    required String label,
    required Query<Map<String, dynamic>> query,
  }) async {
    try {
      await query.get().timeout(const Duration(seconds: 12));
      return AdminDiagnosticResult(
        id: id,
        label: label,
        status: AdminDiagnosticStatus.ok,
        detail: 'เชื่อมต่อ Firestore ได้',
      );
    } on FirebaseException catch (error) {
      return AdminDiagnosticResult(
        id: id,
        label: label,
        status: AdminDiagnosticStatus.fail,
        detail: '${error.code}: ${error.message ?? error.toString()}',
      );
    } catch (error) {
      return AdminDiagnosticResult(
        id: id,
        label: label,
        status: AdminDiagnosticStatus.fail,
        detail: '$error',
      );
    }
  }

  static bool hasFailures(List<AdminDiagnosticResult> results) {
    return results.any((result) => result.status == AdminDiagnosticStatus.fail);
  }
}
