import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_repository.dart';
import '../utils/admin_order_operations.dart';
import 'admin_market_scope.dart';
import 'admin_order_query.dart';

enum AdminOpsReportKind {
  orderDelayed,
  shopSlowPreparing,
  shopClosedWithActiveOrder,
  riderOnlineIdle,
}

class AdminOpsReportRow {
  const AdminOpsReportRow({
    required this.kind,
    required this.title,
    required this.detail,
    required this.orderId,
    this.shopId = '',
    this.riderId = '',
    this.sortTime,
  });

  final AdminOpsReportKind kind;
  final String title;
  final String detail;
  final String orderId;
  final String shopId;
  final String riderId;
  final DateTime? sortTime;

  String get kindLabelTh => switch (kind) {
        AdminOpsReportKind.orderDelayed => 'ออเดอร์ค้าง',
        AdminOpsReportKind.shopSlowPreparing => 'ร้านเตรียมช้า',
        AdminOpsReportKind.shopClosedWithActiveOrder => 'ร้านปิดแต่มีออเดอร์',
        AdminOpsReportKind.riderOnlineIdle => 'ไรเดอร์ online ไม่รับงาน',
      };

  List<String> toCsvRow() {
    return <String>[
      kindLabelTh,
      title,
      detail,
      orderId,
      shopId,
      riderId,
      sortTime?.toIso8601String() ?? '',
    ];
  }
}

class AdminOpsReportSnapshot {
  const AdminOpsReportSnapshot({
    required this.rows,
    required this.asOf,
  });

  final List<AdminOpsReportRow> rows;
  final DateTime asOf;

  String toCsv() {
    final buffer = StringBuffer(
      'ประเภท,หัวข้อ,รายละเอียด,orderId,shopId,riderId,เวลา\n',
    );
    for (final row in rows) {
      buffer.writeln(
        row.toCsvRow().map(_csvEscape).join(','),
      );
    }
    return buffer.toString();
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class AdminOpsReportService {
  AdminOpsReportService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<AdminOpsReportSnapshot> streamReports() {
    final ordersStream = AdminOrderQuery.activeStatusOrders(
      AdminOrderOperations.activeStatuses.toList(growable: false),
    ).snapshots();

    return ordersStream.asyncMap((ordersSnap) async {
      final shopsSnap = await _firestore.collection('shop_operations').get();
      final ridersSnap = await _firestore.collection('riders').limit(500).get();
      return _compose(
        scope: AdminMarketScope.instance,
        orders: ordersSnap.docs.map(AdminOrderRecord.fromSnapshot).toList(),
        shopOps: shopsSnap.docs,
        riders: ridersSnap.docs,
      );
    });
  }

  static AdminOpsReportSnapshot _compose({
    required AdminMarketScope scope,
    required List<AdminOrderRecord> orders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> shopOps,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> riders,
  }) {
    final now = DateTime.now();
    final rows = <AdminOpsReportRow>[];

    final openShopIds = <String>{};
    for (final doc in shopOps) {
      if (doc.data()['isOpen'] == true) {
        openShopIds.add(doc.id);
      }
    }

    final activeRiderIds = riders
        .where((doc) {
          final data = doc.data();
          return data['onlineReady'] == true &&
              (data['adminSuspended'] as bool?) != true;
        })
        .map((doc) => doc.id)
        .toSet();

    final ordersWithRider = orders
        .where((order) => (order.driverId ?? '').trim().isNotEmpty)
        .map((order) => order.driverId!.trim())
        .toSet();

    for (final order in orders.where(scope.matchesOrder)) {
      if (AdminOrderOperations.isDelayed(order, now)) {
        rows.add(
          AdminOpsReportRow(
            kind: AdminOpsReportKind.orderDelayed,
            title: 'ออเดอร์ #${order.displayOrderNumber}',
            detail:
                '${order.shopName ?? order.van1Label} · ${AdminOrderOperations.statusLabelTh(order.status)} · ${AdminOrderOperations.elapsedLabel(order, now)}',
            orderId: order.id,
            shopId: order.shopOwnerId ?? '',
            riderId: order.driverId ?? '',
            sortTime: order.createdAt,
          ),
        );
        continue;
      }

      if (order.status.toLowerCase() == 'preparing') {
        final started = AdminOrderOperations.preparingStartedAt(order) ?? order.createdAt;
        final limit = AdminOrderOperations.preparingLimit(order);
        if (started != null && now.difference(started) > limit * 0.75) {
          rows.add(
            AdminOpsReportRow(
              kind: AdminOpsReportKind.shopSlowPreparing,
              title: 'ร้านเตรียมช้า #${order.displayOrderNumber}',
              detail:
                  '${order.shopName ?? order.van1Label} · ${AdminOrderOperations.elapsedLabel(order, now)}',
              orderId: order.id,
              shopId: order.shopOwnerId ?? '',
              sortTime: started,
            ),
          );
        }
      }

      final shopId = order.shopOwnerId?.trim() ?? '';
      if (shopId.isNotEmpty &&
          !openShopIds.contains(shopId) &&
          AdminOrderOperations.isActiveOrder(order)) {
        rows.add(
          AdminOpsReportRow(
            kind: AdminOpsReportKind.shopClosedWithActiveOrder,
            title: 'ร้านปิด · ออเดอร์ #${order.displayOrderNumber}',
            detail: '${order.shopName ?? shopId} · ${order.status}',
            orderId: order.id,
            shopId: shopId,
            sortTime: order.createdAt,
          ),
        );
      }
    }

    for (final riderId in activeRiderIds) {
      if (!ordersWithRider.contains(riderId)) {
        final riderDoc = riders.firstWhere(
          (doc) => doc.id == riderId,
          orElse: () => riders.first,
        );
        if (riderDoc.id != riderId) {
          continue;
        }
        final data = riderDoc.data();
        rows.add(
          AdminOpsReportRow(
            kind: AdminOpsReportKind.riderOnlineIdle,
            title: 'ไรเดอร์ online ไม่มีงาน',
            detail: (data['displayName'] ?? data['name'] ?? riderId).toString(),
            orderId: '',
            riderId: riderId,
            sortTime: DateTime.now(),
          ),
        );
      }
    }

    rows.sort(
      (a, b) => (b.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );

    return AdminOpsReportSnapshot(rows: rows, asOf: now);
  }
}
