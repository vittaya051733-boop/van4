import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPeerChatMessage {
  const AdminPeerChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.fileName,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String type;
  final String? text;
  final String? mediaUrl;
  final String? fileName;
  final DateTime? createdAt;

  factory AdminPeerChatMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdTs = data['createdAt'];
    return AdminPeerChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      fileName: data['fileName'] as String?,
      createdAt: createdTs is Timestamp ? createdTs.toDate() : null,
    );
  }
}
