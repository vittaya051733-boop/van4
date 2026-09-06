import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../admin_repository.dart';
import '../models/admin_market.dart';
import '../models/admin_session.dart';
import '../utils/branch_geofence_resolver.dart';
import 'admin_shop_branch_index.dart';
import 'admin_branch_query.dart';

/// Holds selected branch + assignment maps for filtering admin dashboards.
/// Canonical shop profile: `{market|shop|restaurant|pharmacy}_registrations/{ownerUid}`.
class AdminMarketScope extends ChangeNotifier {
  AdminMarketScope._();

  static final AdminMarketScope instance = AdminMarketScope._();

  static const String branchesCollection = 'branches';

  /// van1 merchant registration collections (doc id = ownerUid = order.shopOwnerId).
  static const List<String> merchantRegistrationCollections = <String>[
    'market_registrations',
    'shop_registrations',
    'restaurant_registrations',
    'pharmacy_registrations',
    'agriculture_registrations',
    'other_registrations',
  ];

  String? _selectedMarketId;
  bool _canSelectMarket = true;
  String? _lockedBranchId;
  AdminMarketsDocument _catalog = AdminMarketsDocument(
    markets: <AdminMarket>[AdminMarket.centralDefault()],
    defaultMarketId: AdminMarket.defaultBranchId,
  );
  Map<String, AdminShopBranchProfile> _registrationProfileByOwnerId =
      <String, AdminShopBranchProfile>{};
  Map<String, AdminShopBranchProfile> _publicShopProfileByOwnerId =
      <String, AdminShopBranchProfile>{};
  Map<String, String> _riderBranchById = <String, String>{};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _branchesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _shopsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridersSub;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _registrationSubs =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  List<QuerySnapshot<Map<String, dynamic>>?> _registrationSnapshots =
      List<QuerySnapshot<Map<String, dynamic>>?>.filled(
    merchantRegistrationCollections.length,
    null,
  );

  String? get selectedMarketId => _selectedMarketId;

  bool get isAllMarkets => _canSelectMarket && _selectedMarketId == null;

  bool get canSelectMarket => _canSelectMarket;

  String? get lockedBranchId => _lockedBranchId;

  AdminMarketsDocument get catalog => _catalog;

  List<AdminMarket> get activeMarkets =>
      _catalog.markets.where((market) => market.active).toList(growable: false);

  AdminMarket? get selectedMarket => _catalog.marketById(_selectedMarketId);

  String get defaultMarketId => _catalog.defaultMarketId;

  void configureFromSession(AdminSession session) {
    if (!session.allowed) {
      return;
    }
    final branchChanged = session.isBranchScoped
        ? _lockedBranchId != session.normalizedAssignedBranchId
        : _lockedBranchId != null;
    if (session.isBranchScoped) {
      _canSelectMarket = false;
      _lockedBranchId = session.normalizedAssignedBranchId;
      _selectedMarketId = _lockedBranchId;
    } else {
      _canSelectMarket = true;
      _lockedBranchId = null;
    }
    if (branchChanged && _registrationSubs.isNotEmpty) {
      _restartBranchScopedListeners();
    }
    notifyListeners();
  }

