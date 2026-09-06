import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_kyc_center_screen.dart';
import 'models/admin_actor_statement.dart';
import 'services/admin_actor_statement_service.dart';
import 'services/admin_kyc_service.dart';

class AdminActorStatementScreen extends StatefulWidget {
  const AdminActorStatementScreen({super.key});

  @override
  State<AdminActorStatementScreen> createState() =>
      _AdminActorStatementScreenState();
}

class _AdminActorStatementScreenState extends State<AdminActorStatementScreen> {
  late String _periodId;
  var _runningBatch = false;
  AdminKycSummary? _kycSummary;

  @override
  void initState() {
    super.initState();
    _periodId = AdminActorStatementService.defaultPeriodId();
    _loadKycSummary();
  }

  Future<void> _loadKycSummary() async {
    try {
      final summary = await AdminKycService.fetchSummary();
      if (mounted) {
        setState(() => _kycSummary = summary);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _runBatch({bool force = false}) async {
    setState(() => _runningBatch = true);
    try {
      final result = await AdminActorStatementService.runMonthlyBatch(
        periodId: _periodId,
        force: force,
      );
      if (!mounted) {
        return;
      }
      final count = (result['actorCount'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('รันงวด $_periodId ครบ $count ราย')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ล้มเหลว: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _runningBatch = false);
      }
    }
  }

  Future<void> _resend(AdminActorStatement item) async {
    try {
      await AdminActorStatementService.resendEmail(item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งอีเมลซ้ำแล้ว: ${item.displayName}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งซ้ำไม่ได้: $error')),
        );
      }
    }
  }

  Future<void> _generateOne(AdminActorStatement item) async {
    try {
      await AdminActorStatementService.generateOne(
        actorType: item.actorType,
        actorUid: item.actorUid,
        periodId: item.periodId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้างใบแจ้งยอด: ${item.displayName}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สร้างไม่ได้: $error')),
        );
      }
    }
  }

  void _showDetail(AdminActorStatement item) {
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
              Text(item.displayName, style: Theme.of(context).textTheme.titleLarge),
              Text('${item.actorTypeLabel} · ${item.actorUid}'),
              const SizedBox(height: 12),
              Text('สถานะ: ${item.statusLabel}'),
              if (item.skipReason.isNotEmpty)
                Text('เหตุข้าม: ${item.skipReasonLabelTh}'),
              if (item.emailError.isNotEmpty) Text('อีเมล: ${item.emailError}'),
              Text('อีเมล: ${item.recipientEmail.isEmpty ? '-' : item.recipientEmail}'),
              Text('บัตร: ${item.verifiedNationalIdMasked.isEmpty ? '-' : item.verifiedNationalIdMasked}'),
              Text(
                'PDF: ${item.pdfStoragePath.isEmpty ? 'ยังไม่มี' : item.pdfStoragePath.split('/').last}',
              ),
              const SizedBox(height: 12),
              if (item.pdfStoragePath.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _resend(item);
                  },
                  icon: const Icon(Icons.forward_to_inbox_outlined),
                  label: const Text('ส่งอีเมลซ้ำ'),
                ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _generateOne(item);
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('สร้าง/บังคับสร้างใหม่'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบแจ้งยอดรายเดือน'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ศูนย์ KYC',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminKycCenterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_kycSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                color: const Color(0xFFFFF7ED),
                child: ListTile(
                  title: Text(
                    'KYC พร้อมส่ง ${_kycSummary!.complete}/${_kycSummary!.total}',
                  ),
                  subtitle: Text(
                    'ยังไม่พร้อม ${_kycSummary!.notReady} ราย — ต้องมีบัตร+อีเมลก่อนส่ง PDF',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminKycCenterScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    initialValue: _periodId,
                    decoration: const InputDecoration(
                      labelText: 'งวด (YYYY-MM)',
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                    ],
                    onFieldSubmitted: (value) {
                      setState(() => _periodId = value.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _runningBatch ? null : () => _runBatch(),
                  child: _runningBatch
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('รันงวด'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PDF มีรหัสผ่าน DDMMYYYY ค.ศ. จากเลขบัตรที่ยืนยัน — ไม่ส่งรหัสผ่านทางอีเมล',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AdminActorStatement>>(
              stream: AdminActorStatementService.streamForPeriod(_periodId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <AdminActorStatement>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีใบแจ้งยอดในงวดนี้'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text('${item.actorTypeLabel} · ${item.displayName}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${item.statusLabel} · ${item.recipientEmail}'),
                            if (item.skipReason.isNotEmpty)
                              Text('ข้าม: ${item.skipReasonLabelTh}'),
                            if (item.emailError.isNotEmpty)
                              Text('อีเมล: ${item.emailError}'),
                            Text(
                              'ปิดงวด ${item.summary.closingBalance.toStringAsFixed(2)} บาท · ถอน ${item.summary.withdrawCount} ครั้ง',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (item.pdfStoragePath.isNotEmpty)
                              IconButton(
                                tooltip: 'ส่งอีเมลซ้ำ',
                                icon: const Icon(Icons.forward_to_inbox_outlined),
                                onPressed: () => _resend(item),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _showDetail(item),
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
