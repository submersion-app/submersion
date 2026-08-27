import 'dart:math' as math;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

/// Metres per degree of latitude (constant everywhere on a sphere).
const double _metersPerDegreeLatitude = 111194.93;

/// Projects [p] into a local flat east/north plane in metres, anchored at
/// [origin].
///
/// A dive-day track spans kilometres, so the flat-earth error over that span
/// is far below the tightest simplification tolerance (2 m). Working in this
/// plane makes perpendicular point-to-segment distance trivial, which is what
/// Douglas-Peucker needs.
///
/// The longitude delta is unwrapped, so a track crossing the antimeridian
/// stays locally continuous. Raw subtraction reads the step from 179.9 to
/// -179.9 - about 11 km of boat travel - as -359.8 degrees, roughly 40,000 km
/// west. Every deviation Douglas-Peucker measured against that segment was
/// then meaningless, so a dateline track simplified to garbage.
({double east, double north}) projectLocal(
  GpsTrackPoint origin,
  GpsTrackPoint p,
) {
  final metersPerLon = metersPerDegreeLongitude(origin.latitude);
  return (
    east: unwrapLongitudeDelta(p.longitude - origin.longitude) * metersPerLon,
    north: (p.latitude - origin.latitude) * _metersPerDegreeLatitude,
  );
}

/// Maps a raw longitude difference into [-180, 180], taking the short way
/// round. Two points 0.2 degrees apart across the dateline differ by 0.2, not
/// 359.8.
double unwrapLongitudeDelta(double delta) {
  if (delta > 180.0) return delta - 360.0;
  if (delta < -180.0) return delta + 360.0;
  return delta;
}

/// Perpendicular distance in metres from [point] to the segment [a]-[b].
double _perpendicularDistance(
  ({double east, double north}) point,
  ({double east, double north}) a,
  ({double east, double north}) b,
) {
  final dx = b.east - a.east;
  final dy = b.north - a.north;
  final lengthSquared = dx * dx + dy * dy;

  // Degenerate segment: fall back to straight point-to-point distance.
  if (lengthSquared == 0) {
    final px = point.east - a.east;
    final py = point.north - a.north;
    return math.sqrt(px * px + py * py);
  }

  // Project onto the segment, clamped to its extent.
  var t =
      ((point.east - a.east) * dx + (point.north - a.north) * dy) /
      lengthSquared;
  t = t.clamp(0.0, 1.0);

  final projectedX = a.east + t * dx;
  final projectedY = a.north + t * dy;
  final ex = point.east - projectedX;
  final ey = point.north - projectedY;
  return math.sqrt(ex * ex + ey * ey);
}

