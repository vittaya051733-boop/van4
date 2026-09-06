import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_session.dart';
import 'admin_firestore.dart';

class AdminActivityLog {
  AdminActivityLog._();

  static Future<void> logWrite({
    required String targetType,
    required String targetId,
    required String labelTh,
    Map<String, Object?> detail = const <String, Object?>{},
  }) {
    return log(
      action: 'write',
      labelTh: labelTh,
      targetType: targetType,
      targetId: targetId,
      detail: detail,
    );
  }

  static Future<void> logFinancial({
    required String action,
    required String labelTh,
    required String targetType,
    required String targetId,
    Map<String, Object?> detail = const <String, Object?>{},
  }) {
    return log(
      action: action,
      labelTh: labelTh,
      targetType: targetType,
      targetId: targetId,
      category: 'financial',
      detail: detail,
    );
  }

  static Future<void> log({
    required String action,
    required String labelTh,
    String targetType = '',
    String targetId = '',
    String category = 'general',
    Map<String, Object?> detail = const <String, Object?>{},
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) {
        return;
      }
      final session = AdminSessionService.instance.session;
      final email = (session?.email ?? user?.email ?? '').trim().toLowerCase();
      if (email.isEmpty) {
        return;
      }
      await AdminFirestore.instance.collection('admin_activity_logs').add(
        <String, dynamic>{
          'actorEmail': email,
          'actorUid': uid,
          'actorRole': _roleName(session),
          'branchId': session?.normalizedAssignedBranchId ?? 'central',
          'action': action,
          'category': category,
          'targetType': targetType,
          'targetId': targetId,
          'labelTh': labelTh.trim().isEmpty ? action : labelTh.trim(),
          if (detail.isNotEmpty) 'detail': detail,
          'at': FieldValue.serverTimestamp(),
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AdminActivityLog failed: $error');
      }
    }
  }

  static Future<void> logOpenMenu({required String title}) {
    return log(
      action: 'open_menu',
      labelTh: 'เปิดเมนู: $title',
      targetType: 'menu',
      targetId: title,
    );
  }

  static String _roleName(AdminSession? session) {
    if (session == null) {
      return 'unknown';
    }
    return switch (session.role) {
      AdminRole.owner => 'owner',
      AdminRole.branchAdmin => 'branch_admin',
      AdminRole.staffAdmin => 'staff_admin',
    };
  }
}
