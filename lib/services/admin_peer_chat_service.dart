import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_peer_profile.dart';
import '../models/admin_peer_chat_message.dart';
import 'admin_chat_cache_service.dart';
import 'admin_storage_helper.dart';
class AdminPeerChatService {
  AdminPeerChatService._();

  static const String _usersCollection = 'users';

  static String chatIdFor(String uidA, String uidB) {
    if (uidA.trim() == uidB.trim()) {
      return 'chat_${uidA.trim()}_${uidB.trim()}';
    }
    final sorted = <String>[uidA, uidB]..sort();
    return 'chat_${sorted.join('_')}';
  }

  static void assertDistinctPeers(AdminPeerProfile a, AdminPeerProfile b) {
    if (a.uid.trim() == b.uid.trim()) {
      throw StateError(
        'บัญชีแอดมินตรงกับร้านในออเดอร์ — ไม่สามารถเปิดแชทกับตัวเองได้',
      );
    }
  }

  /// สร้าง/ซ่อมห้องแชท (ต้องมี participants ก่อน update ตาม Firestore rules)
  static Future<String> prepareChatRoom({
    required AdminPeerProfile admin,
    required AdminPeerProfile peer,
    String? orderId,
    String? orderCode,
  }) async {
    assertDistinctPeers(admin, peer);
    final chatId = chatIdFor(admin.uid, peer.uid);
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await _ensureChatDocument(
      chatDoc,
      sender: admin,
      target: peer,
      orderId: orderId,
      orderCode: orderCode,
    );
    await markRead(owner: admin, peer: peer);
    return chatId;
  }

  static Stream<List<AdminPeerChatMessage>> streamMessages(String chatId) {
    return Stream<List<AdminPeerChatMessage>>.multi((controller) async {
      try {
        final cached = await AdminChatCacheService.instance.readPeerMessages(chatId);
        if (cached.isNotEmpty && !controller.isClosed) {
          controller.add(cached);
        }
      } catch (error, stack) {
        debugPrint('Peer chat cache read failed: $error\n$stack');
      }

      final subscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(200)
          .snapshots()
          .listen(
            (snapshot) {
              final messages = snapshot.docs
                  .map(AdminPeerChatMessage.fromDoc)
                  .toList(growable: false);
              unawaited(
                AdminChatCacheService.instance.writePeerMessages(chatId, messages),
              );
              if (!controller.isClosed) {
                controller.add(messages);
              }
            },
            onError: controller.addError,
          );

      controller.onCancel = () async {
        await subscription.cancel();
      };
    });
  }

  static Future<void> bindOrderContext({
    required AdminPeerProfile admin,
    required AdminPeerProfile peer,
    required String orderId,
    String? orderCode,
  }) async {
    await prepareChatRoom(
      admin: admin,
      peer: peer,
      orderId: orderId,
      orderCode: orderCode,
    );
  }

  static Future<void> sendText({
    required AdminPeerProfile sender,
    required AdminPeerProfile target,
    required String text,
    String? orderId,
    String? orderCode,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    assertDistinctPeers(sender, target);
    final chatId = chatIdFor(sender.uid, target.uid);
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await _ensureChatDocument(
      chatDoc,
      sender: sender,
      target: target,
      orderId: orderId,
      orderCode: orderCode,
    );

    final messageRef = chatDoc.collection('messages').doc();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );
    await messageRef.set(<String, dynamic>{
      'senderId': sender.uid,
      'senderName': sender.displayName,
      'receiverId': target.uid,
      'type': 'text',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });

    await _updateChatSummary(
      chatDoc,
      lastMessage: trimmed,
      lastMessageType: 'text',
      sender: sender,
      target: target,
    );
  }

  static Future<void> sendImage({
    required AdminPeerProfile sender,
    required AdminPeerProfile target,
    required File file,
    String? orderId,
    String? orderCode,
  }) async {
    assertDistinctPeers(sender, target);
    final chatId = chatIdFor(sender.uid, target.uid);
    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    await _ensureChatDocument(
      chatDoc,
      sender: sender,
      target: target,
      orderId: orderId,
      orderCode: orderCode,
    );

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'image.jpg';
    await AdminStorageHelper.ensureUploadReady();
    final storageRef = AdminStorageHelper.instance.ref().child(
      'chat_uploads/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    await storageRef.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final downloadUrl = await storageRef.getDownloadURL();

    const summaryText = 'ส่งรูปภาพ';
    final messageRef = chatDoc.collection('messages').doc();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );
    await messageRef.set(<String, dynamic>{
      'senderId': sender.uid,
      'senderName': sender.displayName,
      'receiverId': target.uid,
      'type': 'image',
      'text': summaryText,
      'mediaUrl': downloadUrl,
      'fileName': fileName,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
    });

    await _updateChatSummary(
      chatDoc,
      lastMessage: summaryText,
      lastMessageType: 'image',
      sender: sender,
      target: target,
    );
  }

