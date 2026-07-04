import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAnnouncementRecord {
  const AdminAnnouncementRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.targetApps,
    required this.recipientCount,
    required this.createdAt,
    required this.createdBy,
    this.sendEmail = false,
    this.emailDeliveryStatus,
    this.emailSentCount,
  });

  final String id;
  final String title;
  final String body;
  final List<String> targetApps;
  final int recipientCount;
  final DateTime? createdAt;
  final String? createdBy;
  final bool sendEmail;
  final String? emailDeliveryStatus;
  final int? emailSentCount;

  factory AdminAnnouncementRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawTargets = data['targetApps'];
    final targets = rawTargets is List
        ? rawTargets.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    return AdminAnnouncementRecord(
      id: doc.id,
      title: data['title']?.toString().trim() ?? '',
      body: data['body']?.toString().trim() ?? '',
      targetApps: targets,
      recipientCount: _toInt(data['recipientCount']) ?? 0,
      createdAt: _toDateTime(data['createdAt']),
      createdBy: data['createdBy']?.toString(),
      sendEmail: data['sendEmail'] == true,
      emailDeliveryStatus: data['emailDeliveryStatus']?.toString(),
      emailSentCount: _toInt(data['emailSentCount']),
    );
  }
}

class AdminAnnouncementSendResult {
  const AdminAnnouncementSendResult({
    required this.announcementId,
    required this.recipientCount,
    required this.targetApps,
    required this.sendEmail,
  });

  final String announcementId;
  final int recipientCount;
  final List<String> targetApps;
  final bool sendEmail;
}

class AdminAnnouncementSupport {
  AdminAnnouncementSupport._();

  static const String collection = 'platform_announcements';
  static const String notificationAction = 'admin_announcement';

  static const Map<String, String> targetLabels = <String, String>{
    'van1': 'ร้านค้า',
    'van2': 'ลูกค้า',
    'van3': 'ไรเดอร์',
  };

  static Stream<List<AdminAnnouncementRecord>> streamAnnouncements({
    int limit = 40,
  }) {
    return FirebaseFirestore.instance
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminAnnouncementRecord.fromSnapshot)
              .toList(growable: false),
        );
  }

  static Future<List<String>> fetchRecipientUids(String targetApp) async {
    switch (targetApp) {
      case 'van1':
        final snapshot =
            await FirebaseFirestore.instance.collection('users').get();
        return snapshot.docs
            .where((doc) => doc.data()['isAdmin'] != true)
            .map((doc) => doc.id)
            .where((uid) => uid.trim().isNotEmpty)
            .toList(growable: false);
      case 'van2':
        final snapshot = await FirebaseFirestore.instance
            .collection('customer_users')
            .get();
        return snapshot.docs
            .map((doc) => doc.id)
            .where((uid) => uid.trim().isNotEmpty)
            .toList(growable: false);
      case 'van3':
        final snapshot =
            await FirebaseFirestore.instance.collection('riders').get();
        return snapshot.docs
            .where(
              (doc) =>
                  doc.data()['registrationStatus']?.toString() == 'approved',
            )
            .map((doc) => doc.id)
            .where((uid) => uid.trim().isNotEmpty)
            .toList(growable: false);
      default:
        return const <String>[];
    }
  }

  static Future<AdminAnnouncementSendResult> publishAnnouncement({
    required String title,
    required String body,
    required List<String> targetApps,
    bool sendEmail = false,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      throw ArgumentError('กรุณากรอกหัวข้อและรายละเอียดประกาศ');
    }
    if (targetApps.isEmpty) {
      throw ArgumentError('กรุณาเลือกอย่างน้อย 1 ฝั่ง');
    }

    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'van4_admin';
    final normalizedTargets = targetApps.toSet().toList(growable: false);

    final recipientsByApp = <String, List<String>>{};
    for (final targetApp in normalizedTargets) {
      recipientsByApp[targetApp] = await fetchRecipientUids(targetApp);
    }

    final totalRecipients = recipientsByApp.values.fold<int>(
      0,
      (total, uids) => total + uids.length,
    );
    if (totalRecipients == 0) {
      throw StateError('ไม่พบผู้รับในฝั่งที่เลือก');
    }

    final announcementRef =
        FirebaseFirestore.instance.collection(collection).doc();
    await announcementRef.set(<String, dynamic>{
      'title': trimmedTitle,
      'body': trimmedBody,
      'targetApps': normalizedTargets,
      'recipientCount': totalRecipients,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': adminUid,
      'sourceApp': 'van4_admin',
      'sendEmail': sendEmail,
      if (sendEmail) 'emailDeliveryStatus': 'pending',
    });

    await _fanOutNotifications(
      announcementId: announcementRef.id,
      title: trimmedTitle,
      body: trimmedBody,
      recipientsByApp: recipientsByApp,
      adminUid: adminUid,
    );

    return AdminAnnouncementSendResult(
      announcementId: announcementRef.id,
      recipientCount: totalRecipients,
      targetApps: normalizedTargets,
      sendEmail: sendEmail,
    );
  }

  static Future<void> _fanOutNotifications({
    required String announcementId,
    required String title,
    required String body,
    required Map<String, List<String>> recipientsByApp,
    required String adminUid,
  }) async {
    final firestore = FirebaseFirestore.instance;
    const batchLimit = 400;
    var batch = firestore.batch();
    var batchCount = 0;

    Future<void> commitBatchIfNeeded({required bool force}) async {
      if (batchCount == 0) {
        return;
      }
      if (!force && batchCount < batchLimit) {
        return;
      }
      await batch.commit();
      batch = firestore.batch();
      batchCount = 0;
    }

    for (final entry in recipientsByApp.entries) {
      final targetApp = entry.key;
      for (final recipientUid in entry.value) {
        final notificationRef = firestore.collection('app_notifications').doc();
        batch.set(notificationRef, <String, dynamic>{
          'targetApp': targetApp,
          'recipientUid': recipientUid,
          'title': title,
          'body': body,
          'action': notificationAction,
          'sourceApp': 'van4_admin',
          'senderId': adminUid,
          'announcementId': announcementId,
          'read': false,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        await commitBatchIfNeeded(force: batchCount >= batchLimit);
      }
    }

    await commitBatchIfNeeded(force: true);
  }
}

int? _toInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

DateTime? _toDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}
