import 'package:flutter/material.dart';

import 'admin_repository.dart';
import 'models/admin_live_operation_snapshot.dart';
import 'services/admin_live_operation_service.dart';
import 'services/admin_market_scope.dart';
import 'utils/admin_order_operations.dart';
import 'widgets/admin_market_selector.dart';

class AdminLiveOperationScreen extends StatefulWidget {
  const AdminLiveOperationScreen({
    super.key,
    this.embedded = false,
    this.onOpenOrder,
  });

  final bool embedded;
  final void Function(BuildContext context, AdminOrderRecord order)? onOpenOrder;

  @override
  State<AdminLiveOperationScreen> createState() => _AdminLiveOperationScreenState();
}

class _AdminLiveOperationScreenState extends State<AdminLiveOperationScreen> {
  AdminLiveOrderBucket? _selectedBucket;

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<AdminLiveOperationSnapshot>(
      stream: AdminLiveOperationService.instance.streamLiveOperation(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('โหลดงานสดไม่สำเร็จ: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
        }

        final data = snapshot.data!;
        final selected = _selectedBucket;
        final orders = selected == null
            ? data.buckets.values.expand((list) => list).toList(growable: false)
            : data.ordersFor(selected);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AdminMarketScopeBanner(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _LiveSummaryStrip(
                snapshot: data,
                selected: selected,
                onSelect: (bucket) {
                  setState(() {
                    if (_selectedBucket == bucket) {
                      _selectedBucket = null;
                    } else {
                      _selectedBucket = bucket;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Text(
                    selected == null
                        ? 'ออเดอร์ที่กำลังดำเนินการ ${data.totalActive} รายการ'
                        : AdminOrderOperations.bucketLabel(selected),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF9A3412),
                        ),
                  ),
                  const Spacer(),
                  if (selected != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedBucket = null),
                      child: const Text('ดูทั้งหมด'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? _EmptyLiveBoard(selected: selected)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final bucket = AdminOrderOperations.liveBucket(order, data.asOf);
                        return _LiveOrderCard(
                          order: order,
                          bucket: bucket,
                          onTap: () {
                            if (widget.onOpenOrder != null) {
                              widget.onOpenOrder!(context, order);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('งานกำลังดำเนินการ'),
      ),
      body: body,
    );
  }
}

class _LiveSummaryStrip extends StatelessWidget {
  const _LiveSummaryStrip({
    required this.snapshot,
    required this.selected,
    required this.onSelect,
  });

  final AdminLiveOperationSnapshot snapshot;
  final AdminLiveOrderBucket? selected;
  final ValueChanged<AdminLiveOrderBucket> onSelect;

  @override
  Widget build(BuildContext context) {
    final buckets = AdminLiveOrderBucket.values;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: crossAxisCount == 4 ? 1.55 : 1.35,
          children: buckets.map((bucket) {
            final count = snapshot.count(bucket);
            final isSelected = selected == bucket;
            return _BucketTile(
              bucket: bucket,
              count: count,
              selected: isSelected,
              onTap: () => onSelect(bucket),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.bucket,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final AdminLiveOrderBucket bucket;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (bucket) {
      AdminLiveOrderBucket.shopPreparing => const Color(0xFFD97706),
      AdminLiveOrderBucket.waitingRider => const Color(0xFF2563EB),
      AdminLiveOrderBucket.delivering => const Color(0xFF7C3AED),
      AdminLiveOrderBucket.delayed => const Color(0xFFDC2626),
    };

    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : const Color(0xFFFFE0B2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AdminOrderOperations.bucketEmoji(bucket),
                style: const TextStyle(fontSize: 20),
              ),
              const Spacer(),
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
              ),
              Text(
                AdminOrderOperations.bucketLabel(bucket),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveOrderCard extends StatelessWidget {
  const _LiveOrderCard({
    required this.order,
    required this.bucket,
    required this.onTap,
  });

  final AdminOrderRecord order;
  final AdminLiveOrderBucket? bucket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bucketColor = switch (bucket) {
      AdminLiveOrderBucket.shopPreparing => const Color(0xFFD97706),
      AdminLiveOrderBucket.waitingRider => const Color(0xFF2563EB),
      AdminLiveOrderBucket.delivering => const Color(0xFF7C3AED),
      AdminLiveOrderBucket.delayed => const Color(0xFFDC2626),
      null => const Color(0xFFE65100),
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: bucketColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '#${order.displayOrderNumber}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C2D12),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.shopName ?? order.van1Label} → ${order.customerName ?? order.van2Label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AdminOrderOperations.statusLabelTh(order.status)} · ${AdminOrderOperations.elapsedLabel(order)} · ฿${(order.grandTotal ?? 0).toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: bucketColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Builder(
                      builder: (context) {
                        final scope = AdminMarketScope.instance;
                        final branchLabel = scope.branchDisplayLabelForOrder(order);
                        final serviceType = scope.serviceTypeForShopOwner(order.shopOwnerId);
                        if (branchLabel == null && serviceType == null) {
                          return const SizedBox.shrink();
                        }
                        final parts = <String>[
                          if (branchLabel != null) branchLabel,
                          if (serviceType != null) serviceType,
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            parts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFE65100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLiveBoard extends StatelessWidget {
  const _EmptyLiveBoard({required this.selected});

  final AdminLiveOrderBucket? selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.local_shipping_outlined, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              selected == null
                  ? 'ไม่มีออเดอร์ที่กำลังดำเนินการ'
                  : 'ไม่มีรายการในกลุ่มนี้',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
