import 'dart:math' as math;
import 'dart:typed_data';

/// Kilometres per degree of latitude. Constant enough at this scale: the
/// resolver only ever measures a few kilometres of coastline slack.
const double _kmPerDegreeLatitude = 110.574;

/// Kilometres per degree of longitude at the equator, shrunk by cos(lat)
/// at the point being measured.
const double _kmPerDegreeLongitudeAtEquator = 111.320;

/// A closed ring of longitude/latitude pairs, stored flat as
/// `[lon, lat, lon, lat, ...]` with the first pair repeated at the end.
///
/// Flat storage matters here: the shipped table is around ninety thousand
/// vertices, and a list of point objects would cost several times the
/// memory of one [Float64List] holding the same numbers.
class SeaAreaRing {
  SeaAreaRing(this.coordinates)
    : assert(
        coordinates.length >= 8 && coordinates.length.isEven,
        'a ring needs at least three distinct points, closed',
      ) {
    var minX = coordinates[0];
    var maxX = coordinates[0];
    var minY = coordinates[1];
    var maxY = coordinates[1];
    for (var i = 2; i < coordinates.length; i += 2) {
      final x = coordinates[i];
      final y = coordinates[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    minLon = minX;
    maxLon = maxX;
    minLat = minY;
    maxLat = maxY;
  }

  final Float64List coordinates;

  late final double minLon;
  late final double minLat;
  late final double maxLon;
  late final double maxLat;

  /// Vertex count, counting the repeated closing point once.
  int get vertexCount => coordinates.length ~/ 2 - 1;

  /// Crossing-number point-in-polygon test in plate carree space.
  ///
  /// The shipped rings are pre-split at the antimeridian, apart from the
  /// two circumpolar rings (Arctic and Southern oceans) which genuinely
  /// span the full longitude range and close along the top or bottom edge,
  /// so a flat test is correct for every ring in the table.
  bool containsPoint(double lon, double lat) {
    if (lon < minLon || lon > maxLon || lat < minLat || lat > maxLat) {
      return false;
    }
    var inside = false;
    final n = coordinates.length;
    var jx = coordinates[n - 2];
    var jy = coordinates[n - 1];
    for (var i = 0; i < n; i += 2) {
      final ix = coordinates[i];
      final iy = coordinates[i + 1];
      if ((iy > lat) != (jy > lat)) {
        final crossing = (jx - ix) * (lat - iy) / (jy - iy) + ix;
        if (lon < crossing) inside = !inside;
      }
      jx = ix;
      jy = iy;
    }
    return inside;
  }

  /// Distance from the point to the nearest edge, in kilometres.
  ///
  /// Degrees are projected to kilometres at the query latitude before the
  /// comparison, so the answer is meaningful at both the equator and high
  /// latitudes. Zero for a point lying on the ring; inside and outside are
  /// not distinguished, which is what the caller wants when it is asking
  /// "how far off this coastline am I?".
  double distanceKm(double lon, double lat) {
    final kx = _kmPerDegreeLongitudeAtEquator * math.cos(lat * math.pi / 180.0);
    const ky = _kmPerDegreeLatitude;
    var best = double.infinity;
    for (var i = 0; i + 3 < coordinates.length; i += 2) {
      final ax = (coordinates[i] - lon) * kx;
      final ay = (coordinates[i + 1] - lat) * ky;
      final bx = (coordinates[i + 2] - lon) * kx;
      final by = (coordinates[i + 3] - lat) * ky;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      var t = 0.0;
      if (lengthSquared > 0) {
        t = -(ax * dx + ay * dy) / lengthSquared;
        if (t < 0) {
          t = 0;
        } else if (t > 1) {
          t = 1;
        }
      }
      final px = ax + t * dx;
      final py = ay + t * dy;
      final squared = px * px + py * py;
      if (squared < best) best = squared;
    }
    return math.sqrt(best);
  }
}

/// One outline plus the landmasses cut out of it.
///
/// Only islands big enough to hold an inland dive site survive into
/// [holes]; the generator drops smaller ones, so a site on a small island
/// reports the sea around it rather than nothing.
class SeaAreaPolygon {
  const SeaAreaPolygon({required this.outer, this.holes = const []});

  final SeaAreaRing outer;
  final List<SeaAreaRing> holes;

  bool contains(double lon, double lat) {
    if (!outer.containsPoint(lon, lat)) return false;
    for (final hole in holes) {
      if (hole.containsPoint(lon, lat)) return false;
    }
    return true;
  }

  /// Distance to the nearest edge of the outline or of any hole. A point
  /// just inland on a carved-out island is near that island's coast, which
  /// is the answer a shore dive wants.
  double distanceKm(double lon, double lat) {
    var best = outer.distanceKm(lon, lat);
    for (final hole in holes) {
      final d = hole.distanceKm(lon, lat);
      if (d < best) best = d;
    }
    return best;
  }
}

/// One named ocean or sea from the shipped IHO table.
class SeaArea {
  const SeaArea({
    required this.name,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
    required this.areaSquareDegrees,
    required this.polygons,
  });

  factory SeaArea.fromJson(Map<String, dynamic> json) {
    final bbox = (json['bbox'] as List).cast<num>();
    return SeaArea(
      name: json['name'] as String,
      minLon: bbox[0].toDouble(),
      minLat: bbox[1].toDouble(),
      maxLon: bbox[2].toDouble(),
      maxLat: bbox[3].toDouble(),
      areaSquareDegrees: (json['area'] as num).toDouble(),
      polygons: [
        for (final p in json['polygons'] as List)
          _polygonFromJson(p as Map<String, dynamic>),
      ],
    );
  }

  final String name;
  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;

  /// Extent in square degrees, and the specificity ranking with it: the
  /// smallest area containing a point carries the most specific name for
  /// it, which is why the Gulf of Aqaba beats the Red Sea.
  final double areaSquareDegrees;

  final List<SeaAreaPolygon> polygons;

  bool contains(double lon, double lat) {
    if (lon < minLon || lon > maxLon || lat < minLat || lat > maxLat) {
      return false;
    }
    for (final polygon in polygons) {
      if (polygon.contains(lon, lat)) return true;
    }
    return false;
  }

  /// Whether the point falls within [marginKm] of the bounding box: a cheap
  /// reject before the per-edge distance walk.
  bool isNear(double lon, double lat, double marginKm) {
    final latMargin = marginKm / _kmPerDegreeLatitude;
    final scale = math.cos(lat * math.pi / 180.0);
    final lonMargin = scale > 0.01
        ? marginKm / (_kmPerDegreeLongitudeAtEquator * scale)
        : 180.0;
    return lon >= minLon - lonMargin &&
        lon <= maxLon + lonMargin &&
        lat >= minLat - latMargin &&
        lat <= maxLat + latMargin;
  }

  /// Distance from the point to this area's nearest coastline, in
  /// kilometres.
  double distanceKm(double lon, double lat) {
    var best = double.infinity;
    for (final polygon in polygons) {
      final d = polygon.distanceKm(lon, lat);
      if (d < best) best = d;
    }
    return best;
  }

  @override
  String toString() => 'SeaArea($name, ${polygons.length} polygons)';
}

SeaAreaPolygon _polygonFromJson(Map<String, dynamic> json) => SeaAreaPolygon(
  outer: _ringFromJson(json['outer'] as List),
  holes: [
    for (final h in (json['holes'] as List? ?? const []))
      _ringFromJson(h as List),
  ],
);

SeaAreaRing _ringFromJson(List<dynamic> flat) => SeaAreaRing(
  Float64List.fromList([for (final v in flat) (v as num).toDouble()]),
);