  static Future<void> markRead({
    required AdminPeerProfile owner,
    required AdminPeerProfile peer,
  }) async {
    assertDistinctPeers(owner, peer);
    final chatDoc = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatIdFor(owner.uid, peer.uid));
    final snap = await chatDoc.get();
    if (!snap.exists) {
      return;
    }
    final participants = snap.data()?['participants'];
    if (participants is! List || !participants.contains(owner.uid)) {
      return;
    }

    final ownerFriendRef = FirebaseFirestore.instance
        .collection(_usersCollection)
        .doc(owner.uid)
        .collection('friends')
        .doc(peer.uid);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      chatDoc,
      <String, dynamic>{
        'unreadCounts.${owner.uid}': 0,
        'lastReadAt.${owner.uid}': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      ownerFriendRef,
      <String, dynamic>{
        'uid': peer.uid,
        ..._profilePayload(peer),
        'unreadCount': 0,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<AdminPeerProfile> currentAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('กรุณาเข้าสู่ระบบก่อนแชท');
    }
    return AdminPeerProfile(
      uid: user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.trim().isNotEmpty == true ? user.email!.trim() : 'แอดมิน'),
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  static Map<String, dynamic> _profilePayload(AdminPeerProfile profile) {
    return <String, dynamic>{
      'displayName': profile.displayName,
      if (profile.email != null && profile.email!.isNotEmpty) 'email': profile.email,
      if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
        'photoUrl': profile.photoUrl,
    };
  }

  static Future<void> _ensureChatDocument(
    DocumentReference<Map<String, dynamic>> chatDoc, {
    required AdminPeerProfile sender,
    required AdminPeerProfile target,
    String? orderId,
    String? orderCode,
  }) async {
    assertDistinctPeers(sender, target);
    final payload = <String, dynamic>{
      'participants': <String>[sender.uid, target.uid],
      'participantProfiles': <String, dynamic>{
        sender.uid: _profilePayload(sender),
        target.uid: _profilePayload(target),
      },
      'participantNames': <String, dynamic>{
        sender.uid: sender.displayName,
        target.uid: target.displayName,
      },
      'unreadCounts': <String, dynamic>{
        sender.uid: 0,
        target.uid: 0,
      },
      if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId.trim(),
      if (orderCode != null && orderCode.trim().isNotEmpty)
        'orderCode': orderCode.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final snap = await chatDoc.get();
    if (!snap.exists) {
      await chatDoc.set(payload);
      return;
    }

    final existingParticipants = snap.data()?['participants'];
    final senderAllowed = existingParticipants is List &&
        existingParticipants.contains(sender.uid);
    if (!senderAllowed) {
      try {
        await chatDoc.delete();
      } catch (_) {
        throw StateError(
          'ห้องแชทเดิมเสียหาย (ไม่มี participants) — ลบเอกสาร chats/${chatDoc.id} ใน Firebase แล้วลองใหม่',
        );
      }
      await chatDoc.set(payload);
      return;
    }

    await chatDoc.set(payload, SetOptions(merge: true));
  }

  static Future<void> _updateChatSummary(
    DocumentReference<Map<String, dynamic>> chatDoc, {
    required String lastMessage,
    required String lastMessageType,
    required AdminPeerProfile sender,
    required AdminPeerProfile target,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final senderFriendRef = firestore
        .collection(_usersCollection)
        .doc(sender.uid)
        .collection('friends')
        .doc(target.uid);
    final targetFriendRef = firestore
        .collection(_usersCollection)
        .doc(target.uid)
        .collection('friends')
        .doc(sender.uid);

    final batch = firestore.batch();
    batch.set(
      chatDoc,
      <String, dynamic>{
        'lastMessage': lastMessage,
        'lastMessageType': lastMessageType,
        'lastMessageSender': sender.uid,
        'lastSenderId': sender.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.${sender.uid}': 0,
        'unreadCounts.${target.uid}': FieldValue.increment(1),
        'lastReadAt.${sender.uid}': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      senderFriendRef,
      <String, dynamic>{
        'uid': target.uid,
        ..._profilePayload(target),
        'lastMessage': lastMessage,
        'lastActivity': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    try {
      await targetFriendRef.set(
        <String, dynamic>{
          'uid': sender.uid,
          ..._profilePayload(sender),
          'lastMessage': lastMessage,
          'lastActivity': FieldValue.serverTimestamp(),
          'unreadCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException {
      // unread ยังอยู่ที่ chats.unreadCounts แม้ preview ฝั่งคู่สนทนาเขียนไม่ได้
    }
  }
}
