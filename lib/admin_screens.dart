import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_home_shelves_screen.dart';
import 'admin_image_widgets.dart';
import 'admin_order_support.dart';
import 'admin_repository.dart';
import 'admin_shop_screens.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('Van Market Admin'),
        actions: <Widget>[
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
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
                  'ศูนย์ควบคุมแอดมินแว๊นตลาด',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9A3412),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? user.uid,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF7C2D12),
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'เชื่อมโยง van1 (ร้าน) → van2 (ลูกค้า) → van3 (ไรเดอร์) ผ่าน Firestore ร่วม orders + app_notifications',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'เมนูหลัก',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A3412),
                ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.receipt_long_outlined,
            title: 'จัดการออเดอร์',
            subtitle: 'แยกสำเร็จ/ไม่สำเร็จ/ยกเลิก/ขอคืนเงิน + CSV 4 ฝ่าย 18:00',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OrderManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.recommend_outlined,
            title: 'สินค้าแนะนำหน้าแรก',
            subtitle: 'เลือกสินค้าที่แสดงในชั้น "สินค้าแนะนำ" บน van2',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminHomeShelvesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.storefront_outlined,
            title: 'จัดการร้านค้า',
            subtitle: 'อนุมัติร้าน • สินค้ารอตรวจ (AI) • ช่วยอัปโหลด • ตั้งค่ารูป/วิดีโอ',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShopManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.delivery_dining_outlined,
            title: 'จัดการไรเดอร์',
            subtitle: 'เปิด/ระงับความพร้อมรับงาน van3',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RiderManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.people_alt_outlined,
            title: 'จัดการลูกค้า',
            subtitle: 'ดู customer_users จาก van2',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CustomerManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.store_mall_directory_outlined,
            title: 'ร้านค้า (users)',
            subtitle: 'บัญชี merchant ใน collection users (van1)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MerchantManagementScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  AdminDailyCsvScheduler? _csvScheduler;
  bool _exportingCsv = false;

  static const List<AdminOrderCategory> _categories = <AdminOrderCategory>[
    AdminOrderCategory.success,
    AdminOrderCategory.unsuccessful,
    AdminOrderCategory.cancelled,
    AdminOrderCategory.refund,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _csvScheduler = AdminDailyCsvScheduler(
      onExport: (reportDate) => _runDailyCsvExport(reportDate, showFeedback: true),
    )..start();
  }

  @override
  void dispose() {
    _csvScheduler?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runDailyCsvExport(
    DateTime reportDate, {
    bool showFeedback = false,
    bool share = false,
  }) async {
    if (_exportingCsv) {
      return;
    }
    setState(() => _exportingCsv = true);
    try {
      final orders = await AdminRepository.fetchOrdersForDate(reportDate);
      if (share) {
        await exportAndShareDailySettlementCsvFiles(
          reportDate: reportDate,
          orders: orders,
        );
      } else {
        buildAllDailySettlementCsvBundle(
          reportDate: reportDate,
          orders: orders,
        );
      }
      if (showFeedback && mounted) {
        final delivered = filterDeliveredOrders(orders).length;
        final refunds = filterRefundOrders(orders).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              share
                  ? 'ส่งออก CSV 4 ฝ่าย (${_formatReportDate(reportDate)}) — ส่งสำเร็จ $delivered • ขอคืนเงิน $refunds'
                  : 'บันทึก CSV 4 ฝ่าย 18:00 แล้ว — ส่งสำเร็จ $delivered • ขอคืนเงิน $refunds',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งออก CSV ไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  String _formatReportDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('จัดการออเดอร์'),
        actions: <Widget>[
          if (_exportingCsv)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => _runDailyCsvExport(
                DateTime.now(),
                showFeedback: true,
                share: true,
              ),
              tooltip: 'ส่งออก CSV 4 ฝ่ายวันนี้',
              icon: const Icon(Icons.download_outlined),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFFFE0B2),
          tabs: _categories
              .map(
                (category) => Tab(
                  child: StreamBuilder<List<AdminOrderRecord>>(
                    stream: AdminRepository.streamOrders(),
                    builder: (context, snapshot) {
                      final orders = snapshot.data ?? const <AdminOrderRecord>[];
                      final count = filterOrdersByCategory(orders, category).length;
                      return Text('${category.label} ($count)');
                    },
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
      body: StreamBuilder<List<AdminOrderRecord>>(
        stream: AdminRepository.streamOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดออเดอร์ไม่สำเร็จ: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? <AdminOrderRecord>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                color: const Color(0xFFFFF7ED),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'สรุป CSV 4 ฝ่าย อัตโนมัติ 18:00 — ขาดส่ง / ค่าสินค้า / ขอคืนเงิน / ร้าน (หัก GP 18% + ไลด์เดอร์ 15%)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9A3412),
                        height: 1.35,
                      ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories
                      .map(
                        (category) => _OrderCategoryList(
                          orders: filterOrdersByCategory(orders, category),
                          emptyLabel: 'ไม่มีออเดอร์${category.label}',
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCategoryList extends StatelessWidget {
  const _OrderCategoryList({
    required this.orders,
    required this.emptyLabel,
  });

  final List<AdminOrderRecord> orders;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminOrderDetailScreen(order: order),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.displayOrderNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C2D12),
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFE65100)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminOrderDetailScreen extends StatelessWidget {
  const AdminOrderDetailScreen({super.key, required this.order});

  final AdminOrderRecord order;

  Future<void> _cancelOrder(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยกเลิกออเดอร์'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'เหตุผล',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ปิด')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }

    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      reasonController.dispose();
      return;
    }

    try {
      await AdminRepository.adminCancelOrder(
        orderId: order.id,
        reason: reasonController.text,
        adminUid: adminUid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกออเดอร์และแจ้งเตือน van1/van2/van3 แล้ว')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยกเลิกไม่สำเร็จ: $error')),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = resolveAdminOrderCategory(order);
    final isCancelled = order.status.toLowerCase() == 'cancelled';
    final imageUrls = <String>{
      if (order.shopImageUrl != null && order.shopImageUrl!.trim().isNotEmpty)
        order.shopImageUrl!.trim(),
      if (order.deliveryProofImageUrl != null &&
          order.deliveryProofImageUrl!.trim().isNotEmpty)
        order.deliveryProofImageUrl!.trim(),
      ...order.items
          .map((item) => item.imageUrl?.trim())
          .whereType<String>()
          .where((url) => url.isNotEmpty),
    }.toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text(order.displayOrderNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusChip(label: category.label),
              _StatusChip(label: order.status),
            ],
          ),
          const SizedBox(height: 16),
          _detailSection(
            context,
            title: 'ข้อมูลออเดอร์',
            lines: <String>[
              'Order ID: ${order.id}',
              if (order.orderCode != null) 'หมายเลข: ${order.orderCode}',
              if (order.createdAt != null) 'สร้าง: ${_formatDateTime(order.createdAt!)}',
              if (order.deliveredAt != null) 'ส่งสำเร็จ: ${_formatDateTime(order.deliveredAt!)}',
              if (order.cancelledAt != null) 'ยกเลิก: ${_formatDateTime(order.cancelledAt!)}',
              if (order.grandTotal != null) 'ยอดรวม: ฿${order.grandTotal!.toStringAsFixed(2)}',
              if (order.subtotal != null) 'สินค้า: ฿${order.subtotal!.toStringAsFixed(2)}',
              if (order.shippingFee != null) 'ค่าส่ง: ฿${order.shippingFee!.toStringAsFixed(2)}',
              if (order.paymentMethod != null) 'ช่องทางชำระ: ${order.paymentMethod}',
              if (order.paymentStatus != null) 'สถานะชำระ: ${order.paymentStatus}',
              if (order.sourceApp != null) 'source: ${order.sourceApp}',
              if (order.cancelReason != null) 'เหตุผลยกเลิก: ${order.cancelReason}',
            ],
          ),
          const SizedBox(height: 12),
          _detailSection(
            context,
            title: 'เชื่อมโยง van1 / van2 / van3',
            child: Column(
              children: <Widget>[
                _LinkageRow(icon: Icons.storefront_outlined, appLabel: 'van1 ร้าน', value: order.van1Label),
                const SizedBox(height: 6),
                _LinkageRow(icon: Icons.person_outline, appLabel: 'van2 ลูกค้า', value: order.van2Label),
                const SizedBox(height: 6),
                _LinkageRow(
                  icon: Icons.delivery_dining_outlined,
                  appLabel: 'van3 ไรเดอร์',
                  value: order.van3Label,
                ),
              ],
            ),
          ),
          if (order.isRefundCase) ...<Widget>[
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: 'ข้อมูลขอคืนเงิน',
              lines: <String>[
                if (order.refundStatus != null) 'สถานะ: ${order.refundStatus}',
                if (order.refundBankName != null) 'ธนาคาร: ${order.refundBankName}',
                if (order.refundAccountName != null) 'ชื่อบัญชี: ${order.refundAccountName}',
                if (order.refundBankAccountNumber != null)
                  'เลขบัญชี: ${order.refundBankAccountNumber}',
              ],
            ),
          ],
          if (order.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: 'รายการสินค้า (${order.items.length})',
              child: Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _OrderImageThumb(url: item.imageUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                'x${item.quantity}'
                                '${item.unitPrice != null ? ' • ฿${item.unitPrice!.toStringAsFixed(2)}' : ''}'
                                '${item.lineTotal != null ? ' • รวม ฿${item.lineTotal!.toStringAsFixed(2)}' : ''}',
                                style: _mutedStyle(context),
                              ),
                              if (item.note != null && item.note!.isNotEmpty)
                                Text(item.note!, style: _mutedStyle(context)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
          if (imageUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _detailSection(
              context,
              title: 'รูปภาพ',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: imageUrls
                    .map((url) => _OrderImagePreview(url: url))
                    .toList(growable: false),
              ),
            ),
          ],
          if (!isCancelled && category != AdminOrderCategory.refund) ...<Widget>[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _cancelOrder(context),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('ยกเลิกโดยแอดมิน'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailSection(
    BuildContext context, {
    required String title,
    List<String>? lines,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (lines != null)
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: _mutedStyle(context)),
              ),
            ),
          if (child != null) child,
        ],
      ),
    );
  }
}

class _OrderImageThumb extends StatelessWidget {
  const _OrderImageThumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return AdminSafeAvatar(imageUrl: url, size: 56, borderRadius: 12);
  }
}

class _OrderImagePreview extends StatelessWidget {
  const _OrderImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
        child: AdminSafeNetworkImage(
          url: url,
          width: 120,
          height: 120,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _LinkageRow extends StatelessWidget {
  const _LinkageRow({
    required this.icon,
    required this.appLabel,
    required this.value,
  });

  final IconData icon;
  final String appLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: const Color(0xFFE65100)),
        const SizedBox(width: 8),
        Text('$appLabel: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class RiderManagementScreen extends StatelessWidget {
  const RiderManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionScreen<AdminRiderRecord>(
      title: 'จัดการไรเดอร์',
      stream: AdminRepository.streamRiders(),
      emptyLabel: 'ยังไม่พบข้อมูลไรเดอร์',
      itemBuilder: (context, rider) => _RiderCard(rider: rider),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider});

  final AdminRiderRecord rider;

  Future<void> _setOnlineReady(BuildContext context, bool onlineReady) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    try {
      await AdminRepository.setRiderOnlineReady(
        riderId: rider.id,
        onlineReady: onlineReady,
        adminUid: adminUid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(onlineReady ? 'เปิดรับงาน van3 แล้ว' : 'ระงับไรเดอร์แล้ว'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตไม่สำเร็จ: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = rider.adminSuspended || !rider.onlineReady;

    return _AdminInfoCard(
      title: rider.displayName,
      subtitle: suspended ? 'ถูกระงับ / ไม่พร้อมรับงาน' : 'พร้อมรับงาน van3',
      statusChip: _StatusChip(label: suspended ? 'offline' : 'online'),
      detailLines: <String>[
        if (rider.phone != null) 'โทร: ${rider.phone}',
        'สถานะตำแหน่ง: ${rider.locationStatus}',
        if (rider.updatedAt != null) 'อัปเดต: ${_formatDateTime(rider.updatedAt!)}',
        'UID: ${rider.id}',
      ],
      actions: <Widget>[
        if (suspended)
          FilledButton(
            onPressed: () => _setOnlineReady(context, true),
            child: const Text('เปิดรับงาน'),
          )
        else
          OutlinedButton(
            onPressed: () => _setOnlineReady(context, false),
            child: const Text('ระงับ'),
          ),
      ],
    );
  }
}

class CustomerManagementScreen extends StatelessWidget {
  const CustomerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionScreen<AdminCustomerRecord>(
      title: 'จัดการลูกค้า (van2)',
      stream: AdminRepository.streamCustomers(),
      emptyLabel: 'ยังไม่พบข้อมูลลูกค้าใน customer_users',
      itemBuilder: (context, customer) => _AdminInfoCard(
        title: customer.displayName,
        subtitle: 'ลูกค้า van2',
        detailLines: <String>[
          if (customer.phone != null) 'โทร: ${customer.phone}',
          if (customer.email != null) 'อีเมล: ${customer.email}',
          if (customer.createdAt != null) 'สร้างเมื่อ: ${_formatDateTime(customer.createdAt!)}',
          'UID: ${customer.id}',
        ],
      ),
    );
  }
}

class MerchantManagementScreen extends StatelessWidget {
  const MerchantManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionScreen<AdminMerchantRecord>(
      title: 'ร้านค้า (users / van1)',
      stream: AdminRepository.streamMerchants(),
      emptyLabel: 'ยังไม่พบ merchant ใน users',
      itemBuilder: (context, merchant) => _AdminInfoCard(
        title: merchant.displayName,
        subtitle: 'บทบาท: ${merchant.role}',
        detailLines: <String>[
          if (merchant.phone != null) 'โทร: ${merchant.phone}',
          if (merchant.email != null) 'อีเมล: ${merchant.email}',
          if (merchant.createdAt != null) 'สร้างเมื่อ: ${_formatDateTime(merchant.createdAt!)}',
          'UID: ${merchant.id}',
        ],
      ),
    );
  }
}

class _AdminCollectionScreen<T> extends StatelessWidget {
  const _AdminCollectionScreen({
    required this.title,
    required this.stream,
    required this.emptyLabel,
    required this.itemBuilder,
  });

  final String title;
  final Stream<List<T>> stream;
  final String emptyLabel;
  final Widget Function(BuildContext context, T record) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: StreamBuilder<List<T>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final records = snapshot.data ?? <T>[];
          if (records.isEmpty) {
            return Center(child: Text(emptyLabel));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => itemBuilder(context, records[index]),
          );
        },
      ),
    );
  }
}

class _AdminInfoCard extends StatelessWidget {
  const _AdminInfoCard({
    required this.title,
    required this.subtitle,
    required this.detailLines,
    this.imageUrl,
    this.actions,
    this.statusChip,
  });

  final String title;
  final String subtitle;
  final List<String> detailLines;
  final String? imageUrl;
  final List<Widget>? actions;
  final Widget? statusChip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AdminSafeAvatar(imageUrl: imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (statusChip != null) statusChip!,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE65100)),
                    ),
                    const SizedBox(height: 8),
                    ...detailLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null && actions!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    Color bg;
    Color fg;
    if (normalized.contains('approve') ||
        normalized == 'online' ||
        normalized == 'completed' ||
        normalized == 'delivered' ||
        normalized == 'สำเร็จ') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized.contains('reject') ||
        normalized == 'cancelled' ||
        normalized == 'offline' ||
        normalized == 'refund' ||
        normalized == 'ยกเลิก' ||
        normalized == 'ขอคืนเงิน') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else if (normalized.contains('pending')) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFF9A3412);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _AdminPrimaryButton extends StatelessWidget {
  const _AdminPrimaryButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFFE65100), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C2D12),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFE65100), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280));
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
