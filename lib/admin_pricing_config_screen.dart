import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminPricingConfigScreen extends StatefulWidget {
  const AdminPricingConfigScreen({super.key});

  @override
  State<AdminPricingConfigScreen> createState() =>
      _AdminPricingConfigScreenState();
}

class _AdminPricingConfigScreenState extends State<AdminPricingConfigScreen> {
  static const String _collection = 'pricing_config';
  static const String _documentId = 'global';

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  bool _loading = true;
  bool _saving = false;
  _PricingSaveStatus _saveStatus = _PricingSaveStatus.idle;
  String? _saveStatusMessage;
  DateTime? _lastSavedAt;

  static const List<_PricingFieldSpec> _fields = <_PricingFieldSpec>[
    _PricingFieldSpec(
      key: 'taxableMarkupRate',
      label: 'อัตราบวกเพิ่มสินค้าเสียภาษี (ทศนิยม)',
      hint: '0.07 = 7%',
      section: 'ราคาสินค้า',
    ),
    _PricingFieldSpec(
      key: 'nonTaxableMarkupRate',
      label: 'อัตราบวกเพิ่มสินค้าไม่เสียภาษี (ทศนิยม)',
      hint: '0.07 = 7%',
      section: 'ราคาสินค้า',
    ),
    _PricingFieldSpec(
      key: 'toppingMarkupRate',
      label: 'อัตราบวกเพิ่มท็อปปิ้ง (ทศนิยม)',
      hint: '0.07 = 7%',
      section: 'ราคาสินค้า',
    ),
    _PricingFieldSpec(
      key: 'shippingBaseFee',
      label: 'ค่าส่งฐาน (บาท)',
      hint: '25',
      section: 'ค่าส่งท้องถิ่น',
    ),
    _PricingFieldSpec(
      key: 'shippingPerKmFee',
      label: 'ค่าส่งต่อกม. หลังระยะขั้นต่ำ (บาท)',
      hint: '12.5',
      section: 'ค่าส่งท้องถิ่น',
    ),
    _PricingFieldSpec(
      key: 'shippingMinBillableKm',
      label: 'ระยะขั้นต่ำที่คิดค่าส่ง (กม.)',
      hint: '1',
      section: 'ค่าส่งท้องถิ่น',
    ),
    _PricingFieldSpec(
      key: 'shippingMissingCoordsFee',
      label: 'ค่าส่งเมื่อร้านไม่มีพิกัด (บาท)',
      hint: '25',
      section: 'ค่าส่งท้องถิ่น',
    ),
    _PricingFieldSpec(
      key: 'travelBaseFee',
      label: 'ค่าโดยสารฐาน (บาท)',
      hint: '25',
      section: 'บริการโดยสาร',
    ),
    _PricingFieldSpec(
      key: 'travelPerKmFee',
      label: 'ค่าโดยสารต่อกม. หลังระยะขั้นต่ำ (บาท)',
      hint: '12.5',
      section: 'บริการโดยสาร',
    ),
    _PricingFieldSpec(
      key: 'travelMinBillableKm',
      label: 'ระยะขั้นต่ำโดยสาร (กม.)',
      hint: '1',
      section: 'บริการโดยสาร',
    ),
    _PricingFieldSpec(
      key: 'nationwideBaseFee',
      label: 'ส่งทั่วประเทศ — ค่าฐาน (บาท)',
      hint: '45',
      section: 'ส่งทั่วประเทศ',
    ),
    _PricingFieldSpec(
      key: 'nationwidePerKgFee',
      label: 'ส่งทั่วประเทศ — ต่อกก. (บาท)',
      hint: '18',
      section: 'ส่งทั่วประเทศ',
    ),
    _PricingFieldSpec(
      key: 'nationwideRemoteSurcharge',
      label: 'ส่งทั่วประเทศ — ส่วนเพิ่มพื้นที่ห่างไกล (บาท)',
      hint: '30',
      section: 'ส่งทั่วประเทศ',
    ),
    _PricingFieldSpec(
      key: 'marketHubLatitude',
      label: 'พิกัดตลาด — ละติจูด',
      hint: '17.279915312140325',
      section: 'ค่าธรรมเนียมตลาด (หลายร้าน)',
      maxValue: 90,
    ),
    _PricingFieldSpec(
      key: 'marketHubLongitude',
      label: 'พิกัดตลาด — ลองจิจูด',
      hint: '102.87070264132565',
      section: 'ค่าธรรมเนียมตลาด (หลายร้าน)',
      maxValue: 180,
    ),
    _PricingFieldSpec(
      key: 'marketHubRadiusMeters',
      label: 'รัศมีรอบตลาด (เมตร)',
      hint: '150',
      section: 'ค่าธรรมเนียมตลาด (หลายร้าน)',
      maxValue: 10000,
    ),
    _PricingFieldSpec(
      key: 'marketMultiShopMinShops',
      label: 'จำนวนร้านขั้นต่ำในตลาดเพื่อคิดค่าธรรมเนียม',
      hint: '2',
      section: 'ค่าธรรมเนียมตลาด (หลายร้าน)',
      isInteger: true,
      maxValue: 20,
    ),
    _PricingFieldSpec(
      key: 'marketMultiShopCollectionFee',
      label: 'ค่ารวบรวมสินค้าหลายร้านให้ไรเดอร์ (บาท/ครั้ง)',
      hint: '5',
      section: 'ค่าธรรมเนียมตลาด (หลายร้าน)',
    ),
    _PricingFieldSpec(
      key: 'marketServiceFeePerOrder',
      label: 'ค่าบริการต่อออเดอร์ร้านในตลาด (บาท)',
      hint: '5',
      section: 'ค่าธรรมเนียมตลาด (หลายร้าน)',
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      _controllers[field.key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_documentId)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      for (final field in _fields) {
        final raw = data[field.key];
        _controllers[field.key]?.text = raw == null ? '' : '$raw';
      }
    } catch (error) {
      _showSnack('โหลดไม่สำเร็จ: $error', tone: _SnackTone.error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _setSaveStatus(
        _PricingSaveStatus.error,
        'กรุณากรอกตัวเลขให้ครบทุกช่องก่อนบันทึก',
      );
      _showSnack(
        'กรุณากรอกตัวเลขให้ครบทุกช่องก่อนบันทึก',
        tone: _SnackTone.error,
      );
      return;
    }

    setState(() {
      _saving = true;
      _saveStatus = _PricingSaveStatus.saving;
      _saveStatusMessage = 'กำลังบันทึกลง Firestore...';
    });

    try {
      final payload = <String, dynamic>{
        for (final field in _fields)
          field.key: field.isInteger
              ? int.parse(_controllers[field.key]!.text.trim())
              : double.parse(_controllers[field.key]!.text.trim()),
        'note': 'Admin-managed global pricing for van2 cart, shipping, and markup',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_documentId)
          .set(payload, SetOptions(merge: true));

      final savedAt = DateTime.now();
      if (!mounted) {
        return;
      }

      setState(() {
        _lastSavedAt = savedAt;
        _saveStatus = _PricingSaveStatus.success;
        _saveStatusMessage =
            'บันทึกลง pricing_config/global แล้ว — van2 อัปเดตแบบ real-time';
      });

      _showSnack(
        'บันทึกอัตราราคาเรียบร้อยแล้ว',
        tone: _SnackTone.success,
      );
      HapticFeedback.mediumImpact();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setSaveStatus(
        _PricingSaveStatus.error,
        'บันทึกไม่สำเร็จ: $error',
      );
      _showSnack('บันทึกไม่สำเร็จ: $error', tone: _SnackTone.error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _setSaveStatus(_PricingSaveStatus status, String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _saveStatus = status;
      _saveStatusMessage = message;
    });
  }

  void _showSnack(String message, {required _SnackTone tone}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        duration: tone == _SnackTone.success
            ? const Duration(seconds: 4)
            : const Duration(seconds: 5),
        backgroundColor: switch (tone) {
          _SnackTone.success => const Color(0xFF166534),
          _SnackTone.error => const Color(0xFFB91C1C),
          _SnackTone.info => const Color(0xFF1F2937),
        },
        content: Row(
          children: <Widget>[
            Icon(
              switch (tone) {
                _SnackTone.success => Icons.check_circle_rounded,
                _SnackTone.error => Icons.error_outline_rounded,
                _SnackTone.info => Icons.info_outline_rounded,
              },
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveStatusBanner() {
    if (_saveStatus == _PricingSaveStatus.idle && _lastSavedAt == null) {
      return const SizedBox.shrink();
    }

    final Color background;
    final Color foreground;
    final IconData icon;
    final String title;
    final String? subtitle;

    switch (_saveStatus) {
      case _PricingSaveStatus.saving:
        background = const Color(0xFFFFF7ED);
        foreground = const Color(0xFF9A3412);
        icon = Icons.cloud_upload_rounded;
        title = 'กำลังบันทึก...';
        subtitle = _saveStatusMessage;
      case _PricingSaveStatus.success:
        background = const Color(0xFFECFDF5);
        foreground = const Color(0xFF166534);
        icon = Icons.check_circle_rounded;
        title = 'บันทึกสำเร็จ';
        subtitle = _saveStatusMessage;
      case _PricingSaveStatus.error:
        background = const Color(0xFFFEF2F2);
        foreground = const Color(0xFFB91C1C);
        icon = Icons.error_outline_rounded;
        title = 'บันทึกไม่สำเร็จ';
        subtitle = _saveStatusMessage;
      case _PricingSaveStatus.idle:
        background = const Color(0xFFF3F4F6);
        foreground = const Color(0xFF374151);
        icon = Icons.history_rounded;
        title = 'บันทึกล่าสุดในเซสชันนี้';
        subtitle = _lastSavedAt == null
            ? null
            : _formatSavedAt(_lastSavedAt!);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey<String>('$_saveStatus|$_saveStatusMessage|$_lastSavedAt'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: foreground.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_saveStatus == _PricingSaveStatus.saving)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: foreground,
                  ),
                ),
              )
            else
              Icon(icon, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.92),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSavedAt(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute:$second';
  }

  Widget _buildSaveButton({required bool compact}) {
    if (compact) {
      return TextButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_rounded),
        label: Text(_saving ? 'บันทึก...' : 'บันทึก'),
      );
    }

    return FilledButton.icon(
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_rounded),
      label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกลง Firestore'),
    );
  }

  String? _validateInteger(String? value, {required int max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'กรุณากรอกตัวเลข';
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > max) {
      return 'ค่าไม่ถูกต้อง (0 - $max)';
    }
    return null;
  }

  String? _validateNumber(String? value, {required double max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'กรุณากรอกตัวเลข';
    }
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > max) {
      return 'ค่าไม่ถูกต้อง (0 - $max)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าราคาและค่าส่ง'),
        actions: <Widget>[
          if (!_loading) _buildSaveButton(compact: true),
          IconButton(
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'โหลดใหม่',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _saving,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: <Widget>[
                    _buildSaveStatusBanner(),
                    const SizedBox(height: 12),
                    const Text(
                      'ค่าเหล่านี้ใช้ร่วมกับ van2 (ลูกค้า) และ Cloud Functions คำนวณตะกร้า\nแอปลูกค้าจะฟังค่าจาก Firestore แบบ real-time',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  for (final section in _groupedSections()) ...<Widget>[
                    Text(
                      section,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final field in _fields.where((f) => f.section == section))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _controllers[field.key],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.hint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) => field.isInteger
                              ? _validateInteger(value, max: field.maxValue.toInt())
                              : _validateNumber(
                                  value,
                                  max: field.key.contains('Markup')
                                      ? 5
                                      : field.maxValue,
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _buildSaveButton(compact: false),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: null,
    );
  }

  List<String> _groupedSections() {
    return _fields.map((field) => field.section).toSet().toList(growable: false);
  }
}

enum _PricingSaveStatus { idle, saving, success, error }

enum _SnackTone { success, error, info }

class _PricingFieldSpec {
  const _PricingFieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    required this.section,
    this.isInteger = false,
    this.maxValue = 100000,
  });

  final String key;
  final String label;
  final String hint;
  final String section;
  final bool isInteger;
  final double maxValue;
}
