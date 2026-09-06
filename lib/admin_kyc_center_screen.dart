import 'dart:async';

import 'package:flutter/material.dart';

import 'admin_tax_hub_screen.dart';
import 'models/admin_capability.dart';
import 'models/admin_kyc_record.dart';
import 'models/admin_session.dart';
import 'services/admin_activity_log.dart';
import 'services/admin_kyc_service.dart';

class KycCapabilityGate extends StatelessWidget {
  const KycCapabilityGate({super.key, required this.child});

  final Widget child;

  static bool get hasAccess {
    final session = AdminSessionService.instance;
    return session.hasCap(AdminCapability.withdraw) ||
        session.hasCap(AdminCapability.taxCompliance) ||
        session.hasCap(AdminCapability.financeRoi) ||
        session.hasCap(AdminCapability.kycCompliance);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAccess) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

class AdminKycCenterScreen extends StatefulWidget {
  const AdminKycCenterScreen({super.key});

  @override
  State<AdminKycCenterScreen> createState() => _AdminKycCenterScreenState();
}

class _AdminKycCenterScreenState extends State<AdminKycCenterScreen> {
  Future<List<AdminKycRecord>>? _future;
  AdminKycStatus? _filter;

  @override
  void initState() {
    super.initState();
    _reload();
    unawaited(AdminActivityLog.logOpenMenu(title: 'ศูนย์ยืนยันตัวตน'));
  }

  void _reload() {
    setState(() {
      _future = AdminKycService.fetchAll();
    });
  }

  List<AdminKycRecord> _applyFilter(List<AdminKycRecord> records) {
    if (_filter == null) {
      return records;
    }
    return records.where((record) => record.status == _filter).toList();
  }

  String _statusLabel(AdminKycStatus status) {
    return AdminKycRecord(
      actorType: '',
      actorUid: '',
      displayName: '',
      status: status,
    ).statusLabelTh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์ยืนยันตัวตน (KYC)'),
        actions: <Widget>[
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<AdminKycRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดไม่สำเร็จ: ${snapshot.error}'));
          }
          final all = snapshot.data ?? const <AdminKycRecord>[];
          final summary = AdminKycSummary.fromRecords(all);
          final records = _applyFilter(all);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'สรุป ${summary.total} ราย',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('พร้อม: ${summary.complete} · ยังไม่พร้อม: ${summary.notReady}'),
                        Text(
                          'ไม่มีบัตร ${summary.missingId} · บัตรผิด ${summary.invalidId} · '
                          'ไม่มีอีเมล ${summary.missingEmail} · บัตร≠PromptPay ${summary.promptPayMismatch}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
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
                    ...AdminKycStatus.values.map(
                      (status) {
                        final count =
                            all.where((record) => record.status == status).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('${_statusLabel(status)} ($count)'),
                            selected: _filter == status,
                            onSelected: (_) => setState(() => _filter = status),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: records.isEmpty
                    ? const Center(child: Text('ไม่มีรายการในตัวกรองนี้'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return Card(
                            child: ListTile(
                              title: Text('${record.actorTypeLabel} · ${record.displayName}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${record.statusLabelTh} · ${record.email.isEmpty ? 'ไม่มีอีเมล' : record.email}',
                                  ),
                                  if (record.verifiedNationalIdMasked.isNotEmpty)
                                    Text('บัตร: ${record.verifiedNationalIdMasked}'),
                                  if (record.promptPayMasked.isNotEmpty)
                                    Text('PromptPay: ${record.promptPayMasked}'),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDetail(context, record),
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

  void _showDetail(BuildContext context, AdminKycRecord record) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                record.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('${record.actorTypeLabel} · ${record.actorUid}'),
              const SizedBox(height: 12),
              Text('สถานะ: ${record.statusLabelTh}'),
              Text('อีเมล: ${record.email.isEmpty ? '-' : record.email}'),
              Text(
                'บัตรยืนยัน: ${record.verifiedNationalIdMasked.isEmpty ? '-' : record.verifiedNationalIdMasked}',
              ),
              Text(
                'PromptPay: ${record.promptPayMasked.isEmpty ? '-' : record.promptPayMasked}',
              ),
              if (record.branchId.isNotEmpty) Text('สาขา: ${record.branchId}'),
              const SizedBox(height: 16),
              if (!record.isReadyForStatement)
                const Text(
                  'ยังส่งใบแจ้งยอดไม่ได้ — ต้องมีเลขบัตรที่ถูกต้องและอีเมลจริง',
                  style: TextStyle(color: Color(0xFFB45309)),
                ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminTaxHubScreen(),
                    ),
                  );
                },
                child: const Text('ไปศูนย์ภาษี / ใบแจ้งยอด'),
              ),
            ],
          ),
        );
      },
    );
  }
}
