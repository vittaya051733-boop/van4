import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRepository {
  AdminRepository._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> _shopCollections = <String>[
    'market_registrations',
    'shop_registrations',
    'restaurant_registrations',
    'pharmacy_registrations',
    'agriculture_registrations',
    'other_registrations',
  ];

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
    final streams = _shopCollections
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
          final collection = _shopCollections[index];
          merged.addAll(
            snapshot.docs.map((doc) => AdminShopRecord.fromSnapshot(collection, doc)),
          );
        }

        merged.sort((left, right) {
          final leftPending = left.status.toLowerCase().contains('pending') ? 0 : 1;
          final rightPending = right.status.toLowerCase().contains('pending') ? 0 : 1;
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

  static Stream<List<AdminCustomerRecord>> streamCustomers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final customers = snapshot.docs
          .map(AdminCustomerRecord.fromSnapshot)
          .where((customer) => !customer.isAdmin)
          .toList(growable: false);
      return customers..sort((left, right) => left.displayName.compareTo(right.displayName));
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
  });

  final String id;
  final String displayName;
  final String? phone;
  final bool onlineReady;
  final String locationStatus;
  final DateTime? updatedAt;

  factory AdminRiderRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AdminRiderRecord(
      id: doc.id,
      displayName: _firstString(data, const <String>['name', 'displayName']) ?? 'ไรเดอร์ไม่มีชื่อ',
      phone: _firstString(data, const <String>['phone', 'phoneNumber']),
      onlineReady: (data['onlineReady'] as bool?) ?? false,
      locationStatus: _firstString(data, const <String>['locationStatus', 'status']) ?? 'offline',
      updatedAt: _toDateTime(data['updatedAt']) ?? _toDateTime(data['locationUpdatedAt']),
    );
  }
}

class AdminCustomerRecord {
  const AdminCustomerRecord({
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

  factory AdminCustomerRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final role = _firstString(data, const <String>['role']) ?? 'customer';
    final isAdmin = role.toLowerCase() == 'admin' ||
        role.toLowerCase() == 'superadmin' ||
        (data['isAdmin'] as bool?) == true ||
        (data['admin'] as bool?) == true;

    return AdminCustomerRecord(
      id: doc.id,
      displayName: _firstString(data, const <String>['displayName', 'name']) ?? 'ผู้ใช้ไม่มีชื่อ',
      phone: _firstString(data, const <String>['phoneNumber', 'phone']),
      email: _firstString(data, const <String>['email', 'loginEmail']),
      role: role,
      createdAt: _toDateTime(data['createdAt']) ?? _toDateTime(data['updatedAt']),
      isAdmin: isAdmin,
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