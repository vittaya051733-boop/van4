import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminAccessCheck {
  const AdminAccessCheck({
    required this.allowed,
    this.reason,
    this.email,
  });

  final bool allowed;
  final String? reason;
  final String? email;
}

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

  static const String adminCollection = 'admins';

  static String? get _adminUid => FirebaseAuth.instance.currentUser?.uid;

  static Future<AdminAccessCheck> checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      return const AdminAccessCheck(
        allowed: false,
        reason: 'บัญชีนี้ไม่มีอีเมล — ใช้การล็อกอินด้วยอีเมล/รหัสผ่าน',
      );
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }

      try {
        final doc =
            await _firestore.collection(adminCollection).doc(email).get();
        if (!doc.exists) {
          return AdminAccessCheck(
            allowed: false,
            reason: 'ไม่พบ admins/$email ใน Firestore',
            email: email,
          );
        }

        final data = doc.data();
        if (data == null || data['active'] == false) {
          return AdminAccessCheck(
            allowed: false,
            reason: 'บัญชีแอดมินถูกปิดใช้งาน (active = false)',
            email: email,
          );
        }

        return AdminAccessCheck(allowed: true, email: email);
      } on FirebaseException catch (error) {
        lastError = error;
        final message = error.message ?? '';
        final isChannelError = message.contains('Unable to establish connection') ||
            message.contains('channel');
        if (!isChannelError || attempt == 2) {
          return AdminAccessCheck(
            allowed: false,
            reason: 'อ่าน Firestore ไม่ได้: ${error.code} — $message',
            email: email,
          );
        }
      } catch (error) {
        lastError = error;
        if (attempt == 2) {
          return AdminAccessCheck(
            allowed: false,
            reason: 'ตรวจสอบสิทธิ์ไม่สำเร็จ: $error',
            email: email,
          );
        }
      }
    }

    return AdminAccessCheck(
      allowed: false,
      reason: 'ตรวจสอบสิทธิ์ไม่สำเร็จ: $lastError',
      email: email,
    );
  }

  static Future<bool> isAdmin(String uid) async {
    final result = await checkAdminAccess();
    return result.allowed;
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

  static Stream<List<AdminOrderRecord>> streamOrders({int limit = 300}) {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminOrderRecord.fromSnapshot).toList(growable: false));
  }

  static Future<List<AdminOrderRecord>> fetchOrdersForDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snapshot = await _firestore
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(AdminOrderRecord.fromSnapshot).toList(growable: false);
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
        'adminMaxImageCount': AdminShopMediaSettings.defaultMaxImagesFor(shop.serviceType),
        'adminCanUploadVideo': AdminShopMediaSettings.defaultCanUploadVideo(shop.serviceType),
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

  static Stream<Map<String, AdminShopMediaSettings>> streamShopMediaSettingsMap() {
    return _firestore.collection('public_shops').snapshots().map((snapshot) {
      final settings = <String, AdminShopMediaSettings>{};
      for (final doc in snapshot.docs) {
        settings[doc.id] = AdminShopMediaSettings.fromMap(doc.data());
      }
      return settings;
    });
  }

  static Future<AdminShopMediaSettings> fetchShopMediaSettings(String ownerId) async {
    final snapshot = await _firestore.collection('public_shops').doc(ownerId).get();
    return AdminShopMediaSettings.fromMap(snapshot.data());
  }

  static Future<void> updateShopMediaSettings({
    required AdminShopRecord shop,
    required int maxImageCount,
    required bool canUploadVideo,
    required String adminUid,
  }) async {
    final ownerId = shop.ownerId;
    await _firestore.collection('public_shops').doc(ownerId).set(<String, dynamic>{
      'ownerUid': ownerId,
      'shopName': shop.displayName,
      'serviceType': shop.serviceType,
      'adminMaxImageCount': maxImageCount,
      'adminCanUploadVideo': canUploadVideo,
      'adminMediaUpdatedAt': FieldValue.serverTimestamp(),
      'adminMediaUpdatedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore.collection(shop.collection).doc(shop.id).set(<String, dynamic>{
      'adminMaxImageCount': maxImageCount,
      'adminCanUploadVideo': canUploadVideo,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<List<AdminProductRecord>> streamProductsForShop(String ownerUid) {
    return _firestore
        .collection('products')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) => _sortProducts(snapshot.docs));
  }

  static const String platformCatalogCollection = 'platform_catalog';
  static const String homeShelvesDocId = 'home_shelves';

  static Stream<List<String>> streamHomeFeaturedProductIds() {
    return _firestore
        .collection(platformCatalogCollection)
        .doc(homeShelvesDocId)
        .snapshots()
        .map((snapshot) {
      final raw = snapshot.data()?['featuredProductIds'];
      if (raw is! List) {
        return <String>[];
      }
      return raw
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    });
  }

  static Stream<List<AdminProductRecord>> streamActiveProductsForHomePicker() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => _sortProducts(snapshot.docs));
  }

  static Future<void> saveHomeFeaturedProductIds({
    required List<String> productIds,
    required String adminEmail,
  }) async {
    await _firestore
        .collection(platformCatalogCollection)
        .doc(homeShelvesDocId)
        .set(<String, dynamic>{
      'featuredProductIds': productIds,
      'featuredUpdatedAt': FieldValue.serverTimestamp(),
      'featuredUpdatedBy': adminEmail,
    }, SetOptions(merge: true));
  }

  /// สินค้าที่ AI ประเมินว่าต้องให้แอดมินตรวจสอบก่อน (ผิดกฎหมายหรือความมั่นใจต่ำ)
  static Stream<List<AdminProductRecord>> streamPendingAiProductReviews() {
    return _firestore
        .collection('product_admin_reviews')
        .where('adminReviewStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => _sortProducts(snapshot.docs));
  }

  /// @deprecated ใช้ [streamPendingAiProductReviews] แทน
  static Stream<List<AdminProductRecord>> streamIllegalAiProducts() {
    return _firestore
        .collection('product_admin_reviews')
        .where('adminReviewStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => _sortProducts(snapshot.docs));
  }

  static Future<void> approveProductReview({
    required String reviewId,
    required String adminUid,
  }) async {
    final reviewRef = _firestore.collection('product_admin_reviews').doc(reviewId);
    final reviewSnap = await reviewRef.get();
    if (!reviewSnap.exists) {
      throw Exception('ไม่พบคำขอตรวจสอบสินค้า');
    }

    final raw = Map<String, dynamic>.from(reviewSnap.data() ?? <String, dynamic>{});
    if (raw['adminReviewStatus']?.toString() != 'pending') {
      throw Exception('คำขอนี้ถูกดำเนินการแล้ว');
    }

    final specsRaw = raw.remove('specificationsPayload');
    final specificationsPayload = specsRaw is Map
        ? Map<String, dynamic>.from(specsRaw.cast<String, dynamic>())
        : <String, dynamic>{};

    for (final key in <String>[
      'adminReviewStatus',
      'submittedAt',
      'submittedByUid',
      'reviewType',
      'targetProductId',
      'reviewedAt',
      'reviewedBy',
      'rejectReason',
      'publishedProductId',
    ]) {
      raw.remove(key);
    }

    final reviewType = reviewSnap.data()?['reviewType']?.toString() ?? 'create';
    final targetProductId = reviewSnap.data()?['targetProductId']?.toString();
    final ownerUid = raw['ownerUid']?.toString();

    raw['isActive'] = true;
    raw['activeAt'] = FieldValue.serverTimestamp();
    raw['updatedAt'] = FieldValue.serverTimestamp();
    raw['adminApprovedAt'] = FieldValue.serverTimestamp();
    raw['adminApprovedBy'] = adminUid;

    final productsRef = _firestore.collection('products');
    late DocumentReference<Map<String, dynamic>> productRef;

    if (reviewType == 'update' &&
        targetProductId != null &&
        targetProductId.trim().isNotEmpty) {
      productRef = productsRef.doc(targetProductId.trim());
      raw.remove('createdAt');
      await productRef.set(raw, SetOptions(merge: true));
    } else {
      raw['createdAt'] = FieldValue.serverTimestamp();
      productRef = await productsRef.add(raw);
    }

    if (specificationsPayload.isNotEmpty) {
      specificationsPayload['productId'] = productRef.id;
      if (ownerUid != null && ownerUid.isNotEmpty) {
        specificationsPayload['ownerUid'] = ownerUid;
      }
      specificationsPayload['updatedAt'] = FieldValue.serverTimestamp();
      await productRef
          .collection('specifications')
          .doc('main')
          .set(specificationsPayload, SetOptions(merge: true));
    }

    await reviewRef.set(<String, dynamic>{
      'adminReviewStatus': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      'publishedProductId': productRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> rejectProductReview({
    required String reviewId,
    required String adminUid,
    String? reason,
  }) async {
    final reviewRef = _firestore.collection('product_admin_reviews').doc(reviewId);
    final reviewSnap = await reviewRef.get();
    if (!reviewSnap.exists) {
      throw Exception('ไม่พบคำขอตรวจสอบสินค้า');
    }
    if (reviewSnap.data()?['adminReviewStatus']?.toString() != 'pending') {
      throw Exception('คำขอนี้ถูกดำเนินการแล้ว');
    }

    await reviewRef.set(<String, dynamic>{
      'adminReviewStatus': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminUid,
      if (reason != null && reason.trim().isNotEmpty) 'rejectReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static List<AdminProductRecord> _sortProducts(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final products = docs.map(AdminProductRecord.fromSnapshot).toList(growable: true);
    products.sort(
      (left, right) =>
          (right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return products;
  }

  static Future<void> adminCreateProduct({
    required AdminShopRecord shop,
    required String name,
    required String description,
    required double price,
    required int stock,
    required List<String> imageUrls,
    required String adminUid,
  }) async {
    final ownerId = shop.ownerId;
    final publicShop = await _firestore.collection('public_shops').doc(ownerId).get();
    final publicData = publicShop.data() ?? <String, dynamic>{};
    final shopName =
        shop.displayName.isNotEmpty ? shop.displayName : publicData['shopName']?.toString();
    final shopImageUrl = shop.imageUrl ?? publicData['shopImageUrl']?.toString();

    final productData = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'stock': stock,
      'preparationTimeMinutes': 10,
      'preparingDuration': 10 * 60 * 1000,
      'imageUrls': imageUrls,
      'thumbnailUrls': imageUrls,
      'ownerUid': ownerId,
      'shopName': shopName,
      if (shopImageUrl != null && shopImageUrl.trim().isNotEmpty) 'shopImageUrl': shopImageUrl,
      'serviceType': shop.serviceType,
      'isActive': true,
      'activeAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'uploadedByAdmin': true,
      'adminUploadedBy': adminUid,
      'adminUploadedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('products').add(productData);

    await _notifyApp(
      targetApp: 'van1',
      recipientUid: ownerId,
      title: 'แอดมินเพิ่มสินค้าให้ร้าน',
      body: 'สินค้า "$name" ถูกเพิ่มในร้าน ${shop.displayName}',
      action: 'admin_product_created',
    );
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

class AdminShopMediaSettings {
  const AdminShopMediaSettings({
    required this.maxImageCount,
    required this.canUploadVideo,
    this.shopImageUrl,
  });

  final int maxImageCount;
  final bool canUploadVideo;
  final String? shopImageUrl;

  static int defaultMaxImagesFor(String? serviceType) {
    return 1;
  }

  static bool defaultCanUploadVideo(String? serviceType) {
    return false;
  }

  factory AdminShopMediaSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const AdminShopMediaSettings(maxImageCount: 1, canUploadVideo: false);
    }
    final serviceType = data['serviceType']?.toString();
    final maxImages = _toInt(data['adminMaxImageCount']) ??
        defaultMaxImagesFor(serviceType);
    final canVideo = data['adminCanUploadVideo'] is bool
        ? data['adminCanUploadVideo'] as bool
        : defaultCanUploadVideo(serviceType);
    return AdminShopMediaSettings(
      maxImageCount: maxImages.clamp(1, 30),
      canUploadVideo: canVideo,
      shopImageUrl: _firstString(data, const <String>['shopImageUrl', 'imageUrl', 'photoUrl']),
    );
  }
}

class AdminProductRecord {
  const AdminProductRecord({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.imageUrls,
    required this.videoUrl,
    required this.updatedAt,
    required this.uploadedByAdmin,
    this.ownerUid,
    this.shopName,
    this.aiIsLegalInThailand,
    this.aiLegalAnalysisReason,
    this.aiRequiresAdminReview,
    this.aiReviewReasonLabels,
    this.adminReviewStatus,
    this.reviewType,
    this.targetProductId,
  });

  final String id;
  final String name;
  final double? price;
  final int? stock;
  final bool isActive;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime? updatedAt;
  final bool uploadedByAdmin;
  final String? ownerUid;
  final String? shopName;
  final bool? aiIsLegalInThailand;
  final String? aiLegalAnalysisReason;
  final bool? aiRequiresAdminReview;
  final List<String>? aiReviewReasonLabels;
  final String? adminReviewStatus;
  final String? reviewType;
  final String? targetProductId;

  bool get isAiIllegalInThailand => aiIsLegalInThailand == false;
  bool get isPendingAdminReview => adminReviewStatus == 'pending';
  bool get needsLowConfidenceReview =>
      aiRequiresAdminReview == true && aiIsLegalInThailand != false;

  String get aiReviewSummary {
    if (isAiIllegalInThailand) {
      final reason = (aiLegalAnalysisReason ?? '').trim();
      return reason.isNotEmpty
          ? reason
          : 'AI ประเมินว่าสินค้านี้อาจผิดกฎหมาย';
    }
    if (needsLowConfidenceReview) {
      final labels = aiReviewReasonLabels ?? const <String>[];
      if (labels.isNotEmpty) {
        return 'ความมั่นใจต่ำกว่า 80%: ${labels.join(', ')}';
      }
      return 'AI ประเมินความมั่นใจต่ำกว่า 80%';
    }
    return 'รอแอดมินตรวจสอบ';
  }

  factory AdminProductRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawImages = data['imageUrls'];
    final images = rawImages is List
        ? rawImages.map((item) => item.toString()).where((url) => url.trim().isNotEmpty).toList()
        : <String>[];

    return AdminProductRecord(
      id: doc.id,
      name: _firstString(data, const <String>['name']) ?? 'ไม่ระบุชื่อ',
      price: _toDouble(data['price']),
      stock: _toInt(data['stock']),
      isActive: data['isActive'] != false,
      imageUrls: images,
      videoUrl: _firstString(data, const <String>['videoUrl']),
      updatedAt: _toDateTime(data['updatedAt']) ??
          _toDateTime(data['submittedAt']) ??
          _toDateTime(data['createdAt']),
      uploadedByAdmin: data['uploadedByAdmin'] == true,
      ownerUid: _firstString(data, const <String>['ownerUid']),
      shopName: _firstString(data, const <String>['shopName']),
      aiIsLegalInThailand: data['aiIsLegalInThailand'] is bool
          ? data['aiIsLegalInThailand'] as bool
          : null,
      aiLegalAnalysisReason:
          _firstString(data, const <String>['aiLegalAnalysisReason']),
      aiRequiresAdminReview: data['aiRequiresAdminReview'] is bool
          ? data['aiRequiresAdminReview'] as bool
          : null,
      aiReviewReasonLabels: data['aiReviewReasonLabels'] is List
          ? data['aiReviewReasonLabels']
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : null,
      adminReviewStatus: _firstString(data, const <String>['adminReviewStatus']),
      reviewType: _firstString(data, const <String>['reviewType']),
      targetProductId: _firstString(data, const <String>['targetProductId']),
    );
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

class AdminOrderLineItem {
  const AdminOrderLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.imageUrl,
    required this.note,
  });

  final String name;
  final int quantity;
  final double? unitPrice;
  final double? lineTotal;
  final String? imageUrl;
  final String? note;

  factory AdminOrderLineItem.fromMap(Map<dynamic, dynamic> raw) {
    return AdminOrderLineItem(
      name: _firstString(raw, const <String>['name', 'productName', 'title']) ?? 'สินค้า',
      quantity: _toInt(raw['quantity']) ?? 1,
      unitPrice: _toDouble(raw['unitPrice'] ?? raw['price']),
      lineTotal: _toDouble(raw['lineTotal'] ?? raw['total']),
      imageUrl: _firstString(raw, const <String>['imageUrl', 'photoUrl', 'productImage']),
      note: _firstString(raw, const <String>['note', 'notes']),
    );
  }
}

class AdminOrderRecord {
  const AdminOrderRecord({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.statusLabel,
    required this.customerId,
    required this.shopOwnerId,
    required this.driverId,
    required this.grandTotal,
    required this.subtotal,
    required this.shippingFee,
    required this.sourceApp,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
    required this.deliveredAt,
    required this.cancelledAt,
    required this.shopName,
    required this.customerName,
    required this.driverName,
    required this.cancelReason,
    required this.refundRequested,
    required this.refundStatus,
    required this.refundBankName,
    required this.refundAccountName,
    required this.refundBankAccountNumber,
    required this.deliveryProofImageUrl,
    required this.shopImageUrl,
    required this.items,
    required this.rawData,
  });

  final String id;
  final String? orderCode;
  final String status;
  final String? statusLabel;
  final String? customerId;
  final String? shopOwnerId;
  final String? driverId;
  final double? grandTotal;
  final double? subtotal;
  final double? shippingFee;
  final String? sourceApp;
  final String? paymentStatus;
  final String? paymentMethod;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? shopName;
  final String? customerName;
  final String? driverName;
  final String? cancelReason;
  final bool refundRequested;
  final String? refundStatus;
  final String? refundBankName;
  final String? refundAccountName;
  final String? refundBankAccountNumber;
  final String? deliveryProofImageUrl;
  final String? shopImageUrl;
  final List<AdminOrderLineItem> items;
  final Map<String, dynamic> rawData;

  String get displayOrderNumber {
    final code = orderCode?.trim();
    if (code != null && code.isNotEmpty) {
      return code;
    }
    if (id.length <= 10) {
      return id;
    }
    return id.substring(0, 10);
  }

  bool get isRefundCase {
    final normalizedStatus = status.toLowerCase();
    if (normalizedStatus == 'refund') {
      return true;
    }
    if (refundRequested) {
      return true;
    }
    final refund = refundStatus?.trim().toLowerCase();
    return refund != null && refund.isNotEmpty && refund != 'none' && refund != 'rejected';
  }

  String get van1Label => shopOwnerId ?? shopName ?? '-';
  String get van2Label => customerId ?? customerName ?? '-';
  String get van3Label => driverId ?? driverName ?? 'ยังไม่มีไรเดอร์';

  factory AdminOrderRecord.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AdminOrderRecord(
      id: doc.id,
      orderCode: _firstString(data, const <String>['orderCode']),
      status: _firstString(data, const <String>['status']) ?? 'unknown',
      statusLabel: _firstString(data, const <String>['statusLabel']),
      customerId: _firstString(data, const <String>['customerId']),
      shopOwnerId: _firstString(data, const <String>['shopOwnerId', 'shopId']),
      driverId: _firstString(data, const <String>['driverId']),
      grandTotal: _toDouble(data['grandTotal'] ?? data['totalAmount'] ?? data['totalPrice']),
      subtotal: _toDouble(data['subtotal'] ?? data['totalPrice']),
      shippingFee: _toDouble(data['shippingFee'] ?? data['deliveryFee']),
      sourceApp: _firstString(data, const <String>['sourceApp']),
      paymentStatus: _firstString(data, const <String>['paymentStatus']),
      paymentMethod: _firstString(data, const <String>['paymentMethod', 'payMethod']),
      createdAt: _toDateTime(data['createdAt']) ?? _toDateTime(data['timestamp']),
      deliveredAt: _toDateTime(data['deliveredAt']),
      cancelledAt: _toDateTime(data['cancelledAt']),
      shopName: _firstString(data, const <String>['shopName']),
      customerName: _firstString(data, const <String>['customerName']),
      driverName: _firstString(data, const <String>['driverName', 'riderName']),
      cancelReason: _firstString(data, const <String>['cancelReason']),
      refundRequested: data['refundRequested'] == true,
      refundStatus: _firstString(data, const <String>['refundStatus']),
      refundBankName: _firstString(data, const <String>['refundBankName']),
      refundAccountName: _firstString(data, const <String>['refundAccountName']),
      refundBankAccountNumber: _firstString(data, const <String>['refundBankAccountNumber']),
      deliveryProofImageUrl: _firstString(data, const <String>[
        'deliveryProofImageUrl',
        'proofImageUrl',
      ]),
      shopImageUrl: _firstString(data, const <String>['shopImageUrl']),
      items: _parseOrderItems(data),
      rawData: Map<String, dynamic>.from(data),
    );
  }
}

List<AdminOrderLineItem> _parseOrderItems(Map<String, dynamic> data) {
  final rawItems = data['products'] ?? data['items'];
  if (rawItems is! List) {
    return const <AdminOrderLineItem>[];
  }

  return rawItems
      .whereType<Map>()
      .map((item) => AdminOrderLineItem.fromMap(item))
      .toList(growable: false);
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

String? _firstString(Map<dynamic, dynamic> data, List<String> keys) {
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

class AdminSupportTicket {
  AdminSupportTicket({
    required this.id,
    required this.sourceApp,
    required this.sourceLabel,
    required this.requesterUid,
    required this.requesterName,
    this.requesterEmail,
    required this.topicKey,
    required this.topicLabel,
    required this.message,
    required this.imageUrls,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.unreadForAdmin = false,
    this.requesterPhone,
    this.lastMessagePreview,
    this.contactClosed = false,
  });

  factory AdminSupportTicket.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminSupportTicket(
      id: doc.id,
      sourceApp: (data['sourceApp'] as String?)?.trim() ?? '',
      sourceLabel: (data['sourceLabel'] as String?)?.trim() ?? '',
      requesterUid: (data['requesterUid'] as String?)?.trim() ?? '',
      requesterName: (data['requesterName'] as String?)?.trim() ?? 'ผู้ใช้',
      requesterEmail: (data['requesterEmail'] as String?)?.trim(),
      topicKey: (data['topicKey'] as String?)?.trim() ?? '',
      topicLabel: (data['topicLabel'] as String?)?.trim() ?? '',
      message: (data['message'] as String?)?.trim() ?? '',
      imageUrls: ((data['imageUrls'] as List?) ?? const <dynamic>[])
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false),
      status: (data['status'] as String?)?.trim() ?? 'open',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      unreadForAdmin: data['unreadForAdmin'] == true,
      requesterPhone: (data['requesterPhone'] as String?)?.trim(),
      lastMessagePreview: (data['lastMessagePreview'] as String?)?.trim(),
      contactClosed: data['contactClosed'] == true || data['status'] == 'closed',
    );
  }

  final String id;
  final String sourceApp;
  final String sourceLabel;
  final String requesterUid;
  final String requesterName;
  final String? requesterEmail;
  final String topicKey;
  final String topicLabel;
  final String message;
  final List<String> imageUrls;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool unreadForAdmin;
  final String? requesterPhone;
  final String? lastMessagePreview;
  final bool contactClosed;

  bool get isOpen => status == 'open';
  bool get isContactClosed => contactClosed || status == 'closed';
}

extension AdminRepositorySupport on AdminRepository {
  static Stream<List<AdminSupportTicket>> streamSupportTickets({
    String? sourceApp,
  }) {
    return FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final tickets = snapshot.docs
              .map(AdminSupportTicket.fromDoc)
              .toList(growable: false);
          if (sourceApp == null || sourceApp.isEmpty) {
            return tickets;
          }
          return tickets
              .where((ticket) => ticket.sourceApp == sourceApp)
              .toList(growable: false);
        });
  }

  static Future<void> updateSupportTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    await FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .doc(ticketId)
        .update(<String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<AdminSupportMessage>> streamSupportMessages(
    String ticketId,
  ) {
    return FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .doc(ticketId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminSupportMessage.fromDoc)
              .toList(growable: false),
        );
  }

  static Future<void> markReadAsAdmin(String ticketId) async {
    final ref = FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .doc(ticketId);
    final snap = await ref.get();
    if (!snap.exists) {
      return;
    }
    if (snap.data()?['unreadForAdmin'] != true) {
      return;
    }
    await ref.update(<String, dynamic>{
      'unreadForAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> replyToSupportTicket({
    required AdminSupportTicket ticket,
    required String message,
    List<String> imageUrls = const <String>[],
    String? adminName,
  }) async {
    if (ticket.isContactClosed) {
      throw StateError('เรื่องนี้ปิดแล้ว — ไม่สามารถตอบกลับได้');
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('กรุณาระบุข้อความตอบกลับ');
    }

    final user = FirebaseAuth.instance.currentUser;
    final adminUid = user?.uid;
    final senderName = adminName?.trim().isNotEmpty == true
        ? adminName!.trim()
        : (user?.email?.trim().isNotEmpty == true
            ? user!.email!.trim()
            : 'แอดมิน');

    final preview = trimmed.length <= 120
        ? trimmed
        : '${trimmed.substring(0, 117)}...';

    final ticketRef = FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .doc(ticket.id);
    final messageRef = ticketRef.collection('messages').doc();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(messageRef, <String, dynamic>{
      'senderRole': 'admin',
      'senderUid': user?.uid ?? 'admin',
      'senderName': senderName,
      'message': trimmed,
      'imageUrls': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final nextStatus = ticket.status == 'open' ? 'in_progress' : ticket.status;
    batch.update(ticketRef, <String, dynamic>{
      'status': nextStatus,
      'lastMessagePreview': preview,
      'lastMessageRole': 'admin',
      'unreadForRequester': true,
      'unreadForAdmin': false,
      if (adminUid != null) 'assignedAdminUid': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      FirebaseFirestore.instance.collection('app_notifications').doc(),
      <String, dynamic>{
        'targetApp': ticket.sourceApp,
        'recipientUid': ticket.requesterUid,
        'ticketId': ticket.id,
        'title': 'แอดมินตอบกลับ: ${ticket.topicLabel}',
        'body': preview,
        'action': 'admin_support_reply',
        'sourceApp': 'van4_admin',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  static Future<void> closeSupportTicket({
    required AdminSupportTicket ticket,
  }) async {
    if (ticket.isContactClosed) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final adminUid = user?.uid ?? 'admin';

    final ticketRef = FirebaseFirestore.instance
        .collection('admin_support_tickets')
        .doc(ticket.id);
    final messagesSnap = await ticketRef
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .get();
    final messages = messagesSnap.docs
        .map(AdminSupportMessage.fromDoc)
        .toList(growable: false);

    final transcript = <Map<String, dynamic>>[
      <String, dynamic>{
        'role': 'requester',
        'message': ticket.message,
        'imageUrls': ticket.imageUrls,
        if (ticket.createdAt != null)
          'createdAtMs': ticket.createdAt!.millisecondsSinceEpoch,
      },
      ...messages.map(
        (item) => <String, dynamic>{
          'role': item.senderRole,
          'message': item.message,
          'imageUrls': item.imageUrls,
          if (item.createdAt != null)
            'createdAtMs': item.createdAt!.millisecondsSinceEpoch,
        },
      ),
    ];

    final qaPairs = _buildSupportQaPairs(
      initialQuestion: ticket.message,
      initialQuestionImages: ticket.imageUrls,
      messages: messages,
    );

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      FirebaseFirestore.instance
          .collection('admin_support_knowledge')
          .doc(ticket.id),
      <String, dynamic>{
        'ticketId': ticket.id,
        'sourceApp': ticket.sourceApp,
        'sourceLabel': ticket.sourceLabel,
        'topicKey': ticket.topicKey,
        'topicLabel': ticket.topicLabel,
        'requesterUid': ticket.requesterUid,
        'question': ticket.message,
        'questionImageUrls': ticket.imageUrls,
        'transcript': transcript,
        'qaPairs': qaPairs,
        'messageCount': transcript.length,
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedByAdminUid': adminUid,
      },
    );

    batch.update(ticketRef, <String, dynamic>{
      'status': 'closed',
      'contactClosed': true,
      'closedAt': FieldValue.serverTimestamp(),
      'closedByAdminUid': adminUid,
      'unreadForRequester': true,
      'unreadForAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(
      FirebaseFirestore.instance.collection('app_notifications').doc(),
      <String, dynamic>{
        'targetApp': ticket.sourceApp,
        'recipientUid': ticket.requesterUid,
        'ticketId': ticket.id,
        'title': 'เรื่องถูกปิดแล้ว: ${ticket.topicLabel}',
        'body': 'แอดมินปิดการสนทนาแล้ว — ดูประวัติได้ในแชทซัพพอร์ต',
        'action': 'admin_support_closed',
        'sourceApp': 'van4_admin',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  static List<Map<String, dynamic>> _buildSupportQaPairs({
    required String initialQuestion,
    required List<String> initialQuestionImages,
    required List<AdminSupportMessage> messages,
  }) {
    final pairs = <Map<String, dynamic>>[];
    String? pendingQuestion = initialQuestion.trim();
    var pendingQuestionImages = List<String>.from(initialQuestionImages);

    for (final item in messages) {
      if (!item.isAdmin) {
        pendingQuestion = pendingQuestion == null || pendingQuestion.isEmpty
            ? item.message.trim()
            : '${pendingQuestion.trim()}\n${item.message.trim()}';
        pendingQuestionImages = item.imageUrls;
        continue;
      }

      final question = pendingQuestion?.trim();
      if (question == null || question.isEmpty) {
        continue;
      }
      pairs.add(<String, dynamic>{
        'question': question,
        'answer': item.message.trim(),
        'questionImageUrls': pendingQuestionImages,
        'answerImageUrls': item.imageUrls,
      });
      pendingQuestion = null;
      pendingQuestionImages = const <String>[];
    }

    final trailingQuestion = pendingQuestion?.trim();
    if (trailingQuestion != null &&
        trailingQuestion.isNotEmpty &&
        pairs.isEmpty) {
      pairs.add(<String, dynamic>{
        'question': trailingQuestion,
        'answer': '',
        'questionImageUrls': pendingQuestionImages,
        'answerImageUrls': const <String>[],
      });
    }

    return pairs;
  }

  static Future<List<String>> uploadSupportReplyImages({
    required String requesterUid,
    required String ticketId,
    required List<String> localPaths,
  }) async {
    if (localPaths.isEmpty) {
      return <String>[];
    }

    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    for (final path in localPaths.take(4)) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final storagePath =
          'admin_support_uploads/$requesterUid/$ticketId/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final ref = storage.ref().child(storagePath);
      await ref.putFile(file);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }
}

class AdminSupportMessage {
  const AdminSupportMessage({
    required this.id,
    required this.senderRole,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.imageUrls,
    this.createdAt,
  });

  factory AdminSupportMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminSupportMessage(
      id: doc.id,
      senderRole: (data['senderRole'] as String?)?.trim() ?? 'requester',
      senderUid: (data['senderUid'] as String?)?.trim() ?? '',
      senderName: (data['senderName'] as String?)?.trim() ?? 'ผู้ใช้',
      message: (data['message'] as String?)?.trim() ?? '',
      imageUrls: ((data['imageUrls'] as List?) ?? const <dynamic>[])
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  final String id;
  final String senderRole;
  final String senderUid;
  final String senderName;
  final String message;
  final List<String> imageUrls;
  final DateTime? createdAt;

  bool get isAdmin => senderRole == 'admin';
}
