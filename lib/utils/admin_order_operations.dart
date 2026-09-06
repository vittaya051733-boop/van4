import '../admin_repository.dart';

enum AdminLiveOrderBucket {
  shopPreparing,
  waitingRider,
  delivering,
  delayed,
}

class AdminOrderOperations {
  AdminOrderOperations._();

  static const Set<String> terminalStatuses = <String>{
    'delivered',
    'cancelled',
    'canceled',
    'declined',
    'refund',
    'completed',
    'failed',
  };

  static const Set<String> activeStatuses = <String>{
    'pending',
    'preparing',
    'awaiting_rider',
    'accepted',
    'ready',
    'delivering',
  };

  static bool isActiveOrder(AdminOrderRecord order) {
    return activeStatuses.contains(order.status.toLowerCase());
  }

  static bool hasAssignedDriver(AdminOrderRecord order) {
    final driverId = order.driverId?.trim();
    return driverId != null && driverId.isNotEmpty;
  }

  static Duration preparingLimit(AdminOrderRecord order) {
    final raw = order.rawData['preparingDuration'];
    if (raw is num && raw > 0) {
      return Duration(milliseconds: raw.round());
    }
    return const Duration(minutes: 10);
  }

  static DateTime? preparingStartedAt(AdminOrderRecord order) {
    return _readTimestamp(order.rawData['preparingStartTime']) ?? order.createdAt;
  }

  static bool isDelayed(AdminOrderRecord order, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final status = order.status.toLowerCase();
    final createdAt = order.createdAt ?? now;
    final age = now.difference(createdAt);

    if (status == 'preparing') {
      final started = preparingStartedAt(order) ?? createdAt;
      return now.difference(started) > preparingLimit(order);
    }
    if (status == 'awaiting_rider') {
      return age > const Duration(minutes: 15);
    }
    if (status == 'ready' && !hasAssignedDriver(order)) {
      return age > const Duration(minutes: 15);
    }
    if (status == 'delivering' || (status == 'ready' && hasAssignedDriver(order))) {
      return age > const Duration(minutes: 45);
    }
    if (status == 'pending' || status == 'accepted') {
      return age > const Duration(minutes: 25);
    }
    return false;
  }

  static AdminLiveOrderBucket? liveBucket(AdminOrderRecord order, [DateTime? reference]) {
    if (!isActiveOrder(order)) {
      return null;
    }
    if (isDelayed(order, reference)) {
      return AdminLiveOrderBucket.delayed;
    }

    final status = order.status.toLowerCase();
    if (status == 'preparing' || status == 'pending') {
      return AdminLiveOrderBucket.shopPreparing;
    }
    if (status == 'awaiting_rider') {
      return AdminLiveOrderBucket.waitingRider;
    }
    if (status == 'ready' && !hasAssignedDriver(order)) {
      return AdminLiveOrderBucket.waitingRider;
    }
    if (status == 'accepted' && !hasAssignedDriver(order)) {
      return AdminLiveOrderBucket.waitingRider;
    }
    if (status == 'accepted') {
      return AdminLiveOrderBucket.shopPreparing;
    }
    if (status == 'ready' || status == 'delivering') {
      return AdminLiveOrderBucket.delivering;
    }
    return AdminLiveOrderBucket.shopPreparing;
  }

  static String bucketLabel(AdminLiveOrderBucket bucket) {
    return switch (bucket) {
      AdminLiveOrderBucket.shopPreparing => 'ร้านกำลังเตรียมสินค้า',
      AdminLiveOrderBucket.waitingRider => 'รอไรเดอร์',
      AdminLiveOrderBucket.delivering => 'ไรเดอร์กำลังจัดส่ง',
      AdminLiveOrderBucket.delayed => 'ส่งล่าช้า / ค้าง',
    };
  }

  static String bucketEmoji(AdminLiveOrderBucket bucket) {
    return switch (bucket) {
      AdminLiveOrderBucket.shopPreparing => '🟡',
      AdminLiveOrderBucket.waitingRider => '🔵',
      AdminLiveOrderBucket.delivering => '🛵',
      AdminLiveOrderBucket.delayed => '🔴',
    };
  }

  static String statusLabelTh(String status) {
    return switch (status.toLowerCase()) {
      'pending' => 'รอดำเนินการ',
      'preparing' => 'กำลังเตรียม',
      'awaiting_rider' => 'รอไรเดอร์',
      'accepted' => 'ไรเดอร์รับแล้ว',
      'ready' => 'พร้อมส่ง',
      'delivering' => 'กำลังจัดส่ง',
      'delivered' => 'ส่งแล้ว',
      'cancelled' || 'canceled' => 'ยกเลิก',
      _ => status,
    };
  }

  static String elapsedLabel(AdminOrderRecord order, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final start = preparingStartedAt(order) ?? order.createdAt ?? now;
    final minutes = now.difference(start).inMinutes;
    if (minutes < 1) {
      return 'เริ่มเมื่อสักครู่';
    }
    if (minutes < 60) {
      return '$minutes นาที';
    }
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return '$hours ชม. $remain น.';
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
}
