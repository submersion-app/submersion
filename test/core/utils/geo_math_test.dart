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

  group('normalizeLongitude', () {
    test('leaves an in-range longitude alone', () {
      expect(normalizeLongitude(0), 0);
      expect(normalizeLongitude(150), 150);
      expect(normalizeLongitude(-149.5), -149.5);
    });

    test('folds a longitude past 180 back into range', () {
      expect(normalizeLongitude(180.1), closeTo(-179.9, 1e-9));
      expect(normalizeLongitude(190), closeTo(-170, 1e-9));
      expect(normalizeLongitude(-190), closeTo(170, 1e-9));
      expect(normalizeLongitude(540), closeTo(180, 1e-9));
    });

    test('maps both ends of the seam to 180, the range the app stores', () {
      expect(normalizeLongitude(180), 180);
      expect(normalizeLongitude(-180), 180);
    });
  });

  group('longitudeDelta', () {
    test('is the plain difference when that is the short way', () {
      expect(longitudeDelta(10, 30), closeTo(20, 1e-9));
      expect(longitudeDelta(30, 10), closeTo(-20, 1e-9));
    });

    test('crosses the date line when that is shorter', () {
      // Fiji to Tahiti is 29 degrees east, not 327 degrees west.
      expect(longitudeDelta(178, -149), closeTo(33, 1e-9));
      expect(longitudeDelta(-149, 178), closeTo(-33, 1e-9));
    });
  });
}