  void _restartBranchScopedListeners() {
    for (final sub in _registrationSubs) {
      sub.cancel();
    }
    _registrationSubs.clear();
    _registrationSnapshots = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
      merchantRegistrationCollections.length,
      null,
    );
    _ridersSub?.cancel();
    _ridersSub = null;
    _startRegistrationListeners();
    _startRidersListener();
  }

  void _startRegistrationListeners() {
    for (var index = 0; index < merchantRegistrationCollections.length; index++) {
      final collection = merchantRegistrationCollections[index];
      final sub = AdminBranchQuery.snapshots(collection).listen(
        (snapshot) {
          _registrationSnapshots[index] = snapshot;
          _rebuildRegistrationProfiles();
        },
        onError: (Object error) {
          debugPrint('AdminMarketScope $collection stream error: $error');
        },
      );
      _registrationSubs.add(sub);
    }
  }

  void _startRidersListener() {
    _ridersSub ??= AdminBranchQuery.snapshots('riders').listen(
      (snapshot) {
        final next = <String, String>{};
        for (final doc in snapshot.docs) {
          final branchId = _readBranchIdFromEntityData(doc.data());
          if (branchId != null) {
            next[doc.id] = branchId;
          }
        }
        _riderBranchById = next;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('AdminMarketScope riders stream error: $error');
      },
    );
  }

  void resetSessionScope() {
    _canSelectMarket = true;
    _lockedBranchId = null;
    _selectedMarketId = null;
    notifyListeners();
  }

  void start() {
    _branchesSub ??= FirebaseFirestore.instance.collection(branchesCollection).snapshots().listen(
      (snapshot) {
        _catalog = AdminMarketService.parseBranchesSnapshot(snapshot);
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('AdminMarketScope branches stream error: $error');
      },
    );

    if (_registrationSubs.isEmpty) {
      _startRegistrationListeners();
    }

    _shopsSub ??= FirebaseFirestore.instance.collection('public_shops').snapshots().listen(
      (snapshot) {
        final next = <String, AdminShopBranchProfile>{};
        for (final doc in snapshot.docs) {
          final profile = AdminShopBranchProfile.fromFirestoreMap(
            doc.data(),
            source: 'public_shops',
          );
          if (profile != null) {
            next[doc.id] = profile;
          }
        }
        _publicShopProfileByOwnerId = next;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('AdminMarketScope public_shops stream error: $error');
      },
    );

    _startRidersListener();
  }

  void _rebuildRegistrationProfiles() {
    if (_registrationSnapshots.any((snapshot) => snapshot == null)) {
      return;
    }

    final next = <String, AdminShopBranchProfile>{};
    for (var index = 0; index < merchantRegistrationCollections.length; index++) {
      final collection = merchantRegistrationCollections[index];
      final snapshot = _registrationSnapshots[index]!;
      for (final doc in snapshot.docs) {
        final profile = AdminShopBranchProfile.fromFirestoreMap(
          doc.data(),
          source: collection,
        );
        if (profile == null) {
          continue;
        }
        final ownerId = _resolveOwnerId(doc.id, doc.data());
        if (ownerId == null) {
          continue;
        }
        next[ownerId] = profile;
      }
    }
    _registrationProfileByOwnerId = next;
    notifyListeners();
  }

  static String? _resolveOwnerId(String docId, Map<String, dynamic> data) {
    final ownerId = data['ownerId']?.toString().trim() ??
        data['userId']?.toString().trim() ??
        docId.trim();
    if (ownerId.isEmpty) {
      return null;
    }
    return ownerId;
  }

  static String? _readBranchIdFromEntityData(Map<String, dynamic> data) {
    final branchId = data['branchId']?.toString().trim();
    if (branchId != null && branchId.isNotEmpty) {
      return AdminMarket.normalizeBranchId(branchId);
    }
    final legacyMarket = data['marketId']?.toString().trim();
    if (legacyMarket != null && legacyMarket.isNotEmpty) {
      return AdminMarket.normalizeBranchId(legacyMarket);
    }
    return null;
  }

  void stop() {
    resetSessionScope();
    _branchesSub?.cancel();
    _branchesSub = null;
    for (final sub in _registrationSubs) {
      sub.cancel();
    }
    _registrationSubs.clear();
    _registrationSnapshots = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
      merchantRegistrationCollections.length,
      null,
    );
    _shopsSub?.cancel();
    _shopsSub = null;
    _ridersSub?.cancel();
    _ridersSub = null;
  }

  void selectMarket(String? marketId) {
    if (!_canSelectMarket) {
      return;
    }
    final normalized = marketId?.trim();
    if (normalized != null && normalized.isEmpty) {
      _selectedMarketId = null;
    } else {
      _selectedMarketId =
          normalized == null ? null : AdminMarket.normalizeBranchId(normalized);
    }
    notifyListeners();
  }

  String? marketIdForShopOwner(String? ownerId) {
    return resolveShopBranchId(ownerId);
  }

  String? serviceTypeForShopOwner(String? ownerId) {
    final trimmed = ownerId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return _registrationProfileByOwnerId[trimmed]?.serviceType ??
        _publicShopProfileByOwnerId[trimmed]?.serviceType;
  }

  String? branchDisplayLabelForShopOwner(String? ownerId) {
    final branchId = resolveShopBranchId(ownerId);
    if (branchId == null) {
      return null;
    }
    return _catalog.marketById(branchId)?.displayLabel ?? branchId;
  }

  String? resolveShopBranchId(String? ownerId) {
    final trimmed = ownerId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final fromRegistration = _resolveBranchFromProfile(_registrationProfileByOwnerId[trimmed]);
    if (fromRegistration != null) {
      return fromRegistration;
    }

    final fromPublicShop = _resolveBranchFromProfile(_publicShopProfileByOwnerId[trimmed]);
    if (fromPublicShop != null) {
      return fromPublicShop;
    }

    return null;
  }

  String? resolveOrderBranchId(AdminOrderRecord order) {
    final fromShop = resolveShopBranchId(order.shopOwnerId);
    if (fromShop != null) {
      return fromShop;
    }

    final explicit = order.rawData['branchId']?.toString().trim() ??
        order.rawData['marketId']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) {
      return AdminMarket.normalizeBranchId(explicit);
    }

    return null;
  }

  String? branchDisplayLabelForOrder(AdminOrderRecord order) {
    final branchId = resolveOrderBranchId(order);
    if (branchId == null) {
      return null;
    }
    return _catalog.marketById(branchId)?.displayLabel ?? branchId;
  }

  String? _resolveBranchFromProfile(AdminShopBranchProfile? profile) {
    if (profile == null) {
      return null;
    }

    final stored = profile.branchId?.trim();
    if (stored != null && stored.isNotEmpty) {
      return AdminMarket.normalizeBranchId(stored);
    }

    if (profile.hasCoordinates) {
      return BranchGeofenceResolver.resolveBranchIdOrCentral(
        latitude: profile.latitude!,
        longitude: profile.longitude!,
        branches: activeMarkets,
      );
    }

    return null;
  }

  String? marketIdForRider(String? riderId) {
    final trimmed = riderId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return _riderBranchById[trimmed];
  }

  String? resolveEntityMarketId(String? explicitMarketId, {String? fallbackOwnerId}) {
    final explicit = explicitMarketId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return AdminMarket.normalizeBranchId(explicit);
    }
    if (fallbackOwnerId != null) {
      final fromShop = marketIdForShopOwner(fallbackOwnerId);
      if (fromShop != null && fromShop.isNotEmpty) {
        return fromShop;
      }
    }
    return null;
  }

  bool matchesMarketId(String? entityMarketId, {String? shopOwnerId}) {
    if (isAllMarkets) {
      return true;
    }
    final selected = AdminMarket.normalizeBranchId(_selectedMarketId);
    final resolved = resolveEntityMarketId(entityMarketId, fallbackOwnerId: shopOwnerId);
    if (resolved == selected) {
      return true;
    }
    if (resolved == null && selected == defaultMarketId) {
      return true;
    }
    return false;
  }

  bool matchesOrder(AdminOrderRecord order) {
    return matchesMarketId(resolveOrderBranchId(order), shopOwnerId: order.shopOwnerId);
  }

  bool matchesShopOwner(String? ownerId) {
    if (isAllMarkets) {
      return true;
    }
    return matchesMarketId(resolveShopBranchId(ownerId), shopOwnerId: ownerId);
  }

  bool matchesRider(AdminRiderRecord rider) {
    if (isAllMarkets) {
      return true;
    }
    final explicit = rider.branchId ?? rider.marketId;
    return matchesMarketId(explicit ?? marketIdForRider(rider.id));
  }

  bool matchesShopOperation(String shopId) {
    return matchesShopOwner(shopId);
  }
}

