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

/// Bounding box for [points], padded by ten percent of each span and
/// clamped to the valid ranges. Points outside the valid ranges are
/// skipped. Returns null when no point is usable.
///
/// This is the `_calculateBounds` the dive, site and dive-center maps each
/// carry privately (issue #2330 migrates them onto this one).
LatLngBounds? boundsForPoints(List<LatLng> points) {
  double minLat = 90, maxLat = -90;
  double minLng = 180, maxLng = -180;
  var any = false;

  for (final p in points) {
    final lat = p.latitude;
    final lng = p.longitude;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
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
