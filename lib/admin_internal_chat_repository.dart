import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'models/admin_peer_profile.dart';

class AdminDirectoryEntry {
  const AdminDirectoryEntry({
    required this.email,
    required this.authUid,
    required this.displayName,
    required this.active,
  });

  final String email;
  final String? authUid;
  final String displayName;
  final bool active;

  factory AdminDirectoryEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AdminDirectoryEntry(
      email: doc.id,
      authUid: (data['authUid'] as String?)?.trim(),
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? data['displayName'].toString().trim()
          : doc.id,
      active: data['active'] != false,
    );
  }

  AdminPeerProfile? toPeerProfile() {
    final uid = authUid?.trim();
    if (uid == null || uid.isEmpty) {
      return null;
    }
    return AdminPeerProfile(
      uid: uid,
      displayName: displayName,
      email: email,
    );
  }
}

class AdminInternalThread {
  const AdminInternalThread({
    required this.id,
    required this.type,
    required this.title,
    required this.participantUids,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadForCurrentAdmin,
  });

  final String id;
  final String type;
  final String title;
  final List<String> participantUids;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final bool unreadForCurrentAdmin;

  bool get isTeam => type == 'team';

  factory AdminInternalThread.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String? currentUid,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final unreadMap = data['unreadByUid'];
    final unread = currentUid != null &&
        unreadMap is Map &&
        unreadMap[currentUid] == true;

