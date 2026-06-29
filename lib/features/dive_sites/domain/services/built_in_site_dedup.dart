import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Returns the built-in sites that are NOT within [radiusMeters] of any user
/// site. User sites are bucketed into a coarse lat/lng grid so each built-in
/// is tested only against user sites in its own and adjacent cells, keeping
/// the cost near-linear instead of |builtIn| x |userSites|.
List<ExternalDiveSite> visibleBuiltInSites(
  List<ExternalDiveSite> builtIn,
  List<DiveSite> userSites, {
  double radiusMeters = 150,
}) {
  // Cell size of 1 degree comfortably exceeds the 150 m radius at any
  // latitude, so a match can only fall in the same or an adjacent cell.
  const cellDeg = 1.0;
  int keyOf(int gx, int gy) => gx * 100000 + gy;

  final grid = <int, List<GeoPoint>>{};
  for (final site in userSites) {
    final loc = site.location;
    if (loc == null) continue;
    final gx = (loc.longitude / cellDeg).floor();
    final gy = (loc.latitude / cellDeg).floor();
    (grid[keyOf(gx, gy)] ??= <GeoPoint>[]).add(loc);
  }

  bool hasNearbyUserSite(double lat, double lng) {
    final gx = (lng / cellDeg).floor();
    final gy = (lat / cellDeg).floor();
    final probe = GeoPoint(lat, lng);
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final bucket = grid[keyOf(gx + dx, gy + dy)];
        if (bucket == null) continue;
        for (final u in bucket) {
          if (distanceMeters(probe, u) <= radiusMeters) return true;
        }
      }
    }
    return false;
  }

  return builtIn
      .where(
        (b) =>
            b.latitude != null &&
            b.longitude != null &&
            !hasNearbyUserSite(b.latitude!, b.longitude!),
      )
      .toList();
}
