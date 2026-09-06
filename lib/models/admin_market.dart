import 'package:cloud_firestore/cloud_firestore.dart';

/// Branch / market area used by van4 admin filters.
/// Canonical Firestore path: `branches/{branchId}` (e.g. `branches/central`).
class AdminMarket {
  const AdminMarket({
    required this.id,
    required this.name,
    required this.active,
    this.province,
    this.amphoe,
    this.hubLatitude,
    this.hubLongitude,
    this.hubRadiusMeters,
    this.branchLabel,
    this.isCentral = false,
    this.sortOrder = 0,
  });

  static const String defaultBranchId = 'central';

  final String id;
  final String name;
  final bool active;
  final String? province;
  final String? amphoe;
  final double? hubLatitude;
  final double? hubLongitude;
  final int? hubRadiusMeters;
  final String? branchLabel;
  final bool isCentral;
  final int sortOrder;

  String get displayLabel {
    final label = branchLabel?.trim();
    final parts = <String>[name];
    if (label != null && label.isNotEmpty && label != id) {
      parts.add('($label)');
    }
    if (amphoe != null && amphoe!.trim().isNotEmpty) {
      parts.add(amphoe!.trim());
    }
    return parts.join(' · ');
  }

  static String normalizeBranchId(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return defaultBranchId;
    }
    if (value == 'nonsung') {
      return defaultBranchId;
    }
    return value;
  }

  AdminMarket copyWith({
    String? id,
    String? name,
    bool? active,
    String? province,
    String? amphoe,
    double? hubLatitude,
    double? hubLongitude,
    int? hubRadiusMeters,
    String? branchLabel,
    bool? isCentral,
    int? sortOrder,
  }) {
    return AdminMarket(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      province: province ?? this.province,
      amphoe: amphoe ?? this.amphoe,
      hubLatitude: hubLatitude ?? this.hubLatitude,
      hubLongitude: hubLongitude ?? this.hubLongitude,
      hubRadiusMeters: hubRadiusMeters ?? this.hubRadiusMeters,
      branchLabel: branchLabel ?? this.branchLabel,
      isCentral: isCentral ?? this.isCentral,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toBranchFirestore() {
    return <String, dynamic>{
      'branchId': id,
      'branchName': name,
      'branchLabel': branchLabel ?? id,
      'isActive': active,
      'isCentral': isCentral || id == defaultBranchId,
      if (province != null) 'province': province,
      if (amphoe != null) 'amphoe': amphoe,
      if (hubLatitude != null && hubLongitude != null)
        'gpsLocation': <String, double>{
          'latitude': hubLatitude!,
          'longitude': hubLongitude!,
        },
      if (hubRadiusMeters != null) 'deliveryRadiusKm': hubRadiusMeters! / 1000,
      'sortOrder': sortOrder,
    };
  }

  factory AdminMarket.fromBranchDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final gps = data['gpsLocation'];
    double? lat;
    double? lng;
    if (gps is Map) {
      lat = _readDouble(gps['latitude']);
      lng = _readDouble(gps['longitude']);
    }
    lat ??= _readDouble(data['hubLatitude'] ?? data['latitude']);
    lng ??= _readDouble(data['hubLongitude'] ?? data['longitude']);

    final radiusKm = _readDouble(data['deliveryRadiusKm']);
    final radiusMeters = radiusKm != null
        ? (radiusKm * 1000).round()
        : _readInt(data['hubRadiusMeters']);

    final docId = doc.id.trim();
    final branchId = (data['branchId'] ?? docId).toString().trim();

    return AdminMarket(
      id: branchId.isNotEmpty ? branchId : docId,
      name: data['branchName']?.toString().trim() ??
          data['name']?.toString().trim() ??
          'ไม่ระบุชื่อสาขา',
      active: data['isActive'] != false && data['active'] != false,
      province: data['province']?.toString(),
      amphoe: data['amphoe']?.toString(),
      hubLatitude: lat,
      hubLongitude: lng,
      hubRadiusMeters: radiusMeters,
      branchLabel: data['branchLabel']?.toString() ?? branchId,
      isCentral: data['isCentral'] == true || branchId == defaultBranchId,
      sortOrder: _readInt(data['sortOrder']) ?? 0,
    );
  }

  static AdminMarket centralDefault() {
    return const AdminMarket(
      id: defaultBranchId,
      name: 'ตลาดโนนสูง',
      active: true,
      province: 'อุดรธานี',
      amphoe: 'โนนสูง',
      hubLatitude: 17.271,
      hubLongitude: 102.638,
      hubRadiusMeters: 8000,
      branchLabel: 'central',
      isCentral: true,
      sortOrder: 0,
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

class AdminMarketsDocument {
  const AdminMarketsDocument({
    required this.markets,
    required this.defaultMarketId,
  });

  final List<AdminMarket> markets;
  final String defaultMarketId;

  AdminMarket? marketById(String? id) {
    final normalized = AdminMarket.normalizeBranchId(id);
    if (id == null || id.trim().isEmpty) {
      return null;
    }
    for (final market in markets) {
      if (market.id == normalized || market.id == id.trim()) {
        return market;
      }
    }
    return null;
  }
}
