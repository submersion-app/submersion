import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('geo_math', () {
    test('distanceMeters: ~111m for 0.001 deg of longitude at equator', () {
      final d = distanceMeters(const GeoPoint(0, 0), const GeoPoint(0, 0.001));
      expect(d, closeTo(111.3, 1.0));
    });

    test('distanceMeters: zero for identical points', () {
      expect(
        distanceMeters(const GeoPoint(10, 20), const GeoPoint(10, 20)),
        closeTo(0, 0.001),
      );
    });

    test('initialBearingDegrees: due north is 0', () {
      expect(
        initialBearingDegrees(const GeoPoint(0, 0), const GeoPoint(1, 0)),
        closeTo(0, 0.5),
      );
    });

    test('initialBearingDegrees: due east is 90', () {
      expect(
        initialBearingDegrees(const GeoPoint(0, 0), const GeoPoint(0, 1)),
        closeTo(90, 0.5),
      );
    });

    test('formatBearing: zero-padded degrees + 8-point cardinal', () {
      expect(formatBearing(0), '000° N');
      expect(formatBearing(42), '042° NE');
      expect(formatBearing(90), '090° E');
      expect(formatBearing(225), '225° SW');
    });
  });
}