class AdminMarketService {
  AdminMarketService._();

  static final AdminMarketService instance = AdminMarketService._();

  static AdminMarketsDocument parseBranchesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final markets = snapshot.docs.map(AdminMarket.fromBranchDoc).toList(growable: false);
    if (markets.isEmpty) {
      return AdminMarketsDocument(
        markets: <AdminMarket>[AdminMarket.centralDefault()],
        defaultMarketId: AdminMarket.defaultBranchId,
      );
    }

    final sorted = List<AdminMarket>.from(markets)
      ..sort((left, right) {
        if (left.isCentral != right.isCentral) {
          return left.isCentral ? -1 : 1;
        }
        final orderCompare = left.sortOrder.compareTo(right.sortOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.name.compareTo(right.name);
      });

    final defaultBranch = sorted.firstWhere(
      (branch) => branch.isCentral || branch.id == AdminMarket.defaultBranchId,
      orElse: () => sorted.first,
    );

    return AdminMarketsDocument(
      markets: sorted,
      defaultMarketId: defaultBranch.id,
    );
  }

  Stream<AdminMarketsDocument> streamBranchesCatalog() {
    return FirebaseFirestore.instance.collection(AdminMarketScope.branchesCollection).snapshots().map(
          parseBranchesSnapshot,
        );
  }

