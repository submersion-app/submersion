import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/surface_pressure_limits.dart';

/// Issue #4208: a header that holds no reading must not become a surface
/// pressure, on any route a reading takes into the dive.
void main() {
  group('plausibleSurfacePressureBar', () {
    test('keeps a reading some surface could give', () {
      expect(plausibleSurfacePressureBar(0.996), 0.996);
      expect(plausibleSurfacePressureBar(0.47), 0.47);
    });

    test('keeps the ends of the window', () {
      expect(
        plausibleSurfacePressureBar(kMinPlausibleSurfacePressureBar),
        kMinPlausibleSurfacePressureBar,
      );
      expect(
        plausibleSurfacePressureBar(kMaxPlausibleSurfacePressureBar),
        kMaxPlausibleSurfacePressureBar,
      );
    });

    test('a zero header is no reading', () {
      expect(plausibleSurfacePressureBar(0.0), isNull);
    });

    test('nothing outside the window counts', () {
      expect(plausibleSurfacePressureBar(0.39), isNull);
      expect(plausibleSurfacePressureBar(1.21), isNull);
      expect(plausibleSurfacePressureBar(1013.0), isNull);
      expect(plausibleSurfacePressureBar(-1.0), isNull);
    });

    test('null and NaN are no reading', () {
      expect(plausibleSurfacePressureBar(null), isNull);
      expect(plausibleSurfacePressureBar(double.nan), isNull);
    });
  });
}
