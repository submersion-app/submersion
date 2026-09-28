import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Calculate an appropriate zoom level for a set of map points.
///
/// Uses a heuristic based on the maximum geographic span (latitude or
/// longitude) of the bounding box to select a discrete zoom level.
double calculateZoomForBounds(List<LatLng> points, LatLngBounds bounds) {
  if (points.length <= 1) return 12.0;

  final latSpan = bounds.north - bounds.south;
  final lngSpan = bounds.east - bounds.west;
  final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

  if (maxSpan > 5) return 4.0;
  if (maxSpan > 2) return 6.0;
  if (maxSpan > 1) return 7.0;
  if (maxSpan > 0.5) return 8.0;
  if (maxSpan > 0.2) return 9.0;
  if (maxSpan > 0.1) return 10.0;
  return 11.0;
}

/// Whether [p] can be placed on a map: both axes finite and inside the
/// valid ranges. A NaN fails every range comparison, so the finite check
/// has to come first or it slips through.
bool isUsableMapPoint(LatLng p) =>
    p.latitude.isFinite &&
    p.longitude.isFinite &&
    p.latitude >= -90 &&
    p.latitude <= 90 &&
    p.longitude >= -180 &&
    p.longitude <= 180;

/// [longitude] folded into [-180, 180). Both ends of the seam land on -180.
double normalizeLongitude(double longitude) {
  final folded = (longitude + 180) % 360;
  return folded - 180;
}

/// The signed number of degrees to travel east from [from] to reach [to]
/// the short way round, in (-180, 180]. Negative means west.
double longitudeDelta(double from, double to) {
  final delta = normalizeLongitude(to - from);
  return delta == -180 ? 180 : delta;
}

/// The narrowest band of longitudes that holds every one of [longitudes],
/// crossing the date line when that is shorter than going through
/// Greenwich (issue #2516: dives in Australia and the Pacific framed on
/// Africa). [west] is in range; [east] is at or past [west] and can run
/// beyond 180, so `east - west` is the span's width. Null when empty.
///
/// The band is the circle minus its largest gap between neighbouring
/// longitudes.
({double west, double east})? shortestLongitudeSpan(
  Iterable<double> longitudes,
) {
  final sorted = longitudes.map(normalizeLongitude).toList()..sort();
  if (sorted.isEmpty) return null;

  // Start with the gap that wraps from the last longitude round to the
  // first: leaving it out is the ordinary min-to-max span.
  var gap = sorted.first + 360 - sorted.last;
  var west = sorted.first;
  var east = sorted.last;
  for (var i = 1; i < sorted.length; i++) {
    final inner = sorted[i] - sorted[i - 1];
    if (inner > gap) {
      gap = inner;
      west = sorted[i];
      east = sorted[i - 1] + 360;
    }
  }
  return (west: west, east: east);
}

/// Bounding box for [points], padded by ten percent of each span and
/// clamped to the valid ranges. Points that fail [isUsableMapPoint] are
/// skipped. Returns null when no point is usable.
///
/// A box like this cannot cross the date line; to frame points on both
/// sides of it, use `WorldCameraFit` (issue #2516).
LatLngBounds? boundsForPoints(List<LatLng> points) {
  double minLat = 90, maxLat = -90;
  double minLng = 180, maxLng = -180;
  var any = false;

  for (final p in points) {
    if (!isUsableMapPoint(p)) continue;
    final lat = p.latitude;
    final lng = p.longitude;
    any = true;
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
  }
  if (!any) return null;

  final latPadding = (maxLat - minLat) * 0.1;
  final lngPadding = (maxLng - minLng) * 0.1;
  final south = (minLat - latPadding).clamp(-90.0, 90.0);
  final north = (maxLat + latPadding).clamp(-90.0, 90.0);
  final west = (minLng - lngPadding).clamp(-180.0, 180.0);
  final east = (maxLng + lngPadding).clamp(-180.0, 180.0);
  return LatLngBounds(LatLng(south, west), LatLng(north, east));
}
