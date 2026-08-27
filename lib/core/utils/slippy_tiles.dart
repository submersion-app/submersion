import 'dart:math' as math;

/// Normalized Web Mercator world x for [lonDeg]: 0 at -180, 1 at +180.
double mercatorX(double lonDeg) => (lonDeg + 180.0) / 360.0;

/// The Web Mercator latitude limit: the projection diverges beyond it and
/// is undefined at the poles.
const double _maxMercatorLatDeg = 85.05112878;

/// Normalized Web Mercator world y for [latDeg]: 0 at the projection's
/// north edge (~85.05 N), 1 at its south edge. Latitudes beyond the
/// projection limit clamp to the nearest edge rather than diverging.
double mercatorY(double latDeg) {
  final lat = latDeg.clamp(-_maxMercatorLatDeg, _maxMercatorLatDeg);
  final latRad = lat * math.pi / 180.0;
  final y =
      (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
      2.0;
  return y.clamp(0.0, 1.0);
}

/// The slippy-map tile containing (lat, lon) at [zoom]; indices clamp to
/// the world's 0..n-1 range so edge coordinates never name a tile that
/// does not exist.
({int x, int y}) slippyTileOf(double lat, double lon, int zoom) {
  final n = 1 << zoom;
  return (
    x: (mercatorX(lon) * n).floor().clamp(0, n - 1),
    y: (mercatorY(lat) * n).floor().clamp(0, n - 1),
  );
}

/// The zoom where a box of [lonSpanDeg] spans about [targetTiles] tiles,
/// clamped to [minZoom]..[maxZoom]. Keeps terrain-drape mosaics at a
/// handful of fetches regardless of latitude or box size.
int imageryZoomFor({
  required double lonSpanDeg,
  required int maxZoom,
  int targetTiles = 4,
  int minZoom = 10,
}) {
  if (lonSpanDeg <= 0) return minZoom;
  final z = (math.log(targetTiles * 360.0 / lonSpanDeg) / math.ln2).round();
  return z.clamp(minZoom, maxZoom);
}
