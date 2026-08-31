import 'package:flutter/material.dart';

import 'admin_image_widgets.dart';
import 'admin_repository.dart';
import 'utils/admin_callable_errors.dart';

class AdminClaimScreen extends StatefulWidget {
  const AdminClaimScreen({
    super.key,
    required this.order,
    this.initialSelectedQty,
    this.initialReason,
    this.linkedTicketId,
  });

  final AdminOrderRecord order;
  final Map<String, int>? initialSelectedQty;
  final String? initialReason;
  final String? linkedTicketId;

  @override
  State<AdminClaimScreen> createState() => _AdminClaimScreenState();
}

class _AdminClaimScreenState extends State<AdminClaimScreen> {
  static const List<_ClaimReasonOption> _reasons = <_ClaimReasonOption>[
    _ClaimReasonOption(key: 'mismatch', label: 'ไม่ตรงปก'),
    _ClaimReasonOption(key: 'damaged', label: 'เสียหาย'),
    _ClaimReasonOption(key: 'wrong_item', label: 'ส่งผิดชิ้น'),
    _ClaimReasonOption(key: 'other', label: 'อื่น ๆ'),
  ];

  static const List<int> _shopPayoutPercentPresets = <int>[25, 50, 75, 100];

  final Map<String, int> _selectedQty = <String, int>{};
  final List<_ClaimExtraProduct> _extraProducts = <_ClaimExtraProduct>[];
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _shopPayoutController = TextEditingController();

