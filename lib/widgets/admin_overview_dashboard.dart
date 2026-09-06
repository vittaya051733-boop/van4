import 'package:flutter/material.dart';

import '../admin_withdraw_queue_screen.dart';
import '../admin_shop_screens.dart';
import '../models/admin_overview_snapshot.dart';
import '../services/admin_overview_service.dart';
import 'admin_market_selector.dart';

String formatOverviewBaht(double amount) {
  final rounded = amount.round();
  final text = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String formatOverviewDateTh(DateTime date) {
  const weekdays = <String>[
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัส',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];
  const months = <String>[
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  final weekday = weekdays[(date.weekday - 1).clamp(0, 6)];
  final month = months[(date.month - 1).clamp(0, 11)];
  return 'วัน$weekday ${date.day} $month ${date.year + 543}';
}

class AdminOverviewDashboard extends StatelessWidget {
  const AdminOverviewDashboard({
    super.key,
    required this.onOpenWorkInboxTab,
    required this.onOpenLiveTab,
    required this.onOpenAlertTab,
  });

  final VoidCallback onOpenWorkInboxTab;
  final VoidCallback onOpenLiveTab;
  final VoidCallback onOpenAlertTab;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminOverviewSnapshot>(
      stream: AdminOverviewService.instance.streamOverview(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _OverviewErrorCard(message: '${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const _OverviewLoadingCard();
        }

        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AdminMarketScopeBanner(),
            const SizedBox(height: 12),
            _OverviewHeader(asOf: data.asOf),
            const SizedBox(height: 16),
            _QuickControlRow(
              onOpenLiveTab: onOpenLiveTab,
              onOpenAlertTab: onOpenAlertTab,
            ),
            const SizedBox(height: 16),
            _KpiGrid(data: data),
            if (data.attentionBreakdown.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _AttentionPanel(
                items: data.attentionBreakdown,
                total: data.attentionTotal,
                onOpenWorkInboxTab: onOpenWorkInboxTab,
                onOpenAlertTab: onOpenAlertTab,
                onNavigate: (context, item) => _openAttentionTarget(context, item),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openAttentionTarget(BuildContext context, AdminAttentionItem item) {
    switch (item.id) {
      case 'withdraw':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdminWithdrawQueueScreen(),
          ),
        );
      case 'product_review':
      case 'support_ticket':
        onOpenWorkInboxTab();
      case 'shop_approval':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ShopManagementScreen(),
          ),
        );
    }
  }
}

class _QuickControlRow extends StatelessWidget {
  const _QuickControlRow({
    required this.onOpenLiveTab,
    required this.onOpenAlertTab,
  });

  final VoidCallback onOpenLiveTab;
  final VoidCallback onOpenAlertTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickControlButton(
            icon: Icons.local_shipping_rounded,
            label: 'งานสด',
            subtitle: 'ออเดอร์กำลังดำเนินการ',
            color: const Color(0xFF2563EB),
            onTap: onOpenLiveTab,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickControlButton(
            icon: Icons.notification_important_rounded,
            label: 'ปัญหา',
            subtitle: 'ศูนย์แจ้งเตือน',
            color: const Color(0xFFDC2626),
            onTap: onOpenAlertTab,
          ),
        ),
      ],
    );
  }
}

class _QuickControlButton extends StatelessWidget {
  const _QuickControlButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF7C2D12),
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.asOf});

  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE65100), Color(0xFFBF360C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ภาพรวมแว้นตลาดวันนี้',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatOverviewDateTh(asOf),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'อัปเดตแบบเรียลไทม์จาก Firestore',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final AdminOverviewSnapshot data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
        final tiles = <_KpiTileData>[
          _KpiTileData(
            emoji: '📦',
            label: 'ออเดอร์วันนี้',
            value: '${data.ordersToday}',
            accent: const Color(0xFF2563EB),
          ),
          _KpiTileData(
            emoji: '💰',
            label: 'ยอดขาย',
            value: '${formatOverviewBaht(data.salesTodayBaht)} บาท',
            accent: const Color(0xFF059669),
          ),
          _KpiTileData(
            emoji: '🏪',
            label: 'ร้านเปิด',
            value: '${data.openShops} ร้าน',
            accent: const Color(0xFFD97706),
          ),
          _KpiTileData(
            emoji: '🛵',
            label: 'ไรเดอร์ทำงาน',
            value: '${data.activeRiders} คน',
            accent: const Color(0xFF7C3AED),
          ),
          _KpiTileData(
            emoji: '👤',
            label: 'ลูกค้าใช้งาน',
            value: '${data.activeCustomersToday} คน',
            accent: const Color(0xFF0891B2),
          ),
          _KpiTileData(
            emoji: '⚠️',
            label: 'เรื่องต้องจัดการ',
            value: '${data.attentionTotal} เรื่อง',
            accent: data.attentionTotal > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF6B7280),
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 3 ? 1.35 : 1.15,
          ),
          itemBuilder: (context, index) => _KpiTile(data: tiles[index]),
        );
      },
    );
  }
}

class _KpiTileData {
  const _KpiTileData({
    required this.emoji,
    required this.label,
    required this.value,
    required this.accent,
  });

  final String emoji;
  final String label;
  final String value;
  final Color accent;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE0B2)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(data.emoji, style: const TextStyle(fontSize: 22)),
          const Spacer(),
          Text(
            data.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: data.accent,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.items,
    required this.total,
    required this.onOpenWorkInboxTab,
    required this.onOpenAlertTab,
    required this.onNavigate,
  });

  final List<AdminAttentionItem> items;
  final int total;
  final VoidCallback onOpenWorkInboxTab;
  final VoidCallback onOpenAlertTab;
  final void Function(BuildContext context, AdminAttentionItem item) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.notifications_active_rounded, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'มีเรื่องต้องจัดการ $total รายการ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9A3412),
                      ),
                ),
              ),
              TextButton(
                onPressed: onOpenAlertTab,
                child: const Text('ดูทั้งหมด'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => _AttentionRow(
              item: item,
              onTap: () => onNavigate(context, item),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap});

  final AdminAttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.severity) {
      AdminAttentionSeverity.critical => (Icons.error_rounded, const Color(0xFFDC2626)),
      AdminAttentionSeverity.warning => (Icons.warning_amber_rounded, const Color(0xFFEA580C)),
      AdminAttentionSeverity.info => (Icons.info_outline_rounded, const Color(0xFFD97706)),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7C2D12),
                      ),
                ),
              ),
              Text(
                '${item.count}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewLoadingCard extends StatelessWidget {
  const _OverviewLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: const Center(
        child: Column(
          children: <Widget>[
            CircularProgressIndicator(color: Color(0xFFE65100)),
            SizedBox(height: 14),
            Text('กำลังโหลดภาพรวมวันนี้...'),
          ],
        ),
      ),
    );
  }
}

class _OverviewErrorCard extends StatelessWidget {
  const _OverviewErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'โหลดภาพรวมไม่สำเร็จ: $message',
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }
}
