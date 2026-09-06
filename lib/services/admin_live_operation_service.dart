import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_repository.dart';
import '../models/admin_live_operation_snapshot.dart';
import '../utils/admin_order_operations.dart';
import 'admin_order_query.dart';
import 'admin_market_scope.dart';

class AdminLiveOperationService {
  AdminLiveOperationService._();

  static final AdminLiveOperationService instance = AdminLiveOperationService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<AdminOrderRecord>> streamActiveOrders() {
    return AdminOrderQuery.activeStatusOrders(
          AdminOrderOperations.activeStatuses.toList(growable: false),
        )
        .snapshots()
        .map(
          (snapshot) {
            final orders = snapshot.docs
                .map(AdminOrderRecord.fromSnapshot)
                .where(AdminOrderOperations.isActiveOrder)
                .toList(growable: false);
            orders.sort((left, right) {
              final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final rightTime = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return rightTime.compareTo(leftTime);
            });
            return orders;
          },
        );
  }

  static AdminLiveOperationSnapshot _compose(List<AdminOrderRecord> orders) {
    final now = DateTime.now();
    final buckets = <AdminLiveOrderBucket, List<AdminOrderRecord>>{
      AdminLiveOrderBucket.shopPreparing: <AdminOrderRecord>[],
      AdminLiveOrderBucket.waitingRider: <AdminOrderRecord>[],
      AdminLiveOrderBucket.delivering: <AdminOrderRecord>[],
      AdminLiveOrderBucket.delayed: <AdminOrderRecord>[],
    };

    for (final order in orders) {
      final bucket = AdminOrderOperations.liveBucket(order, now);
      if (bucket == null) {
        continue;
      }
      buckets[bucket]!.add(order);
    }

    return AdminLiveOperationSnapshot(buckets: buckets, asOf: now);
  }

  Stream<AdminLiveOperationSnapshot> streamLiveOperation() {
    return streamWithAdminMarketScope((scope) {
      return streamActiveOrders().map((orders) {
        final filtered = orders.where(scope.matchesOrder).toList(growable: false);
        return _compose(filtered);
      });
    });
  }
}
