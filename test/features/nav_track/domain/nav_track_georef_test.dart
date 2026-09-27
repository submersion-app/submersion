import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';

void main() {
  group('offsetToGeoPoint', () {
    test('the anchor itself is a zero offset', () {
      const anchor = GeoPoint(47.3, 8.5);
      final p = offsetToGeoPoint(anchor, east: 0, north: 0);
      expect(p.latitude, closeTo(anchor.latitude, 1e-12));
      expect(p.longitude, closeTo(anchor.longitude, 1e-12));
    });

    test('a northward offset increases latitude, not longitude', () {
      const anchor = GeoPoint(47.3, 8.5);
      final p = offsetToGeoPoint(anchor, east: 0, north: 100);
      expect(p.latitude, greaterThan(anchor.latitude));
      expect(p.longitude, closeTo(anchor.longitude, 1e-9));
    });

    test(
      'an eastward offset increases longitude, barely touching latitude',
      () {
        const anchor = GeoPoint(47.3, 8.5);
        final p = offsetToGeoPoint(anchor, east: 100, north: 0);
        expect(p.longitude, greaterThan(anchor.longitude));
        // A pure "east" step follows a great circle, which is not exactly a
        // parallel of latitude away from the equator, so latitude drifts by
        // a physically negligible amount (well under a millimetre here) --
        // not exactly zero, which would be the flat-earth answer instead.
        expect(p.latitude, closeTo(anchor.latitude, 1e-7));
      },
    );
  });

  group('offsetFromAnchor', () {
    test('the anchor itself has a zero offset', () {
      const anchor = GeoPoint(47.3, 8.5);
      final offset = offsetFromAnchor(anchor, anchor);
      expect(offset.east, closeTo(0, 1e-9));
      expect(offset.north, closeTo(0, 1e-9));
    });
  });

  group('round trip: lat/lon -> ENU -> lat/lon, within 1 cm', () {
    void checkRoundTrip(GeoPoint anchor, GeoPoint original) {
      final offset = offsetFromAnchor(anchor, original);
      final back = offsetToGeoPoint(
        anchor,
        east: offset.east,
        north: offset.north,
      );
      // 1 cm in degrees of latitude is about 1e-7; use a generous margin
      // since the two conversions use slightly different projections
      // (great-circle bearing/distance one way, flat-earth the other).
      const oneCmInDegrees = 1e-7;
      expect(
        (back.latitude - original.latitude).abs(),
        lessThan(oneCmInDegrees),
      );
      expect(
        (back.longitude - original.longitude).abs(),
        lessThan(oneCmInDegrees / math.cos(anchor.latitude * math.pi / 180)),
      );
    }

    test('at a Swiss lake latitude, a route-scale offset (about 1.5 km)', () {
      checkRoundTrip(const GeoPoint(46.9, 7.2), const GeoPoint(46.913, 7.21));
    });

    test('near the equator, a route-scale offset', () {
      checkRoundTrip(const GeoPoint(0.1, 30.0), const GeoPoint(0.11, 30.01));
    });

    test('at a high latitude, a route-scale offset', () {
      checkRoundTrip(const GeoPoint(68.5, 15.0), const GeoPoint(68.51, 15.02));
    });

    test('for the exact anchor coordinate', () {
      const anchor = GeoPoint(47.3, 8.5);
      checkRoundTrip(anchor, anchor);
    });
  });
}
