import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWorkSourceType {
  AdminWorkSourceType._();

  static const String productReview = 'product_review';
  static const String supportTicket = 'support_ticket';
  static const String shopApproval = 'shop_approval';
  static const String order = 'order';
  static const String withdraw = 'withdraw';
}

class AdminWorkTaskIds {
  AdminWorkTaskIds._();

  static String docId(String sourceType, String sourceId) {
    final safe = sourceId.replaceAll('/', '_');
    final clipped = safe.length > 200 ? safe.substring(0, 200) : safe;
    return '${sourceType}_$clipped';
  }
}

class AdminWorkTask {
  const AdminWorkTask({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.branchId,
    required this.status,
    this.claimedByUid,
    this.claimedByEmail,
    this.claimedByName,
    this.claimedAt,
    this.completedByEmail,
    this.completedByUid,
    this.completedAt,
    this.failedByEmail,
    this.failedByUid,
    this.failedAt,
    this.updatedAt,
  });

  final String id;
  final String sourceType;
  final String sourceId;
  final String title;
  final String branchId;
  final String status;
  final String? claimedByUid;
  final String? claimedByEmail;
  final String? claimedByName;
  final DateTime? claimedAt;
  final String? completedByEmail;
  final String? completedByUid;
  final DateTime? completedAt;
  final String? failedByEmail;
  final String? failedByUid;
  final DateTime? failedAt;
  final DateTime? updatedAt;

  bool get isClaimed => status == 'claimed';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  String get claimedByLabel {
    final name = claimedByName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final email = claimedByEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'แอดมิน';
  }

  static AdminWorkTask fromMap(String id, Map<String, dynamic> data) {
    return AdminWorkTask(
      id: id,
      sourceType: data['sourceType']?.toString() ?? '',
      sourceId: data['sourceId']?.toString() ?? '',
      title: data['title']?.toString() ?? id,
      branchId: data['branchId']?.toString() ?? 'central',
      status: data['status']?.toString() ?? 'open',
      claimedByUid: data['claimedByUid']?.toString(),
      claimedByEmail: data['claimedByEmail']?.toString(),
      claimedByName: data['claimedByName']?.toString(),
      claimedAt: _readTime(data['claimedAt']),
      completedByEmail: data['completedByEmail']?.toString(),
      completedByUid: data['completedByUid']?.toString(),
      completedAt: _readTime(data['completedAt']),
      failedByEmail: data['failedByEmail']?.toString(),
      failedByUid: data['failedByUid']?.toString(),
      failedAt: _readTime(data['failedAt']),
      updatedAt: _readTime(data['updatedAt']),
    );
  }
}

DateTime? _readTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}
