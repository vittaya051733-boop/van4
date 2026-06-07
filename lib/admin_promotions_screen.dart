import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรโมชั่นและคูปอง'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(text: 'โปรอัตโนมัติ'),
            Tab(text: 'คูปอง'),
            Tab(text: 'รูปแบบ UI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[
          _OfferListTab(collection: 'promotions', isCoupon: false),
          _OfferListTab(collection: 'coupons', isCoupon: true),
          _PromotionDisplayConfigTab(),
        ],
      ),
    );
  }
}

class _OfferListTab extends StatelessWidget {
  const _OfferListTab({required this.collection, required this.isCoupon});

  final String collection;
  final bool isCoupon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('โหลดไม่สำเร็จ: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(isCoupon ? 'เพิ่มคูปอง' : 'เพิ่มโปร'),
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Text(
                'ยังไม่มีรายการ — กดปุ่มด้านบนเพื่อสร้าง',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            for (final doc in docs)
              _OfferCard(
                doc: doc,
                isCoupon: isCoupon,
                onEdit: () => _openEditor(context, doc: doc),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _OfferEditorScreen(
          collection: collection,
          isCoupon: isCoupon,
          doc: doc,
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.doc,
    required this.isCoupon,
    required this.onEdit,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isCoupon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final active = data['active'] == true;
    final name = (data['name'] ?? doc.id).toString();
    final code = isCoupon ? (data['code'] ?? '').toString() : '';
    final discount = data['discount'] is Map
        ? Map<String, dynamic>.from(data['discount'] as Map)
        : const <String, dynamic>{};
    final discountLabel = _discountSummary(discount);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            if (code.isNotEmpty) 'โค้ด: $code',
            discountLabel,
            active ? 'เปิดใช้งาน' : 'ปิดอยู่',
          ].join(' • '),
        ),
        trailing: IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
        ),
      ),
    );
  }

  String _discountSummary(Map<String, dynamic> discount) {
    final type = (discount['type'] ?? 'fixed').toString();
    final value = discount['value'];
    if (type == 'percent') {
      return 'ลด $value%';
    }
    if (type == 'free_shipping') {
      return 'ฟรีค่าส่ง';
    }
    return 'ลด ฿$value';
  }
}

class _OfferEditorScreen extends StatefulWidget {
  const _OfferEditorScreen({
    required this.collection,
    required this.isCoupon,
    this.doc,
  });

  final String collection;
  final bool isCoupon;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<_OfferEditorScreen> createState() => _OfferEditorScreenState();
}

