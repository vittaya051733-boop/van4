import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'admin_repository.dart';
import 'admin_screens.dart';
import 'services/admin_activity_log.dart';
import 'services/admin_ops_report_service.dart';
import 'widgets/admin_market_selector.dart';
import 'models/admin_capability.dart';
import 'models/admin_session.dart';

class OpsReportCapabilityGate extends StatelessWidget {
  const OpsReportCapabilityGate({super.key, required this.child});

  final Widget child;

  static bool get hasAccess {
    final session = AdminSessionService.instance;
    return session.hasCap(AdminCapability.opsReports) ||
        session.hasCap(AdminCapability.overview);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAccess) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

class AdminOpsReportScreen extends StatefulWidget {
  const AdminOpsReportScreen({super.key});

  @override
  State<AdminOpsReportScreen> createState() => _AdminOpsReportScreenState();
}

class _AdminOpsReportScreenState extends State<AdminOpsReportScreen> {
  AdminOpsReportKind? _filter;
  var _exporting = false;

  @override
  void initState() {
    super.initState();
    unawaited(AdminActivityLog.logOpenMenu(title: 'รายงาน Ops'));
  }

  Future<void> _exportCsv(AdminOpsReportSnapshot snapshot) async {
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      await Share.share(
        snapshot.toCsv(),
        subject: 'Van Ops Report',
      );
      unawaited(
        AdminActivityLog.logFinancial(
          action: 'export_ops_report',
          labelTh: 'Export รายงาน Ops ${snapshot.rows.length} แถว',
          targetType: 'ops_report',
          targetId: snapshot.asOf.toIso8601String(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงาน Ops'),
        actions: <Widget>[
          StreamBuilder<AdminOpsReportSnapshot>(
            stream: AdminOpsReportService.streamReports(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Export CSV',
                onPressed: _exporting ? null : () => _exportCsv(snapshot.data!),
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<AdminOpsReportSnapshot>(
        stream: AdminOpsReportService.streamReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('โหลดไม่สำเร็จ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          var rows = data.rows;
          if (_filter != null) {
            rows = rows.where((row) => row.kind == _filter).toList(growable: false);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AdminMarketScopeBanner(),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'อัปเดต ${data.asOf.toLocal()} · ${rows.length} รายการ',
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: <Widget>[
                    FilterChip(
                      label: const Text('ทั้งหมด'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    ...AdminOpsReportKind.values.map(
                      (kind) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            AdminOpsReportRow(
                              kind: kind,
                              title: '',
                              detail: '',
                              orderId: '',
                            ).kindLabelTh,
                          ),
                          selected: _filter == kind,
                          onSelected: (_) => setState(() => _filter = kind),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('ไม่มีรายการในตัวกรองนี้'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return Card(
                            child: ListTile(
                              title: Text(row.title),
                              subtitle: Text('${row.kindLabelTh} · ${row.detail}'),
                              trailing: row.orderId.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.receipt_long_outlined),
                                      onPressed: () async {
                                        final order = await AdminRepository.fetchOrderById(
                                          row.orderId,
                                        );
                                        if (!context.mounted || order == null) {
                                          return;
                                        }
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => AdminOrderDetailScreen(
                                              order: order,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
