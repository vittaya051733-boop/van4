import 'package:flutter/material.dart';

import 'admin_announcement_screen.dart';
import 'admin_announcement_support.dart';
import 'admin_catalog_review_screen.dart';
import 'admin_repository.dart';
import 'admin_work_inbox_screen.dart';

/// System notifications hub: pending work + recent platform announcements.
class AdminNotificationsTab extends StatelessWidget {
  const AdminNotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text(
          'งานที่ต้องดู',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF9A3412),
              ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<AdminWorkInboxSnapshot>(
          stream: AdminRepositoryWorkInbox.streamWorkInbox(),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.hasError) {
              return _errorCard('โหลดงานแอดมินไม่สำเร็จ: ${snapshot.error}');
            }
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: <Widget>[
                _countTile(
                  context,
                  icon: Icons.smart_toy_outlined,
                  title: 'สินค้า AI รอตรวจ',
                  count: data.productReviewCount,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminWorkInboxScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _countTile(
                  context,
                  icon: Icons.support_agent_outlined,
                  title: 'ข้อความติดต่อ (ยังไม่อ่าน)',
                  count: data.unreadTicketCount,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminWorkInboxScreen(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<AdminCatalogProductRecord>>(
          stream: AdminRepository.streamPendingCatalogReviews(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            if (snapshot.hasError) {
              return _errorCard('โหลดคิวหมวดสินค้าไม่สำเร็จ');
            }
            return _countTile(
              context,
              icon: Icons.category_outlined,
              title: 'หมวดสินค้ารอแอดมิน',
              count: count,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminCatalogReviewScreen(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'ประกาศที่ส่งแล้ว',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9A3412),
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminAnnouncementScreen(),
                ),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('ส่งประกาศ'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<AdminAnnouncementRecord>>(
          stream: AdminAnnouncementSupport.streamAnnouncements(limit: 20),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _errorCard('โหลดประกาศไม่สำเร็จ: ${snapshot.error}');
            }
            final items = snapshot.data ?? const <AdminAnnouncementRecord>[];
            if (items.isEmpty) {
              return _emptyCard('ยังไม่มีประกาศ — กด "ส่งประกาศ" เพื่อแจ้ง van1/2/3');
            }
            return Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _announcementCard(item),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Widget _countTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFFE65100)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0B2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                )
              else
                const Text(
                  'ไม่มี',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _announcementCard(AdminAnnouncementRecord item) {
    final targets = item.targetApps
        .map((app) => AdminAnnouncementSupport.targetLabels[app] ?? app)
        .join(', ');
    final when = item.createdAt == null
        ? ''
        : _formatDateTime(item.createdAt!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.title.isEmpty ? '(ไม่มีหัวข้อ)' : item.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (item.body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              item.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'ไปยัง: $targets • ${item.recipientCount} คน${when.isEmpty ? '' : ' • $when'}',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB45309))),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF6B7280)),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month ${value.year} $hour:$minute';
  }
}
