import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_session.dart';

/// Branch-scoped Firestore queries for branch_admin (rules reject unfiltered lists).
class AdminBranchQuery {
  AdminBranchQuery._();

  static String? get _branchFilter => AdminSessionService.instance.assignedBranchId;

  static Query<Map<String, dynamic>> collection(String name) {
    final query = FirebaseFirestore.instance.collection(name);
    final branchId = _branchFilter;
    if (branchId != null) {
      return query.where('branchId', isEqualTo: branchId);
    }
    return query;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> snapshots(String name) {
    return collection(name).snapshots();
  }
}
