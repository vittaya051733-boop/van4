import 'package:flutter/material.dart';

import 'admin_claim_screen.dart';
import 'admin_repository.dart';
import 'admin_support_screens.dart';
import 'models/admin_capability.dart';
import 'models/admin_session.dart';
import 'services/admin_activity_log.dart';
import 'services/admin_dispute_service.dart';

class DisputeCapabilityGate extends StatelessWidget {
  const DisputeCapabilityGate({super.key, required this.child});

  final Widget child;

  static bool get hasAccess {
    final session = AdminSessionService.instance;
    return session.hasCap(AdminCapability.disputeHub) ||
        session.hasCap(AdminCapability.workInbox) ||
        session.hasCap(AdminCapability.orders);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAccess) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

class AdminDisputeHubScreen extends StatefulWidget {
  const AdminDisputeHubScreen({super.key});

  @override
  State<AdminDisputeHubScreen> createState() => _AdminDisputeHubScreenState();
}

class _AdminDisputeHubScreenState extends State<AdminDisputeHubScreen> {
  var _activeOnly = true;

  @override
  void initState() {
    super.initState();
    AdminActivityLog.logOpenMenu(title: 'ศูนย์ข้อพิพาท');
  }

  Future<void> _openDispute(BuildContext context, AdminDisputeItem item) async {
    if (item.orderId.isNotEmpty) {
      final order = await AdminRepository.fetchOrderById(item.orderId);
      if (!context.mounted) {
        return;
      }
      if (order != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdminClaimScreen(
              order: order,
              linkedTicketId: item.ticket.id,
              initialReason: item.ticket.claimRequest?.reason,
            ),
          ),
        );
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminSupportTicketDetailScreen(ticket: item.ticket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์ข้อพิพาท / เคลม'),
        actions: <Widget>[
          FilterChip(
            label: const Text('เฉพาะที่เปิด'),
            selected: _activeOnly,
            onSelected: (value) => setState(() => _activeOnly = value),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<AdminDisputeItem>>(
        stream: AdminDisputeService.streamDisputes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('โหลดไม่สำเร็จ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var items = snapshot.data!;
          if (_activeOnly) {
            items = items.where((item) => item.isActive).toList(growable: false);
          }
          if (items.isEmpty) {
            return const Center(child: Text('ไม่มีข้อพิพาทในตัวกรองนี้'));
          }

          final openCount = items.where((item) => item.stage == AdminDisputeStage.open).length;
          final reviewCount =
              items.where((item) => item.stage == AdminDisputeStage.inReview).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('เปิดใหม่ $openCount · กำลังตรวจ $reviewCount · รวม ${items.length}'),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final claim = item.ticket.claimRequest;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          item.isActive ? Icons.gavel_outlined : Icons.check_circle_outline,
                          color: item.isActive
                              ? const Color(0xFFE65100)
                              : const Color(0xFF16A34A),
                        ),
                        title: Text(item.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${item.stageLabelTh} · ${item.subtitle}'),
                            if (claim != null && claim.items.isNotEmpty)
                              Text('รายการเคลม ${claim.items.length} ชิ้น'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDispute(context, item),
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