class _OfferEditorScreenState extends State<_OfferEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _shortLabelController;
  late final TextEditingController _homeBannerController;
  late final TextEditingController _badgeController;
  late final TextEditingController _discountValueController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _minSubtotalController;
  late final TextEditingController _priorityController;
  late final TextEditingController _maxTotalController;
  late final TextEditingController _maxPerUserController;
  late final TextEditingController _productIdsController;
  late final TextEditingController _shopIdsController;

  bool _active = true;
  bool _stackable = true;
  String _discountType = 'percent';
  String _applyTo = 'subtotal';
  String _geoType = 'none';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data() ?? const <String, dynamic>{};
    final display = data['display'] is Map
        ? Map<String, dynamic>.from(data['display'] as Map)
        : const <String, dynamic>{};
    final conditions = data['conditions'] is Map
        ? Map<String, dynamic>.from(data['conditions'] as Map)
        : const <String, dynamic>{};
    final discount = data['discount'] is Map
        ? Map<String, dynamic>.from(data['discount'] as Map)
        : const <String, dynamic>{};
    final geo = conditions['geo'] is Map
        ? Map<String, dynamic>.from(conditions['geo'] as Map)
        : const <String, dynamic>{};

    _nameController = TextEditingController(text: (data['name'] ?? '').toString());
    _codeController = TextEditingController(text: (data['code'] ?? '').toString());
    _shortLabelController =
        TextEditingController(text: (display['shortLabel'] ?? '').toString());
    _homeBannerController =
        TextEditingController(text: (display['homeBannerText'] ?? '').toString());
    _badgeController =
        TextEditingController(text: (display['badgeText'] ?? '').toString());
    _discountValueController =
        TextEditingController(text: '${discount['value'] ?? ''}');
    _maxDiscountController =
        TextEditingController(text: '${discount['maxDiscount'] ?? ''}');
    _minSubtotalController =
        TextEditingController(text: '${conditions['minSubtotal'] ?? ''}');
    _priorityController =
        TextEditingController(text: '${data['priority'] ?? 0}');
    _maxTotalController =
        TextEditingController(text: '${conditions['maxRedemptionsTotal'] ?? ''}');
    _maxPerUserController =
        TextEditingController(text: '${conditions['maxRedemptionsPerUser'] ?? ''}');
    _productIdsController = TextEditingController(
      text: _joinList(conditions['productIds']),
    );
    _shopIdsController = TextEditingController(
      text: _joinList(conditions['shopIds']),
    );

    _active = data['active'] != false;
    _stackable = widget.isCoupon
        ? data['stackableWithPromotion'] != false
        : data['stackableWithCoupon'] != false;
    _discountType = (discount['type'] ?? 'percent').toString();
    _applyTo = (discount['applyTo'] ?? 'subtotal').toString();
    _geoType = (geo['type'] ?? 'none').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _shortLabelController.dispose();
    _homeBannerController.dispose();
    _badgeController.dispose();
    _discountValueController.dispose();
    _maxDiscountController.dispose();
    _minSubtotalController.dispose();
    _priorityController.dispose();
    _maxTotalController.dispose();
    _maxPerUserController.dispose();
    _productIdsController.dispose();
    _shopIdsController.dispose();
    super.dispose();
  }

  String _joinList(dynamic raw) {
    if (raw is! List) {
      return '';
    }
    return raw.map((value) => value.toString().trim()).where((v) => v.isNotEmpty).join(', ');
  }

  List<String> _splitIds(String raw) {
    return raw
        .split(RegExp(r'[,\s]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final discountValue = double.parse(_discountValueController.text.trim());
      final maxDiscount = _maxDiscountController.text.trim().isEmpty
          ? null
          : double.parse(_maxDiscountController.text.trim());
      final minSubtotal = _minSubtotalController.text.trim().isEmpty
          ? null
          : double.parse(_minSubtotalController.text.trim());

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'active': _active,
        'priority': int.tryParse(_priorityController.text.trim()) ?? 0,
        'discount': <String, dynamic>{
          'type': _discountType,
          'value': discountValue,
          'applyTo': _applyTo,
          if (maxDiscount != null) 'maxDiscount': maxDiscount,
        },
        'display': <String, dynamic>{
          'shortLabel': _shortLabelController.text.trim(),
          'homeBannerText': _homeBannerController.text.trim(),
          'badgeText': _badgeController.text.trim(),
        },
        'conditions': <String, dynamic>{
          if (minSubtotal != null) 'minSubtotal': minSubtotal,
          if (_maxTotalController.text.trim().isNotEmpty)
            'maxRedemptionsTotal':
                int.parse(_maxTotalController.text.trim()),
          if (_maxPerUserController.text.trim().isNotEmpty)
            'maxRedemptionsPerUser':
                int.parse(_maxPerUserController.text.trim()),
          'productIds': _splitIds(_productIdsController.text),
          'shopIds': _splitIds(_shopIdsController.text),
          'geo': <String, dynamic>{'type': _geoType},
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.isCoupon) {
        payload['code'] = _codeController.text.trim().toUpperCase();
        payload['stackableWithPromotion'] = _stackable;
      } else {
        payload['stackableWithCoupon'] = _stackable;
      }

      final collection = FirebaseFirestore.instance.collection(widget.collection);
      if (widget.doc == null) {
        payload['redemptionCount'] = 0;
        payload['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(payload);
      } else {
        await collection.doc(widget.doc!.id).set(payload, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showSnack('บันทึกไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc == null ? 'สร้างรายการ' : 'แก้ไขรายการ'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('บันทึก'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            SwitchListTile(
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('เปิดใช้งาน'),
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ชื่อโปร/คูปอง'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
            ),
            if (widget.isCoupon)
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'รหัสคูปอง'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'กรุณากรอกโค้ด' : null,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _discountType,
              decoration: const InputDecoration(labelText: 'ประเภทส่วนลด'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'percent', child: Text('เปอร์เซ็นต์')),
                DropdownMenuItem(value: 'fixed', child: Text('จำนวนเงิน (บาท)')),
                DropdownMenuItem(value: 'free_shipping', child: Text('ฟรีค่าส่ง')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _discountType = value);
                }
              },
            ),
            TextFormField(
              controller: _discountValueController,
              decoration: InputDecoration(
                labelText: _discountType == 'percent'
                    ? 'เปอร์เซ็นต์ลด'
                    : 'จำนวนเงินลด (บาท)',
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || double.tryParse(value.trim()) == null
                      ? 'กรุณากรอกตัวเลข'
                      : null,
            ),
            DropdownButtonFormField<String>(
              value: _applyTo,
              decoration: const InputDecoration(labelText: 'คิดส่วนลดจาก'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'subtotal', child: Text('ราคาสินค้า')),
                DropdownMenuItem(value: 'shipping', child: Text('ค่าส่ง')),
                DropdownMenuItem(value: 'grand_total', child: Text('ยอดรวมทั้งหมด')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _applyTo = value);
                }
              },
            ),
            TextFormField(
              controller: _maxDiscountController,
              decoration: const InputDecoration(
                labelText: 'เพดานส่วนลด (บาท) — สำหรับ %',
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _minSubtotalController,
              decoration: const InputDecoration(labelText: 'ยอดขั้นต่ำ (บาท)'),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              value: _stackable,
              onChanged: (value) => setState(() => _stackable = value),
              title: Text(
                widget.isCoupon
                    ? 'ใช้พร้อมโปรอัตโนมัติได้'
                    : 'ใช้พร้อมคูปองได้',
              ),
            ),
            if (!widget.isCoupon)
              TextFormField(
                controller: _priorityController,
                decoration: const InputDecoration(labelText: 'ลำดับความสำคัญ'),
                keyboardType: TextInputType.number,
              ),
            const Divider(height: 24),
            const Text('การแสดงผลบน van2', style: TextStyle(fontWeight: FontWeight.w800)),
            TextFormField(
              controller: _shortLabelController,
              decoration: const InputDecoration(labelText: 'ข้อความสั้นในตะกร้า'),
            ),
            TextFormField(
              controller: _homeBannerController,
              decoration: const InputDecoration(labelText: 'ข้อความแบนเนอร์หน้าแรก'),
            ),
            TextFormField(
              controller: _badgeController,
              decoration: const InputDecoration(labelText: 'ป้ายบนการ์ดสินค้า'),
            ),
            const Divider(height: 24),
            const Text('เงื่อนไขเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.w800)),
            TextFormField(
              controller: _productIdsController,
              decoration: const InputDecoration(
                labelText: 'รหัสสินค้า (คั่นด้วย comma)',
              ),
            ),
            TextFormField(
              controller: _shopIdsController,
              decoration: const InputDecoration(
                labelText: 'รหัสร้าน (คั่นด้วย comma)',
              ),
            ),
            DropdownButtonFormField<String>(
              value: _geoType,
              decoration: const InputDecoration(labelText: 'พื้นที่'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'none', child: Text('ทุกพื้นที่')),
                DropdownMenuItem(value: 'market_hub', child: Text('รัศมีตลาดเว้น')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _geoType = value);
                }
              },
            ),
            TextFormField(
              controller: _maxTotalController,
              decoration: const InputDecoration(labelText: 'โควต้ารวมทั้งระบบ'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _maxPerUserController,
              decoration: const InputDecoration(labelText: 'โควต้าต่อลูกค้า'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionDisplayConfigTab extends StatefulWidget {
  const _PromotionDisplayConfigTab();

  @override
  State<_PromotionDisplayConfigTab> createState() =>
      _PromotionDisplayConfigTabState();
}

class _PromotionDisplayConfigTabState extends State<_PromotionDisplayConfigTab> {
  static const String _collection = 'promotion_display_config';
  static const String _documentId = 'global';

  String _cartStyle = 'expanded';
  bool _showAutoPromotionsInCart = true;
  bool _showCouponField = true;
  bool _homePromoBanner = true;
  bool _productBadge = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_documentId)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      _cartStyle = (data['cartStyle'] ?? 'expanded').toString();
      _showAutoPromotionsInCart = data['showAutoPromotionsInCart'] != false;
      _showCouponField = data['showCouponField'] != false;
      _homePromoBanner = data['homePromoBanner'] != false;
      _productBadge = data['productBadge'] != false;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection(_collection).doc(_documentId).set(
        <String, dynamic>{
          'cartStyle': _cartStyle,
          'showAutoPromotionsInCart': _showAutoPromotionsInCart,
          'showCouponField': _showCouponField,
          'homePromoBanner': _homePromoBanner,
          'productBadge': _productBadge,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _showSnack('บันทึกรูปแบบ UI แล้ว — van2 อัปเดตทันที');
    } catch (error) {
      _showSnack('บันทึกไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        const Text(
          'เลือกรูปแบบการแสดงโปร/คูปองบนแอปลูกค้า van2',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _cartStyle,
          decoration: const InputDecoration(labelText: 'สไตล์ตะกร้า'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(
              value: 'expanded',
              child: Text('expanded — โปร + คูปอง + breakdown'),
            ),
            DropdownMenuItem(
              value: 'compact',
              child: Text('compact — คูปอง + ส่วนลดรวม'),
            ),
            DropdownMenuItem(
              value: 'banner_only',
              child: Text('banner_only — คูปองอย่างเดียว'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _cartStyle = value);
            }
          },
        ),
        SwitchListTile(
          value: _showAutoPromotionsInCart,
          onChanged: (value) => setState(() => _showAutoPromotionsInCart = value),
          title: const Text('แสดงโปรอัตโนมัติในตะกร้า'),
        ),
        SwitchListTile(
          value: _showCouponField,
          onChanged: (value) => setState(() => _showCouponField = value),
          title: const Text('แสดงช่องกรอกคูปอง'),
        ),
        SwitchListTile(
          value: _homePromoBanner,
          onChanged: (value) => setState(() => _homePromoBanner = value),
          title: const Text('แบนเนอร์โปรหน้าแรก'),
        ),
        SwitchListTile(
          value: _productBadge,
          onChanged: (value) => setState(() => _productBadge = value),
          title: const Text('ป้ายลดบนการ์ดสินค้า'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('บันทึกรูปแบบ UI'),
        ),
      ],
    );
  }
}
