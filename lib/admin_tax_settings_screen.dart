import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/admin_tax_config.dart';
import 'services/admin_tax_service.dart';

class AdminTaxSettingsScreen extends StatefulWidget {
  const AdminTaxSettingsScreen({super.key});

  @override
  State<AdminTaxSettingsScreen> createState() => _AdminTaxSettingsScreenState();
}

class _AdminTaxSettingsScreenState extends State<AdminTaxSettingsScreen> {
  final _legalNameController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _branchCodeController = TextEditingController(text: '00000');
  final _vatRateController = TextEditingController(text: '7');
  var _vatRegistered = false;
  var _pricesIncludeVat = true;
  var _fiscalStartMonth = 1;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await AdminTaxService.fetchTaxConfig();
      if (!mounted) {
        return;
      }
      _legalNameController.text = config.legalName;
      _taxIdController.text = config.taxId;
      _branchCodeController.text = config.branchCode;
      _vatRateController.text = (config.defaultVatRate * 100).toStringAsFixed(0);
      setState(() {
        _vatRegistered = config.vatRegistered;
        _pricesIncludeVat = config.pricesIncludeVat;
        _fiscalStartMonth = config.fiscalYearStartMonth;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดไม่สำเร็จ: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final vatPercent = double.tryParse(_vatRateController.text.trim()) ?? 7;
      final config = AdminTaxConfig(
        legalName: _legalNameController.text,
        taxId: _taxIdController.text,
        branchCode: _branchCodeController.text,
        vatRegistered: _vatRegistered,
        defaultVatRate: (vatPercent / 100).clamp(0, 1),
        pricesIncludeVat: _pricesIncludeVat,
        fiscalYearStartMonth: _fiscalStartMonth,
      );
      await AdminTaxService.saveTaxConfig(config);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกตั้งค่าภาษีแล้ว')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _taxIdController.dispose();
    _branchCodeController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าภาษี')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                TextField(
                  controller: _legalNameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อนิติบุคคล',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _taxIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'เลขผู้เสียภาษี (13 หลัก)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _branchCodeController,
                  decoration: const InputDecoration(
                    labelText: 'รหัสสาขา',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('จดทะเบียน VAT'),
                  value: _vatRegistered,
                  onChanged: (value) => setState(() => _vatRegistered = value),
                ),
                TextField(
                  controller: _vatRateController,
                  enabled: _vatRegistered,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'อัตรา VAT (%)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('รายได้แพลตฟอร์มรวม VAT'),
                  subtitle: const Text('ปิด = ราคาแยก VAT (B2B)'),
                  value: _pricesIncludeVat,
                  onChanged: _vatRegistered
                      ? (value) => setState(() => _pricesIncludeVat = value)
                      : null,
                ),
                DropdownButtonFormField<int>(
                  value: _fiscalStartMonth,
                  decoration: const InputDecoration(
                    labelText: 'เดือนเริ่มปีบัญชี',
                    border: OutlineInputBorder(),
                  ),
                  items: List<DropdownMenuItem<int>>.generate(
                    12,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('เดือน ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _fiscalStartMonth = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
    );
  }
}
