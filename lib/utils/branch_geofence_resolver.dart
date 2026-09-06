import 'dart:math' as math;

import '../models/admin_market.dart';

/// Matches shop coordinates to the nearest active branch within its radius.
/// Mirrors van1 BranchAssignmentService without adding geolocator.
class BranchGeofenceResolver {
  BranchGeofenceResolver._();

  static String? resolveBranchId({
    required double latitude,
    required double longitude,
    required List<AdminMarket> branches,
  }) {
    String? bestId;
    double? bestDistanceMeters;

    for (final branch in branches) {
      if (!branch.active) {
        continue;
      }
      final hubLat = branch.hubLatitude;
      final hubLng = branch.hubLongitude;
      final radiusMeters = branch.hubRadiusMeters;
      if (hubLat == null || hubLng == null || radiusMeters == null || radiusMeters <= 0) {
        continue;
      }

      final distanceMeters = haversineMeters(
        latitude,
        longitude,
        hubLat,
        hubLng,
      );
      if (distanceMeters > radiusMeters) {
        continue;
      }

      if (bestDistanceMeters == null || distanceMeters < bestDistanceMeters) {
        bestDistanceMeters = distanceMeters;
        bestId = branch.id;
      }
    }

    return bestId;
  }

  static String resolveBranchIdOrCentral({
    required double latitude,
    required double longitude,
    required List<AdminMarket> branches,
  }) {
    return resolveBranchId(
          latitude: latitude,
          longitude: longitude,
          branches: branches,
        ) ??
        AdminMarket.defaultBranchId;
  }

  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }
}
