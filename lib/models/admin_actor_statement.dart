import 'package:cloud_firestore/cloud_firestore.dart';

class AdminActorStatement {
  const AdminActorStatement({
    required this.id,
    required this.actorType,
    required this.actorUid,
    required this.periodId,
    required this.displayName,
    required this.recipientEmail,
    required this.status,
    this.periodLabelTh = '',
    this.verifiedNationalIdMasked = '',
    this.summary = const AdminActorStatementSummary(),
    this.pdfStoragePath = '',
    this.skipReason = '',
    this.emailError = '',
    this.generatedAt,
    this.emailSentAt,
    this.updatedAt,
  });

  final String id;
  final String actorType;
  final String actorUid;
  final String periodId;
  final String periodLabelTh;
  final String displayName;
  final String recipientEmail;
  final String verifiedNationalIdMasked;
  final AdminActorStatementSummary summary;
  final String pdfStoragePath;
  final String status;
  final String skipReason;
  final String emailError;
  final DateTime? generatedAt;
  final DateTime? emailSentAt;
  final DateTime? updatedAt;

  String get actorTypeLabel =>
      actorType == 'merchant' ? 'ร้านค้า' : actorType == 'rider' ? 'ไรเดอร์' : actorType;

  String get skipReasonLabelTh {
    switch (skipReason) {
      case 'missing_or_invalid_verified_national_id':
        return 'ไม่มีเลขบัตรที่ยืนยัน';
      case 'cannot_derive_pdf_password':
        return 'สร้างรหัสผ่าน PDF ไม่ได้';
      case 'missing_recipient_email':
        return 'ไม่มีอีเมลผู้รับ';
      case 'already_emailed':
        return 'ส่งอีเมลแล้ว';
      default:
        return skipReason;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'emailed':
        return 'ส่งอีเมลแล้ว';
      case 'generated':
        return 'สร้าง PDF แล้ว';
      case 'skipped':
        return 'ข้าม';
      case 'failed':
        return 'ล้มเหลว';
      default:
        return status;
    }
  }

  factory AdminActorStatement.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final summaryMap = data['summary'];
    return AdminActorStatement(
      id: doc.id,
      actorType: (data['actorType'] ?? '').toString(),
      actorUid: (data['actorUid'] ?? '').toString(),
      periodId: (data['periodId'] ?? '').toString(),
      periodLabelTh: (data['periodLabelTh'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      recipientEmail: (data['recipientEmail'] ?? '').toString(),
      verifiedNationalIdMasked:
          (data['verifiedNationalIdMasked'] ?? '').toString(),
      summary: summaryMap is Map<String, dynamic>
          ? AdminActorStatementSummary.fromMap(summaryMap)
          : const AdminActorStatementSummary(),
      pdfStoragePath: (data['pdfStoragePath'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      skipReason: (data['skipReason'] ?? '').toString(),
      emailError: (data['emailError'] ?? '').toString(),
      generatedAt: _readDate(data['generatedAt']),
      emailSentAt: _readDate(data['emailSentAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}

class AdminActorStatementSummary {
  const AdminActorStatementSummary({
    this.openingBalance = 0,
    this.creditsIn = 0,
    this.debitsOut = 0,
    this.closingBalance = 0,
    this.withdrawTotal = 0,
    this.withdrawCount = 0,
    this.lineCount = 0,
  });

  final double openingBalance;
  final double creditsIn;
  final double debitsOut;
  final double closingBalance;
  final double withdrawTotal;
  final int withdrawCount;
  final int lineCount;

  factory AdminActorStatementSummary.fromMap(Map<String, dynamic> map) {
    double readMoney(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse('$value') ?? 0;
    }

    return AdminActorStatementSummary(
      openingBalance: readMoney(map['openingBalance']),
      creditsIn: readMoney(map['creditsIn']),
      debitsOut: readMoney(map['debitsOut']),
      closingBalance: readMoney(map['closingBalance']),
      withdrawTotal: readMoney(map['withdrawTotal']),
      withdrawCount: (map['withdrawCount'] as num?)?.toInt() ?? 0,
      lineCount: (map['lineCount'] as num?)?.toInt() ?? 0,
    );
  }
}
