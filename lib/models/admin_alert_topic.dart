import 'admin_alert_item.dart';

/// Labels and helpers for admin alert topic focus preferences.
class AdminAlertTopic {
  const AdminAlertTopic._();

  static const List<AdminAlertType> allTypes = AdminAlertType.values;

  static String label(AdminAlertType type) => switch (type) {
        AdminAlertType.orderDelayed => 'ออเดอร์ค้าง',
        AdminAlertType.shopSlowPreparing => 'ร้านเตรียมช้า',
        AdminAlertType.withdrawPending => 'รออนุมัติถอนเงิน',
        AdminAlertType.productReview => 'สินค้ารอตรวจ (AI)',
        AdminAlertType.supportTicket => 'ข้อความติดต่อ',
        AdminAlertType.shopApproval => 'ร้านรออนุมัติ',
      };

  static String shortLabel(AdminAlertType type) => switch (type) {
        AdminAlertType.orderDelayed => 'ออเดอร์ค้าง',
        AdminAlertType.shopSlowPreparing => 'ร้านช้า',
        AdminAlertType.withdrawPending => 'ถอนเงิน',
        AdminAlertType.productReview => 'สินค้า AI',
        AdminAlertType.supportTicket => 'ติดต่อ',
        AdminAlertType.shopApproval => 'ร้านใหม่',
      };
}

extension AdminAlertCenterFocus on AdminAlertCenterSnapshot {
  List<AdminAlertItem> itemsWithFocusFirst(Set<AdminAlertType> focusedTypes) {
    final sorted = List<AdminAlertItem>.from(items);
    sorted.sort((left, right) {
      final leftFocused = focusedTypes.contains(left.type) ? 0 : 1;
      final rightFocused = focusedTypes.contains(right.type) ? 0 : 1;
      if (leftFocused != rightFocused) {
        return leftFocused.compareTo(rightFocused);
      }
      final severityCompare = left.severity.index.compareTo(right.severity.index);
      if (severityCompare != 0) {
        return severityCompare;
      }
      return right.sortTime.compareTo(left.sortTime);
    });
    return sorted;
  }

  int focusedCount(Set<AdminAlertType> focusedTypes) {
    return items.where((item) => focusedTypes.contains(item.type)).length;
  }
}
