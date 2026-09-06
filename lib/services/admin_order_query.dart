import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_session.dart';

/// Builds Firestore order queries scoped to branch admin when applicable.
class AdminOrderQuery {
  AdminOrderQuery._();

  static String? get _branchFilter => AdminSessionService.instance.assignedBranchId;

  static Query<Map<String, dynamic>> collection() {
    final query = FirebaseFirestore.instance.collection('orders');
    final branchId = _branchFilter;
    if (branchId != null) {
      return query.where('branchId', isEqualTo: branchId);
    }
    return query;
  }

  static Query<Map<String, dynamic>> orderByCreatedAtDesc({int? limit}) {
    var query = collection().orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query;
  }

  static Query<Map<String, dynamic>> todayOrders(DateTime start, DateTime end) {
    return collection()
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true);
  }

  static Query<Map<String, dynamic>> activeStatusOrders(List<String> statuses) {
    return collection()
        .where('status', whereIn: statuses)
        .limit(200);
  }
}
