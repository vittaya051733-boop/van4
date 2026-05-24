import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_repository.dart';

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
            subtitle: 'ดูออเดอร์ข้ามแอป ยกเลิก และติดตาม van1/van2/van3',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OrderManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.storefront_outlined,
            title: 'จัดการร้านค้า',
            subtitle: 'อนุมัติ/ปฏิเสธร้าน และซิงก์ public_shops ให้ van2',
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

class OrderManagementScreen extends StatelessWidget {
  const OrderManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('จัดการออเดอร์'),
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
          if (orders.isEmpty) {
            return const Center(child: Text('ยังไม่มีออเดอร์'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

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
    final isCancelled = order.status.toLowerCase() == 'cancelled';

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
            children: <Widget>[
              Expanded(
                child: Text(
                  'ออเดอร์ #${order.id}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(label: order.status),
            ],
          ),
          if (order.createdAt != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('สร้าง: ${_formatDateTime(order.createdAt!)}', style: _mutedStyle(context)),
          ],
          if (order.grandTotal != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('ยอดรวม: ฿${order.grandTotal!.toStringAsFixed(2)}', style: _mutedStyle(context)),
          ],
          const SizedBox(height: 12),
          _LinkageRow(
            icon: Icons.storefront_outlined,
            appLabel: 'van1 ร้าน',
            value: order.van1Label,
          ),
          const SizedBox(height: 6),
          _LinkageRow(
            icon: Icons.person_outline,
            appLabel: 'van2 ลูกค้า',
            value: order.van2Label,
          ),
          const SizedBox(height: 6),
          _LinkageRow(
            icon: Icons.delivery_dining_outlined,
            appLabel: 'van3 ไรเดอร์',
            value: order.van3Label,
          ),
          if (order.sourceApp != null || order.paymentStatus != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              [
                if (order.sourceApp != null) 'source: ${order.sourceApp}',
                if (order.paymentStatus != null) 'ชำระ: ${order.paymentStatus}',
              ].join(' • '),
              style: _mutedStyle(context),
            ),
          ],
          if (!isCancelled) ...<Widget>[
            const SizedBox(height: 12),
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

class ShopManagementScreen extends StatelessWidget {
  const ShopManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('จัดการร้านค้า'),
      ),
      body: StreamBuilder<List<AdminShopRecord>>(
        stream: AdminRepository.streamShops(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}'));
          }

          final shops = snapshot.data ?? <AdminShopRecord>[];
          if (shops.isEmpty) {
            return const Center(child: Text('ยังไม่พบข้อมูลร้านค้า'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ShopCard(shop: shops[index]),
          );
        },
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});

  final AdminShopRecord shop;

  Future<void> _approve(BuildContext context) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    try {
      await AdminRepository.approveShop(shop: shop, adminUid: adminUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติ ${shop.displayName} แล้ว — แจ้ง van1 + เปิด public_shops')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อนุมัติไม่สำเร็จ: $error')));
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ปฏิเสธ ${shop.displayName}'),
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
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ปฏิเสธ')),
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
      await AdminRepository.rejectShop(
        shop: shop,
        adminUid: adminUid,
        reason: reasonController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธ ${shop.displayName} และแจ้ง van1 แล้ว')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $error')));
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminInfoCard(
      title: shop.displayName,
      subtitle: '${shop.serviceType} • ${shop.status}',
      imageUrl: shop.imageUrl,
      statusChip: _StatusChip(
        label: shop.isApproved
            ? 'approved'
            : shop.isRejected
                ? 'rejected'
                : shop.isPendingReview
                    ? 'pending'
                    : shop.status,
      ),
      detailLines: <String>[
        'เจ้าของ (van1): ${shop.ownerId}',
        if (shop.phone != null) 'โทร: ${shop.phone}',
        if (shop.email != null) 'อีเมล: ${shop.email}',
        if (shop.address != null) 'ที่อยู่: ${shop.address}',
        'แหล่งข้อมูล: ${shop.collection}',
        'โปรไฟล์ครบ: ${shop.isProfileCompleted ? 'ใช่' : 'ยังไม่ครบ'}',
        if (shop.createdAt != null) 'อัปเดต: ${_formatDateTime(shop.createdAt!)}',
      ],
      actions: shop.isApproved
          ? null
          : <Widget>[
              if (!shop.isRejected)
                FilledButton.icon(
                  onPressed: () => _approve(context),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('อนุมัติ'),
                ),
              if (!shop.isRejected) const SizedBox(width: 8),
              if (!shop.isRejected)
                OutlinedButton.icon(
                  onPressed: () => _reject(context),
                  icon: const Icon(Icons.block_outlined, size: 18),
                  label: const Text('ปฏิเสธ'),
                ),
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(16),
                  image: imageUrl != null && imageUrl!.trim().isNotEmpty
                      ? DecorationImage(image: NetworkImage(imageUrl!.trim()), fit: BoxFit.cover)
                      : null,
                ),
                child: imageUrl != null && imageUrl!.trim().isNotEmpty
                    ? null
                    : const Icon(Icons.inventory_2_outlined, color: Color(0xFFE65100)),
              ),
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
    if (normalized.contains('approve') || normalized == 'online' || normalized == 'completed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized.contains('reject') || normalized == 'cancelled' || normalized == 'offline') {
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
