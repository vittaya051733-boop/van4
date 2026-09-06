import 'package:flutter/material.dart';

import 'models/admin_activity_log_entry.dart';
import 'models/admin_capability.dart';
import 'models/admin_session.dart';
import 'services/admin_work_task_service.dart';

class FinancialAuditCapabilityGate extends StatelessWidget {
  const FinancialAuditCapabilityGate({super.key, required this.child});

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

class AdminFinancialAuditScreen extends StatelessWidget {
  const AdminFinancialAuditScreen({super.key});

  static String _formatTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit การเงิน / ภาษี')),
      body: Column(
        children: <Widget>[
          if (AdminSessionService.instance.isBranchScoped)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF7ED),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'สาขา ${AdminSessionService.instance.assignedBranchId ?? '-'}',
                style: const TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AdminActivityLogEntry>>(
              stream: AdminWorkTaskService.watchLogs(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('โหลดไม่สำเร็จ: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final logs = snapshot.data!
                    .where(
                      (log) =>
                          log.category == 'financial' ||
                          log.targetType == 'withdraw' ||
                          log.action.contains('withdraw') ||
                          log.action.contains('vat') ||
                          log.action.contains('tax'),
                    )
                    .toList(growable: false);
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีบันทึกการเงิน/ภาษี'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${log.actionLabelTh} · ${_formatTime(log.at)}',
                              style: const TextStyle(
                                color: Color(0xFF9A3412),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.labelTh,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${log.actorEmail} · ${log.targetType}/${log.targetId}',
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                            if (log.detail.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                log.detail.entries
                                    .map((entry) => '${entry.key}: ${entry.value}')
                                    .join(' · '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