  String _reason = 'mismatch';
  bool _platformPaysShop = false;
  double _shopPayoutPercent = 100;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.initialSelectedQty;
    if (preset != null && preset.isNotEmpty) {
      _selectedQty.addAll(preset);
    } else {
      for (final item in widget.order.items) {
        final id = item.productId?.trim() ?? '';
        if (id.isEmpty) {
          continue;
        }
        _selectedQty[id] = item.quantity;
      }
    }
    final initialReason = widget.initialReason?.trim();
    if (initialReason != null && initialReason.isNotEmpty) {
      _reason = initialReason;
    }
    _creditController.text = _defaultCreditAmount().toStringAsFixed(0);
    _applyShopPayoutPercent();
  }

  @override
  void dispose() {
    _creditController.dispose();
    _shopPayoutController.dispose();
    super.dispose();
  }

  void _syncAmountDefaults() {
    _creditController.text = _defaultCreditAmount().toStringAsFixed(0);
    if (_platformPaysShop) {
      _applyShopPayoutPercent();
    }
  }

  void _applyShopPayoutPercent([double? percent]) {
    if (percent != null) {
      _shopPayoutPercent = percent.clamp(0, 100);
    }
    final base = _shopPayoutBaseAmount();
    final amount = base * (_shopPayoutPercent / 100);
    _shopPayoutController.text = amount.toStringAsFixed(0);
  }

  void _onShopPayoutManualEdit(String value) {
    final amount = double.tryParse(value.trim()) ?? 0;
    final base = _shopPayoutBaseAmount();
    if (base > 0) {
      _shopPayoutPercent = ((amount / base) * 100).clamp(0, 100);
    }
  }

  double _shopPayoutBaseAmount() => _defaultShopPayoutAmount();

  double _defaultCreditAmount() {
    var total = 0.0;
    for (final item in widget.order.items) {
      final id = item.productId?.trim() ?? '';
      if (id.isEmpty || (_selectedQty[id] ?? 0) <= 0) {
        continue;
      }
      final qty = _selectedQty[id]!;
      final unit = item.unitPrice ??
          ((item.lineTotal ?? 0) / (item.quantity <= 0 ? 1 : item.quantity));
      total += unit * qty;
    }
    for (final extra in _extraProducts) {
      total += extra.price * extra.quantity;
    }
    if (total <= 0) {
      return widget.order.grandTotal ?? widget.order.subtotal ?? 0;
    }
    return total;
  }

  double _defaultShopPayoutAmount() {
    var total = 0.0;
    for (final item in widget.order.items) {
      final id = item.productId?.trim() ?? '';
      if (id.isEmpty || (_selectedQty[id] ?? 0) <= 0) {
        continue;
      }
      final qty = _selectedQty[id]!;
      final unit = item.merchantUnitPayout ??
          item.unitPrice ??
          ((item.lineTotal ?? 0) / (item.quantity <= 0 ? 1 : item.quantity));
      total += unit * qty;
    }
    for (final extra in _extraProducts) {
      total += extra.price * extra.quantity;
    }
    return total;
  }

  List<Map<String, dynamic>> _selectedItemsPayload() {
    final items = <Map<String, dynamic>>[];
    for (final entry in _selectedQty.entries) {
      if (entry.value <= 0) {
        continue;
      }
      items.add(<String, dynamic>{
        'productId': entry.key,
        'quantity': entry.value,
      });
    }
    for (final extra in _extraProducts) {
      items.add(<String, dynamic>{
        'productId': extra.id,
        'quantity': extra.quantity,
      });
    }
    return items;
  }

  Future<void> _submit(String kind) async {
    if (_submitting) {
      return;
    }
    final items = _selectedItemsPayload();
    if (kind == 'replacement' && items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกสินค้าที่จะส่งทดแทนอย่างน้อย 1 รายการ')),
      );
      return;
    }

    final creditAmount = double.tryParse(_creditController.text.trim());
    final shopPayoutAmount = _platformPaysShop
        ? double.tryParse(_shopPayoutController.text.trim())
        : null;
    if (kind == 'replacement' && _platformPaysShop && (shopPayoutAmount ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุเครดิตให้ร้านรอบ 2 มากกว่า 0')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await AdminRepository.adminResolveClaim(
        originalOrderId: widget.order.id,
        kind: kind,
        reason: _reason,
        items: items,
        platformPaysShop: _platformPaysShop,
        creditAmount: kind == 'credit' ? creditAmount : null,
        shopPayoutAmount: kind == 'replacement' ? shopPayoutAmount : null,
      );
      if (!mounted) {
        return;
      }
      final claimId = (result['claimId'] as String?)?.trim();
      final linkedTicketId = widget.linkedTicketId?.trim();
      if (linkedTicketId != null &&
          linkedTicketId.isNotEmpty &&
          claimId != null &&
          claimId.isNotEmpty) {
        final resolutionNote = kind == 'replacement'
            ? 'ดำเนินการเคลมแล้ว — ส่งสินค้าทดแทน (${result['orderCode'] ?? result['replacementOrderId'] ?? ''})'
            : 'ดำเนินการเคลมแล้ว — ให้คูปอง ${result['couponCode'] ?? ''}';
        await AdminRepositorySupport.markClaimTicketResolved(
          ticketId: linkedTicketId,
          claimId: claimId,
          resolutionNote: resolutionNote.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      final message = kind == 'replacement'
          ? 'สร้างออเดอร์ทดแทน ${result['orderCode'] ?? result['replacementOrderId'] ?? ''} แล้ว'
          : 'ให้คูปอง ${result['couponCode'] ?? ''} แล้ว';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.trim())));
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AdminCallableErrors.message(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _pickShopProduct() async {
    final shopOwnerId = widget.order.shopOwnerId?.trim() ?? '';
    if (shopOwnerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ออเดอร์นี้ไม่มีร้านสำหรับเลือกสินค้าเพิ่ม')),
      );
      return;
    }

    final selected = await showModalBottomSheet<AdminProductRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: StreamBuilder<List<AdminProductRecord>>(
            stream: AdminRepository.streamProductsForShop(shopOwnerId),
            builder: (context, snapshot) {
              final products = snapshot.data ?? const <AdminProductRecord>[];
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (products.isEmpty) {
                return const Center(child: Text('ร้านนี้ยังไม่มีสินค้า'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: AdminSafeAvatar(
                      imageUrl: product.imageUrls.isEmpty ? null : product.imageUrls.first,
                      size: 44,
                      borderRadius: 8,
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      product.price == null ? '-' : '฿${product.price!.toStringAsFixed(0)}',
                    ),
                    onTap: () => Navigator.of(context).pop(product),
                  );
                },
              );
            },
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }
    setState(() {
      final existingOriginal = _selectedQty.containsKey(selected.id);
      if (existingOriginal) {
        _selectedQty[selected.id] = (_selectedQty[selected.id] ?? 0) + 1;
        return;
      }
      final extraIndex = _extraProducts.indexWhere((item) => item.id == selected.id);
      if (extraIndex >= 0) {
        _extraProducts[extraIndex] = _extraProducts[extraIndex].copyWith(
          quantity: _extraProducts[extraIndex].quantity + 1,
        );
        return;
      }
      _extraProducts.add(
        _ClaimExtraProduct(
          id: selected.id,
          name: selected.name,
          price: selected.price ?? 0,
          imageUrl: selected.imageUrls.isEmpty ? null : selected.imageUrls.first,
          quantity: 1,
        ),
      );
    });
    _syncAmountDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final alreadyClaimed = widget.order.hasResolvedClaim;
    final isReplacementOrder = widget.order.isClaimReplacement;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('เคลมสินค้า'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (alreadyClaimed || isReplacementOrder)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isReplacementOrder
                    ? 'นี่คือออเดอร์ทดแทน — ไม่สามารถเคลมซ้ำ'
                    : widget.order.claimStatus == 'replaced'
                        ? 'ส่งทดแทนแล้ว (${widget.order.replacementOrderId ?? '-'})'
                        : 'ให้คูปองเครดิตแล้ว',
              ),
            ),
          Text(
            'เลือกสินค้า',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (widget.order.items.isEmpty)
            const Text('ออเดอร์นี้ไม่มีรายการสินค้า'),
          ...widget.order.items.map((item) {
            final id = item.productId?.trim() ?? '';
            final enabled = id.isNotEmpty;
            final qty = enabled ? (_selectedQty[id] ?? 0) : 0;
            final selected = enabled && qty > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  AdminSafeAvatar(
                    imageUrl: item.imageUrl,
                    size: 52,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          enabled
                              ? 'x${item.quantity}'
                                  '${item.unitPrice != null ? ' • ฿${item.unitPrice!.toStringAsFixed(0)}' : ''}'
                              : 'ไม่มี productId — เลือกส่งทดแทนไม่ได้',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    _ClaimQtyStepper(
                      quantity: qty,
                      enabled: !alreadyClaimed,
                      onDecrement: qty <= 1
                          ? null
                          : () => setState(() {
                                _selectedQty[id] = qty - 1;
                                _syncAmountDefaults();
                              }),
                      onIncrement: () => setState(() {
                        _selectedQty[id] = qty + 1;
                        _syncAmountDefaults();
                      }),
                    ),
                  Checkbox(
                    value: selected,
                    onChanged: !enabled || alreadyClaimed
                        ? null
                        : (checked) {
                            setState(() {
                              _selectedQty[id] = checked == true ? item.quantity : 0;
                              _syncAmountDefaults();
                            });
                          },
                  ),
                ],
              ),
            );
          }),
          ..._extraProducts.map((extra) {
            return ListTile(
              leading: AdminSafeAvatar(imageUrl: extra.imageUrl, size: 40, borderRadius: 8),
              title: Text(extra.name),
              subtitle: Text('สินค้าเพิ่มจากร้าน • x${extra.quantity}'),
              trailing: IconButton(
                onPressed: alreadyClaimed
                    ? null
                    : () => setState(() {
                          _extraProducts.removeWhere((item) => item.id == extra.id);
                          _syncAmountDefaults();
                        }),
                icon: const Icon(Icons.close),
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: alreadyClaimed ? null : _pickShopProduct,
              icon: const Icon(Icons.add_rounded),
              label: const Text('เพิ่มสินค้าจากร้านเดียวกัน'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'เหตุผล',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _reasons
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    selected: _reason == option.key,
                    onSelected: alreadyClaimed
                        ? null
                        : (_) => setState(() => _reason = option.key),
                  ),
                )
                .toList(growable: false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('แพลตฟอร์มออกให้ร้าน (ร้านได้เงินรอบสอง)'),
            subtitle: const Text('ใช้เมื่อส่งสินค้าทดแทน — กำหนดยอดเครดิตให้ร้านได้ด้านล่าง'),
            value: _platformPaysShop,
            onChanged: alreadyClaimed
                ? null
                : (value) => setState(() {
                      _platformPaysShop = value;
                      if (value) {
                        _shopPayoutPercent = 100;
                        _applyShopPayoutPercent();
                      }
                    }),
          ),
          if (_platformPaysShop) ...<Widget>[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final base = _shopPayoutBaseAmount();
                final amount =
                    double.tryParse(_shopPayoutController.text.trim()) ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'เครดิตให้ร้าน รอบ 2',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      base > 0
                          ? 'ฐานจากสินค้าที่เลือก ฿${base.toStringAsFixed(0)}'
                          : 'เลือกสินค้าก่อนเพื่อคำนวณฐาน',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: _shopPayoutPercentPresets
                          .map(
                            (preset) => ChoiceChip(
                              label: Text('$preset%'),
                              selected: _shopPayoutPercent.round() == preset,
                              onSelected: alreadyClaimed
                                  ? null
                                  : (_) => setState(() {
                                        _applyShopPayoutPercent(preset.toDouble());
                                      }),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    Slider(
                      value: _shopPayoutPercent,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_shopPayoutPercent.round()}%',
                      activeColor: const Color(0xFFE65100),
                      onChanged: alreadyClaimed
                          ? null
                          : (value) => setState(() {
                                _applyShopPayoutPercent(value);
                              }),
                    ),
                    Row(
                      children: <Widget>[
                        Text(
                          '${_shopPayoutPercent.round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          '≈ ฿${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _shopPayoutController,
                      enabled: !alreadyClaimed,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: alreadyClaimed
                          ? null
                          : (value) => setState(() => _onShopPayoutManualEdit(value)),
                      decoration: const InputDecoration(
                        labelText: 'ยอดสุทธิ (บาท)',
                        helperText: 'ปรับเปอร์เซ็นต์ด้วยสไลด์/ปุ่ม หรือพิมพ์ยอดเอง',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _creditController,
            enabled: !alreadyClaimed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'ยอดคูปองเครดิตลูกค้า (บาท)',
              helperText: 'ใช้เมื่อกด "ให้คูปองเครดิต"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: alreadyClaimed || _submitting ? null : () => _submit('replacement'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: const Text('ส่งสินค้าทดแทน (ไม่คิดเงิน)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: alreadyClaimed || _submitting ? null : () => _submit('credit'),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: const Text('ให้คูปองเครดิต'),
          ),
        ],
      ),
    );
  }
}

class _ClaimReasonOption {
  const _ClaimReasonOption({required this.key, required this.label});

  final String key;
  final String label;
}

class _ClaimExtraProduct {
  const _ClaimExtraProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  _ClaimExtraProduct copyWith({int? quantity}) {
    return _ClaimExtraProduct(
      id: id,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl,
    );
  }
}

class _ClaimQtyStepper extends StatelessWidget {
  const _ClaimQtyStepper({
    required this.quantity,
    required this.enabled,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final bool enabled;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _qtyIcon(
          icon: Icons.remove,
          onTap: enabled ? onDecrement : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        _qtyIcon(
          icon: Icons.add,
          onTap: enabled ? onIncrement : null,
        ),
      ],
    );
  }

  Widget _qtyIcon({required IconData icon, required VoidCallback? onTap}) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}
