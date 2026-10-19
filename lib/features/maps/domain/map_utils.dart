import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/geo_math.dart';

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

/// A drawn download rectangle after [clampRegionToWorld].
///
/// [crossesDateLine] is true when the box straddles longitude 180: one
/// download cannot cover it (the tile cache takes a plain bounding box), so
/// the caller must not download it as drawn.
typedef RegionBounds = ({
  LatLng southWest,
  LatLng northEast,
  bool crossesDateLine,
});

/// A drawn download rectangle, moved into one copy of the world.
///
/// The region picker scrolls east and west without end, so a corner can sit
/// at a longitude beyond +-180 (another copy of the world). The tile counter
/// and the downloader need -180..180:
/// - A box 360 degrees wide or more covers the whole world, so it becomes
///   -180..180.
/// - Otherwise whole worlds are subtracted so the west edge lands in
///   [-180, 180). If the east edge is then past 180 the box straddles the date
///   line: [RegionBounds.crossesDateLine] is set and the east edge is held to
///   180. Nothing is dropped silently: the picker disables Select Region and
///   says why.
/// Latitudes are held to the web Mercator limit.
RegionBounds clampRegionToWorld(LatLng southWest, LatLng northEast) {
  const maxLat = 85.0511;
  final south = southWest.latitude.clamp(-maxLat, maxLat).toDouble();
  final north = northEast.latitude.clamp(-maxLat, maxLat).toDouble();
  // The box as drawn: its first span runs from the west edge to the east edge
  // or, past the date line, to 180; a second span means it straddles the line.
  final spans = longitudeSpans(southWest.longitude, northEast.longitude);
  return (
    southWest: LatLng(south, spans.first.west),
    northEast: LatLng(north, spans.first.east),
    crossesDateLine: spans.length > 1,
  );
}

/// The longitude spans, each inside -180..180, that a rectangle from [west] to
/// [east] covers on the map.
///
/// The region picker keeps longitudes continuous past +-180 (the map repeats
/// the world), but flutter_map's polygons accept only -180..180. A box 360
/// degrees wide or more is the whole world; a box that straddles the date
/// line is two spans, one on each side of it; anything else is one span.
List<({double west, double east})> longitudeSpans(double west, double east) {
  if (east - west >= 360) return [(west: -180, east: 180)];
  final shift = ((west + 180) / 360).floor() * 360.0;
  final spanWest = west - shift;
  final spanEast = east - shift;
  if (spanEast <= 180) return [(west: spanWest, east: spanEast)];
  return [(west: spanWest, east: 180), (west: -180, east: spanEast - 360)];
}
