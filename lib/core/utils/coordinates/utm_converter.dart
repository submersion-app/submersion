import 'dart:math' as math;

/// WGS84 ellipsoid and UTM projection constants.
const double _a = 6378137.0; // semi-major axis, metres
const double _f = 1 / 298.257223563; // flattening
const double _e2 = _f * (2 - _f); // first eccentricity squared
const double _ep2 = _e2 / (1 - _e2); // second eccentricity squared
const double _k0 = 0.9996; // scale factor on the central meridian

/// Meridional arc series coefficients.
const double _m1 = 1 - _e2 / 4 - 3 * _e2 * _e2 / 64 - 5 * _e2 * _e2 * _e2 / 256;
const double _m2 =
    3 * _e2 / 8 + 3 * _e2 * _e2 / 32 + 45 * _e2 * _e2 * _e2 / 1024;
const double _m3 = 15 * _e2 * _e2 / 256 + 45 * _e2 * _e2 * _e2 / 1024;
const double _m4 = 35 * _e2 * _e2 * _e2 / 3072;

/// Footpoint-latitude series coefficients, used by the inverse projection.
final double _sqrtE = math.sqrt(1 - _e2);
final double _ee = (1 - _sqrtE) / (1 + _sqrtE);
final double _p2 = 3 / 2 * _ee - 27 / 32 * math.pow(_ee, 3);
final double _p3 = 21 / 16 * math.pow(_ee, 2) - 55 / 32 * math.pow(_ee, 4);
final double _p4 = 151 / 96 * math.pow(_ee, 3);
final double _p5 = 1097 / 512 * math.pow(_ee, 4);

/// Latitude band letters from 80S to 84N in 8-degree steps. I and O are
/// omitted because they are too easily confused with 1 and 0, and X spans
/// 12 degrees rather than 8 so the grid reaches 84N.
const String _bandLetters = 'CDEFGHJKLMNPQRSTUVWXX';

/// The northernmost latitude UTM is defined for. Beyond this the standard
/// switches to the Universal Polar Stereographic projection, which this app
/// does not implement.
const double utmMaxLatitude = 84.0;

/// The southernmost latitude UTM is defined for. See [utmMaxLatitude].
const double utmMinLatitude = -80.0;

/// A point projected into a UTM zone.
class UtmCoordinate {
  final int zone;
  final String band;
  final double easting;
  final double northing;

  const UtmCoordinate({
    required this.zone,
    required this.band,
    required this.easting,
    required this.northing,
  });

  /// Bands N and later are north of the equator. The letter, not the sign of
  /// the northing, decides: southern northings carry a false offset that
  /// makes them positive too.
  bool get isNorthern => band.codeUnitAt(0) >= 'N'.codeUnitAt(0);
}

/// The latitude band letter, or null outside the UTM band.
String? utmBandFor(double latitude) {
  if (latitude < utmMinLatitude || latitude > utmMaxLatitude) return null;
  return _bandLetters[((latitude + 80) ~/ 8).clamp(0, 20)];
}

/// The UTM zone number, including the two regional exceptions.
int utmZoneFor(double latitude, double longitude) {
  // Southern Norway: zone 32 is widened westward so Bergen and Stavanger
  // share a zone with the rest of the coast.
  if (latitude >= 56 && latitude < 64 && longitude >= 3 && longitude < 12) {
    return 32;
  }
  // Svalbard: zones 32, 34, and 36 are absorbed by their neighbours, so four
  // zones are reassigned rather than one widened.
  if (latitude >= 72 && latitude < 84) {
    if (longitude >= 0 && longitude < 9) return 31;
    if (longitude >= 9 && longitude < 21) return 33;
    if (longitude >= 21 && longitude < 33) return 35;
    if (longitude >= 33 && longitude < 42) return 37;
  }
  return ((longitude + 180) ~/ 6) + 1;
}

