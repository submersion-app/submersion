import 'dart:math' as math;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const double _earthRadiusMeters = 6371000.0;

double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// Great-circle distance between two points in meters (Haversine).
double distanceMeters(GeoPoint a, GeoPoint b) {
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return _earthRadiusMeters * c;
}

/// Initial (forward) bearing from [a] to [b] in degrees, normalized to 0-360.
double initialBearingDegrees(GeoPoint a, GeoPoint b) {
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final bearing = math.atan2(y, x) * 180.0 / math.pi;
  return (bearing + 360.0) % 360.0;
}

const List<String> _cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

/// Formats a bearing as zero-padded degrees + 8-point cardinal, e.g. "042° NE".
String formatBearing(double degrees) {
  final normalized = (degrees % 360 + 360) % 360;
  final index = (((normalized + 22.5) % 360) ~/ 45);
  final padded = normalized.round().toString().padLeft(3, '0');
  return '$padded° ${_cardinals[index]}';
}
