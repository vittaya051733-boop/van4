import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_repository.dart';
import 'admin_order_support.dart';
import 'models/admin_market.dart';
import 'services/admin_market_scope.dart';
import 'services/admin_overview_service.dart';
import 'widgets/admin_overview_dashboard.dart';

class AdminMarketManagementScreen extends StatefulWidget {
  const AdminMarketManagementScreen({super.key});

  @override
  State<AdminMarketManagementScreen> createState() =>
      _AdminMarketManagementScreenState();
}

class _AdminMarketManagementScreenState extends State<AdminMarketManagementScreen> {
  bool _seeding = false;

  Future<void> _ensureCatalog() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    if (email == null || email.isEmpty || _seeding) {
      return;
    }
    setState(() => _seeding = true);
    try {
      await AdminMarketService.instance.ensureDefaultCatalog(adminEmail: email);
    } finally {
      if (mounted) {
        setState(() => _seeding = false);
      }
    }
  }

  Future<void> _openMarketEditor({AdminMarket? market}) async {
    final saved = await showDialog<AdminMarket>(
      context: context,
      builder: (context) => _MarketEditorDialog(initial: market),
    );
    if (saved == null || !mounted) {
      return;
    }

    final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? 'admin';
    await AdminMarketService.instance.saveBranch(
      branch: saved,
      adminEmail: email,
    );
  }

  Future<void> _assignShops(AdminMarket market) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MarketAssignmentScreen(market: market, mode: _AssignmentMode.shops),
      ),
    );
  }

  Future<void> _assignRiders(AdminMarket market) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MarketAssignmentScreen(market: market, mode: _AssignmentMode.riders),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCatalog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('จัดการสาขา'),
        actions: <Widget>[
          if (_seeding)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        onPressed: () => _openMarketEditor(),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('เพิ่มสาขา'),
      ),
      body: ListenableBuilder(
        listenable: AdminMarketScope.instance,
        builder: (context, _) {
          final catalog = AdminMarketScope.instance.catalog;
          return StreamBuilder<List<AdminOrderRecord>>(
            stream: AdminOverviewService.streamOrdersForToday(),
            builder: (context, ordersSnapshot) {
              final orders = ordersSnapshot.data ?? const <AdminOrderRecord>[];
              return StreamBuilder<List<AdminShopRecord>>(
                stream: AdminRepository.streamShops(),
                builder: (context, shopsSnapshot) {
                  final shops = shopsSnapshot.data ?? const <AdminShopRecord>[];
                  return StreamBuilder<List<AdminRiderRecord>>(
                    stream: AdminRepository.streamRiders(),
                    builder: (context, ridersSnapshot) {
                      final riders = ridersSnapshot.data ?? const <AdminRiderRecord>[];
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                        children: <Widget>[
                          Text(
                            'เลือกสาขาเพื่อดูร้านค้า ไรเดอร์ ออเดอร์ และรายได้แยกตามพื้นที่ — สาขากลาง central = ตลาดโนนสูง (branches/central)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B7280),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ...catalog.markets.map(
                            (market) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MarketStatsCard(
                                market: market,
                                stats: _MarketStats.compute(
                                  marketId: market.id,
                                  defaultMarketId: catalog.defaultMarketId,
                                  orders: orders,
                                  shops: shops,
                                  riders: riders,
                                ),
                                onEdit: () => _openMarketEditor(market: market),
                                onSelect: () =>
                                    AdminMarketScope.instance.selectMarket(market.id),
                                onAssignShops: () => _assignShops(market),
                                onAssignRiders: () => _assignRiders(market),
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
          );
        },
      ),
    );
  }
}

class _MarketStats {
  const _MarketStats({
    required this.shopsApproved,
    required this.ridersAssigned,
    required this.ordersToday,
    required this.salesTodayBaht,
  });

  final int shopsApproved;
  final int ridersAssigned;
  final int ordersToday;
  final double salesTodayBaht;

  static _MarketStats compute({
    required String marketId,
    required String defaultMarketId,
    required List<AdminOrderRecord> orders,
    required List<AdminShopRecord> shops,
    required List<AdminRiderRecord> riders,
  }) {
    final scope = AdminMarketScope.instance;

    bool matchesEntity(String? entityBranchId, {String? shopOwnerId}) {
      final resolved = scope.resolveEntityMarketId(entityBranchId, fallbackOwnerId: shopOwnerId);
      final target = AdminMarket.normalizeBranchId(marketId);
      if (resolved == target) {
        return true;
      }
      if (resolved == null && target == defaultMarketId) {
        return true;
      }
      return false;
    }

    final filteredOrders = orders
        .where(
          (order) => matchesEntity(
            order.rawData['branchId']?.toString() ?? order.rawData['marketId']?.toString(),
            shopOwnerId: order.shopOwnerId,
          ),
        )
        .toList(growable: false);
    final sales = filteredOrders
        .where((order) => order.isDeliveredSuccess)
        .fold<double>(0, (total, order) => total + (order.grandTotal ?? 0));

    final shopCount = shops
        .where((shop) => shop.isApproved && matchesEntity(scope.marketIdForShopOwner(shop.ownerId), shopOwnerId: shop.ownerId))
        .length;
    final riderCount = riders
        .where(
          (rider) => matchesEntity(rider.branchId ?? rider.marketId ?? scope.marketIdForRider(rider.id)),
        )
        .length;

    return _MarketStats(
      shopsApproved: shopCount,
      ridersAssigned: riderCount,
      ordersToday: filteredOrders.length,
      salesTodayBaht: sales,
    );
  }
}

class _MarketStatsCard extends StatelessWidget {
  const _MarketStatsCard({
    required this.market,
    required this.stats,
    required this.onEdit,
    required this.onSelect,
    required this.onAssignShops,
    required this.onAssignRiders,
  });

  final AdminMarket market;
  final _MarketStats stats;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onAssignShops;
  final VoidCallback onAssignRiders;

  @override
  Widget build(BuildContext context) {
    final selected = AdminMarketScope.instance.selectedMarketId == market.id;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFFE65100) : const Color(0xFFFFE0B2),
          width: selected ? 2 : 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      market.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C2D12),
                          ),
                    ),
                    if (market.amphoe != null)
                      Text(
                        '${market.amphoe}${market.province != null ? ', ${market.province}' : ''}',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatChip(label: '🏪 ${stats.shopsApproved} ร้าน'),
              _StatChip(label: '🛵 ${stats.ridersAssigned} ไรเดอร์'),
              _StatChip(label: '📦 ${stats.ordersToday} ออเดอร์'),
              _StatChip(label: '💰 ${formatOverviewBaht(stats.salesTodayBaht)} บาท'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(onPressed: onSelect, child: const Text('เลือกดูตลาดนี้')),
              OutlinedButton(onPressed: onAssignShops, child: const Text('ผูกร้าน')),
              OutlinedButton(onPressed: onAssignRiders, child: const Text('ผูกไรเดอร์')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

enum _AssignmentMode { shops, riders }

class _MarketAssignmentScreen extends StatelessWidget {
  const _MarketAssignmentScreen({
    required this.market,
    required this.mode,
  });

  final AdminMarket market;
  final _AssignmentMode mode;

  @override
  Widget build(BuildContext context) {
    final title = mode == _AssignmentMode.shops
        ? 'ผูกร้าน → ${market.name}'
        : 'ผูกไรเดอร์ → ${market.name}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: mode == _AssignmentMode.shops ? _ShopAssignmentList(market: market) : _RiderAssignmentList(market: market),
    );
  }
}

class _ShopAssignmentList extends StatelessWidget {
  const _ShopAssignmentList({required this.market});

  final AdminMarket market;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminShopRecord>>(
      stream: AdminRepository.streamShops(),
      builder: (context, snapshot) {
        final shops = snapshot.data ?? const <AdminShopRecord>[];
        if (shops.isEmpty) {
          return const Center(child: Text('ยังไม่มีร้านค้า'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: shops.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final shop = shops[index];
            final assigned = AdminMarketScope.instance.marketIdForShopOwner(shop.ownerId);
            final isCurrent = assigned == market.id ||
                (assigned == null && market.id == AdminMarketScope.instance.defaultMarketId);
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isCurrent ? const Color(0xFFE65100) : const Color(0xFFFFE0B2),
                ),
              ),
              title: Text(shop.displayName),
              subtitle: Text(
                assigned == null
                    ? 'ยังไม่มีป้ายสาขา → นับเป็น central'
                    : 'สาขา: $assigned',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? 'admin';
                  await AdminMarketService.instance.assignShopMarket(
                    ownerId: shop.ownerId,
                    marketId: market.id,
                    adminEmail: email,
                    branch: market,
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                child: const Text('ผูก'),
              ),
            );
          },
        );
      },
    );
  }
}

class _RiderAssignmentList extends StatelessWidget {
  const _RiderAssignmentList({required this.market});

  final AdminMarket market;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminRiderRecord>>(
      stream: AdminRepository.streamRiders(),
      builder: (context, snapshot) {
        final riders = snapshot.data ?? const <AdminRiderRecord>[];
        if (riders.isEmpty) {
          return const Center(child: Text('ยังไม่มีไรเดอร์'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: riders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final rider = riders[index];
            final assigned = rider.branchId ??
                rider.marketId ??
                AdminMarketScope.instance.marketIdForRider(rider.id);
            final isCurrent = assigned == market.id ||
                (assigned == null && market.id == AdminMarketScope.instance.defaultMarketId);
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isCurrent ? const Color(0xFFE65100) : const Color(0xFFFFE0B2),
                ),
              ),
              title: Text(rider.displayName),
              subtitle: Text(
                assigned == null
                    ? 'ยังไม่มีป้ายสาขา → นับเป็น central'
                    : 'สาขา: $assigned',
              ),
              trailing: FilledButton(
                onPressed: () async {
                  final email = FirebaseAuth.instance.currentUser?.email?.trim() ?? 'admin';
                  await AdminMarketService.instance.assignRiderMarket(
                    riderId: rider.id,
                    marketId: market.id,
                    adminEmail: email,
                    branch: market,
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                child: const Text('ผูก'),
              ),
            );
          },
        );
      },
    );
  }
}

class _MarketEditorDialog extends StatefulWidget {
  const _MarketEditorDialog({this.initial});

  final AdminMarket? initial;

  @override
  State<_MarketEditorDialog> createState() => _MarketEditorDialogState();
}

class _MarketEditorDialogState extends State<_MarketEditorDialog> {
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _provinceController;
  late final TextEditingController _amphoeController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _idController = TextEditingController(text: initial?.id ?? '');
    _nameController = TextEditingController(text: initial?.name ?? '');
    _provinceController = TextEditingController(text: initial?.province ?? '');
    _amphoeController = TextEditingController(text: initial?.amphoe ?? '');
    _latController = TextEditingController(text: initial?.hubLatitude?.toString() ?? '');
    _lngController = TextEditingController(text: initial?.hubLongitude?.toString() ?? '');
    _radiusController =
        TextEditingController(text: () {
          final meters = initial?.hubRadiusMeters;
          if (meters == null) return '8';
          return (meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 1);
        }());
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _provinceController.dispose();
    _amphoeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'แก้ไขสาขา' : 'เพิ่มสาขา'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _idController,
              enabled: !editing,
              decoration: const InputDecoration(
                labelText: 'รหัสสาขา (branchId)',
                hintText: 'central',
              ),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ชื่อสาขา (branchName)'),
            ),
            TextField(
              controller: _amphoeController,
              decoration: const InputDecoration(labelText: 'อำเภอ'),
            ),
            TextField(
              controller: _provinceController,
              decoration: const InputDecoration(labelText: 'จังหวัด'),
            ),
            TextField(
              controller: _latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              decoration: const InputDecoration(labelText: 'Hub Latitude'),
            ),
            TextField(
              controller: _lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              decoration: const InputDecoration(labelText: 'Hub Longitude'),
            ),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'รัศมีจัดส่ง (กม.) — deliveryRadiusKm'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () {
            final id = _idController.text.trim();
            final name = _nameController.text.trim();
            if (id.isEmpty || name.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              AdminMarket(
                id: id,
                name: name,
                active: widget.initial?.active ?? true,
                province: _provinceController.text.trim().isEmpty
                    ? null
                    : _provinceController.text.trim(),
                amphoe:
                    _amphoeController.text.trim().isEmpty ? null : _amphoeController.text.trim(),
                hubLatitude: double.tryParse(_latController.text.trim()),
                hubLongitude: double.tryParse(_lngController.text.trim()),
                hubRadiusMeters: () {
                  final km = double.tryParse(_radiusController.text.trim());
                  if (km == null) return int.tryParse(_radiusController.text.trim());
                  return (km * 1000).round();
                }(),
                branchLabel: id,
                isCentral: id == AdminMarket.defaultBranchId,
                sortOrder: widget.initial?.sortOrder ?? 99,
              ),
            );
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
