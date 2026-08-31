import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../utils/guarded_functions.dart';

Map<String, dynamic>? _readMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

double _readMoney(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

DateTime? _readTimestamp(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

class AdminCreditOverview {
  const AdminCreditOverview({
    required this.merchantWalletCount,
    required this.merchantCreditTotal,
    required this.merchantWithdrawableTotal,
    required this.merchantLockedTotal,
    required this.riderCount,
    required this.riderCreditTotal,
    required this.shopScheduledCount,
    required this.shopHeldCount,
    required this.riderScheduledCount,
    required this.riderHeldCount,
  });

  final int merchantWalletCount;
  final double merchantCreditTotal;
  final double merchantWithdrawableTotal;
  final double merchantLockedTotal;
  final int riderCount;
  final double riderCreditTotal;
  final int shopScheduledCount;
  final int shopHeldCount;
  final int riderScheduledCount;
  final int riderHeldCount;

  factory AdminCreditOverview.fromMap(Map<String, dynamic> data) {
    final merchant = _readMap(data['merchant']) ?? const <String, dynamic>{};
    final rider = _readMap(data['rider']) ?? const <String, dynamic>{};
    final pending = _readMap(data['pendingReleases']) ?? const <String, dynamic>{};
    return AdminCreditOverview(
      merchantWalletCount: _readInt(merchant['walletCount']),
      merchantCreditTotal: _readMoney(merchant['creditTotal']),
      merchantWithdrawableTotal: _readMoney(merchant['withdrawableTotal']),
      merchantLockedTotal: _readMoney(merchant['lockedTotal']),
      riderCount: _readInt(rider['riderCount']),
      riderCreditTotal: _readMoney(rider['creditTotal']),
      shopScheduledCount: _readInt(pending['shopScheduledCount']),
      shopHeldCount: _readInt(pending['shopHeldCount']),
      riderScheduledCount: _readInt(pending['riderScheduledCount']),
      riderHeldCount: _readInt(pending['riderHeldCount']),
    );
  }
}

class AdminMerchantWalletRow {
  const AdminMerchantWalletRow({
    required this.uid,
    required this.totalCredit,
    required this.withdrawableCredit,
    required this.lockedCredit,
    this.displayName,
  });

  final String uid;
  final double totalCredit;
  final double withdrawableCredit;
  final double lockedCredit;
  final String? displayName;

  factory AdminMerchantWalletRow.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminMerchantWalletRow(
      uid: doc.id,
      totalCredit: _readMoney(data['totalCredit']),
      withdrawableCredit: _readMoney(data['withdrawableCredit']),
      lockedCredit: _readMoney(data['lockedCredit']),
    );
  }
}

class AdminMerchantWalletSnapshotDetail {
  const AdminMerchantWalletSnapshotDetail({
    required this.totalCredit,
    required this.withdrawableCredit,
    required this.lockedCredit,
    required this.omiseWithdrawableCredit,
    required this.omiseLockedCredit,
    required this.omisePendingCredit,
    required this.canWithdraw,
    required this.contractStatus,
    required this.isContractCancelled,
  });

  final double totalCredit;
  final double withdrawableCredit;
  final double lockedCredit;
  final double omiseWithdrawableCredit;
  final double omiseLockedCredit;
  final double omisePendingCredit;
  final bool canWithdraw;
  final String contractStatus;
  final bool isContractCancelled;

  factory AdminMerchantWalletSnapshotDetail.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return AdminMerchantWalletSnapshotDetail(
      totalCredit: _readMoney(map['totalCredit']),
      withdrawableCredit: _readMoney(map['withdrawableCredit']),
      lockedCredit: _readMoney(map['lockedCredit']),
      omiseWithdrawableCredit: _readMoney(map['omiseWithdrawableCredit']),
      omiseLockedCredit: _readMoney(map['omiseLockedCredit']),
      omisePendingCredit: _readMoney(map['omisePendingCredit']),
      canWithdraw: map['canWithdraw'] == true,
      contractStatus: map['contractStatus']?.toString() ?? 'active',
      isContractCancelled: map['isContractCancelled'] == true,
    );
  }
}

class AdminPendingReleaseOrder {
  const AdminPendingReleaseOrder({
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.amount,
    this.holdReason,
  });

  final String orderId;
  final String orderCode;
  final String status;
  final double amount;
  final String? holdReason;

  factory AdminPendingReleaseOrder.fromMap(Map<String, dynamic> raw) {
    return AdminPendingReleaseOrder(
      orderId: raw['orderId']?.toString() ?? '',
      orderCode: raw['orderCode']?.toString() ?? '',
      status: raw['status']?.toString() ?? '',
      amount: _readMoney(raw['amount']),
      holdReason: raw['holdReason']?.toString(),
    );
  }
}

class AdminActorWalletSnapshot {
  const AdminActorWalletSnapshot({
    required this.uid,
    required this.actorType,
    required this.displayName,
    required this.creditTotal,
    required this.availableBalance,
    required this.pendingWithdrawTotal,
    required this.merchantWallet,
    required this.pendingReleases,
  });

  final String uid;
  final String actorType;
  final String displayName;
  final double creditTotal;
  final double availableBalance;
  final double pendingWithdrawTotal;
  final AdminMerchantWalletSnapshotDetail? merchantWallet;
  final List<AdminPendingReleaseOrder> pendingReleases;