  Future<void> ensureDefaultCatalog({required String adminEmail}) async {
    final ref = FirebaseFirestore.instance
        .collection(AdminMarketScope.branchesCollection)
        .doc(AdminMarket.defaultBranchId);
    final snapshot = await ref.get();
    if (snapshot.exists && snapshot.data()?['branchName'] != null) {
      return;
    }

    final central = AdminMarket.centralDefault();
    await ref.set(<String, dynamic>{
      ...central.toBranchFirestore(),
      'seededFrom': 'van4_admin',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminEmail,
    }, SetOptions(merge: true));
  }

  Future<void> saveBranch({
    required AdminMarket branch,
    required String adminEmail,
  }) async {
    await FirebaseFirestore.instance
        .collection(AdminMarketScope.branchesCollection)
        .doc(branch.id)
        .set(<String, dynamic>{
      ...branch.toBranchFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminEmail,
    }, SetOptions(merge: true));
  }

  Future<void> assignShopMarket({
    required String ownerId,
    required String marketId,
    required String adminEmail,
    AdminMarket? branch,
  }) async {
    final normalized = AdminMarket.normalizeBranchId(marketId);
    final branchMeta = branch ?? AdminMarketScope.instance.catalog.marketById(normalized);
    await FirebaseFirestore.instance.collection('public_shops').doc(ownerId).set(
      <String, dynamic>{
        'branchId': normalized,
        if (branchMeta != null) 'branchName': branchMeta.name,
        'branchLabel': branchMeta?.branchLabel ?? normalized,
        'marketId': normalized,
        'branchAssignedAt': FieldValue.serverTimestamp(),
        'branchAssignedBy': adminEmail,
        'branchAssignmentSource': 'van4_admin_manual',
      },
      SetOptions(merge: true),
    );
  }

  Future<void> assignRiderMarket({
    required String riderId,
    required String marketId,
    required String adminEmail,
    AdminMarket? branch,
  }) async {
    final normalized = AdminMarket.normalizeBranchId(marketId);
    final branchMeta = branch ?? AdminMarketScope.instance.catalog.marketById(normalized);
    await FirebaseFirestore.instance.collection('riders').doc(riderId).set(
      <String, dynamic>{
        'branchId': normalized,
        if (branchMeta != null) 'branchName': branchMeta.name,
        'branchLabel': branchMeta?.branchLabel ?? normalized,
        'marketId': normalized,
        'branchAssignedAt': FieldValue.serverTimestamp(),
        'branchAssignedBy': adminEmail,
        'branchAssignmentSource': 'van4_admin_manual',
      },
      SetOptions(merge: true),
    );
  }
}

Stream<T> streamWithAdminMarketScope<T>(Stream<T> Function(AdminMarketScope scope) builder) {
  final scope = AdminMarketScope.instance;
  return Stream<T>.multi((controller) {
    StreamSubscription<T>? innerSub;

    void resubscribe() {
      innerSub?.cancel();
      innerSub = builder(scope).listen(
        controller.add,
        onError: controller.addError,
      );
    }

    scope.addListener(resubscribe);
    resubscribe();

    controller.onCancel = () async {
      scope.removeListener(resubscribe);
      await innerSub?.cancel();
    };
  });
}
