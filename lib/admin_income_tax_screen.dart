import 'package:flutter/material.dart';

import 'models/tax_income_period.dart';
import 'services/admin_project_finance_service.dart';
import 'services/admin_tax_service.dart';

class AdminIncomeTaxScreen extends StatelessWidget {
  const AdminIncomeTaxScreen({super.key});

  List<String> _recentQuarterIds() {
    final now = DateTime.now();
    return List<String>.generate(6, (index) {
      final date = DateTime(now.year, now.month - index * 3, 1);
      return incomePeriodIdFromDate(date);
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final quarters = _recentQuarterIds().toSet().toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('ภาษีเงินได้ (รายไตรมาส)')),
      body: StreamBuilder<List<TaxIncomePeriod>>(
        stream: AdminTaxService.streamIncomePeriods(),
        builder: (context, snapshot) {
          final saved = {
            for (final period in snapshot.data ?? const <TaxIncomePeriod>[])
              period.id: period,
          };

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: quarters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final periodId = quarters[index];
              final existing = saved[periodId];
              return Card(
                child: ListTile(
                  title: Text(periodId.toUpperCase()),
                  subtitle: Text(
                    existing == null
                        ? 'ยังไม่สรุป — กดเพื่อคำนวณจากงวด VAT'
                        : 'รายได้ ex-VAT ${formatBaht(existing.revenueExVat)} · กำไรประมาณ ${formatBaht(existing.estimatedTaxableProfit)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminIncomePeriodDetailScreen(periodId: periodId),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminIncomePeriodDetailScreen extends StatefulWidget {
  const AdminIncomePeriodDetailScreen({super.key, required this.periodId});

  final String periodId;

  @override
  State<AdminIncomePeriodDetailScreen> createState() =>
      _AdminIncomePeriodDetailScreenState();
}

class _AdminIncomePeriodDetailScreenState
    extends State<AdminIncomePeriodDetailScreen> {
  TaxIncomePeriod? _period;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final period = await AdminTaxService.buildOrSaveIncomePeriod(widget.periodId);
      if (mounted) {
        setState(() {
          _period = period;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สรุปไม่สำเร็จ: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _period;
    return Scaffold(
      appBar: AppBar(title: Text('ไตรมาส ${widget.periodId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : period == null
              ? const Center(child: Text('ไม่มีข้อมูล'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('รายได้ ex-VAT: ${formatBaht(period.revenueExVat)}'),
                            Text(
                              'รายจ่ายหักได้: ${formatBaht(period.expenseDeductible)}',
                            ),
                            const Divider(),
                            Text(
                              'กำไรประมาณการ: ${formatBaht(period.estimatedTaxableProfit)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'งวด VAT: ${period.linkedVatPeriodIds.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          AdminTaxService.exportIncomePnlCsv(widget.periodId),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export P&L CSV'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('คำนวณใหม่'),
                    ),
                  ],
                ),
    );
  }
}