  factory AdminActorWalletSnapshot.fromMap(Map<String, dynamic> data) {
    final releasesRaw = data['pendingReleases'];
    final releases = releasesRaw is List
        ? releasesRaw
            .whereType<Map>()
            .map((item) => AdminPendingReleaseOrder.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <AdminPendingReleaseOrder>[];

    return AdminActorWalletSnapshot(
      uid: data['uid']?.toString() ?? '',
      actorType: data['actorType']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      creditTotal: _readMoney(data['creditTotal']),
      availableBalance: _readMoney(data['availableBalance']),
      pendingWithdrawTotal: _readMoney(data['pendingWithdrawTotal']),
      merchantWallet: data['merchantWallet'] is Map
          ? AdminMerchantWalletSnapshotDetail.fromMap(
              Map<String, dynamic>.from(data['merchantWallet'] as Map),
            )
          : null,
      pendingReleases: releases,
    );
  }
}

class AdminCreditLedgerItem {
  const AdminCreditLedgerItem({
    required this.id,
    required this.amount,
    required this.type,
    this.reason,
    this.note,
    this.orderId,
    this.timestamp,
  });

  final String id;
  final double amount;
  final String type;
  final String? reason;
  final String? note;
  final String? orderId;
  final DateTime? timestamp;

  factory AdminCreditLedgerItem.fromMap(Map<String, dynamic> raw) {
    return AdminCreditLedgerItem(
      id: raw['id']?.toString() ?? '',
      amount: _readMoney(raw['amount']),
      type: raw['type']?.toString() ?? '',
      reason: raw['reason']?.toString(),
      note: raw['note']?.toString(),
      orderId: raw['orderId']?.toString(),
      timestamp: _readTimestamp(raw['timestamp']),
    );
  }
}

class AdminCreditAdjustResult {
  const AdminCreditAdjustResult({
    required this.success,
    required this.duplicate,
    required this.creditId,
    required this.beforeBalance,
    required this.afterBalance,
    required this.amount,
  });

  final bool success;
  final bool duplicate;
  final String creditId;
  final double beforeBalance;
  final double afterBalance;
  final double amount;

  factory AdminCreditAdjustResult.fromMap(Map<String, dynamic> data) {
    return AdminCreditAdjustResult(
      success: data['success'] == true,
      duplicate: data['duplicate'] == true,
      creditId: data['creditId']?.toString() ?? '',
      beforeBalance: _readMoney(data['beforeBalance']),
      afterBalance: _readMoney(data['afterBalance'] ?? data['creditTotal']),
      amount: _readMoney(data['amount']),
    );
  }
}

class AdminCreditService {
  AdminCreditService._();

  static const _uuid = Uuid();

  static Future<Map<String, dynamic>> _call(
    String name, {
    Map<String, dynamic>? parameters,
  }) async {
    final result = await GuardedFunctions.call(name, parameters: parameters);
    if (result.data is Map) {
      return Map<String, dynamic>.from(result.data as Map);
    }
    return <String, dynamic>{};
  }

  static Future<AdminCreditOverview> fetchOverview() async {
    final data = await _call('adminGetCreditOverview');
    return AdminCreditOverview.fromMap(data);
  }

  static Stream<List<AdminMerchantWalletRow>> streamMerchantWallets() {
    return FirebaseFirestore.instance
        .collection('merchant_wallets')
        .orderBy('totalCredit', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminMerchantWalletRow.fromDoc)
              .toList(growable: false),
        );
  }

  static Future<AdminActorWalletSnapshot> fetchActorWallet({
    required String uid,
    required String actorType,
  }) async {
    final data = await _call(
      'adminGetActorWallet',
      parameters: <String, dynamic>{
        'uid': uid.trim(),
        'actorType': actorType,
      },
    );
    return AdminActorWalletSnapshot.fromMap(data);
  }

  static Future<({List<AdminCreditLedgerItem> items, String? nextCursorId})>
      fetchLedger({
    required String uid,
    String? cursorId,
    int limit = 50,
  }) async {
    final data = await _call(
      'adminListCreditLedger',
      parameters: <String, dynamic>{
        'uid': uid.trim(),
        'limit': limit,
        if (cursorId != null && cursorId.isNotEmpty) 'cursorId': cursorId,
      },
    );
    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map(
              (item) => AdminCreditLedgerItem.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <AdminCreditLedgerItem>[];
    return (
      items: items,
      nextCursorId: data['nextCursorId']?.toString(),
    );
  }

  static Future<AdminCreditAdjustResult> adjustCredit({
    required String uid,
    required String actorType,
    required double amount,
    required String reason,
    String? note,
  }) async {
    final data = await _call(
      'adminAdjustCredit',
      parameters: <String, dynamic>{
        'uid': uid.trim(),
        'actorType': actorType,
        'amount': amount,
        'reason': reason.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'clientToken': _uuid.v4(),
      },
    );
    return AdminCreditAdjustResult.fromMap(data);
  }

  static String errorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'internal') {
        return 'ระบบ backend ขัดข้อง (มักเกิดจาก index Firestore ยังไม่ deploy — รอ 2–5 นาทีแล้วลองใหม่)';
      }
      return error.message ?? 'Cloud Function error: ${error.code}';
    }
    return error.toString();
  }
}
