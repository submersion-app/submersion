import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// Pure selection of the best equipment set for a dive.
///
/// Precedence: a geofence containing any of the dive's points (nearest center
/// wins) beats the global default, which beats nothing.
class EquipmentSetSelector {
  const EquipmentSetSelector._();

  /// The geofence-matched set (nearest center) for [divePoints], or null when
  /// no geofence contains any point. Ignores the global default -- callers use
  /// this to decide whether to *suggest* a set (only geofences suggest).
  static EquipmentSet? matchingGeofenceSet({
    required List<GeoPoint> divePoints,
    required List<EquipmentSet> sets,
    required List<EquipmentSetGeofence> geofences,
  }) {
    if (divePoints.isEmpty || geofences.isEmpty) return null;
    EquipmentSetGeofence? best;
    var bestDistance = double.infinity;
    for (final fence in geofences) {
      final nearest = _minDistanceToAnyPoint(fence.center, divePoints);
      if (nearest > fence.radiusMeters) continue;
      if (best == null ||
          nearest < bestDistance ||
          (nearest == bestDistance && _isMoreSpecific(fence, best))) {
        best = fence;
        bestDistance = nearest;
      }
    }
    if (best == null) return null;
    for (final s in sets) {
      if (s.id == best.setId) return s;
    }
    return null;
  }

  /// Best set for a dive: a geofence match beats the global default, which
  /// beats nothing.
  static EquipmentSet? bestSetFor({
    required List<GeoPoint> divePoints,
    required List<EquipmentSet> sets,
    required List<EquipmentSetGeofence> geofences,
  }) {
    final geofenceMatch = matchingGeofenceSet(
      divePoints: divePoints,
      sets: sets,
      geofences: geofences,
    );
    if (geofenceMatch != null) return geofenceMatch;
    for (final s in sets) {
      if (s.isDefault) return s;
    }
    return null;
  }

  static double _minDistanceToAnyPoint(GeoPoint center, List<GeoPoint> points) {
    var min = double.infinity;
    for (final p in points) {
      final d = distanceMeters(center, p);
      if (d < min) min = d;
    }
    return min;
  }

  /// Tie-break when two fences are equidistant: smaller radius (more specific)
  /// wins, then lexicographic setId for determinism.
  static bool _isMoreSpecific(
    EquipmentSetGeofence candidate,
    EquipmentSetGeofence current,
  ) {
    if (candidate.radiusMeters != current.radiusMeters) {
      return candidate.radiusMeters < current.radiusMeters;
    }
    return candidate.setId.compareTo(current.setId) < 0;
  }
}
