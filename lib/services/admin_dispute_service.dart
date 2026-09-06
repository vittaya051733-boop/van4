import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_repository.dart';
import '../models/admin_claim_request.dart';

enum AdminDisputeStage {
  open,
  awaitingEvidence,
  inReview,
  resolved,
}

class AdminDisputeItem {
  const AdminDisputeItem({
    required this.id,
    required this.stage,
    required this.title,
    required this.subtitle,
    required this.orderId,
    required this.ticket,
    this.updatedAt,
  });

  final String id;
  final AdminDisputeStage stage;
  final String title;
  final String subtitle;
  final String orderId;
  final AdminSupportTicket ticket;
  final DateTime? updatedAt;

  String get stageLabelTh => switch (stage) {
        AdminDisputeStage.open => 'เปิดใหม่',
        AdminDisputeStage.awaitingEvidence => 'รอหลักฐาน',
        AdminDisputeStage.inReview => 'กำลังตรวจ',
        AdminDisputeStage.resolved => 'ปิดแล้ว',
      };

  bool get isActive => stage != AdminDisputeStage.resolved;
}

class AdminDisputeService {
  AdminDisputeService._();

  static Stream<List<AdminDisputeItem>> streamDisputes() {
    return FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .orderBy('updatedAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => _fromTicket(AdminSupportTicket.fromDoc(doc)))
          .whereType<AdminDisputeItem>()
          .toList(growable: false);
      items.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return items;
    });
  }

  static AdminDisputeItem? _fromTicket(AdminSupportTicket ticket) {
    final isClaim =
        ticket.topicKey == AdminClaimRequest.topicKey || ticket.claimRequest != null;
    if (!isClaim) {
      return null;
    }

    AdminDisputeStage stage;
    if (ticket.isContactClosed || ticket.status == 'closed') {
      stage = AdminDisputeStage.resolved;
    } else if (ticket.hasPendingClaimRequest) {
      stage = AdminDisputeStage.open;
    } else if (ticket.status == 'awaiting_user') {
      stage = AdminDisputeStage.awaitingEvidence;
    } else {
      stage = AdminDisputeStage.inReview;
    }

    final orderId = ticket.orderId?.trim() ?? '';
    return AdminDisputeItem(
      id: ticket.id,
      stage: stage,
      title: ticket.topicLabel.trim().isEmpty ? 'เคลมสินค้า' : ticket.topicLabel.trim(),
      subtitle:
          '${ticket.sourceLabel.isNotEmpty ? ticket.sourceLabel : ticket.sourceApp} · ${ticket.status} · ${orderId.isEmpty ? 'ไม่มีออเดอร์' : '#$orderId'}',
      orderId: orderId,
      ticket: ticket,
      updatedAt: ticket.updatedAt ?? ticket.createdAt,
    );
  }
}
