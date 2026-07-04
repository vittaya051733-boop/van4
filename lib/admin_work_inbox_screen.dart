import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_image_widgets.dart';
import 'admin_internal_chat_hub_screen.dart';
import 'admin_repository.dart';
import 'admin_shop_screens.dart';
import 'admin_support_screens.dart';

enum _WorkInboxFilter {
  all,
  productReview,
  customer,
  merchant,
  rider,
}

class AdminWorkInboxScreen extends StatefulWidget {
  const AdminWorkInboxScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<AdminWorkInboxScreen> createState() => _AdminWorkInboxScreenState();
}

class _AdminWorkInboxScreenState extends State<AdminWorkInboxScreen> {
  _WorkInboxFilter _filter = _WorkInboxFilter.all;
  final Set<String> _processingReviewIds = <String>{};

  String? get _sourceApp => switch (_filter) {
        _WorkInboxFilter.customer => 'van2',
        _WorkInboxFilter.merchant => 'van1',
        _WorkInboxFilter.rider => 'van3',
        _ => null,
      };

  AdminWorkItemKind? get _kindFilter => switch (_filter) {
        _WorkInboxFilter.productReview => AdminWorkItemKind.productReview,
        _WorkInboxFilter.all => null,
        _ => AdminWorkItemKind.supportTicket,
      };

  Future<void> _approveProduct(AdminProductRecord product) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    setState(() => _processingReviewIds.add(product.id));
    try {
      await AdminRepository.approveProductReview(
        reviewId: product.id,
        adminUid: adminUid,
      );
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติ "${product.name}" — ขึ้นขายแล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingReviewIds.remove(product.id));
      }
    }
  }

  Future<void> _rejectProduct(AdminProductRecord product) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ปฏิเสธ "${product.name}"'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'เหตุผล (ไม่บังคับ)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ปฏิเสธ'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    setState(() => _processingReviewIds.add(product.id));
    try {
      await AdminRepository.rejectProductReview(
        reviewId: product.id,
        adminUid: adminUid,
        reason: reasonController.text,
      );
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธ "${product.name}" แล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $error')),
        );
      }
    } finally {
      reasonController.dispose();
      if (mounted) {
        setState(() => _processingReviewIds.remove(product.id));
      }
    }
  }

  void _openProductReview(AdminProductRecord product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminPendingProductReviewScreen(
          product: product,
          processing: _processingReviewIds.contains(product.id),
          onApprove: () => _approveProduct(product),
          onReject: () => _rejectProduct(product),
          onEdit: product.needsLowConfidenceReview
              ? () async {
                  final edited = await openAdminEditPendingReview(context, product);
                  if (edited == true && mounted) {
                    Navigator.of(context).maybePop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'แก้ไข "${product.name}" แล้ว — ยังอยู่ในคิวรอตรวจสอบ',
                        ),
                      ),
                    );
                  }
                }
              : null,
        ),
      ),
    );
  }

  void _openSupportTicket(AdminSupportTicket ticket) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminSupportTicketDetailScreen(ticket: ticket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workBody = _buildWorkInboxBody();

    final tabbed = DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFFE65100),
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFFE65100),
              tabs: const <Tab>[
                Tab(text: 'งานแอดมิน'),
                Tab(text: 'แชทแอดมิน'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                workBody,
                const AdminInternalChatHubScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return tabbed;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('งานแอดมิน'),
        bottom: const TabBar(
          tabs: <Tab>[
            Tab(text: 'งานแอดมิน'),
            Tab(text: 'แชทแอดมิน'),
          ],
        ),
      ),
      body: TabBarView(
        children: <Widget>[
          workBody,
          const AdminInternalChatHubScreen(embedded: true),
        ],
      ),
    );
  }

  Widget _buildWorkInboxBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SummaryBanner(filter: _filter),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              _FilterChip(
                label: 'ทั้งหมด',
                selected: _filter == _WorkInboxFilter.all,
                onSelected: () => setState(() => _filter = _WorkInboxFilter.all),
              ),
              _FilterChip(
                label: 'สินค้ารอตรวจ',
                selected: _filter == _WorkInboxFilter.productReview,
                onSelected: () =>
                    setState(() => _filter = _WorkInboxFilter.productReview),
              ),
              _FilterChip(
                label: 'ลูกค้า',
                selected: _filter == _WorkInboxFilter.customer,
                onSelected: () => setState(() => _filter = _WorkInboxFilter.customer),
              ),
              _FilterChip(
                label: 'ร้านค้า',
                selected: _filter == _WorkInboxFilter.merchant,
                onSelected: () => setState(() => _filter = _WorkInboxFilter.merchant),
              ),
              _FilterChip(
                label: 'ไรเดอร์',
                selected: _filter == _WorkInboxFilter.rider,
                onSelected: () => setState(() => _filter = _WorkInboxFilter.rider),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<AdminWorkInboxSnapshot>(
            stream: AdminRepositoryWorkInbox.streamWorkInbox(
              sourceApp: _sourceApp,
              kindFilter: _kindFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('โหลดงานแอดมินไม่สำเร็จ\n${snapshot.error}'),
                  ),
                );
              }

              final inbox = snapshot.data;
              final items = inbox?.items ?? const <AdminWorkItem>[];
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    'ไม่มีงานค้าง — ทุกอย่างเรียบร้อย',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (item.kind == AdminWorkItemKind.productReview &&
                      item.product != null) {
                    return _ProductReviewWorkTile(
                      product: item.product!,
                      onTap: () => _openProductReview(item.product!),
                    );
                  }
                  if (item.kind == AdminWorkItemKind.supportTicket &&
                      item.ticket != null) {
                    return AdminSupportTicketTile(
                      ticket: item.ticket!,
                      onTap: () => _openSupportTicket(item.ticket!),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.filter});

  final _WorkInboxFilter filter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminWorkInboxSnapshot>(
      stream: AdminRepositoryWorkInbox.streamWorkInbox(),
      builder: (context, snapshot) {
        final inbox = snapshot.data;
        if (inbox == null || inbox.attentionCount == 0) {
          return const SizedBox.shrink();
        }

        final parts = <String>[
          if (inbox.productReviewCount > 0)
            'สินค้ารอตรวจ ${inbox.productReviewCount}',
          if (inbox.unreadTicketCount > 0)
            'ข้อความใหม่ ${inbox.unreadTicketCount}',
        ];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.inbox_outlined, color: Color(0xFFB45309), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parts.join(' • '),
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ProductReviewWorkTile extends StatelessWidget {
  const _ProductReviewWorkTile({
    required this.product,
    required this.onTap,
  });

  final AdminProductRecord product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (product.imageUrls.isNotEmpty) ...<Widget>[
                AdminWorkInboxThumbnail(imageUrls: product.imageUrls),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _WorkKindChip(
                          label: 'สินค้ารอตรวจ',
                          background: Color(0xFFFFF7ED),
                          foreground: Color(0xFFB45309),
                        ),
                        _WorkKindChip(
                          label: 'ร้านค้า / AI',
                          background: Color(0xFFF3F4F6),
                          foreground: Color(0xFF374151),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (product.shopName?.trim().isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        product.shopName!.trim(),
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      product.aiReviewSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _WorkKindChip(
                        label: 'ต้องตรวจสอบ',
                        background: Color(0xFFFEE2E2),
                        foreground: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkKindChip extends StatelessWidget {
  const _WorkKindChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
