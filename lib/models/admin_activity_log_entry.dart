import 'package:cloud_firestore/cloud_firestore.dart';

class AdminActivityLogEntry {
  const AdminActivityLogEntry({
    required this.id,
    required this.actorEmail,
    required this.actorUid,
    required this.actorRole,
    required this.branchId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.labelTh,
    this.at,
    this.category = 'general',
    this.detail = const <String, Object?>{},
  });

  final String id;
  final String actorEmail;
  final String actorUid;
  final String actorRole;
  final String branchId;
  final String action;
  final String targetType;
  final String targetId;
  final String labelTh;
  final DateTime? at;
  final String category;
  final Map<String, Object?> detail;

  String get actionLabelTh => switch (action) {
        'claim' => 'รับงาน',
        'complete' => 'เสร็จงาน',
        'fail' => 'ไม่สำเร็จ',
        'open_menu' => 'เปิดเมนู',
        'write' => 'บันทึกข้อมูล',
        'confirm_withdraw' => 'ยืนยันถอน',
        'reject_withdraw' => 'ปฏิเสธถอน',
        'close_vat_period' => 'ปิดงวด VAT',
        'export_ops_report' => 'Export Ops',
        _ => action,
      };

  static AdminActivityLogEntry fromMap(String id, Map<String, dynamic> data) {
    DateTime? at;
    final rawAt = data['at'];
    if (rawAt is Timestamp) {
      at = rawAt.toDate();
    }
    return AdminActivityLogEntry(
      id: id,
      actorEmail: data['actorEmail']?.toString() ?? '',
      actorUid: data['actorUid']?.toString() ?? '',
      actorRole: data['actorRole']?.toString() ?? '',
      branchId: data['branchId']?.toString() ?? 'central',
      action: data['action']?.toString() ?? '',
      targetType: data['targetType']?.toString() ?? '',
      targetId: data['targetId']?.toString() ?? '',
      labelTh: data['labelTh']?.toString() ?? '',
      at: at,
      category: data['category']?.toString() ?? 'general',
      detail: data['detail'] is Map
          ? Map<String, Object?>.from(data['detail'] as Map)
          : const <String, Object?>{},
    );
  }
}
