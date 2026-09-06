import '../admin_repository.dart';
import '../utils/admin_order_operations.dart';

class AdminLiveOperationSnapshot {
  const AdminLiveOperationSnapshot({
    required this.buckets,
    required this.asOf,
  });

  final Map<AdminLiveOrderBucket, List<AdminOrderRecord>> buckets;
  final DateTime asOf;

  int count(AdminLiveOrderBucket bucket) => buckets[bucket]?.length ?? 0;

  int get totalActive {
    return buckets.values.fold<int>(0, (total, list) => total + list.length);
  }

  List<AdminOrderRecord> ordersFor(AdminLiveOrderBucket bucket) {
    return buckets[bucket] ?? const <AdminOrderRecord>[];
  }
}
