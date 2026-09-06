class AdminOverviewSnapshot {
  const AdminOverviewSnapshot({
    required this.ordersToday,
    required this.salesTodayBaht,
    required this.openShops,
    required this.activeRiders,
    required this.activeCustomersToday,
    required this.attentionTotal,
    required this.attentionBreakdown,
    required this.asOf,
  });

  final int ordersToday;
  final double salesTodayBaht;
  final int openShops;
  final int activeRiders;
  final int activeCustomersToday;
  final int attentionTotal;
  final List<AdminAttentionItem> attentionBreakdown;
  final DateTime asOf;

  factory AdminOverviewSnapshot.emptyNow() {
    return AdminOverviewSnapshot(
      ordersToday: 0,
      salesTodayBaht: 0,
      openShops: 0,
      activeRiders: 0,
      activeCustomersToday: 0,
      attentionTotal: 0,
      attentionBreakdown: const <AdminAttentionItem>[],
      asOf: DateTime.now(),
    );
  }
}

class AdminAttentionItem {
  const AdminAttentionItem({
    required this.id,
    required this.label,
    required this.count,
    required this.severity,
  });

  final String id;
  final String label;
  final int count;
  final AdminAttentionSeverity severity;
}

enum AdminAttentionSeverity {
  critical,
  warning,
  info,
}
