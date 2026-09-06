import 'dart:async';

import 'package:flutter/material.dart';

import 'models/tax_ledger_entry.dart';
import 'models/tax_vat_period.dart';
import 'services/admin_project_finance_service.dart';
import 'services/admin_activity_log.dart';
import 'services/admin_tax_service.dart';

class AdminVatPeriodScreen extends StatelessWidget {
  const AdminVatPeriodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('งวด VAT')),
      body: StreamBuilder<List<TaxVatPeriod>>(
        stream: AdminTaxService.streamVatPeriods(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final periods = snapshot.data ?? const <TaxVatPeriod>[];
          if (periods.isEmpty) {
            final current = AdminTaxService.periodIdFromDate(DateTime.now());
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('ยังไม่มีงวด — เริ่มจากงวดปัจจุบัน'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await AdminTaxService.ensureVatPeriodOpen(current);
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminVatPeriodDetailScreen(periodId: current),
                            ),
                          );
                        }
                      },
                      child: Text('เปิดงวด $current'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: periods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final period = periods[index];
              return Card(
                child: ListTile(
                  title: Text(period.id),
                  subtitle: Text(
                    '${vatPeriodStatusLabelTh(period.status)} · ภ.VAT ${formatBaht(period.netVatPayable)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AdminVatPeriodDetailScreen(periodId: period.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final controller = TextEditingController(
            text: AdminTaxService.periodIdFromDate(DateTime.now()),
          );
          final periodId = await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('เปิดงวด VAT'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'YYYY-MM',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('เปิด'),
                ),
              ],
            ),
          );
          controller.dispose();
          if (periodId == null || periodId.isEmpty || !context.mounted) {
            return;
          }
          await AdminTaxService.ensureVatPeriodOpen(periodId);
          if (!context.mounted) {
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminVatPeriodDetailScreen(periodId: periodId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('งวดใหม่'),
      ),
    );
  }
}

class AdminVatPeriodDetailScreen extends StatefulWidget {
  const AdminVatPeriodDetailScreen({super.key, required this.periodId});

  final String periodId;

  @override
  State<AdminVatPeriodDetailScreen> createState() =>
      _AdminVatPeriodDetailScreenState();
}

class _AdminVatPeriodDetailScreenState extends State<AdminVatPeriodDetailScreen> {
  var _busy = false;

  Future<void> _closePeriod() async {
    setState(() => _busy = true);
    try {
      await AdminTaxService.closeVatPeriodViaCf(widget.periodId);
      unawaited(
        AdminActivityLog.logFinancial(
          action: 'close_vat_period',
          targetType: 'tax_vat_period',
          targetId: widget.periodId,
          labelTh: 'ปิดงวด VAT ${widget.periodId}',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ปิดงวด VAT แล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปิดงวดไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addManualEntry() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    var entryType = TaxLedgerEntryType.adjustment;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('รายการปรับปรุง / มือ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<TaxLedgerEntryType>(
                  value: entryType,
                  decoration: const InputDecoration(
                    labelText: 'ประเภท',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<TaxLedgerEntryType>>[
                    DropdownMenuItem(
                      value: TaxLedgerEntryType.adjustment,
                      child: Text('ปรับปรุง'),
                    ),
                    DropdownMenuItem(
                      value: TaxLedgerEntryType.platformRevenue,
                      child: Text('รายได้อื่น'),
                    ),
                    DropdownMenuItem(
                      value: TaxLedgerEntryType.inputVat,
                      child: Text('ภาษีซื้อ'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocal(() => entryType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน (บาท)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );

    final title = titleController.text.trim();
    final amount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0;
    titleController.dispose();
    amountController.dispose();

    if (saved != true || title.isEmpty || amount <= 0) {
      return;
    }

    try {
      final config = await AdminTaxService.fetchTaxConfig();
      await AdminTaxService.createManualEntry(
        periodId: widget.periodId,
        entryType: entryType,
        revenueCategory: entryType == TaxLedgerEntryType.platformRevenue
            ? TaxLedgerRevenueCategory.other
            : null,
        title: title,
        amountGross: amount,
        taxConfig: config,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกรายการแล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('งวด VAT ${widget.periodId}')),
      body: StreamBuilder<List<TaxLedgerEntry>>(
        stream: AdminTaxService.streamLedgerForPeriod(widget.periodId),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <TaxLedgerEntry>[];
          final active = entries
              .where((entry) => entry.status == TaxLedgerStatus.active)
              .toList(growable: false);
          final summary = AdminTaxService.summarizePeriod(active);

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('ภาษีขาย: ${formatBaht(summary.outputVatTotal)}'),
                        Text('ภาษีซื้อ: ${formatBaht(summary.inputVatTotal)}'),
                        Text(
                          'ภ.VAT สุทธิ: ${formatBaht(summary.netVatPayable)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'รายการ: ขาย ${summary.outputLineCount} · ซื้อ ${summary.inputLineCount}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: active.length,
                        itemBuilder: (context, index) {
                          final entry = active[index];
                          return ListTile(
                            title: Text(
                              entry.title ??
                                  entry.orderId ??
                                  entryTypeLabelTh(entry.entryType),
                            ),
                            subtitle: Text(
                              '${entry.revenueCategory != null ? revenueCategoryLabelTh(entry.revenueCategory!) : entryTypeLabelTh(entry.entryType)} · ex-VAT ${formatBaht(entry.amountExVat)} · VAT ${formatBaht(entry.vatAmount)}',
                            ),
                            trailing: entry.source == TaxLedgerSource.orderDelivered ||
                                    entry.source == TaxLedgerSource.withdrawConfirmed
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.block_outlined),
                                    onPressed: () async {
                                      try {
                                        await AdminTaxService.voidLedgerEntryViaCf(
                                          entryId: entry.id,
                                          reason: 'void from van4',
                                        );
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('$error')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _busy ? null : _addManualEntry,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('รายการมือ'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => AdminTaxService.exportVatCsvBundle(widget.periodId),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Export CSV'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _closePeriod,
                icon: const Icon(Icons.lock_outline),
                label: const Text('ปิดงวด'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
