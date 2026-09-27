import 'dart:math' as math;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Earth's mean radius in metres, as used by the spherical (haversine)
/// distance and bearing calculations in `core/utils/geo_math.dart`
/// (`distanceMeters`, `initialBearingDegrees`, and [enuOffsetMeters] built
/// on them).
///
/// Duplicated here, not imported, because that file keeps its own radius
/// private -- but the value must match exactly: [offsetToGeoPoint] is the
/// closed-form spherical inverse of [offsetFromAnchor], and a different
/// radius on either side would turn a route's own start/end round trip
/// (pick a point on the map, correct the route onto it, draw the result)
/// into a silent few-metre drift instead of landing back where the diver
/// clicked. `metersPerDegreeLatitude`'s nominal constant is deliberately
/// NOT used here for the same reason: it is calibrated for the bathymetry
/// terrain's own flat-earth mesh, not for round-tripping against
/// [enuOffsetMeters].
const double _earthRadiusMeters = 6371000.0;

/// Converts a local east-north-metre offset from [anchor] to an absolute
/// coordinate.
///
/// The exact spherical inverse of [offsetFromAnchor]: recovers the
/// distance and bearing [offsetFromAnchor] encoded as (east, north) and
/// applies the standard direct geodesic formula on a sphere of
/// [_earthRadiusMeters]. Every route consumer that needs to place a
/// corrected point on a map (the 2D layer, the terrain check, a future KML
/// export) uses this, so a route's own georeferencing stays internally
/// consistent even though it is not the same approximation the bathymetry
/// terrain mesh uses for its grid.
GeoPoint offsetToGeoPoint(
  GeoPoint anchor, {
  required double east,
  required double north,
}) {
  final distance = math.sqrt(east * east + north * north);
  if (distance == 0) return anchor;

  // atan2(east, north) recovers the compass bearing (0 = north, clockwise)
  // that enuOffsetMeters encoded as (east, north) = d * (sin brg, cos brg).
  final bearing = math.atan2(east, north);
  final angularDistance = distance / _earthRadiusMeters;
  final lat1 = anchor.latitude * math.pi / 180.0;

  final lat2 = math.asin(
    math.sin(lat1) * math.cos(angularDistance) +
        math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
  );
  final lon2 =
      anchor.longitude * math.pi / 180.0 +
      math.atan2(
        math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
        math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
      );

  return GeoPoint(
    lat2 * 180.0 / math.pi,
    _normalizeLongitude(lon2 * 180.0 / math.pi),
  );
}

/// The local east-north-metre offset of [point] from [anchor].
///
/// A thin, route-vocabulary wrapper over [enuOffsetMeters] (the same
/// haversine distance-and-bearing decomposition the dead-reckoning
/// seascape uses for its own exit-fix offsets), so route code reads in
/// terms of an anchor and a point rather than the generic ENU pair.
({double east, double north}) offsetFromAnchor(
  GeoPoint anchor,
  GeoPoint point,
) => enuOffsetMeters(anchor, point);

/// Wraps a longitude in degrees to (-180, 180], the range every other
/// coordinate in this app is stored and compared in.
double _normalizeLongitude(double degrees) {
  var d = degrees;
  while (d > 180) {
    d -= 360;
  }
  while (d <= -180) {
    d += 360;
  }
  return d;
}