/// Reduces [points] to the subset whose maximum perpendicular deviation from
/// the retained polyline stays within [toleranceMeters] (Douglas-Peucker).
///
/// First and last points are always retained. Surviving points keep their
/// original timestamps and accuracy - this decimates, it never interpolates.
List<GpsTrackPoint> simplifyTrack(
  List<GpsTrackPoint> points,
  double toleranceMeters,
) {
  if (points.length < 3) return List.unmodifiable(points);

  final origin = points.first;
  final projected = [for (final p in points) projectLocal(origin, p)];
  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  // Iterative rather than recursive: a 21k-point track would risk a deep
  // recursion on pathological input.
  final stack = <({int start, int end})>[(start: 0, end: points.length - 1)];

  while (stack.isNotEmpty) {
    final segment = stack.removeLast();
    var maxDistance = 0.0;
    var maxIndex = -1;

    for (var i = segment.start + 1; i < segment.end; i++) {
      final distance = _perpendicularDistance(
        projected[i],
        projected[segment.start],
        projected[segment.end],
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxIndex != -1 && maxDistance > toleranceMeters) {
      keep[maxIndex] = true;
      stack.add((start: segment.start, end: maxIndex));
      stack.add((start: maxIndex, end: segment.end));
    }
  }

  return List.unmodifiable([
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ]);
}

/// Converts a track point to the [GeoPoint] the shared geo helpers take.
GeoPoint toGeoPoint(GpsTrackPoint p) => GeoPoint(p.latitude, p.longitude);

/// Points whose timestamp falls within [fromEpochSeconds]..[toEpochSeconds]
/// inclusive. Both bounds are wall-clock-as-UTC epoch SECONDS.
List<GpsTrackPoint> windowTrack(
  List<GpsTrackPoint> points, {
  required int fromEpochSeconds,
  required int toEpochSeconds,
}) {
  if (fromEpochSeconds > toEpochSeconds) return const [];
  return List.unmodifiable([
    for (final p in points)
      if (p.timestamp >= fromEpochSeconds && p.timestamp <= toEpochSeconds) p,
  ]);
}

/// Bounding box of [points], or null when empty.
///
/// Longitudes are unwrapped across the antimeridian: a track running from
/// 179.9 E to 179.9 W reports minLon 179.9 and maxLon 180.1 (a 0.2 deg span)
/// rather than the 359.8 deg span a naive min/max would produce, which would
/// fit the camera to the entire globe.
({double minLat, double maxLat, double minLon, double maxLon})? trackBounds(
  List<GpsTrackPoint> points,
) {
  if (points.isEmpty) return null;

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
  }

  var minLon = points.first.longitude;
  var maxLon = points.first.longitude;
  for (final p in points) {
    if (p.longitude < minLon) minLon = p.longitude;
    if (p.longitude > maxLon) maxLon = p.longitude;
  }

  // A raw span wider than half the globe means the track almost certainly
  // wraps the antimeridian rather than genuinely circling the planet. Re-run
  // the extent with western longitudes shifted into a continuous frame.
  if (maxLon - minLon > 180.0) {
    var shiftedMin = double.infinity;
    var shiftedMax = double.negativeInfinity;
    for (final p in points) {
      final lon = p.longitude < 0 ? p.longitude + 360.0 : p.longitude;
      if (lon < shiftedMin) shiftedMin = lon;
      if (lon > shiftedMax) shiftedMax = lon;
    }
    minLon = shiftedMin;
    maxLon = shiftedMax;
  }

  return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
}

/// Whether [bounds] was unwrapped past the antimeridian by [trackBounds].
///
/// True means maxLon exceeds 180 and the bounds CANNOT be handed to
/// flutter_map's LatLngBounds, which asserts `east <= 180`.
bool crossesAntimeridian(
  ({double minLat, double maxLat, double minLon, double maxLon}) bounds,
) => bounds.maxLon > 180.0;

/// Wraps a longitude back into the -180..180 range flutter_map accepts.
double normalizeLongitude(double lon) {
  var wrapped = (lon + 180.0) % 360.0;
  if (wrapped < 0) wrapped += 360.0;
  return wrapped - 180.0;
}

/// A point's longitude in the same continuous frame [trackBounds] used, so a
/// caller that draws against those bounds stays consistent with them.
///
/// Mixing a shifted minLon with raw point longitudes puts the western half of
/// an antimeridian track hundreds of degrees off.
double longitudeInBoundsFrame(
  double lon,
  ({double minLat, double maxLat, double minLon, double maxLon}) bounds,
) => crossesAntimeridian(bounds) && lon < 0 ? lon + 360.0 : lon;

/// Ground speed in metres per second between two consecutive fixes.
///
/// Returns 0 for zero or negative elapsed time. GPS logs do occasionally
/// carry out-of-order or duplicated timestamps, and a negative speed would
/// poison bucketing and the max-speed statistic.
double speedMpsBetween(GpsTrackPoint a, GpsTrackPoint b) {
  final elapsed = b.timestamp - a.timestamp;
  if (elapsed <= 0) return 0.0;
  return distanceMeters(toGeoPoint(a), toGeoPoint(b)) / elapsed;
}

/// Total along-track distance in metres.
double trackDistanceMeters(List<GpsTrackPoint> points) {
  if (points.length < 2) return 0.0;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += distanceMeters(toGeoPoint(points[i - 1]), toGeoPoint(points[i]));
  }
  return total;
}
