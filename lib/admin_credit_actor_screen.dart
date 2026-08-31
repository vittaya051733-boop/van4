import 'package:flutter/material.dart';

import 'admin_repository.dart';
import 'admin_screens.dart';
import 'services/admin_credit_service.dart';
import 'services/admin_merchant_contract_service.dart';

class AdminCreditActorScreen extends StatefulWidget {
  const AdminCreditActorScreen({
    super.key,
    required this.uid,
    required this.actorType,
    this.initialDisplayName,
  });

  final String uid;
  final String actorType;
  final String? initialDisplayName;

  @override
  State<AdminCreditActorScreen> createState() => _AdminCreditActorScreenState();
}

class _AdminCreditActorScreenState extends State<AdminCreditActorScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  AdminActorWalletSnapshot? _snapshot;
  List<AdminCreditLedgerItem> _ledger = <AdminCreditLedgerItem>[];
  String? _ledgerCursor;
  bool _loading = true;
  bool _loadingMoreLedger = false;
  bool _submitting = false;
  String? _error;

  bool get _isMerchant => widget.actorType == 'merchant';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _ledgerCursor = null;
    });
    try {
      final snapshot = await AdminCreditService.fetchActorWallet(
        uid: widget.uid,
        actorType: widget.actorType,
      );
      List<AdminCreditLedgerItem> ledger = const <AdminCreditLedgerItem>[];
      String? ledgerCursor;
      String? ledgerWarning;
      try {
        final ledgerPage = await AdminCreditService.fetchLedger(uid: widget.uid);
        ledger = ledgerPage.items;
        ledgerCursor = ledgerPage.nextCursorId;
      } catch (ledgerError) {
        ledgerWarning = AdminCreditService.errorMessage(ledgerError);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _ledger = ledger;
        _ledgerCursor = ledgerCursor;
        _loading = false;
        _error = ledgerWarning;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = AdminCreditService.errorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreLedger() async {
    final cursor = _ledgerCursor;
    if (cursor == null || _loadingMoreLedger) {
      return;
    }
    setState(() => _loadingMoreLedger = true);
    try {
      final page = await AdminCreditService.fetchLedger(
        uid: widget.uid,
        cursorId: cursor,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ledger = <AdminCreditLedgerItem>[..._ledger, ...page.items];
        _ledgerCursor = page.nextCursorId;
        _loadingMoreLedger = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingMoreLedger = false);
      _snack(AdminCreditService.errorMessage(error));
    }
  }

  Future<void> _syncMerchantWallet() async {
    if (!_isMerchant) {
      return;
    }
    try {
      await AdminMerchantContractService.instance.syncMerchantWallet(widget.uid);
      await _reload();
      if (mounted) {
        _snack('ซิงค์ merchant_wallets แล้ว');
      }
    } catch (error) {
      if (mounted) {
        _snack(AdminMerchantContractService.errorMessage(error));
      }
    }
  }

  Future<void> _submitAdjust() async {
    if (_submitting) {
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();
    if (amount == null || amount == 0) {
      _snack('กรุณาระบุจำนวนเงิน (+/-)');
      return;
    }
    if (reason.isEmpty) {
      _snack('กรุณาระบุเหตุผล');
      return;
    }

    final before = _snapshot?.creditTotal ?? 0;
    final after = before + amount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันปรับเครดิต'),
        content: Text(
          '${widget.initialDisplayName ?? _snapshot?.displayName ?? widget.uid}\n'
          '฿${before.toStringAsFixed(0)} → ฿${after.toStringAsFixed(0)}'
          ' (${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(0)})',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await AdminCreditService.adjustCredit(
        uid: widget.uid,
        actorType: widget.actorType,
        amount: amount,
        reason: reason,
        note: _noteController.text,
      );
      _amountController.clear();
      _reasonController.clear();
      _noteController.clear();
      await _reload();
      if (!mounted) {
        return;
      }
      _snack(
        result.duplicate
            ? 'รายการนี้บันทึกไปแล้ว'
            : 'ปรับเครดิตแล้ว → ฿${result.afterBalance.toStringAsFixed(0)}',
      );
    } catch (error) {
      if (mounted) {
        _snack(AdminCreditService.errorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openOrder(String orderId) async {
    final order = await AdminRepository.fetchOrderById(orderId);
    if (!mounted) {
      return;
    }
    if (order == null) {
      _snack('ไม่พบออเดอร์');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminOrderDetailScreen(order: order),
      ),
    );
  }

  void _applyPreset(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialDisplayName ?? _snapshot?.displayName ?? widget.uid;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (_isMerchant)
            IconButton(
              tooltip: 'ซิงค์ wallet',
              onPressed: _syncMerchantWallet,
              icon: const Icon(Icons.sync_rounded),
            ),
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _snapshot == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_error ?? 'โหลดข้อมูลไม่สำเร็จ', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFCC80)),
                          ),
                          child: Text(
                            'ประวัติ ledger โหลดไม่ครบ: $_error',
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      _buildSummary(),
                      const SizedBox(height: 16),
                      _buildAdjustForm(),
                      const SizedBox(height: 16),
                      _buildPendingReleases(),
                      const SizedBox(height: 16),
                      _buildLedger(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary() {
    final snap = _snapshot!;
    final mw = snap.merchantWallet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _isMerchant ? 'van1 ร้านค้า' : 'van3 ไรเดอร์',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('UID: ${widget.uid}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            'ยอด ledger (Σ credits): ฿${snap.creditTotal.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          Text('ถอนได้ (คำนวณ): ฿${snap.availableBalance.toStringAsFixed(0)}'),
          if (snap.pendingWithdrawTotal > 0)
            Text('รอถอน (hold): ฿${snap.pendingWithdrawTotal.toStringAsFixed(0)}'),
          if (mw != null) ...<Widget>[
            const Divider(height: 20),
            Text('merchant_wallets snapshot'),
            Text('ถอนได้ Omise: ฿${mw.omiseWithdrawableCredit.toStringAsFixed(0)}'),
            Text('Omise pending: ฿${mw.omisePendingCredit.toStringAsFixed(0)}'),
            Text('Omise locked: ฿${mw.omiseLockedCredit.toStringAsFixed(0)}'),
            Text('สัญญา: ${mw.contractStatus}'),
          ],
        ],
      ),
    );
  }

  Widget _buildAdjustForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ปรับเครดิต (ledger)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            ActionChip(label: const Text('+100'), onPressed: () => _applyPreset(100)),
            ActionChip(label: const Text('+500'), onPressed: () => _applyPreset(500)),
            ActionChip(label: const Text('-100'), onPressed: () => _applyPreset(-100)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(
            labelText: 'จำนวน (บาท) — ใส่ลบเพื่อหัก',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: 'เหตุผล (บังคับ)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'หมายเหตุ (ถ้ามี)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _submitting ? null : _submitAdjust,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            minimumSize: const Size.fromHeight(48),
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.tune_rounded),
          label: const Text('บันทึกการปรับยอด'),
        ),
      ],
    );
  }

  Widget _buildPendingReleases() {
    final pending = _snapshot?.pendingReleases ?? const <AdminPendingReleaseOrder>[];
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'รอปล่อยเครดิต / hold',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        ...pending.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.orderCode),
              subtitle: Text(
                '${item.status} · ฿${item.amount.toStringAsFixed(0)}'
                '${item.holdReason != null ? '\n${item.holdReason}' : ''}',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openOrder(item.orderId),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLedger() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ประวัติ ledger',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (_ledger.isEmpty)
          const Text('ยังไม่มีรายการ')
        else
          ..._ledger.map(_ledgerTile),
        if (_ledgerCursor != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: _loadingMoreLedger ? null : _loadMoreLedger,
              child: _loadingMoreLedger
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('โหลดเพิ่ม'),
            ),
          ),
      ],
    );
  }

  Widget _ledgerTile(AdminCreditLedgerItem item) {
    final ts = item.timestamp;
    final when = ts == null ? '' : ts.toLocal().toString().substring(0, 16);
    final sign = item.amount >= 0 ? '+' : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${item.type} · $sign${item.amount.toStringAsFixed(0)} บาท'),
      subtitle: Text(
        <String>[
          if (item.reason != null && item.reason!.isNotEmpty) item.reason!,
          if (when.isNotEmpty) when,
          if (item.orderId != null) 'order: ${item.orderId}',
        ].join('\n'),
      ),
    );
  }
}
