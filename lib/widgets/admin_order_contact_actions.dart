import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_peer_chat_screen.dart';
import '../admin_image_widgets.dart';
import '../admin_repository.dart';
import '../models/admin_claim_request.dart';
import '../models/admin_peer_profile.dart';
import '../utils/admin_support_call_launcher.dart';

class AdminOrderContactActions extends StatelessWidget {
  const AdminOrderContactActions({
    super.key,
    required this.order,
    this.compact = false,
    this.pendingClaimTicketId,
    this.onOpenClaimTicket,
  });

  final AdminOrderRecord order;
  final bool compact;
  final String? pendingClaimTicketId;
  final VoidCallback? onOpenClaimTicket;

  Future<void> _callCustomer(BuildContext context) async {
    final customerId = order.customerId?.trim();
    if (customerId == null || customerId.isEmpty) {
      _snack(context, 'ไม่พบ UID ลูกค้า');
      return;
    }
    final customer = await AdminRepository.fetchCustomerByUid(customerId);
    if (!context.mounted) {
      return;
    }
    await AdminSupportCallLauncher.startVoiceCallToPeer(
      context: context,
      peer: AdminPeerProfile(
        uid: customerId,
        displayName: customer?.displayName ?? order.customerName ?? 'ลูกค้า',
        email: customer?.email,
        photoUrl: null,
      ),
      phoneNumber: customer?.phone,
      sourceApp: 'van2',
    );
  }

  Future<void> _chatShop(BuildContext context) async {
    final shopOwnerId = order.shopOwnerId?.trim();
    if (shopOwnerId == null || shopOwnerId.isEmpty) {
      _snack(context, 'ไม่พบ UID ร้านค้า');
      return;
    }
    final merchant = await AdminRepository.fetchMerchantByUid(shopOwnerId);
    if (!context.mounted) {
      return;
    }
    final adminUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (adminUid != null && adminUid == shopOwnerId) {
      _snack(
        context,
        'บัญชีแอดมินตรงกับร้านในออเดอร์ — ใช้บัญชี van4 แอดมินแยกจาก van1 ร้าน',
      );
      return;
    }
    final orderCode = order.orderCode?.trim();
    final contextLabel = orderCode != null && orderCode.isNotEmpty
        ? 'ออเดอร์ $orderCode • เคลม'
        : 'ออเดอร์ ${order.id.substring(0, 6)} • เคลม';
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminPeerChatScreen(
          peer: AdminPeerProfile(
            uid: shopOwnerId,
            displayName: merchant?.displayName ?? order.shopName ?? 'ร้านค้า',
            email: merchant?.email,
            photoUrl: null,
          ),
          orderId: order.id,
          orderCode: orderCode,
          contextLabel: contextLabel,
          phoneNumber: merchant?.phone,
          sourceApp: 'van1',
        ),
      ),
    );
  }

  Future<void> _callShop(BuildContext context) async {
    final shopOwnerId = order.shopOwnerId?.trim();
    if (shopOwnerId == null || shopOwnerId.isEmpty) {
      _snack(context, 'ไม่พบ UID ร้านค้า');
      return;
    }
    final merchant = await AdminRepository.fetchMerchantByUid(shopOwnerId);
    if (!context.mounted) {
      return;
    }
    final phone = merchant?.phone?.trim();
    try {
      await AdminSupportCallLauncher.startVoiceCallToPeer(
        context: context,
        peer: AdminPeerProfile(
          uid: shopOwnerId,
          displayName: merchant?.displayName ?? order.shopName ?? 'ร้านค้า',
          email: merchant?.email,
          photoUrl: null,
        ),
        phoneNumber: phone,
        sourceApp: 'van1',
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      if (phone != null && phone.isNotEmpty) {
        await _dialPhone(context, phone);
      } else {
        _snack(context, 'โทรร้านไม่สำเร็จ — ไม่มีเบอร์สำรอง');
      }
    }
  }

  Future<void> _dialPhone(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        _snack(context, 'เปิดแอปโทรไม่ได้');
      }
    }
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (compact)
        OutlinedButton.icon(
          onPressed: () => _callCustomer(context),
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('โทรลูกค้า'),
        )
      else
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _callCustomer(context),
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('โทรลูกค้า'),
          ),
        ),
      if (compact)
        OutlinedButton.icon(
          onPressed: () => _chatShop(context),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('แชทร้าน'),
        )
      else
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _chatShop(context),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('แชทร้าน'),
          ),
        ),
      if (compact)
        OutlinedButton.icon(
          onPressed: () => _callShop(context),
          icon: const Icon(Icons.storefront_outlined, size: 18),
          label: const Text('โทรร้าน'),
        )
      else
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _callShop(context),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('โทรร้าน'),
          ),
        ),
      if (pendingClaimTicketId != null && onOpenClaimTicket != null)
        if (compact)
          OutlinedButton.icon(
            onPressed: onOpenClaimTicket,
            icon: const Icon(Icons.inbox_outlined, size: 18),
            label: const Text('ตั๋วเคลม'),
          )
        else
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onOpenClaimTicket,
              icon: const Icon(Icons.inbox_outlined, size: 18),
              label: const Text('ตั๋วขอเคลม'),
            ),
          ),
    ];

    if (compact) {
      return Wrap(spacing: 8, runSpacing: 8, children: children);
    }
    return Row(
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    );
  }
}

class AdminClaimRequestCard extends StatelessWidget {
  const AdminClaimRequestCard({
    super.key,
    required this.claimRequest,
    this.onResolve,
    this.showResolveButton = true,
  });

  final AdminClaimRequest claimRequest;
  final VoidCallback? onResolve;
  final bool showResolveButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'คำขอเคลม — ${claimRequest.reasonLabelText}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...claimRequest.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  AdminSafeAvatar(
                    imageUrl: item.imageUrl,
                    size: 40,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} x${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showResolveButton && onResolve != null && claimRequest.isPending) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: onResolve,
                child: const Text('ดำเนินการเคลม'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
