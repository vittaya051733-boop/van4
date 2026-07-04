import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminMerchantWalletSnapshot {
  const AdminMerchantWalletSnapshot({
    required this.totalCredit,
    required this.withdrawableCredit,
    required this.lockedCredit,
    required this.canWithdraw,
    required this.isContractCancelled,
    required this.contractStatus,
    required this.securityDepositAmount,
  });

  final double totalCredit;
  final double withdrawableCredit;
  final double lockedCredit;
  final bool canWithdraw;
  final bool isContractCancelled;
  final String contractStatus;
  final double securityDepositAmount;

  factory AdminMerchantWalletSnapshot.fromMap(Map<String, dynamic> data) {
    return AdminMerchantWalletSnapshot(
      totalCredit: _readMoney(data['totalCredit']),
      withdrawableCredit: _readMoney(data['withdrawableCredit']),
      lockedCredit: _readMoney(data['lockedCredit']),
      canWithdraw: data['canWithdraw'] == true,
      isContractCancelled: data['isContractCancelled'] == true,
      contractStatus: data['contractStatus']?.toString() ?? 'active',
      securityDepositAmount: _readMoney(data['securityDepositAmount']),
    );
  }

  static double _readMoney(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }
}

class AdminMerchantContractService {
  AdminMerchantContractService._();

  static final AdminMerchantContractService instance =
      AdminMerchantContractService._();

  static const _walletCollection = 'merchant_wallets';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Stream<AdminMerchantWalletSnapshot?> watchMerchantWallet(String merchantUid) {
    final trimmedUid = merchantUid.trim();
    if (trimmedUid.isEmpty) {
      return Stream<AdminMerchantWalletSnapshot?>.value(null);
    }

    return FirebaseFirestore.instance
        .collection(_walletCollection)
        .doc(trimmedUid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return AdminMerchantWalletSnapshot.fromMap(
        snapshot.data() ?? const <String, dynamic>{},
      );
    });
  }

  Future<AdminMerchantWalletSnapshot> syncMerchantWallet(String merchantUid) async {
    final trimmedUid = merchantUid.trim();
    if (trimmedUid.isEmpty) {
      throw StateError('merchantUid is required');
    }

    final result = await _functions.httpsCallable('getMerchantWallet').call(
      <String, dynamic>{'merchantUid': trimmedUid},
    );
    final data = result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : const <String, dynamic>{};
    return AdminMerchantWalletSnapshot.fromMap(data);
  }

  Future<Map<String, dynamic>> cancelMerchantContract({
    required String merchantUid,
    String reason = '',
  }) async {
    final trimmedUid = merchantUid.trim();
    if (trimmedUid.isEmpty) {
      throw StateError('merchantUid is required');
    }

    final result =
        await _functions.httpsCallable('adminCancelMerchantContract').call(
      <String, dynamic>{
        'merchantUid': trimmedUid,
        'reason': reason.trim(),
      },
    );

    return result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : const <String, dynamic>{};
  }

  static String errorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Cloud Function error: ${error.code}';
    }
    return error.toString();
  }
}