/// Projects a WGS84 latitude/longitude into UTM.
///
/// Returns null outside the UTM latitude band rather than extrapolating the
/// series, which diverges badly near the poles.
UtmCoordinate? latLngToUtm(double latitude, double longitude) {
  final band = utmBandFor(latitude);
  if (band == null) return null;
  final zone = utmZoneFor(latitude, longitude);
  final centralLongitude = zone * 6 - 183;

  final latRad = latitude * math.pi / 180;
  final latSin = math.sin(latRad);
  final latCos = math.cos(latRad);
  final latTan = latSin / latCos;
  final latTan2 = latTan * latTan;
  final latTan4 = latTan2 * latTan2;

  final n = _a / math.sqrt(1 - _e2 * latSin * latSin);
  final c = _ep2 * latCos * latCos;
  final deltaLon = (longitude - centralLongitude) * math.pi / 180;
  final t = latCos * deltaLon;
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;
  final t5 = t4 * t;
  final t6 = t5 * t;

  final m =
      _a *
      (_m1 * latRad -
          _m2 * math.sin(2 * latRad) +
          _m3 * math.sin(4 * latRad) -
          _m4 * math.sin(6 * latRad));

  final easting =
      _k0 *
          n *
          (t +
              t3 / 6 * (1 - latTan2 + c) +
              t5 / 120 * (5 - 18 * latTan2 + latTan4 + 72 * c - 58 * _ep2)) +
      500000.0;

  var northing =
      _k0 *
      (m +
          n *
              latTan *
              (t2 / 2 +
                  t4 / 24 * (5 - latTan2 + 9 * c + 4 * c * c) +
                  t6 /
                      720 *
                      (61 - 58 * latTan2 + latTan4 + 600 * c - 330 * _ep2)));
  // The southern hemisphere carries a false northing so values stay positive.
  if (latitude < 0) northing += 10000000.0;

  return UtmCoordinate(
    zone: zone,
    band: band,
    easting: easting,
    northing: northing,
  );
}

/// Inverse projection back to WGS84 degrees.
({double latitude, double longitude}) utmToLatLng(
  int zone,
  String band,
  double easting,
  double northing,
) {
  final northern = band.codeUnitAt(0) >= 'N'.codeUnitAt(0);
  final x = easting - 500000.0;
  final y = northern ? northing : northing - 10000000.0;

  final m = y / _k0;
  final mu = m / (_a * _m1);
  final footprint =
      mu +
      _p2 * math.sin(2 * mu) +
      _p3 * math.sin(4 * mu) +
      _p4 * math.sin(6 * mu) +
      _p5 * math.sin(8 * mu);

  final pSin = math.sin(footprint);
  final pCos = math.cos(footprint);
  final pTan = pSin / pCos;
  final pTan2 = pTan * pTan;
  final pTan4 = pTan2 * pTan2;

  final epSin = 1 - _e2 * pSin * pSin;
  final n = _a / math.sqrt(epSin);
  final r = (1 - _e2) / epSin;
  final c = _ep2 * pCos * pCos;
  final c2 = c * c;

  final d = x / (n * _k0);
  final d2 = d * d;
  final d3 = d2 * d;
  final d4 = d3 * d;
  final d5 = d4 * d;
  final d6 = d5 * d;

  final latitude =
      footprint -
      (pTan / r) *
          (d2 / 2 -
              d4 / 24 * (5 + 3 * pTan2 + 10 * c - 4 * c2 - 9 * _ep2) +
              d6 /
                  720 *
                  (61 +
                      90 * pTan2 +
                      298 * c +
                      45 * pTan4 -
                      252 * _ep2 -
                      3 * c2));
  final longitude =
      (d -
          d3 / 6 * (1 + 2 * pTan2 + c) +
          d5 /
              120 *
              (5 - 2 * c + 28 * pTan2 - 3 * c2 + 8 * _ep2 + 24 * pTan4)) /
      pCos;

  return (
    latitude: latitude * 180 / math.pi,
    longitude: longitude * 180 / math.pi + (zone * 6 - 183),
  );
}
