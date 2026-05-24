import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminRepository {
  AdminRepository._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> shopCollections = <String>[
    'market_registrations',
    'shop_registrations',
    'restaurant_registrations',
    'pharmacy_registrations',
    'agriculture_registrations',
    'other_registrations',
  ];

  static String? get _adminUid => FirebaseAuth.instance.currentUser?.uid;

  static Future<bool> isAdmin(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) {
      return false;
    }

    final role = (data['role'] as String?)?.trim().toLowerCase();
    return role == 'admin' ||
        role == 'superadmin' ||
        (data['isAdmin'] as bool?) == true ||
        (data['admin'] as bool?) == true;
  }

  static Stream<List<AdminShopRecord>> streamShops() {
    final streams = shopCollections
        .map((collection) => _firestore.collection(collection).snapshots())
        .toList(growable: false);

    return Stream<List<AdminShopRecord>>.multi((controller) {
      final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(streams.length, null);
      final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

      void emitIfReady() {
        if (latest.any((snapshot) => snapshot == null)) {
          return;
        }

        final merged = <AdminShopRecord>[];
        for (var index = 0; index < streams.length; index++) {
          final snapshot = latest[index]!;
          final collection = shopCollections[index];
          merged.addAll(
            snapshot.docs.map((doc) => AdminShopRecord.fromSnapshot(collection, doc)),
          );
        }

        merged.sort((left, right) {
          final leftPending = left.isPendingReview ? 0 : 1;
          final rightPending = right.isPendingReview ? 0 : 1;
          final pendingCompare = leftPending.compareTo(rightPending);
          if (pendingCompare != 0) {
            return pendingCompare;
          }
          return left.displayName.toLowerCase().compareTo(right.displayName.toLowerCase());
        });
        controller.add(merged);
      }

      for (var index = 0; index < streams.length; index++) {
        subscriptions.add(
          streams[index].listen(
            (snapshot) {
              latest[index] = snapshot;
              emitIfReady();
            },
            onError: controller.addError,
          ),
        );
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  static Stream<List<AdminRiderRecord>> streamRiders() {
    return _firestore.collection('riders').snapshots().map((snapshot) {
      final riders = snapshot.docs.map(AdminRiderRecord.fromSnapshot).toList(growable: false);
      return riders..sort((left, right) => left.displayName.compareTo(right.displayName));
    });
  }

  static Stream<List<AdminMerchantRecord>> streamMerchants() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final merchants = snapshot.docs
          .map(AdminMerchantRecord.fromSnapshot)
          .where((user) => !user.isAdmin)
          .toList(growable: false);
      return merchants..sort((left, right) => left.displayName.compareTo(right.displayName));
    });
  }

  static Stream<List<AdminCustomerRecord>> streamCustomers() {
    return _firestore.collection('customer_users').snapshots().map((snapshot) {
      final customers = snapshot.docs.map(AdminCustomerRecord.fromSnapshot).toList(growable: false);
      return customers..sort((left, right) => left.displayName.compareTo(right.displayName));
    });
  }

  static Stream<List<AdminOrderRecord>> streamOrders({int limit = 80}) {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminOrderRecord.fromSnapshot).toList(growable: false));
  }

  static Future<void> approveShop({
    required AdminShopRecord shop,
    required String adminUid,
  }) async {
    final ownerId = shop.ownerId;
    final docRef = _firestore.collection(shop.collection).doc(shop.id);
    final batch = _firestore.batch();

    batch.update(docRef, <String, dynamic>{
      'status': 'approved',
      'isProfileCompleted': true,
      'adminApprovedAt': FieldValue.serverTimestamp(),
      'adminApprovedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      _firestore.collection('public_shops').doc(ownerId),
      <String, dynamic>{
        'ownerUid': ownerId,
        'shopName': shop.displayName,
        'serviceType': shop.serviceType,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (shop.imageUrl != null) 'shopImageUrl': shop.imageUrl,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    await _notifyApp(
      targetApp: 'van1',
      recipientUid: ownerId,
      title: 'ร้านได้รับการอนุมัติ',
      body: 'ร้าน ${shop.displayName} พร้อมเปิดขายบนแอปลูกค้าแล้ว',
      action: 'shop_approved',
    );
  }

  static Future<void> rejectShop({
    required AdminShopRecord shop,
    required String adminUid,
    required String reason,
  }) async {
    await _firestore.collection(shop.collection).doc(shop.id).update(<String, dynamic>{
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'adminRejectedAt': FieldValue.serverTimestamp(),
      'adminRejectedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifyApp(
      targetApp: 'van1',
      recipientUid: shop.ownerId,
      title: 'ร้านไม่ผ่านการอนุมัติ',
      body: reason.trim().isEmpty ? 'กรุณาติดต่อแอดมินเพื่อแก้ไขข้อมูล' : reason.trim(),
      action: 'shop_rejected',
    );
  }

  static Future<void> acceptContract(String userId, {required String adminUid}) async {
    await _firestore.collection('contracts').doc(userId).set(<String, dynamic>{
      'status': 'accepted',
      'adminAcceptedAt': FieldValue.serverTimestamp(),
      'adminAcceptedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notifyApp(
      targetApp: 'van1',
      recipientUid: userId,
      title: 'สัญญาได้รับการอนุมัติ',
      body: 'คุณสามารถดำเนินการลงทะเบียนร้านต่อได้',
      action: 'contract_accepted',
    );
  }

  static Future<void> setRiderOnlineReady({
    required String riderId,
    required bool onlineReady,
    required String adminUid,
  }) async {
    await _firestore.collection('riders').doc(riderId).set(<String, dynamic>{
      'onlineReady': onlineReady,
      'adminUpdatedAt': FieldValue.serverTimestamp(),
      'adminUpdatedBy': adminUid,
      if (!onlineReady) 'adminSuspended': true,
      if (onlineReady) 'adminSuspended': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> adminCancelOrder({
    required String orderId,
    required String reason,
    required String adminUid,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await orderRef.get();
    if (!snapshot.exists) {
      throw StateError('ไม่พบออเดอร์');
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    await orderRef.update(<String, dynamic>{
      'status': 'cancelled',
      'statusLabel': 'admin_cancelled',
      'cancelReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'adminAction': <String, dynamic>{
        'action': 'cancel',
        'by': adminUid,
        'at': FieldValue.serverTimestamp(),
        'reason': reason.trim(),
      },
    });

    final customerId = _firstString(data, const <String>['customerId']);
    final shopOwnerId = _firstString(data, const <String>['shopOwnerId', 'shopId']);
    final driverId = _firstString(data, const <String>['driverId']);

    if (customerId != null) {
      await _notifyApp(
        targetApp: 'van2',
        recipientUid: customerId,
        title: 'ออเดอร์ถูกยกเลิกโดยแอดมิน',
        body: reason.trim(),
        action: 'order_cancelled',
        orderId: orderId,
      );
    }
    if (shopOwnerId != null) {
      await _notifyApp(
        targetApp: 'van1',
        recipientUid: shopOwnerId,
        title: 'ออเดอร์ถูกยกเลิกโดยแอดมิน',
        body: 'ออเดอร์ #$orderId ถูกยกเลิก',
        action: 'order_cancelled',
        orderId: orderId,
      );
    }
    if (driverId != null) {
      await _notifyApp(
        targetApp: 'van3',
        recipientUid: driverId,
        title: 'ออเดอร์ถูกยกเลิกโดยแอดมิน',
        body: 'ออเดอร์ #$orderId ถูกยกเลิก',
        action: 'order_cancelled',
        orderId: orderId,
      );
    }

    await orderRef.collection('timeline').add(<String, dynamic>{
      'type': 'admin_cancel',
      'message': reason.trim(),
      'actorRole': 'admin',
      'actorId': adminUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _notifyApp({
    required String targetApp,
    required String recipientUid,
    required String title,
    required String body,
    required String action,
    String? orderId,
  }) async {
    if (recipientUid.trim().isEmpty) {
      return;
    }

    await _firestore.collection('app_notifications').add(<String, dynamic>{
      'targetApp': targetApp,
      'recipientUid': recipientUid,
      'title': title,
      'body': body,
      'action': action,
      'sourceApp': 'van4_admin',
      'senderId': _adminUid ?? 'van4_admin',
      if (orderId != null) 'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminShopRecord {
  const AdminShopRecord({
    required this.id,
    required this.collection,
    required this.displayName,
    required this.serviceType,
    required this.status,
    required this.ownerId,
    required this.phone,
    required this.email,
    required this.imageUrl,
    required this.createdAt,
    required this.address,
    required this.isProfileCompleted,
  });

  final String id;
  final String collection;
  final String displayName;
  final String serviceType;
  final String status;
  final String ownerId;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final DateTime? createdAt;
  final String? address;
  final bool isProfileCompleted;

  bool get isPendingReview {
    final normalized = status.toLowerCase();
    return normalized.contains('pending') || normalized == 'unknown';
  }

  bool get isApproved => status.toLowerCase() == 'approved';

  bool get isRejected => status.toLowerCase() == 'rejected';

  factory AdminShopRecord.fromSnapshot(
    String collection,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return AdminShopRecord(
      id: doc.id,
      collection: collection,
      displayName: _firstString(data, const <String>['name', 'shopName', 'displayName']) ?? 'ไม่ระบุชื่อร้าน',
      serviceType: _firstString(data, const <String>['serviceType']) ?? 'ไม่ระบุประเภท',
      status: _firstString(data, const <String>['status']) ?? 'unknown',
      ownerId: _firstString(data, const <String>['ownerId', 'userId']) ?? doc.id,
      phone: _firstString(data, const <String>['phone', 'phoneNumber']),
      email: _firstString(data, const <String>['email', 'loginEmail']),
      imageUrl: _firstString(data, const <String>['shopImageUrl', 'imageUrl', 'photoUrl']),
      createdAt: _toDateTime(data['createdAt']) ?? _toDateTime(data['updatedAt']),
      address: _firstString(data, const <String>['address']),
      isProfileCompleted: data['isProfileCompleted'] == true,
    );
  }
}

class AdminRiderRecord {
  const AdminRiderRecord({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.onlineReady,
    required this.locationStatus,
    required this.updatedAt,
    required this.adminSuspended,
  });

  final String id;
  final String displayName;
  final String? phone;
  final bool onlineReady;
  final String locationStatus;
  final DateTime? updatedAt;
  final bool adminSuspended;

  factory AdminRiderRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AdminRiderRecord(
      id: doc.id,
      displayName: _firstString(data, const <String>['name', 'displayName']) ?? 'ไรเดอร์ไม่มีชื่อ',
      phone: _firstString(data, const <String>['phone', 'phoneNumber']),
      onlineReady: (data['onlineReady'] as bool?) ?? false,
      locationStatus: _firstString(data, const <String>['locationStatus', 'status']) ?? 'offline',
      updatedAt: _toDateTime(data['updatedAt']) ?? _toDateTime(data['locationUpdatedAt']),
      adminSuspended: (data['adminSuspended'] as bool?) ?? false,
    );
  }
}

class AdminMerchantRecord {
  const AdminMerchantRecord({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.isAdmin,
  });

  final String id;
  final String displayName;
  final String? phone;
  final String? email;
  final String role;
  final DateTime? createdAt;
  final bool isAdmin;

  factory AdminMerchantRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final role = _firstString(data, const <String>['role']) ?? 'merchant';
    final isAdmin = role.toLowerCase() == 'admin' ||
        role.toLowerCase() == 'superadmin' ||
        (data['isAdmin'] as bool?) == true ||
        (data['admin'] as bool?) == true;

    return AdminMerchantRecord(
      id: doc.id,
      displayName: _firstString(data, const <String>['displayName', 'name']) ?? 'ร้านค้าไม่มีชื่อ',
      phone: _firstString(data, const <String>['phoneNumber', 'phone']),
      email: _firstString(data, const <String>['email', 'loginEmail']),
      role: role,
      createdAt: _toDateTime(data['createdAt']) ?? _toDateTime(data['updatedAt']),
      isAdmin: isAdmin,
    );
  }
}

class AdminCustomerRecord {
  const AdminCustomerRecord({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String? phone;
  final String? email;
  final DateTime? createdAt;

  factory AdminCustomerRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AdminCustomerRecord(
      id: doc.id,
      displayName: _firstString(data, const <String>['displayName', 'name']) ?? 'ลูกค้าไม่มีชื่อ',
      phone: _firstString(data, const <String>['phoneNumber', 'phone']),
      email: _firstString(data, const <String>['email', 'loginEmail']),
      createdAt: _toDateTime(data['createdAt']) ?? _toDateTime(data['updatedAt']),
    );
  }
}

class AdminOrderRecord {
  const AdminOrderRecord({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.customerId,
    required this.shopOwnerId,
    required this.driverId,
    required this.grandTotal,
    required this.sourceApp,
    required this.paymentStatus,
    required this.createdAt,
    required this.shopName,
    required this.customerName,
    required this.driverName,
  });

  final String id;
  final String status;
  final String? statusLabel;
  final String? customerId;
  final String? shopOwnerId;
  final String? driverId;
  final double? grandTotal;
  final String? sourceApp;
  final String? paymentStatus;
  final DateTime? createdAt;
  final String? shopName;
  final String? customerName;
  final String? driverName;

  String get van1Label => shopOwnerId ?? shopName ?? '-';
  String get van2Label => customerId ?? customerName ?? '-';
  String get van3Label => driverId ?? driverName ?? 'ยังไม่มีไรเดอร์';

  factory AdminOrderRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AdminOrderRecord(
      id: doc.id,
      status: _firstString(data, const <String>['status']) ?? 'unknown',
      statusLabel: _firstString(data, const <String>['statusLabel']),
      customerId: _firstString(data, const <String>['customerId']),
      shopOwnerId: _firstString(data, const <String>['shopOwnerId', 'shopId']),
      driverId: _firstString(data, const <String>['driverId']),
      grandTotal: _toDouble(data['grandTotal'] ?? data['totalAmount'] ?? data['totalPrice']),
      sourceApp: _firstString(data, const <String>['sourceApp']),
      paymentStatus: _firstString(data, const <String>['paymentStatus']),
      createdAt: _toDateTime(data['createdAt']) ?? _toDateTime(data['timestamp']),
      shopName: _firstString(data, const <String>['shopName']),
      customerName: _firstString(data, const <String>['customerName']),
      driverName: _firstString(data, const <String>['driverName']),
    );
  }
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
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

double? _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
