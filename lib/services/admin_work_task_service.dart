import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_activity_log_entry.dart';
import '../models/admin_session.dart';
import '../models/admin_work_task.dart';
import '../utils/guarded_functions.dart';
import 'admin_firestore.dart';

class AdminWorkTaskService {
  AdminWorkTaskService._();

  static String _branchFilter() {
    return AdminSessionService.instance.assignedBranchId ?? 'central';
  }

  static bool get _branchScoped => AdminSessionService.instance.isBranchScoped;

  static Stream<AdminWorkTask?> watchTask({
    required String sourceType,
    required String sourceId,
  }) {
    final id = AdminWorkTaskIds.docId(sourceType, sourceId);
    return AdminFirestore.instance
        .collection('admin_work_tasks')
        .doc(id)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) {
        return null;
      }
      return AdminWorkTask.fromMap(snap.id, data);
    });
  }

  static Stream<List<AdminWorkTask>> watchTasks() {
    Query<Map<String, dynamic>> query =
        AdminFirestore.instance.collection('admin_work_tasks');
    if (_branchScoped) {
      query = query.where('branchId', isEqualTo: _branchFilter());
    }
    return query.limit(200).snapshots().map((snap) {
      final tasks = snap.docs
          .map((doc) => AdminWorkTask.fromMap(doc.id, doc.data()))
          .toList();
      tasks.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return tasks;
    });
  }

  static Stream<List<AdminActivityLogEntry>> watchLogs() {
    Query<Map<String, dynamic>> query =
        AdminFirestore.instance.collection('admin_activity_logs');
    if (_branchScoped) {
      query = query.where('branchId', isEqualTo: _branchFilter());
    }
    return query.limit(200).snapshots().map((snap) {
      final logs = snap.docs
          .map((doc) => AdminActivityLogEntry.fromMap(doc.id, doc.data()))
          .toList();
      logs.sort(
        (a, b) => (b.at ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.at ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return logs;
    });
  }

  static Future<void> claim({
    required String sourceType,
    required String sourceId,
    required String title,
    String? branchId,
  }) async {
    await GuardedFunctions.call(
      'adminClaimWork',
      parameters: <String, dynamic>{
        'sourceType': sourceType,
        'sourceId': sourceId,
        'title': title,
        'branchId': (branchId ?? '').trim().isNotEmpty
            ? branchId!.trim()
            : _branchFilter(),
      },
    );
  }

  static Future<void> complete({
    required String sourceType,
    required String sourceId,
  }) async {
    await GuardedFunctions.call(
      'adminCompleteWork',
      parameters: <String, dynamic>{
        'sourceType': sourceType,
        'sourceId': sourceId,
      },
    );
  }

  static Future<void> fail({
    required String sourceType,
    required String sourceId,
  }) async {
    await GuardedFunctions.call(
      'adminFailWork',
      parameters: <String, dynamic>{
        'sourceType': sourceType,
        'sourceId': sourceId,
      },
    );
  }

  static Future<void> resetTeamStats() async {
    await GuardedFunctions.call('adminResetWorkStats');
  }
}
