enum AdminKycStatus {
  complete,
  missingId,
  invalidId,
  missingEmail,
  promptPayMismatch,
}

class AdminKycRecord {
  const AdminKycRecord({
    required this.actorType,
    required this.actorUid,
    required this.displayName,
    required this.status,
    this.verifiedNationalIdMasked = '',
    this.promptPayMasked = '',
    this.email = '',
    this.verifiedAt,
    this.verificationSource = '',
    this.branchId = '',
    this.marketId = '',
  });

  final String actorType;
  final String actorUid;
  final String displayName;
  final AdminKycStatus status;
  final String verifiedNationalIdMasked;
  final String promptPayMasked;
  final String email;
  final DateTime? verifiedAt;
  final String verificationSource;
  final String branchId;
  final String marketId;

  String get actorTypeLabel =>
      actorType == 'merchant' ? 'ร้านค้า' : actorType == 'rider' ? 'ไรเดอร์' : actorType;

  String get statusLabelTh => switch (status) {
        AdminKycStatus.complete => 'พร้อมใช้งาน',
        AdminKycStatus.missingId => 'ยังไม่ยืนยันบัตร',
        AdminKycStatus.invalidId => 'เลขบัตรไม่ถูกต้อง',
        AdminKycStatus.missingEmail => 'ไม่มีอีเมลจริง',
        AdminKycStatus.promptPayMismatch => 'บัตร ≠ PromptPay',
      };

  bool get isReadyForStatement =>
      status == AdminKycStatus.complete ||
      (status == AdminKycStatus.promptPayMismatch &&
          verifiedNationalIdMasked.isNotEmpty &&
          email.isNotEmpty);
}
