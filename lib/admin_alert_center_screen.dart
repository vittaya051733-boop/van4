import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_repository.dart';
import 'admin_shop_screens.dart';
import 'admin_support_screens.dart';
import 'admin_withdraw_queue_screen.dart';
import 'admin_work_inbox_screen.dart';
import 'models/admin_alert_item.dart';
import 'models/admin_alert_topic.dart';
import 'models/admin_overview_snapshot.dart';
import 'models/admin_work_task.dart';
import 'services/admin_alert_center_service.dart';
import 'services/admin_alert_preferences_service.dart';
import 'widgets/admin_alert_focus_selector.dart';
import 'widgets/admin_market_selector.dart';
import 'widgets/admin_work_claim_bar.dart';

class AdminAlertCenterScreen extends StatefulWidget {
  const AdminAlertCenterScreen({
    super.key,
    this.embedded = false,
    this.onOpenWorkInboxTab,
    this.onOpenOrder,
  });

  final bool embedded;
  final VoidCallback? onOpenWorkInboxTab;
  final void Function(BuildContext context, AdminOrderRecord order)? onOpenOrder;

  @override
  State<AdminAlertCenterScreen> createState() => _AdminAlertCenterScreenState();
}

class _AdminAlertCenterScreenState extends State<AdminAlertCenterScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(AdminAlertPreferencesService.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<AdminAlertCenterSnapshot>(
      stream: AdminAlertCenterService.instance.streamAlerts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('โหลดแจ้งเตือนไม่สำเร็จ: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE65100)));
        }

        final data = snapshot.data!;
        if (data.items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              const AdminAlertFocusSelector(compact: true),
              const SizedBox(height: 16),
              _EmptyAlerts(asOf: data.asOf),
            ],
          );
        }

        return ListenableBuilder(
          listenable: AdminAlertPreferencesService.instance,
          builder: (context, _) {
            final focusedTypes = AdminAlertPreferencesService.instance.focusedTypes;
            final sortedItems = data.itemsWithFocusFirst(focusedTypes);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                const AdminMarketScopeBanner(),
                const SizedBox(height: 12),
                const AdminAlertFocusSelector(compact: true),
                const SizedBox(height: 12),
                _AlertSummaryHeader(
                  snapshot: data,
                  focusedCount: data.focusedCount(focusedTypes),
                ),
                const SizedBox(height: 16),
                ...sortedItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AlertCard(
                      item: item,
                      dimmed: !focusedTypes.contains(item.type),
                      onTap: () => _openAlert(context, item),
                    ),
                  ),
                ),
              ],
            );
          },
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
        title: const Text('ศูนย์แจ้งเตือนปัญหา'),
      ),
      body: body,
    );
  }

  void _openAlert(BuildContext context, AdminAlertItem item) {
    switch (item.type) {
      case AdminAlertType.orderDelayed:
      case AdminAlertType.shopSlowPreparing:
        final order = item.order;
        if (order != null) {
          if (widget.onOpenOrder != null) {
            widget.onOpenOrder!(context, order);
          }
        }
      case AdminAlertType.withdrawPending:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdminWithdrawQueueScreen(),
          ),
        );
      case AdminAlertType.productReview:
      case AdminAlertType.supportTicket:
        final ticket = item.workItem?.ticket;
        final product = item.workItem?.product;
        if (ticket != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminSupportTicketDetailScreen(ticket: ticket),
            ),
          );
          return;
        }
        if (product != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AdminWorkInboxScreen(),
            ),
          );
          return;
        }
        widget.onOpenWorkInboxTab?.call();
      case AdminAlertType.shopApproval:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ShopManagementScreen(),
          ),
        );
    }
  }
}

class _AlertSummaryHeader extends StatelessWidget {
  const _AlertSummaryHeader({
    required this.snapshot,
    required this.focusedCount,
  });

  final AdminAlertCenterSnapshot snapshot;
  final int focusedCount;

  @override
  Widget build(BuildContext context) {
    final critical = snapshot.countBySeverity(AdminAttentionSeverity.critical);
    final warning = snapshot.countBySeverity(AdminAttentionSeverity.warning);
    final info = snapshot.countBySeverity(AdminAttentionSeverity.info);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFDC2626), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.notification_important_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'มีเรื่องต้องจัดการ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${snapshot.totalCount} รายการทั้งหมด · โฟกัส $focusedCount · อัปเดตเรียลไทม์',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (critical > 0) _SeverityChip(label: '🔴 เร่งด่วน $critical', color: Colors.white),
              if (warning > 0)
                _SeverityChip(
                  label: '🟠 ควรจัดการ $warning',
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              if (info > 0)
                _SeverityChip(
                  label: '🟡 ทั่วไป $info',
                  color: Colors.white.withValues(alpha: 0.85),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.item,
    required this.onTap,
    this.dimmed = false,
  });

  final AdminAlertItem item;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.severity) {
      AdminAttentionSeverity.critical => (Icons.error_rounded, const Color(0xFFDC2626)),
      AdminAttentionSeverity.warning => (Icons.warning_amber_rounded, const Color(0xFFEA580C)),
      AdminAttentionSeverity.info => (Icons.info_outline_rounded, const Color(0xFFD97706)),
    };
    final claimBar = _claimBarFor(item);

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dimmed
                    ? const Color(0xFFE5E7EB)
                    : color.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: dimmed ? const Color(0xFF9CA3AF) : color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: dimmed
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF7C2D12),
                                  ),
                            ),
                          ),
                          if (dimmed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'ไม่โฟกัส',
                                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                              height: 1.35,
                            ),
                      ),
                      if (claimBar != null) claimBar,
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFE65100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget? _claimBarFor(AdminAlertItem item) {
    switch (item.type) {
      case AdminAlertType.productReview:
        final product = item.workItem?.product;
        if (product == null) {
          return null;
        }
        return AdminWorkClaimBar(
          sourceType: AdminWorkSourceType.productReview,
          sourceId: product.id,
          title: product.name,
          compact: true,
        );
      case AdminAlertType.supportTicket:
        final ticket = item.workItem?.ticket;
        if (ticket == null) {
          return null;
        }
        return AdminWorkClaimBar(
          sourceType: AdminWorkSourceType.supportTicket,
          sourceId: ticket.id,
          title: ticket.topicLabel,
          compact: true,
        );
      case AdminAlertType.shopApproval:
        final shop = item.shop;
        if (shop == null) {
          return null;
        }
        return AdminWorkClaimBar(
          sourceType: AdminWorkSourceType.shopApproval,
          sourceId: shop.id,
          title: shop.displayName,
          branchId: shop.branchId,
          compact: true,
        );
      case AdminAlertType.withdrawPending:
        final requestId = item.withdrawRequestId;
        if (requestId == null || requestId.isEmpty) {
          return null;
        }
        return AdminWorkClaimBar(
          sourceType: AdminWorkSourceType.withdraw,
          sourceId: requestId,
          title: item.title,
          compact: true,
        );
      case AdminAlertType.orderDelayed:
      case AdminAlertType.shopSlowPreparing:
        final order = item.order;
        if (order == null) {
          return null;
        }
        final code = (order.orderCode ?? '').trim();
        return AdminWorkClaimBar(
          sourceType: AdminWorkSourceType.order,
          sourceId: order.id,
          title: code.isNotEmpty ? code : order.id,
          branchId: order.rawData['branchId']?.toString(),
          compact: true,
        );
    }
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts({required this.asOf});

  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีปัญหาค้างตอนนี้',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF065F46),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'ระบบจะแจ้งที่นี่เมื่อมีออเดอร์ค้าง ร้านช้า หรืองานแอดมิน',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
