import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_repository.dart';
import '../models/admin_alert_item.dart';
import '../models/admin_overview_snapshot.dart';
import '../utils/admin_order_operations.dart';
import 'admin_order_query.dart';
import 'admin_market_scope.dart';

class AdminAlertCenterService {
  AdminAlertCenterService._();

  static final AdminAlertCenterService instance = AdminAlertCenterService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<AdminOrderRecord>> _streamActiveOrders() {
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

  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _streamPendingWithdrawDocs() {
    return _firestore
        .collection('withdraw_requests')
        .where('status', isEqualTo: 'pending_admin')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  static AdminAlertCenterSnapshot _compose({
    required AdminMarketScope scope,
    required List<AdminOrderRecord> activeOrders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> withdrawDocs,
    required List<AdminShopRecord> shops,
    required AdminWorkInboxSnapshot inbox,
  }) {
    final now = DateTime.now();
    final items = <AdminAlertItem>[];

    for (final order in activeOrders.where(scope.matchesOrder)) {
      if (AdminOrderOperations.isDelayed(order, now)) {
        items.add(
          AdminAlertItem(
            id: 'order_delayed_${order.id}',
            type: AdminAlertType.orderDelayed,
            title: 'ออเดอร์ค้าง #${order.displayOrderNumber}',
            subtitle:
                '${order.shopName ?? order.van1Label} · ${AdminOrderOperations.statusLabelTh(order.status)} · ${AdminOrderOperations.elapsedLabel(order, now)}',
            severity: AdminAttentionSeverity.critical,
            sortTime: order.createdAt ?? now,
            order: order,
          ),
        );
        continue;
      }

      if (order.status.toLowerCase() == 'preparing') {
        final started = AdminOrderOperations.preparingStartedAt(order) ?? order.createdAt;
        final limit = AdminOrderOperations.preparingLimit(order);
        if (started != null && now.difference(started) > limit * 0.75) {
          items.add(
            AdminAlertItem(
              id: 'shop_slow_${order.id}',
              type: AdminAlertType.shopSlowPreparing,
              title: 'ร้านเตรียมช้า #${order.displayOrderNumber}',
              subtitle:
                  '${order.shopName ?? order.van1Label} · ${AdminOrderOperations.elapsedLabel(order, now)}',
              severity: AdminAttentionSeverity.warning,
              sortTime: started,
              order: order,
            ),
          );
        }
      }
    }

    for (final doc in withdrawDocs) {
      final data = doc.data();
      if (!_matchesWithdraw(data, scope)) {
        continue;
      }
      final amount = _readMoney(data['amount']);
      final actorLabel = _readActorLabel(data);
      final timestamp = _readTimestamp(data['timestamp']) ?? now;
      items.add(
        AdminAlertItem(
          id: 'withdraw_${doc.id}',
          type: AdminAlertType.withdrawPending,
          title: 'รออนุมัติถอนเงิน',
          subtitle: '$actorLabel · ฿${amount.toStringAsFixed(0)}',
          severity: AdminAttentionSeverity.warning,
          sortTime: timestamp,
          withdrawRequestId: doc.id,
        ),
      );
    }

    for (final workItem in inbox.items.where((item) => item.needsAttention)) {
      if (workItem.kind == AdminWorkItemKind.productReview && workItem.product != null) {
        final product = workItem.product!;
        if (!scope.matchesShopOwner(product.ownerUid)) {
          continue;
        }
        items.add(
          AdminAlertItem(
            id: 'product_${product.id}',
            type: AdminAlertType.productReview,
            title: 'สินค้ารอตรวจ',
            subtitle: product.name,
            severity: AdminAttentionSeverity.warning,
            sortTime: workItem.sortTime,
            workItem: workItem,
          ),
        );
      }
      if (workItem.kind == AdminWorkItemKind.supportTicket && workItem.ticket != null) {
        final ticket = workItem.ticket!;
        items.add(
          AdminAlertItem(
            id: 'ticket_${ticket.id}',
            type: AdminAlertType.supportTicket,
            title: 'ข้อความติดต่อใหม่',
            subtitle: '${ticket.sourceApp} · ${ticket.topicLabel.isNotEmpty ? ticket.topicLabel : ticket.requesterName}',
            severity: AdminAttentionSeverity.info,
            sortTime: workItem.sortTime,
            workItem: workItem,
          ),
        );
      }
    }

    for (final shop in shops.where((entry) => entry.isPendingReview)) {
      if (!scope.matchesShopOwner(shop.ownerId)) {
        continue;
      }
      items.add(
        AdminAlertItem(
          id: 'shop_${shop.collection}_${shop.id}',
          type: AdminAlertType.shopApproval,
          title: 'ร้านรออนุมัติ',
          subtitle: '${shop.displayName} · ${shop.serviceType}',
          severity: AdminAttentionSeverity.info,
          sortTime: shop.createdAt ?? now,
          shop: shop,
        ),
      );
    }

    items.sort((left, right) {
      final severityCompare = left.severity.index.compareTo(right.severity.index);
      if (severityCompare != 0) {
        return severityCompare;
      }
      return right.sortTime.compareTo(left.sortTime);
    });

    return AdminAlertCenterSnapshot(items: items, asOf: now);
  }

  static double _readMoney(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static String _readActorLabel(Map<String, dynamic> data) {
    final actorType = data['actorType']?.toString().trim();
    final actorName = data['actorName']?.toString().trim();
    if (actorName != null && actorName.isNotEmpty) {
      return actorName;
    }
    return switch (actorType) {
      'merchant' => 'ร้านค้า',
      'rider' => 'ไรเดอร์',
      _ => 'ผู้ใช้',
    };
  }

  static DateTime? _readTimestamp(Object? value) {
    if (value == null) {
      return null;
    }
    try {
      return (value as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }

  static bool _matchesWithdraw(Map<String, dynamic> data, AdminMarketScope scope) {
    if (scope.isAllMarkets) {
      return true;
    }
    final uid = data['uid']?.toString().trim() ?? '';
    if (uid.isEmpty) {
      return true;
    }
    final actorType = data['actorType']?.toString().trim();
    if (actorType == 'rider') {
      return scope.matchesMarketId(scope.marketIdForRider(uid));
    }
    if (actorType == 'merchant') {
      return scope.matchesShopOwner(uid);
    }
    return true;
  }

  Stream<AdminAlertCenterSnapshot> streamAlerts() {
    return streamWithAdminMarketScope((scope) {
      return Stream<AdminAlertCenterSnapshot>.multi((controller) {
      List<AdminOrderRecord>? activeOrders;
      List<QueryDocumentSnapshot<Map<String, dynamic>>>? withdrawDocs;
      List<AdminShopRecord>? shops;
      AdminWorkInboxSnapshot? inbox;

      void emitIfReady() {
        if (activeOrders == null ||
            withdrawDocs == null ||
            shops == null ||
            inbox == null) {
          return;
        }

        controller.add(
          _compose(
            scope: scope,
            activeOrders: activeOrders!,
            withdrawDocs: withdrawDocs!,
            shops: shops!,
            inbox: inbox!,
          ),
        );
      }

      final subs = <StreamSubscription<dynamic>>[
        _streamActiveOrders().listen(
          (value) {
            activeOrders = value;
            emitIfReady();
          },
          onError: controller.addError,
        ),
        _streamPendingWithdrawDocs().listen(
          (value) {
            withdrawDocs = value;
            emitIfReady();
          },
          onError: controller.addError,
        ),
        AdminRepository.streamShops().listen(
          (value) {
            shops = value;
            emitIfReady();
          },
          onError: controller.addError,
        ),
        AdminRepositoryWorkInbox.streamWorkInbox().listen(
          (value) {
            inbox = value;
            emitIfReady();
          },
          onError: controller.addError,
        ),
      ];

      controller.onCancel = () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      };
      });
    });
  }
}
