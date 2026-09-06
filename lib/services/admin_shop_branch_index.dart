/// Cached branch + location profile for a merchant shop (owner uid).
class AdminShopBranchProfile {
  const AdminShopBranchProfile({
    this.branchId,
    this.latitude,
    this.longitude,
    this.serviceType,
    this.source = 'unknown',
  });

  final String? branchId;
  final double? latitude;
  final double? longitude;
  final String? serviceType;
  final String source;

  bool get hasCoordinates => latitude != null && longitude != null;

  static AdminShopBranchProfile? fromFirestoreMap(
    Map<String, dynamic> data, {
    required String source,
  }) {
    final coords = _extractCoordinates(data);
    final branchId = _readBranchId(data);
    final serviceType = data['serviceType']?.toString().trim();

    if (branchId == null && coords == null && (serviceType == null || serviceType.isEmpty)) {
      return null;
    }

    return AdminShopBranchProfile(
      branchId: branchId,
      latitude: coords?.$1,
      longitude: coords?.$2,
      serviceType: serviceType?.isEmpty == true ? null : serviceType,
      source: source,
    );
  }

  static String? _readBranchId(Map<String, dynamic> data) {
    final branchId = data['branchId']?.toString().trim();
    if (branchId != null && branchId.isNotEmpty) {
      return branchId;
    }
    final legacyMarket = data['marketId']?.toString().trim();
    if (legacyMarket != null && legacyMarket.isNotEmpty) {
      return legacyMarket;
    }
    return null;
  }

  static (double, double)? _extractCoordinates(Map<String, dynamic> data) {
    final locationRaw = data['location'] ?? data['shopLocation'] ?? data['branchMatchedFromLocation'];
    if (locationRaw is Map) {
      final lat = _toDouble(locationRaw['latitude'] ?? locationRaw['lat']);
      final lng = _toDouble(
        locationRaw['longitude'] ?? locationRaw['lng'] ?? locationRaw['long'],
      );
      if (lat != null && lng != null) {
        return (lat, lng);
      }
    }

    final lat = _toDouble(data['latitude'] ?? data['shopLatitude'] ?? data['lat']);
    final lng = _toDouble(data['longitude'] ?? data['shopLongitude'] ?? data['lng']);
    if (lat != null && lng != null) {
      return (lat, lng);
    }
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}
