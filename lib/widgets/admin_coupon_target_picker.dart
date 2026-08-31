import 'package:flutter/material.dart';

import '../admin_repository.dart';

/// เลือกร้านและสินค้าที่คูปองใช้ได้ (บันทึกเป็น conditions.shopIds / productIds)
class AdminCouponTargetPicker extends StatelessWidget {
  const AdminCouponTargetPicker({
    super.key,
    required this.selectedShopOwnerIds,
    required this.selectedProductIds,
    required this.onChanged,
  });

  final List<String> selectedShopOwnerIds;
  final List<String> selectedProductIds;
  final void Function(List<String> shopOwnerIds, List<String> productIds) onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<({List<String> shops, List<String> products})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CouponTargetPickerSheet(
        initialShopOwnerIds: selectedShopOwnerIds,
        initialProductIds: selectedProductIds,
      ),
    );
    if (result != null) {
      onChanged(result.shops, result.products);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTargets =
        selectedShopOwnerIds.isNotEmpty || selectedProductIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _openPicker(context),
          icon: const Icon(Icons.storefront_outlined),
          label: Text(hasTargets ? 'แก้ไขร้าน/สินค้า' : 'เลือกร้าน/สินค้า'),
        ),
        if (hasTargets) ...<Widget>[
          const SizedBox(height: 8),
          if (selectedShopOwnerIds.isNotEmpty)
            Text(
              'ร้าน: ${selectedShopOwnerIds.length} ร้าน',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          if (selectedProductIds.isNotEmpty)
            Text(
              'สินค้า: ${selectedProductIds.length} รายการ',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          const SizedBox(height: 4),
          Text(
            'ว่าง = ใช้ได้ทุกร้าน/สินค้า',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ] else
          const Text(
            'ยังไม่จำกัดร้าน/สินค้า — คูปองใช้ได้ทั้งแอป',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
      ],
    );
  }
}

class _CouponTargetPickerSheet extends StatefulWidget {
  const _CouponTargetPickerSheet({
    required this.initialShopOwnerIds,
    required this.initialProductIds,
  });

  final List<String> initialShopOwnerIds;
  final List<String> initialProductIds;

  @override
  State<_CouponTargetPickerSheet> createState() => _CouponTargetPickerSheetState();
}

class _CouponTargetPickerSheetState extends State<_CouponTargetPickerSheet> {
  late Set<String> _shopOwnerIds;
  late Set<String> _productIds;
  String? _filterShopOwnerId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _shopOwnerIds = widget.initialShopOwnerIds.toSet();
    _productIds = widget.initialProductIds.toSet();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesProduct(AdminProductRecord product) {
    if (_filterShopOwnerId != null && product.ownerUid != _filterShopOwnerId) {
      return false;
    }
    if (_searchQuery.isEmpty) {
      return true;
    }
    final haystack = [
      product.name,
      product.shopName ?? '',
      product.id,
    ].join(' ').toLowerCase();
    return haystack.contains(_searchQuery);
  }

  void _toggleProduct(AdminProductRecord product) {
    setState(() {
      if (_productIds.contains(product.id)) {
        _productIds.remove(product.id);
      } else {
        _productIds.add(product.id);
        final owner = product.ownerUid?.trim();
        if (owner != null && owner.isNotEmpty) {
          _shopOwnerIds.add(owner);
        }
      }
    });
  }

  void _toggleShop(String ownerId) {
    setState(() {
      if (_shopOwnerIds.contains(ownerId)) {
        _shopOwnerIds.remove(ownerId);
      } else {
        _shopOwnerIds.add(ownerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'จำกัดร้าน/สินค้าที่ใช้คูปองได้',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาสินค้า...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<AdminShopRecord>>(
              stream: AdminRepository.streamShops(),
              builder: (context, shopsSnapshot) {
                final shops = (shopsSnapshot.data ?? const <AdminShopRecord>[])
                    .where((shop) => shop.isApproved)
                    .toList(growable: false);
                return SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: <Widget>[
                      FilterChip(
                        label: const Text('ทุกร้าน'),
                        selected: _filterShopOwnerId == null,
                        onSelected: (_) => setState(() => _filterShopOwnerId = null),
                      ),
                      for (final shop in shops)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FilterChip(
                            label: Text(shop.displayName, overflow: TextOverflow.ellipsis),
                            selected: _filterShopOwnerId == shop.ownerId,
                            onSelected: (_) {
                              setState(() {
                                _filterShopOwnerId =
                                    _filterShopOwnerId == shop.ownerId ? null : shop.ownerId;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'เลือกร้าน (ใช้ ownerUid):',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            SizedBox(
              height: 52,
              child: StreamBuilder<List<AdminShopRecord>>(
                stream: AdminRepository.streamShops(),
                builder: (context, snapshot) {
                  final shops = (snapshot.data ?? const <AdminShopRecord>[])
                      .where((shop) => shop.isApproved)
                      .toList(growable: false);
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      final selected = _shopOwnerIds.contains(shop.ownerId);
                      return FilterChip(
                        label: Text(shop.displayName),
                        selected: selected,
                        onSelected: (_) => _toggleShop(shop.ownerId),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: StreamBuilder<List<AdminProductRecord>>(
                stream: AdminRepository.streamActiveProductsForHomePicker(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final products = (snapshot.data ?? const <AdminProductRecord>[])
                      .where(_matchesProduct)
                      .toList(growable: false);
                  if (products.isEmpty) {
                    return const Center(child: Text('ไม่พบสินค้า'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final selected = _productIds.contains(product.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggleProduct(product),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.shopName ?? product.ownerUid ?? '-'} • ${product.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: product.imageUrls.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  product.imageUrls.first,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop((
                    shops: _shopOwnerIds.toList(growable: false),
                    products: _productIds.toList(growable: false),
                  ));
                },
                child: Text(
                  'ยืนยัน (${_shopOwnerIds.length} ร้าน • ${_productIds.length} สินค้า)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
