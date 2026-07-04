import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/admin_project_finance_service.dart';

class AdminProjectFinanceScreen extends StatefulWidget {
  const AdminProjectFinanceScreen({super.key});

  @override
  State<AdminProjectFinanceScreen> createState() =>
      _AdminProjectFinanceScreenState();
}

class _AdminProjectFinanceScreenState extends State<AdminProjectFinanceScreen> {
  AdminProjectFinanceSnapshot? _snapshot;
  bool _loadingSnapshot = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _refreshSnapshot();
  }

  Future<void> _refreshSnapshot() async {
    setState(() {
      _loadingSnapshot = true;
      _errorText = null;
    });

    try {
      final snapshot = await AdminProjectFinanceService.buildSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loadingSnapshot = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _loadingSnapshot = false;
      });
    }
  }

  Future<void> _openInvestmentDialog() async {
    final current = _snapshot?.config ?? const AdminProjectFinanceConfig();
    final investmentController = TextEditingController(
      text: current.initialInvestmentBaht > 0
          ? formatBaht(current.initialInvestmentBaht, fractionDigits: 0)
          : '',
    );
    final uploadValueController = TextEditingController(
      text: current.productUploadRevenuePerItem > 0
          ? formatBaht(current.productUploadRevenuePerItem, fractionDigits: 0)
          : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ตั้งค่าเงินลงทุน'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: investmentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'เงินลงทุนก้อนแรก (บาท)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uploadValueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'มูลค่าต่อสินค้าที่อัปโหลด (บาท/ชิ้น)',
                    helperText: 'ใส่ 0 ถ้าไม่นับรายได้จากการอัปโหลดสินค้า',
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
        );
      },
    );

    if (saved != true || !mounted) {
      investmentController.dispose();
      uploadValueController.dispose();
      return;
    }

    final initialInvestment = _parseMoneyInput(investmentController.text);
    final uploadRevenuePerItem = _parseMoneyInput(uploadValueController.text);
    investmentController.dispose();
    uploadValueController.dispose();

    try {
      await AdminProjectFinanceService.saveConfig(
        AdminProjectFinanceConfig(
          initialInvestmentBaht: initialInvestment,
          productUploadRevenuePerItem: uploadRevenuePerItem,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกการตั้งค่าเงินลงทุนแล้ว')),
      );
      await _refreshSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
      );
    }
  }

  Future<void> _openAddExpenseDialog() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final categoryController = TextEditingController();
    String? receiptPath;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('เพิ่มรายจ่าย / ใบเสร็จ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'รายการ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'จำนวนเงิน (บาท)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'หมวด (ไม่บังคับ)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'หมายเหตุ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (sheetContext) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(
                                  leading: const Icon(Icons.photo_camera_outlined),
                                  title: const Text('ถ่ายใบเสร็จ'),
                                  onTap: () => Navigator.pop(
                                    sheetContext,
                                    ImageSource.camera,
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library_outlined),
                                  title: const Text('เลือกจากคลัง'),
                                  onTap: () => Navigator.pop(
                                    sheetContext,
                                    ImageSource.gallery,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (source == null) {
                          return;
                        }
                        final picked = await ImagePicker().pickImage(
                          source: source,
                          imageQuality: 80,
                        );
                        if (picked == null) {
                          return;
                        }
                        setLocalState(() => receiptPath = picked.path);
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(
                        receiptPath == null
                            ? 'แนบใบเสร็จ/หลักฐาน'
                            : 'เปลี่ยนไฟล์ใบเสร็จ',
                      ),
                    ),
                    if (receiptPath != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        receiptPath!.split(RegExp(r'[\\/]')).last,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
            );
          },
        );
      },
    );

    final title = titleController.text.trim();
    final amount = _parseMoneyInput(amountController.text);
    final note = noteController.text.trim();
    final category = categoryController.text.trim();
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    categoryController.dispose();

    if (saved != true || !mounted) {
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อรายการ')),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเงินมากกว่า 0')),
      );
      return;
    }

    try {
      await AdminProjectFinanceService.addExpense(
        title: title,
        amountBaht: amount,
        note: note.isEmpty ? null : note,
        category: category.isEmpty ? null : category,
        localReceiptPath: receiptPath,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกรายจ่ายแล้ว')),
      );
      await _refreshSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
      );
    }
  }

  Future<void> _confirmDeleteExpense(AdminProjectExpenseRecord expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบรายจ่าย'),
        content: Text('ลบ "${expense.title}" (${formatBaht(expense.amountBaht)} บาท)?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await AdminProjectFinanceService.deleteExpense(expense.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบรายจ่ายแล้ว')),
      );
      await _refreshSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบไม่สำเร็จ: $error')),
      );
    }
  }

  double _parseMoneyInput(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return double.tryParse(normalized) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('บัญชีโปรเจกต์ / ROI'),
        actions: <Widget>[
          IconButton(
            onPressed: _loadingSnapshot ? null : _refreshSnapshot,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'คำนวณใหม่',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseDialog,
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('เพิ่มรายจ่าย'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSnapshot,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            if (_loadingSnapshot && snapshot == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorText != null)
              _ErrorCard(message: _errorText!, onRetry: _refreshSnapshot)
            else if (snapshot != null) ...<Widget>[
              _SummaryCard(snapshot: snapshot),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openInvestmentDialog,
                icon: const Icon(Icons.savings_outlined),
                label: const Text('ตั้งค่าเงินลงทุนก้อนแรก'),
              ),
              const SizedBox(height: 20),
              Text(
                'รายจ่าย / ใบเสร็จ',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9A3412),
                    ),
              ),
              const SizedBox(height: 12),
              if (snapshot.expenses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'ยังไม่มีรายจ่าย — กดปุ่ม "เพิ่มรายจ่าย" เพื่ออัปโหลดใบเสร็จ',
                  ),
                )
              else
                ...snapshot.expenses.map(
                  (expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExpenseCard(
                      expense: expense,
                      onDelete: () => _confirmDeleteExpense(expense),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final AdminProjectFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final roiText = snapshot.roiPercent == null
        ? 'ตั้งเงินลงทุนก่อน'
        : '${snapshot.roiPercent!.toStringAsFixed(2)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ROI โปรเจกต Van Market',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A3412),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            roiText,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE65100),
                ),
          ),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'เงินลงทุนก้อนแรก',
            value: '${formatBaht(snapshot.config.initialInvestmentBaht)} บาท',
          ),
          _MetricRow(
            label: 'รายรับอัตโนมัติ (ขาย)',
            value: '${formatBaht(snapshot.salesPlatformRevenueBaht)} บาท',
            hint: 'GP + ค่าส่งแพลตฟอร์ม จากออเดอร์สำเร็จ ${snapshot.deliveredOrderCount} รายการ',
          ),
          _MetricRow(
            label: 'รายรับอัตโนมัติ (อัปโหลดสินค้า)',
            value: '${formatBaht(snapshot.productUploadRevenueBaht)} บาท',
            hint: 'สินค้าในระบบ ${snapshot.productUploadCount} ชิ้น × ${formatBaht(snapshot.config.productUploadRevenuePerItem, fractionDigits: 0)} บาท/ชิ้น',
          ),
          _MetricRow(
            label: 'รายจ่ายรวม',
            value: '${formatBaht(snapshot.totalExpensesBaht)} บาท',
          ),
          const Divider(height: 24),
          _MetricRow(
            label: 'กำไรสุทธิ (รายรับ − รายจ่าย)',
            value: '${formatBaht(snapshot.netProfitBaht)} บาท',
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.hint,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                  color: emphasize ? const Color(0xFF166534) : const Color(0xFF111827),
                ),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onDelete,
  });

  final AdminProjectExpenseRecord expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: expense.receiptImageUrl == null
            ? const CircleAvatar(
                child: Icon(Icons.receipt_outlined),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  expense.receiptImageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                ),
              ),
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${formatBaht(expense.amountBaht)} บาท'),
            if ((expense.category ?? '').isNotEmpty)
              Text('หมวด: ${expense.category}'),
            if ((expense.note ?? '').isNotEmpty) Text(expense.note!),
          ],
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'โหลดข้อมูลไม่สำเร็จ',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
