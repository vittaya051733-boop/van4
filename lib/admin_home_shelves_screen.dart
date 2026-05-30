import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_image_widgets.dart';
import 'admin_repository.dart';

class AdminHomeShelvesScreen extends StatefulWidget {
  const AdminHomeShelvesScreen({super.key});

  @override
  State<AdminHomeShelvesScreen> createState() => _AdminHomeShelvesScreenState();
}

class _AdminHomeShelvesScreenState extends State<AdminHomeShelvesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedProductIds = <String>[];
  bool _dirty = false;
  bool _saving = false;
  String _searchQuery = '';
  String _remoteFeaturedSignature = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _hasDisplayImage(AdminProductRecord product) {
    return product.imageUrls.isNotEmpty;
  }

  bool _matchesSearch(AdminProductRecord product) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final haystack = [
      product.name,
      product.shopName ?? '',
      product.ownerUid ?? '',
      product.id,
    ].join(' ').toLowerCase();
    return haystack.contains(_searchQuery);
  }

  AdminProductRecord? _findProduct(
    List<AdminProductRecord> products,
    String productId,
  ) {
    for (final product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  void _addProduct(AdminProductRecord product) {
    if (_selectedProductIds.contains(product.id)) {
      return;
    }
    setState(() {
      _selectedProductIds = <String>[..._selectedProductIds, product.id];
      _dirty = true;
    });
  }

  void _removeProduct(String productId) {
    setState(() {
      _selectedProductIds =
          _selectedProductIds.where((id) => id != productId).toList(growable: false);
      _dirty = true;
    });
  }

  void _moveProduct(int index, int delta) {
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= _selectedProductIds.length) {
      return;
    }
    setState(() {
      final next = List<String>.from(_selectedProductIds);
      final item = next.removeAt(index);
      next.insert(targetIndex, item);
      _selectedProductIds = next;
      _dirty = true;
    });
  }

  Future<void> _saveFeaturedProducts() async {
    if (_saving) {
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบอีเมลแอดมิน')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AdminRepository.saveHomeFeaturedProductIds(
        productIds: _selectedProductIds,
        adminEmail: email,
      );
      if (!mounted) {
        return;
      }
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกสินค้าแนะนำหน้าแรกแล้ว')),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('สินค้าแนะนำหน้าแรก'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving || !_dirty ? null : _saveFeaturedProducts,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'บันทึก',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
      body: StreamBuilder<List<AdminProductRecord>>(
        stream: AdminRepository.streamActiveProductsForHomePicker(),
        builder: (context, productsSnapshot) {
          final products = productsSnapshot.data ?? const <AdminProductRecord>[];
          final displayableProducts =
              products.where(_hasDisplayImage).toList(growable: false);

          return StreamBuilder<List<String>>(
            stream: AdminRepository.streamHomeFeaturedProductIds(),
            builder: (context, featuredSnapshot) {
              final remoteIds = featuredSnapshot.data ?? const <String>[];
              final remoteSignature = remoteIds.join(',');
              if (!_dirty && remoteSignature != _remoteFeaturedSignature) {
                _remoteFeaturedSignature = remoteSignature;
                _selectedProductIds = List<String>.from(remoteIds);
              }

              final selectedProducts = _selectedProductIds
                  .map((id) => _findProduct(displayableProducts, id))
                  .whereType<AdminProductRecord>()
                  .toList(growable: false);

              final availableProducts = displayableProducts
                  .where(
                    (product) =>
                        !_selectedProductIds.contains(product.id) &&
                        _matchesSearch(product),
                  )
                  .toList(growable: false);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Text(
                    'เลือกสินค้าที่จะแสดงในชั้น "สินค้าแนะนำ" บนหน้าแรก van2',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF7C2D12),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ระบบจะเติมสินค้าใหม่โดยอัตโนมัติหากเลือกน้อยกว่า 12 รายการ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'สินค้าที่เลือก (${selectedProducts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF9A3412),
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedProducts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Text('ยังไม่ได้เลือกสินค้า'),
                    )
                  else
                    ...List<Widget>.generate(selectedProducts.length, (index) {
                      final product = selectedProducts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: AdminSafeNetworkImage(url: product.imageUrls.first),
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Text(product.shopName ?? product.ownerUid ?? '-'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'เลื่อนขึ้น',
                                onPressed: index == 0 ? null : () => _moveProduct(index, -1),
                                icon: const Icon(Icons.arrow_upward_rounded),
                              ),
                              IconButton(
                                tooltip: 'เลื่อนลง',
                                onPressed: index == selectedProducts.length - 1
                                    ? null
                                    : () => _moveProduct(index, 1),
                                icon: const Icon(Icons.arrow_downward_rounded),
                              ),
                              IconButton(
                                tooltip: 'ลบ',
                                onPressed: () => _removeProduct(product.id),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาสินค้า / ร้าน / รหัส',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'เพิ่มสินค้า (${availableProducts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF9A3412),
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (productsSnapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (availableProducts.isEmpty)
                    const Text('ไม่พบสินค้าที่ตรงเงื่อนไข')
                  else
                    ...availableProducts.take(80).map(
                          (product) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: AdminSafeNetworkImage(url: product.imageUrls.first),
                                ),
                              ),
                              title: Text(product.name),
                              subtitle: Text(product.shopName ?? product.ownerUid ?? '-'),
                              trailing: IconButton(
                                tooltip: 'เพิ่ม',
                                onPressed: () => _addProduct(product),
                                icon: const Icon(Icons.add_circle_outline_rounded),
                              ),
                              onTap: () => _addProduct(product),
                            ),
                          ),
                        ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