    return AdminInternalThread(
      id: doc.id,
      type: (data['type'] as String?)?.trim() ?? 'dm',
      title: (data['title'] as String?)?.trim() ?? 'แชทแอดมิน',
      participantUids: ((data['participantUids'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((uid) => uid.trim().isNotEmpty)
          .toList(growable: false),
      lastMessagePreview: (data['lastMessagePreview'] as String?)?.trim(),
      lastMessageAt: data['lastMessageAt'] is Timestamp
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      unreadForCurrentAdmin: unread,
    );
  }
}

class AdminInternalAttachment {
  const AdminInternalAttachment({
    required this.name,
    required this.url,
    required this.mimeType,
  });

  final String name;
  final String url;
  final String mimeType;

  factory AdminInternalAttachment.fromMap(Map<String, dynamic> map) {
    return AdminInternalAttachment(
      name: (map['name'] as String?)?.trim() ?? 'ไฟล์',
      url: (map['url'] as String?)?.trim() ?? '',
      mimeType: (map['mimeType'] as String?)?.trim() ?? 'application/octet-stream',
    );
  }
}

class AdminInternalMessage {
  const AdminInternalMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.imageUrls,
    required this.attachments,
    required this.createdAt,
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String message;
  final List<String> imageUrls;
  final List<AdminInternalAttachment> attachments;
  final DateTime? createdAt;

  factory AdminInternalMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawAttachments = data['attachments'];
    return AdminInternalMessage(
      id: doc.id,
      senderUid: (data['senderUid'] as String?)?.trim() ?? '',
      senderName: (data['senderName'] as String?)?.trim() ?? 'แอดมิน',
      message: (data['message'] as String?)?.trim() ?? '',
      imageUrls: ((data['imageUrls'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false),
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map>()
              .map((item) => AdminInternalAttachment.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .where((item) => item.url.isNotEmpty)
              .toList(growable: false)
          : const <AdminInternalAttachment>[],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class AdminInternalChatRepository {
  AdminInternalChatRepository._();

  static const String teamThreadId = 'team';
  static const int maxImages = 4;
  static const int maxFiles = 2;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  static String dmThreadIdFor(String uidA, String uidB) {
    final sorted = <String>[uidA.trim(), uidB.trim()]..sort();
    return 'dm_${sorted.join('_')}';
  }

  static Stream<List<AdminDirectoryEntry>> streamAdminDirectory() {
    return _firestore.collection('admins').snapshots().map((snapshot) {
      final currentEmail = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
      return snapshot.docs
          .map(AdminDirectoryEntry.fromDoc)
          .where((entry) => entry.active)
          .where((entry) => currentEmail == null || entry.email != currentEmail)
          .toList(growable: false)
        ..sort((left, right) => left.displayName.compareTo(right.displayName));
    });
  }

  static Stream<List<AdminInternalThread>> streamRecentThreads() {
    final currentUid = _currentUid;
    return _firestore
        .collection('admin_internal_threads')
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => AdminInternalThread.fromDoc(
                  doc,
                  currentUid: currentUid,
                ),
              )
              .toList(growable: false),
        );
  }

  static Stream<List<AdminInternalMessage>> streamMessages(String threadId) {
    return _firestore
        .collection('admin_internal_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(300)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminInternalMessage.fromDoc)
              .toList(growable: false),
        );
  }

  static Future<String> ensureTeamThread() async {
    final ref = _firestore.collection('admin_internal_threads').doc(teamThreadId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(<String, dynamic>{
        'type': 'team',
        'title': 'ห้องทีมแอดมิน',
        'participantUids': const <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': 'เริ่มแชททีมแอดมิน',
      });
    }
    return teamThreadId;
  }

  static Future<String> ensureDmThread(AdminPeerProfile peer) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      throw StateError('กรุณาเข้าสู่ระบบ');
    }
    final threadId = dmThreadIdFor(currentUid, peer.uid);
    final ref = _firestore.collection('admin_internal_threads').doc(threadId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(<String, dynamic>{
        'type': 'dm',
        'title': peer.displayName,
        'participantUids': <String>[currentUid, peer.uid],
        'participantEmails': <String>[
          if (FirebaseAuth.instance.currentUser?.email != null)
            FirebaseAuth.instance.currentUser!.email!.trim().toLowerCase(),
          if (peer.email != null) peer.email!.trim().toLowerCase(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': 'เริ่มแชทส่วนตัว',
      });
    }
    return threadId;
  }

  static Future<void> markThreadRead(String threadId) async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      return;
    }
    await _firestore.collection('admin_internal_threads').doc(threadId).set(
      <String, dynamic>{
        'unreadByUid.$currentUid': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> sendMessage({
    required String threadId,
    required String message,
    List<String> imageLocalPaths = const <String>[],
    List<({String path, String name, String? mimeType})> fileLocalItems =
        const <({String path, String name, String? mimeType})>[],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final senderUid = user?.uid;
    if (senderUid == null) {
      throw StateError('กรุณาเข้าสู่ระบบ');
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty && imageLocalPaths.isEmpty && fileLocalItems.isEmpty) {
      throw ArgumentError('กรุณาระบุข้อความหรือแนบไฟล์');
    }

    final imageUrls = await _uploadImages(threadId, imageLocalPaths);
    final attachments = await _uploadFiles(threadId, fileLocalItems);

    final preview = trimmed.isNotEmpty
        ? (trimmed.length <= 120 ? trimmed : '${trimmed.substring(0, 117)}...')
        : imageUrls.isNotEmpty
            ? '[รูปภาพ ${imageUrls.length} ไฟล์]'
            : '[ไฟล์ ${attachments.length} รายการ]';

    final threadRef = _firestore.collection('admin_internal_threads').doc(threadId);
    final messageRef = threadRef.collection('messages').doc();
    final threadSnap = await threadRef.get();
    final participantUids = ((threadSnap.data()?['participantUids'] as List?) ??
            const <dynamic>[])
        .map((item) => item.toString())
        .where((uid) => uid.trim().isNotEmpty)
        .toList(growable: false);

    final unreadUpdates = <String, dynamic>{};
    for (final uid in participantUids) {
      if (uid != senderUid) {
        unreadUpdates['unreadByUid.$uid'] = true;
      }
    }
    unreadUpdates['unreadByUid.$senderUid'] = false;

    final batch = _firestore.batch();
    batch.set(messageRef, <String, dynamic>{
      'senderUid': senderUid,
      'senderEmail': user?.email,
      'senderName': user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : (user?.email ?? 'แอดมิน'),
      'message': trimmed,
      'imageUrls': imageUrls,
      'attachments': attachments
          .map(
            (item) => <String, dynamic>{
              'name': item.name,
              'url': item.url,
              'mimeType': item.mimeType,
            },
          )
          .toList(growable: false),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      threadRef,
      <String, dynamic>{
        'lastMessagePreview': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderUid': senderUid,
        ...unreadUpdates,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<List<String>> _uploadImages(
    String threadId,
    List<String> localPaths,
  ) async {
    if (localPaths.isEmpty) {
      return <String>[];
    }
    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    for (final path in localPaths.take(maxImages)) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final storagePath =
          'admin_internal_chat/$threadId/images/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final ref = storage.ref().child(storagePath);
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  static Future<List<AdminInternalAttachment>> _uploadFiles(
    String threadId,
    List<({String path, String name, String? mimeType})> items,
  ) async {
    if (items.isEmpty) {
      return <AdminInternalAttachment>[];
    }
    final storage = FirebaseStorage.instance;
    final attachments = <AdminInternalAttachment>[];
    for (final item in items.take(maxFiles)) {
      final file = File(item.path);
      if (!file.existsSync()) {
        continue;
      }
      final safeName = item.name.trim().isEmpty
          ? file.uri.pathSegments.last
          : item.name.trim();
      final storagePath =
          'admin_internal_chat/$threadId/files/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final ref = storage.ref().child(storagePath);
      await ref.putFile(file);
      attachments.add(
        AdminInternalAttachment(
          name: safeName,
          url: await ref.getDownloadURL(),
          mimeType: item.mimeType?.trim().isNotEmpty == true
              ? item.mimeType!.trim()
              : 'application/octet-stream',
        ),
      );
    }
    return attachments;
  }

  static Future<AdminPeerProfile?> fetchPeerProfile(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final presence = await _firestore.collection('admin_presence').doc(trimmed).get();
    if (presence.exists) {
      final data = presence.data() ?? <String, dynamic>{};
      return AdminPeerProfile(
        uid: trimmed,
        displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
            ? data['displayName'].toString().trim()
            : 'แอดมิน',
        email: (data['email'] as String?)?.trim(),
      );
    }

    final admins = await _firestore
        .collection('admins')
        .where('authUid', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (admins.docs.isNotEmpty) {
      final doc = admins.docs.first;
      final data = doc.data();
      return AdminPeerProfile(
        uid: trimmed,
        displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
            ? data['displayName'].toString().trim()
            : doc.id,
        email: doc.id,
      );
    }
    return AdminPeerProfile(uid: trimmed, displayName: 'แอดมิน');
  }

  static AdminPeerProfile? peerFromDmThread(
    AdminInternalThread thread, {
    required String currentUid,
  }) {
    final otherUid = thread.participantUids.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) {
      return null;
    }
    return AdminPeerProfile(uid: otherUid, displayName: thread.title);
  }
}
