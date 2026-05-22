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
            icon: Icons.storefront_outlined,
            title: 'จัดการร้านค้า',
            subtitle: 'ตรวจสอบร้าน อนุมัติข้อมูล และติดตามสถานะการเปิดขาย',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShopManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.delivery_dining_outlined,
            title: 'จัดการไรเดอร์',
            subtitle: 'ดูข้อมูลไรเดอร์ งานวิ่ง และสถานะความพร้อมรับงาน',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RiderManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminPrimaryButton(
            icon: Icons.people_alt_outlined,
            title: 'จัดการลูกค้า',
            subtitle: 'ตรวจสอบผู้ใช้งาน ประวัติ และช่องทางติดต่อในระบบ',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CustomerManagementScreen()),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ShopManagementScreen()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('เข้าหน้าจัดการร้านค้า'),
          ),
        ],
      ),
    );
  }
}

class ShopManagementScreen extends StatelessWidget {
  const ShopManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionScreen<AdminShopRecord>(
      title: 'จัดการร้านค้า',
      stream: AdminRepository.streamShops(),
      emptyLabel: 'ยังไม่พบข้อมูลร้านค้า',
      itemBuilder: (context, shop) => _AdminInfoCard(
        title: shop.displayName,
        subtitle: '${shop.serviceType} • ${shop.status}',
        imageUrl: shop.imageUrl,
        detailLines: <String>[
          'เจ้าของ: ${shop.ownerId}',
          if (shop.phone != null) 'โทร: ${shop.phone}',
          if (shop.email != null) 'อีเมล: ${shop.email}',
          'แหล่งข้อมูล: ${shop.collection}',
          if (shop.createdAt != null) 'อัปเดต: ${_formatDateTime(shop.createdAt!)}',
        ],
      ),
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
      itemBuilder: (context, rider) => _AdminInfoCard(
        title: rider.displayName,
        subtitle: rider.onlineReady ? 'พร้อมรับงาน' : 'ยังไม่พร้อมรับงาน',
        detailLines: <String>[
          if (rider.phone != null) 'โทร: ${rider.phone}',
          'สถานะตำแหน่ง: ${rider.locationStatus}',
          if (rider.updatedAt != null) 'อัปเดต: ${_formatDateTime(rider.updatedAt!)}',
          'UID: ${rider.id}',
        ],
      ),
    );
  }
}

class CustomerManagementScreen extends StatelessWidget {
  const CustomerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminCollectionScreen<AdminCustomerRecord>(
      title: 'จัดการลูกค้า',
      stream: AdminRepository.streamCustomers(),
      emptyLabel: 'ยังไม่พบข้อมูลลูกค้า',
      itemBuilder: (context, customer) => _AdminInfoCard(
        title: customer.displayName,
        subtitle: 'บทบาท: ${customer.role}',
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
  });

  final String title;
  final String subtitle;
  final List<String> detailLines;
  final String? imageUrl;

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
      child: Row(
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
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE65100))),
                const SizedBox(height: 8),
                ...detailLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}