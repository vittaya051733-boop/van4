import '../admin_repository.dart';
import 'admin_overview_snapshot.dart';

enum AdminAlertType {
  orderDelayed,
  shopSlowPreparing,
  withdrawPending,
  productReview,
  supportTicket,
  shopApproval,
}

class AdminAlertCenterSnapshot {
  const AdminAlertCenterSnapshot({
    required this.items,
    required this.asOf,
  });

  final List<AdminAlertItem> items;
  final DateTime asOf;

  int get totalCount => items.length;

  int countBySeverity(AdminAttentionSeverity severity) {
    return items.where((item) => item.severity == severity).length;
  }
}

class AdminAlertItem {
  const AdminAlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.sortTime,
    this.order,
    this.withdrawRequestId,
    this.shop,
    this.workItem,
  });

  final String id;
  final AdminAlertType type;
  final String title;
  final String subtitle;
  final AdminAttentionSeverity severity;
  final DateTime sortTime;
  final AdminOrderRecord? order;
  final String? withdrawRequestId;
  final AdminShopRecord? shop;
  final AdminWorkItem? workItem;
}
