import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_image_widgets.dart';
import 'admin_repository.dart';
import 'models/home_page_lock_config.dart';
import 'models/home_quick_action_config.dart';
import 'models/home_shelves_config.dart';

class AdminHomeShelvesScreen extends StatefulWidget {
  const AdminHomeShelvesScreen({super.key});

  @override
  State<AdminHomeShelvesScreen> createState() => _AdminHomeShelvesScreenState();
}

class _AdminHomeShelvesScreenState extends State<AdminHomeShelvesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _homeLockMessageController = TextEditingController();
  List<String> _selectedProductIds = <String>[];
  Map<String, bool> _quickActions = HomeQuickActionConfig.defaults.enabledById;
  bool _homeLocked = false;
  bool _dirty = false;
  bool _saving = false;
  bool _savingQuickActions = false;
  bool _savingHomeLock = false;
  String _searchQuery = '';
  String _remoteFeaturedSignature = '';
  String _remoteQuickActionsSignature = '';
  String _remoteHomeLockSignature = '';

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
    _homeLockMessageController.dispose();
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

  Future<void> _setQuickActionEnabled(String id, bool enabled) async {
    if (_savingQuickActions) {
      return;
    }
    final previous = Map<String, bool>.from(_quickActions);
    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบอีเมลแอดมิน')),
      );
      return;
    }

    setState(() {
      _quickActions = <String, bool>{..._quickActions, id: enabled};
      _savingQuickActions = true;
    });
    try {
      await AdminRepository.saveHomeQuickActions(
        enabledById: _quickActions,
        adminEmail: email,
      );
      if (!mounted) {
        return;
      }
      _remoteQuickActionsSignature =
          HomeQuickActionConfig.fromEnabledById(_quickActions).signature;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _quickActions = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกปุ่มไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingQuickActions = false);
      }
    }
  }

  Future<void> _saveHomePageLock({bool? enabled, String? message}) async {
    if (_savingHomeLock) {
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบอีเมลแอดมิน')),
      );
      return;
    }

    final previousEnabled = _homeLocked;
    final previousMessage = _homeLockMessageController.text;
    final nextEnabled = enabled ?? _homeLocked;
    final nextMessage = message ?? _homeLockMessageController.text;

    setState(() {
      _homeLocked = nextEnabled;
      if (message != null) {
        _homeLockMessageController.text = nextMessage;
      }
      _savingHomeLock = true;
    });

    try {
      await AdminRepository.saveHomePageLock(
        enabled: nextEnabled,
        message: nextMessage,
        adminEmail: email,
      );
      if (!mounted) {
        return;
      }
      _remoteHomeLockSignature = HomePageLockConfig.fromLocal(
        enabled: nextEnabled,
        message: nextMessage,
      ).signature;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextEnabled ? 'ปิดหน้าโฮม van2 แล้ว' : 'เปิดหน้าโฮม van2 แล้ว',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _homeLocked = previousEnabled;
        _homeLockMessageController.text = previousMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกปิดหน้าโฮมไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingHomeLock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('หน้าแรก van2'),
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

              return StreamBuilder<HomeShelvesConfig>(
                stream: AdminRepository.streamHomeShelvesConfig(),
                builder: (context, shelvesSnapshot) {
                  final shelvesConfig = shelvesSnapshot.data ??
                      HomeShelvesConfig.defaults;
                  final remoteActions = shelvesConfig.quickActions;
                  if (!_savingQuickActions &&
                      remoteActions.signature != _remoteQuickActionsSignature) {
                    _remoteQuickActionsSignature = remoteActions.signature;
                    _quickActions = remoteActions.enabledById;
                  }
                  final remoteLock = shelvesConfig.homeLock;
                  if (!_savingHomeLock &&
                      remoteLock.signature != _remoteHomeLockSignature) {
                    _remoteHomeLockSignature = remoteLock.signature;
                    _homeLocked = remoteLock.enabled;
                    _homeLockMessageController.text = remoteLock.message;
                  }
                  final visibleCount =
                      HomeQuickActionConfig.fromEnabledById(_quickActions)
                          .visibleCount;

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
                    'ปิดหน้าโฮม van2',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF9A3412),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เปิดแล้วลูกค้าจะกดอะไรบนหน้าโฮมไม่ได้ และเห็นข้อความด้านล่างทับหน้าแรบโปร่งใส',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: SwitchListTile(
                      value: _homeLocked,
                      onChanged: _savingHomeLock
                          ? null
                          : (value) => _saveHomePageLock(enabled: value),
                      title: const Text(
                        'ปิดหน้าโฮม',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _homeLocked
                            ? 'กำลังปิด — ลูกค้าเห็นเฉพาะข้อความปรับปรุง'
                            : 'เปิดอยู่ — ลูกค้าใช้หน้าโฮมได้ตามปกติ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _homeLockMessageController,
                    minLines: 3,
                    maxLines: 6,
                    enabled: !_savingHomeLock,
                    decoration: InputDecoration(
                      labelText: 'ข้อความแสดงบนหน้าโฮม',
                      hintText: HomePageLockConfig.defaultMessage,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _savingHomeLock
                          ? null
                          : () => _saveHomePageLock(
                                enabled: _homeLocked,
                                message: _homeLockMessageController.text,
                              ),
                      icon: _savingHomeLock
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('บันทึกข้อความ'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'ปุ่มหน้าแรก van2',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF9A3412),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ปิดแล้วปุ่มจะหายจากหน้าแรก และปุ่มที่เหลือเรียงชิดกัน ไม่เว้นช่องว่าง — ตอนนี้แสดง $visibleCount ปุ่ม',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...HomeQuickActionConfig.specs.map((spec) {
                    final enabled = _quickActions[spec.id] != false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: SwitchListTile(
                        value: enabled,
                        onChanged: _savingQuickActions
                            ? null
                            : (value) => _setQuickActionEnabled(spec.id, value),
                        title: Text(
                          spec.labelTh,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(spec.adminSubtitle),
                      ),
                    );
                  }),
                  const SizedBox(height: 22),
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
          );
        },
      ),
    );
  }
}
