import 'package:flutter/material.dart';

import 'models/ecosystem_health_point.dart';
import 'services/ecosystem_health_service.dart';

class AdminEcosystemHealthScreen extends StatefulWidget {
  const AdminEcosystemHealthScreen({super.key});

  @override
  State<AdminEcosystemHealthScreen> createState() =>
      _AdminEcosystemHealthScreenState();
}

class _AdminEcosystemHealthScreenState extends State<AdminEcosystemHealthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final EcosystemHealthService _health = EcosystemHealthService.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _health.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_health.lastProbeAt == null && !_health.isProbing) {
        _health.runProbes();
      }
    });
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _health.removeListener(_onChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = _health.counts();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('สุขภาพระบบ / จุดเชื่อม Firebase'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ตรวจตอนนี้',
            onPressed: _health.isProbing ? null : () => _health.runProbes(),
            icon: _health.isProbing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const <Widget>[
            Tab(text: 'รวม'),
            Tab(text: 'แยกตามแอป'),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          _SummaryBanner(
            counts: all,
            lastProbeAt: _health.lastProbeAt,
            health: _health,
          ),
          if (_health.lastProbeError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _health.lastProbeError!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _CombinedTab(health: _health),
                _SplitByAppTab(health: _health),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.counts,
    required this.lastProbeAt,
    required this.health,
  });

  final EcosystemHealthCounts counts;
  final DateTime? lastProbeAt;
  final EcosystemHealthService health;

  @override
  Widget build(BuildContext context) {
    final hb1 = health.latestHeartbeatAt(EcosystemHealthApp.van1);
    final hb2 = health.latestHeartbeatAt(EcosystemHealthApp.van2);
    final hb3 = health.latestHeartbeatAt(EcosystemHealthApp.van3);
    final anyHb = hb1 != null || hb2 != null || hb3 != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'จุดเชื่อมทั้งหมด ${counts.total} จุด',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A3412),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CountChip(
                label: 'เขียว ${counts.ok}',
                color: const Color(0xFF166534),
                bg: const Color(0xFFDCFCE7),
              ),
              _CountChip(
                label: 'แดง ${counts.fail}',
                color: const Color(0xFF991B1B),
                bg: const Color(0xFFFEE2E2),
              ),
              _CountChip(
                label: 'ยังไม่ตรวจ ${counts.unknown}',
                color: const Color(0xFF92400E),
                bg: const Color(0xFFFEF3C7),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Heartbeat: van1 ${_hbLabel(hb1)} · van2 ${_hbLabel(hb2)} · van3 ${_hbLabel(hb3)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9A3412),
            ),
          ),
          if (!anyHb) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'ยังไม่มีสัญญาณจากแอป — ทำต่อ:\n'
              '1) ติดตั้ง APK ใหม่ van1 / van2 / van3 (โฟลเดอร์ releases)\n'
              '2) ล็อกอินแล้วค้างหน้าแรกอย่างน้อย 1 นาที\n'
              '3) กดรีเฟรชมุมขวาบนในหน้านี้\n'
              'จุดโครงสร้างร่วม/van4 ควรเขียวจากปุ่มรีเฟรชได้ทันทีโดยไม่ต้องรอแอปอื่น',
              style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            lastProbeAt == null
                ? 'ยังไม่เคยตรวจอัตโนมัติ — กดรีเฟรชมุมขวาบน'
                : 'ตรวจล่าสุด: ${_fmt(lastProbeAt!)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  static String _hbLabel(DateTime? at) {
    if (at == null) {
      return 'ไม่มี';
    }
    final seconds = DateTime.now().difference(at).inSeconds;
    if (seconds < 120) {
      return 'สด';
    }
    return 'ค้าง';
  }

  static String _fmt(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _CombinedTab extends StatelessWidget {
  const _CombinedTab({required this.health});

  final EcosystemHealthService health;

  @override
  Widget build(BuildContext context) {
    final failing = health.failingPoints();
    final points = [...EcosystemHealthCatalog.points]
      ..sort((a, b) {
        int rank(EcosystemHealthTone t) => switch (t) {
              EcosystemHealthTone.fail => 0,
              EcosystemHealthTone.unknown => 1,
              EcosystemHealthTone.ok => 2,
            };
        final c = rank(health.statusOf(a.id).tone)
            .compareTo(rank(health.statusOf(b.id).tone));
        if (c != 0) return c;
        return a.priority.compareTo(b.priority);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        if (failing.isNotEmpty) ...<Widget>[
          Text(
            'จุดที่ควรแก้ก่อน (${failing.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF991B1B),
                ),
          ),
          const SizedBox(height: 8),
          ...failing.map((p) => _PointCard(point: p, status: health.statusOf(p.id))),
          const SizedBox(height: 16),
        ],
        Text(
          'ทุกจุด (เรียงแดง → เหลือง → เขียว)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF9A3412),
              ),
        ),
        const SizedBox(height: 8),
        ...points.map((p) => _PointCard(point: p, status: health.statusOf(p.id))),
      ],
    );
  }
}

class _SplitByAppTab extends StatelessWidget {
  const _SplitByAppTab({required this.health});

  final EcosystemHealthService health;

  @override
  Widget build(BuildContext context) {
    const apps = <EcosystemHealthApp>[
      EcosystemHealthApp.shared,
      EcosystemHealthApp.van3,
      EcosystemHealthApp.van2,
      EcosystemHealthApp.van1,
      EcosystemHealthApp.van4,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        for (final app in apps) ...<Widget>[
          _AppSectionHeader(app: app, counts: health.counts(app: app)),
          const SizedBox(height: 8),
          ...EcosystemHealthCatalog.points
              .where((p) => p.app == app)
              .map((p) => _PointCard(point: p, status: health.statusOf(p.id))),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _AppSectionHeader extends StatelessWidget {
  const _AppSectionHeader({required this.app, required this.counts});

  final EcosystemHealthApp app;
  final EcosystemHealthCounts counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            EcosystemHealthCatalog.appLabelTh(app),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A3412),
                ),
          ),
        ),
        _CountChip(
          label: 'รวม ${counts.total}',
          color: const Color(0xFF9A3412),
          bg: const Color(0xFFFFEDD5),
        ),
        const SizedBox(width: 6),
        _CountChip(
          label: '🟢 ${counts.ok}',
          color: const Color(0xFF166534),
          bg: const Color(0xFFDCFCE7),
        ),
        const SizedBox(width: 6),
        _CountChip(
          label: '🔴 ${counts.fail}',
          color: const Color(0xFF991B1B),
          bg: const Color(0xFFFEE2E2),
        ),
      ],
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({required this.point, required this.status});

  final EcosystemHealthPoint point;
  final EcosystemHealthPointStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color dot, String toneLabel) = switch (status.tone) {
      EcosystemHealthTone.ok => (
          const Color(0xFF86EFAC),
          const Color(0xFF16A34A),
          'เขียว — ไม่หลุด',
        ),
      EcosystemHealthTone.fail => (
          const Color(0xFFFCA5A5),
          const Color(0xFFDC2626),
          'แดง — หลุด / มีปัญหา',
        ),
      EcosystemHealthTone.unknown => (
          const Color(0xFFFDE68A),
          const Color(0xFFD97706),
          'เหลือง — ยังไม่ตรวจ',
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  point.titleTh,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${point.id} · ${point.collection}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 6),
                Text(
                  point.detailTh,
                  style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                Text(
                  toneLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dot,
                  ),
                ),
                if (status.message != null && status.message!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    status.message!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
