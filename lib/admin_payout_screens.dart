import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_order_support.dart';
import 'admin_settlement_support.dart';

class AdminLeaderProfileScreen extends StatefulWidget {
  const AdminLeaderProfileScreen({super.key});

  @override
  State<AdminLeaderProfileScreen> createState() =>
      _AdminLeaderProfileScreenState();
}

class _AdminLeaderProfileScreenState extends State<AdminLeaderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await AdminSettlementSupport.fetchLeaderProfile();
      _nameController.text = profile.displayName;
      _bankController.text = profile.bankName;
      _accountNumberController.text = profile.accountNumber;
      _accountNameController.text = profile.accountName;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await AdminSettlementSupport.saveLeaderProfile(
        AdminLeaderProfile(
          displayName: _nameController.text.trim(),
          bankName: _bankController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          accountName: _accountNameController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกบัญชีไลด์เดอร์แล้ว')),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีไลด์เดอร์')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const Text(
                    'ใช้สำหรับแถว leader ในไฟล์ bulk_transfer เมื่อสรุปยอดรายวัน',
                    style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อผู้รับ (ไลด์เดอร์)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty == true ? 'กรุณากรอกชื่อ' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bankController,
                    decoration: const InputDecoration(
                      labelText: 'ธนาคาร',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty == true ? 'กรุณากรอกธนาคาร' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                      labelText: 'เลขบัญชี',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.trim().isEmpty == true ? 'กรุณากรอกเลขบัญชี' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountNameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อบัญชี',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty == true ? 'กรุณากรอกชื่อบัญชี' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                  ),
                ],
              ),
            ),
    );
  }
}

class AdminSettlementFeeConfigScreen extends StatefulWidget {
  const AdminSettlementFeeConfigScreen({super.key});

  @override
  State<AdminSettlementFeeConfigScreen> createState() =>
      _AdminSettlementFeeConfigScreenState();
}

class _AdminSettlementFeeConfigScreenState
    extends State<AdminSettlementFeeConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gpController = TextEditingController();
  final _riderController = TextEditingController();
  final _leaderController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gpController.dispose();
    _riderController.dispose();
    _leaderController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rates = await AdminSettlementSupport.fetchSettlementFeeRates();
      _gpController.text = _formatPercent(rates.gpRatePercent);
      _riderController.text = _formatPercent(rates.riderPlatformRatePercent);
      _leaderController.text = _formatPercent(rates.leaderRatePercent);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  double? _parsePercent(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value < 0 || value > 100) {
      return null;
    }
    return value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final gp = _parsePercent(_gpController.text)!;
      final rider = _parsePercent(_riderController.text)!;
      final leader = _parsePercent(_leaderController.text)!;
      await AdminSettlementSupport.saveSettlementFeeRates(
        AdminSettlementFeeRates(
          gpRate: gp / 100,
          riderPlatformRate: rider / 100,
          leaderRate: leader / 100,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกอัตราหักแล้ว')),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าอัตราหัก')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const Text(
                    'ใช้คำนวณยอดใน CSV สรุปรายวัน (ร้านค้า / ไรเดอร์ / ไลด์เดอร์)',
                    style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gpController,
                    decoration: const InputDecoration(
                      labelText: 'หัก GP จากสินค้า (%)',
                      helperText: 'ค่าเริ่มต้น 18% — หักจากยอดสินค้าก่อนส่งร้าน',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        _parsePercent(value) == null ? 'กรอก 0–100' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _riderController,
                    decoration: const InputDecoration(
                      labelText: 'หักจากค่าส่งไรเดอร์ (%)',
                      helperText: 'ค่าเริ่มต้น 15% — ไรเดอร์ได้ส่วนที่เหลือ',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        _parsePercent(value) == null ? 'กรอก 0–100' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _leaderController,
                    decoration: const InputDecoration(
                      labelText: 'หักส่วนแบ่งไลด์เดอร์จากร้าน (%)',
                      helperText:
                          'ค่าเริ่มต้น 15% — หักจากยอดหลัง GP ก่อนส่งร้าน',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        _parsePercent(value) == null ? 'กรอก 0–100' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                  ),
                ],
              ),
            ),
    );
  }
}

class AdminPayoutImportScreen extends StatefulWidget {
  const AdminPayoutImportScreen({super.key});

  @override
  State<AdminPayoutImportScreen> createState() =>
      _AdminPayoutImportScreenState();
}

class _AdminPayoutImportScreenState extends State<AdminPayoutImportScreen> {
  bool _importing = false;
  String? _preview;
  PayoutImportResult? _result;

  Future<void> _pickAndImport() async {
    setState(() {
      _importing = true;
      _result = null;
      _preview = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'txt'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      final file = picked.files.first;
      final raw = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      final rows = AdminSettlementSupport.parsePayoutResultCsv(raw);
      if (rows.isEmpty) {
        throw StateError('ไม่พบแถวที่มี transfer_status ในไฟล์');
      }
      final result = await AdminSettlementSupport.applyPayoutImport(rows);
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = raw.length > 1200 ? '${raw.substring(0, 1200)}...' : raw;
        _result = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'อัปเดต ${result.updated} รายการ • ข้าม ${result.skipped} • ผิดพลาด ${result.errors.length}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('นำเข้าไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('นำเข้า CSV ผลโอนเงิน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'หลังโอนผ่านธนาคารแล้ว ให้กรอก transfer_status (paid/failed) ในไฟล์ bulk_transfer แล้วอัปโหลดกลับ\n\nทุกแถวมี order_number (หมายเลขออเดอร์) + order_id — นำเข้าใช้ได้ทั้งสองแบบ',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _importing ? null : _pickAndImport,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(_importing ? 'กำลังนำเข้า...' : 'เลือกไฟล์ CSV'),
          ),
          if (_result != null) ...<Widget>[
            const SizedBox(height: 20),
            Text(
              'อัปเดต ${_result!.updated} • ข้าม ${_result!.skipped} • ผิดพลาด ${_result!.errors.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final error in _result!.errors.take(20))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
          ],
          if (_preview != null) ...<Widget>[
            const SizedBox(height: 20),
            const Text('ตัวอย่างไฟล์', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                _preview!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
