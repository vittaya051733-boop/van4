import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_kyc_record.dart';
import '../utils/thai_national_id.dart';

class AdminKycService {
  AdminKycService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _pickPromptPayId(Map<String, dynamic> data) {
    final nationalId = normalizeNationalId(
      data['promptPayNationalId'] ??
          data['promptPayNationalIdOrTaxId'] ??
          data['promptPayId'],
    );
    if (nationalId.length == 13) {
      return nationalId;
    }
    final phone = normalizeNationalId(data['promptPayPhoneNumber']);
    return phone;
  }

  static String _pickEmail(Map<String, dynamic> data) {
    for (final field in const <String>[
      'contactEmail',
      'email',
      'registrationEmail',
      'shopEmail',
    ]) {
      final candidate = (data[field] ?? '').toString().trim().toLowerCase();
      if (candidate.contains('@') && !isPseudoVanEmail(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  static AdminKycRecord _buildRecord({
    required String actorType,
    required String actorUid,
    required String displayName,
    required String verifiedId,
    required Map<String, dynamic> profile,
    String verificationSource = 'ocr',
    String branchId = '',
    String marketId = '',
  }) {
    final promptPayRaw = _pickPromptPayId(profile);
    final email = _pickEmail(profile);
    final verifiedDigits = normalizeNationalId(verifiedId);
    final promptPayDigits = normalizeNationalId(promptPayRaw);

    AdminKycStatus status;
    if (verifiedDigits.length != 13) {
      status = AdminKycStatus.missingId;
    } else if (!validateThaiNationalIdChecksum(verifiedDigits)) {
      status = AdminKycStatus.invalidId;
    } else if (email.isEmpty) {
      status = AdminKycStatus.missingEmail;
    } else if (promptPayDigits.length == 13 &&
        promptPayDigits != verifiedDigits) {
      status = AdminKycStatus.promptPayMismatch;
    } else {
      status = AdminKycStatus.complete;
    }

    DateTime? verifiedAt;
    final rawVerifiedAt = profile['verifiedNationalIdAt'] ?? profile['verifiedAt'];
    if (rawVerifiedAt is Timestamp) {
      verifiedAt = rawVerifiedAt.toDate();
    }

    return AdminKycRecord(
      actorType: actorType,
      actorUid: actorUid,
      displayName: displayName,
      status: status,
      verifiedNationalIdMasked: maskNationalId(verifiedDigits),
      promptPayMasked: promptPayDigits.length == 13
          ? maskNationalId(promptPayDigits)
          : (promptPayRaw.isNotEmpty ? '***${promptPayRaw.substring(promptPayRaw.length.clamp(0, 4))}' : ''),
      email: email,
      verifiedAt: verifiedAt,
      verificationSource: (profile['verifiedNationalIdSource'] ?? verificationSource)
          .toString(),
      branchId: branchId,
      marketId: marketId,
    );
  }

  static Future<AdminKycSummary> fetchSummary() async {
    final records = await fetchAll();
    return AdminKycSummary.fromRecords(records);
  }

  static Future<List<AdminKycRecord>> fetchAll() async {
    final records = <AdminKycRecord>[];

    final contractsSnap = await _firestore.collection('contracts').limit(500).get();
    for (final doc in contractsSnap.docs) {
      final data = doc.data();
      final uid = doc.id;
      final userSnap = await _firestore.collection('users').doc(uid).get();
      final userData = userSnap.data() ?? <String, dynamic>{};
      final shopSnap = await _firestore.collection('public_shops').doc(uid).get();
      final shopData = shopSnap.data() ?? <String, dynamic>{};
      final displayName = (shopData['name'] ?? shopData['shopName'] ?? userData['displayName'] ?? uid)
          .toString()
          .trim();
      final merged = <String, dynamic>{...userData, ...data};
      records.add(
        _buildRecord(
          actorType: 'merchant',
          actorUid: uid,
          displayName: displayName,
          verifiedId: (data['verifiedNationalId'] ?? '').toString(),
          profile: merged,
          branchId: (data['branchId'] ?? shopData['branchId'] ?? '').toString(),
          marketId: (shopData['marketId'] ?? '').toString(),
        ),
      );
    }

    final ridersSnap = await _firestore.collection('riders').limit(500).get();
    for (final doc in ridersSnap.docs) {
      final uid = doc.id;
      final riderData = Map<String, dynamic>.from(doc.data());
      var verifiedId = (riderData['verifiedNationalId'] ?? '').toString();
      if (normalizeNationalId(verifiedId).length != 13) {
        final reg = await _firestore.collection('rider_registrations').doc(uid).get();
        if (reg.exists) {
          riderData.addAll(reg.data() ?? <String, dynamic>{});
          verifiedId = (riderData['verifiedNationalId'] ?? verifiedId).toString();
        }
      }
      final displayName = (riderData['displayName'] ?? riderData['fullName'] ?? riderData['name'] ?? uid)
          .toString()
          .trim();
      records.add(
        _buildRecord(
          actorType: 'rider',
          actorUid: uid,
          displayName: displayName,
          verifiedId: verifiedId,
          profile: riderData,
          branchId: (riderData['branchId'] ?? '').toString(),
          marketId: (riderData['marketId'] ?? '').toString(),
        ),
      );
    }

    records.sort((a, b) {
      final statusCmp = a.status.index.compareTo(b.status.index);
      if (statusCmp != 0) {
        return statusCmp;
      }
      return a.displayName.compareTo(b.displayName);
    });
    return records;
  }
}

class AdminKycSummary {
  const AdminKycSummary({
    required this.total,
    required this.complete,
    required this.missingId,
    required this.invalidId,
    required this.missingEmail,
    required this.promptPayMismatch,
  });

  final int total;
  final int complete;
  final int missingId;
  final int invalidId;
  final int missingEmail;
  final int promptPayMismatch;

  int get notReady => total - complete;

  factory AdminKycSummary.fromRecords(List<AdminKycRecord> records) {
    var complete = 0;
    var missingId = 0;
    var invalidId = 0;
    var missingEmail = 0;
    var promptPayMismatch = 0;
    for (final record in records) {
      switch (record.status) {
        case AdminKycStatus.complete:
          complete += 1;
        case AdminKycStatus.missingId:
          missingId += 1;
        case AdminKycStatus.invalidId:
          invalidId += 1;
        case AdminKycStatus.missingEmail:
          missingEmail += 1;
        case AdminKycStatus.promptPayMismatch:
          promptPayMismatch += 1;
      }
    }
    return AdminKycSummary(
      total: records.length,
      complete: complete,
      missingId: missingId,
      invalidId: invalidId,
      missingEmail: missingEmail,
      promptPayMismatch: promptPayMismatch,
    );
  }
}
