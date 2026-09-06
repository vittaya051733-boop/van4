import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../admin_order_support.dart';
import '../admin_repository.dart';
import '../models/admin_overview_snapshot.dart';
import 'admin_market_scope.dart';
import 'admin_order_query.dart';

class AdminOverviewService {
  AdminOverviewService._();

  static final AdminOverviewService instance = AdminOverviewService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static ({DateTime start, DateTime end}) _todayBounds([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return (start: start, end: start.add(const Duration(days: 1)));
  }

  static Stream<List<AdminOrderRecord>> streamOrdersForToday() {
    final bounds = _todayBounds();
    return AdminOrderQuery.todayOrders(bounds.start, bounds.end)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminOrderRecord.fromSnapshot)
              .toList(growable: false),
        );
  }

  static Stream<int> streamOpenShopCount(AdminMarketScope scope) {
    return _firestore.collection('shop_operations').snapshots().map((snapshot) {
      var count = 0;
      for (final doc in snapshot.docs) {
        if (doc.data()['isOpen'] != true) {
          continue;
        }
        if (scope.matchesShopOperation(doc.id)) {
          count++;
        }
      }
      return count;
    });
  }

  static Stream<int> streamPendingWithdrawCount() {
    return _firestore
        .collection('withdraw_requests')
        .where('status', isEqualTo: 'pending_admin')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static AdminOverviewSnapshot _compose({
    required List<AdminOrderRecord> ordersToday,
    required int openShops,
    required List<AdminRiderRecord> riders,
    required int pendingWithdraw,
    required int pendingShops,
    required int productReviewCount,
    required int unreadTicketCount,
  }) {
    final deliveredToday = ordersToday.where((order) {
      if (!order.isDeliveredSuccess) {
        return false;
      }
      final deliveredAt = order.deliveredAt;
      if (deliveredAt != null) {
        final bounds = _todayBounds();
        return !deliveredAt.isBefore(bounds.start) && deliveredAt.isBefore(bounds.end);
      }
      return true;
    });

    final salesToday = deliveredToday.fold<double>(
      0,
      (total, order) => total + (order.grandTotal ?? 0),
    );

    final customerIds = ordersToday
        .map((order) => order.customerId?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final activeRiders = riders.where(_isRiderWorking).length;

    final breakdown = <AdminAttentionItem>[];
    if (pendingWithdraw > 0) {
      breakdown.add(
        AdminAttentionItem(
          id: 'withdraw',
          label: 'รออนุมัติถอนเงิน',
          count: pendingWithdraw,
          severity: AdminAttentionSeverity.warning,
        ),
      );
    }
    if (productReviewCount > 0) {
      breakdown.add(
        AdminAttentionItem(
          id: 'product_review',
          label: 'สินค้ารอตรวจ',
          count: productReviewCount,
          severity: AdminAttentionSeverity.warning,
        ),
      );
    }
    if (unreadTicketCount > 0) {
      breakdown.add(
        AdminAttentionItem(
          id: 'support_ticket',
          label: 'ข้อความติดต่อใหม่',
          count: unreadTicketCount,
          severity: AdminAttentionSeverity.info,
        ),
      );
    }
    if (pendingShops > 0) {
      breakdown.add(
        AdminAttentionItem(
          id: 'shop_approval',
          label: 'ร้านรออนุมัติ',
          count: pendingShops,
          severity: AdminAttentionSeverity.info,
        ),
      );
    }

    return AdminOverviewSnapshot(
      ordersToday: ordersToday.length,
      salesTodayBaht: salesToday,
      openShops: openShops,
      activeRiders: activeRiders,
      activeCustomersToday: customerIds.length,
      attentionTotal: breakdown.fold<int>(0, (total, item) => total + item.count),
      attentionBreakdown: breakdown,
      asOf: DateTime.now(),
    );
  }

  static bool _isRiderWorking(AdminRiderRecord rider) {
    if (rider.adminSuspended || !rider.onlineReady) {
      return false;
    }
    final reg = (rider.registrationStatus ?? 'legacy').trim().toLowerCase();
    return reg == 'approved' || reg == 'legacy';
  }

  static int _pendingShopsForScope(List<AdminShopRecord> shops, AdminMarketScope scope) {
    return shops
        .where((shop) => shop.isPendingReview && scope.matchesShopOwner(shop.ownerId))
        .length;
  }

  Stream<AdminOverviewSnapshot> streamOverview() {
    return streamWithAdminMarketScope((scope) {
      return Stream<AdminOverviewSnapshot>.multi((controller) {
        List<AdminOrderRecord>? orders;
        int? openShops;
        List<AdminRiderRecord>? riders;
        int? pendingWithdraw;
        List<AdminShopRecord>? shops;
        AdminWorkInboxSnapshot? inbox;

        void emitIfReady() {
          if (orders == null ||
              openShops == null ||
              riders == null ||
              pendingWithdraw == null ||
              shops == null ||
              inbox == null) {
            return;
          }

          controller.add(
            _compose(
              ordersToday: orders!.where(scope.matchesOrder).toList(growable: false),
              openShops: openShops!,
              riders: riders!.where(scope.matchesRider).toList(growable: false),
              pendingWithdraw: pendingWithdraw!,
              pendingShops: _pendingShopsForScope(shops!, scope),
              productReviewCount: inbox!.productReviewCount,
              unreadTicketCount: inbox!.unreadTicketCount,
            ),
          );
        }

        final subs = <StreamSubscription<dynamic>>[];

        void listenSafe<T>({
          required Stream<T> stream,
          required void Function(T value) onData,
          required void Function(T fallback) onFallback,
          required T fallback,
        }) {
          subs.add(
            stream.listen(
              onData,
              onError: (Object error, StackTrace stack) {
                debugPrint('AdminOverview stream error: $error');
                onFallback(fallback);
              },
            ),
          );
        }

        listenSafe<List<AdminOrderRecord>>(
          stream: streamOrdersForToday(),
          fallback: const <AdminOrderRecord>[],
          onData: (value) {
            orders = value;
            emitIfReady();
          },
          onFallback: (value) {
            orders = value;
            emitIfReady();
          },
        );
        listenSafe<int>(
          stream: streamOpenShopCount(scope),
          fallback: 0,
          onData: (value) {
            openShops = value;
            emitIfReady();
          },
          onFallback: (value) {
            openShops = value;
            emitIfReady();
          },
        );
        listenSafe<List<AdminRiderRecord>>(
          stream: AdminRepository.streamRiders(),
          fallback: const <AdminRiderRecord>[],
          onData: (value) {
            riders = value;
            emitIfReady();
          },
          onFallback: (value) {
            riders = value;
            emitIfReady();
          },
        );
        listenSafe<int>(
          stream: streamPendingWithdrawCount(),
          fallback: 0,
          onData: (value) {
            pendingWithdraw = value;
            emitIfReady();
          },
          onFallback: (value) {
            pendingWithdraw = value;
            emitIfReady();
          },
        );
        listenSafe<List<AdminShopRecord>>(
          stream: AdminRepository.streamShops(),
          fallback: const <AdminShopRecord>[],
          onData: (value) {
            shops = value;
            emitIfReady();
          },
          onFallback: (value) {
            shops = value;
            emitIfReady();
          },
        );
        listenSafe<AdminWorkInboxSnapshot>(
          stream: AdminRepositoryWorkInbox.streamWorkInbox(),
          fallback: const AdminWorkInboxSnapshot(
            items: <AdminWorkItem>[],
            attentionCount: 0,
            productReviewCount: 0,
            unreadTicketCount: 0,
          ),
          onData: (value) {
            inbox = value;
            emitIfReady();
          },
          onFallback: (value) {
            inbox = value;
            emitIfReady();
          },
        );

        controller.onCancel = () async {
          for (final sub in subs) {
            await sub.cancel();
          }
        };
      });
    });
  }
}
