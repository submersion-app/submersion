import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';

void main() {
  group('CnsCalculationMethod.classic (NOAA step table)', () {
    const m = CnsCalculationMethod.classic;
    test('zero at or below 0.5 bar', () {
      expect(m.cnsPerMinute(0.5), 0.0);
      expect(m.cnsPerMinute(0.2), 0.0);
    });
    test('whole band charged at upper-bound rate', () {
      expect(m.cnsPerMinute(0.55), closeTo(100 / 720, 1e-9));
      expect(m.cnsPerMinute(1.25), closeTo(100 / 180, 1e-9));
      expect(m.cnsPerMinute(1.21), closeTo(100 / 180, 1e-9));
      expect(m.cnsPerMinute(1.2), closeTo(100 / 210, 1e-9));
    });
    test('legacy flat rule above 1.6 bar', () {
      expect(m.cnsPerMinute(1.61), 10.0);
      expect(m.cnsPerMinute(2.0), 10.0);
    });
  });

  group('CnsCalculationMethod.shearwater (linear interpolation)', () {
    const m = CnsCalculationMethod.shearwater;
    test('zero at or below 0.5 bar', () {
      expect(m.cnsPerMinute(0.5), 0.0);
    });
    test('flat 720-min rate between 0.5 and 0.6', () {
      expect(m.cnsPerMinute(0.55), closeTo(100 / 720, 1e-9));
    });
    test('exact at every NOAA entry', () {
      expect(m.cnsPerMinute(0.6), closeTo(100 / 720, 1e-9));
      expect(m.cnsPerMinute(1.0), closeTo(100 / 300, 1e-9));
      expect(m.cnsPerMinute(1.3), closeTo(100 / 180, 1e-9));
      expect(m.cnsPerMinute(1.5), closeTo(100 / 120, 1e-9));
      expect(m.cnsPerMinute(1.6), closeTo(100 / 45, 1e-9));
    });
    test('interpolates the time limits between entries', () {
      expect(m.cnsPerMinute(1.25), closeTo(100 / 195, 1e-9));
      expect(m.cnsPerMinute(0.65), closeTo(100 / 645, 1e-9));
      expect(m.cnsPerMinute(1.45), closeTo(100 / 135, 1e-9));
      expect(m.cnsPerMinute(1.55), closeTo(100 / 82.5, 1e-9));
    });
    test('1.6-1.65 window uses the 45-min rate, above 1.65 flat 15 %/min', () {
      expect(m.cnsPerMinute(1.62), closeTo(100 / 45, 1e-9));
      expect(m.cnsPerMinute(1.65), closeTo(100 / 45, 1e-9));
      expect(m.cnsPerMinute(1.66), 15.0);
      expect(m.cnsPerMinute(2.0), 15.0);
    });
  });

  group('CnsCalculationMethod.subsurface (two-line exponential fit)', () {
    const m = CnsCalculationMethod.subsurface;
    test('zero at or below 0.5 bar', () {
      expect(m.cnsPerMinute(0.5), 0.0);
    });
    test('lower fit line values', () {
      expect(m.cnsPerMinute(0.55), closeTo(0.13272, 5e-4));
      expect(m.cnsPerMinute(1.0), closeTo(0.31757, 5e-4));
      expect(m.cnsPerMinute(1.25), closeTo(0.51563, 5e-4));
      expect(m.cnsPerMinute(1.3), closeTo(0.56811, 5e-4));
      expect(m.cnsPerMinute(1.5), closeTo(0.83720, 5e-4));
    });
    test('upper fit line values', () {
      expect(m.cnsPerMinute(1.55), closeTo(1.30665, 2e-3));
      expect(m.cnsPerMinute(1.6), closeTo(2.13375, 2e-3));
      expect(m.cnsPerMinute(1.9), closeTo(40.462, 0.1));
    });
    test('reproduces the NOAA table within 8.1 percent at every entry', () {
      const knots = [0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6];
      const limits = [720, 570, 450, 360, 300, 240, 210, 180, 150, 120, 45];
      // Worst deviation of the two-line fit is 8.08% at ppO2 1.1 (259 vs 240 min).
      for (var i = 0; i < knots.length; i++) {
        final equivalentLimit = 100 / m.cnsPerMinute(knots[i]);
        expect(
          (equivalentLimit - limits[i]).abs() / limits[i],
          lessThan(0.081),
          reason: 'at ppO2 ${knots[i]}',
        );
      }
    });
  });

  group('shared properties', () {
    test('shearwater rate is monotonically non-decreasing', () {
      const m = CnsCalculationMethod.shearwater;
      for (var p = 0.51; p < 2.5; p += 0.01) {
        expect(
          m.cnsPerMinute(p + 0.01) + 1e-12 >= m.cnsPerMinute(p),
          isTrue,
          reason: 'not monotone at ppO2 $p',
        );
      }
    });

    test('subsurface rate is monotone within each fit line', () {
      // The two fitted lines meet discontinuously at 1.5 bar: the rate drops
      // about 4.5% stepping onto the upper line. This mirrors Subsurface's
      // actual formula and is asserted here so the dip is documented, not
      // accidental.
      const m = CnsCalculationMethod.subsurface;
      for (var p = 0.51; p < 1.48; p += 0.01) {
        expect(
          m.cnsPerMinute(p + 0.01) >= m.cnsPerMinute(p),
          isTrue,
          reason: 'lower line not monotone at ppO2 $p',
        );
      }
      for (var p = 1.51; p < 2.5; p += 0.01) {
        expect(
          m.cnsPerMinute(p + 0.01) >= m.cnsPerMinute(p),
          isTrue,
          reason: 'upper line not monotone at ppO2 $p',
        );
      }
      expect(m.cnsPerMinute(1.501), lessThan(m.cnsPerMinute(1.5)));
    });
    test('dbValue roundtrip and unknown fallback', () {
      for (final m in CnsCalculationMethod.values) {
        expect(CnsCalculationMethod.fromDbValue(m.dbValue), m);
      }
      expect(
        CnsCalculationMethod.fromDbValue('bogus'),
        CnsCalculationMethod.shearwater,
      );
      expect(
        CnsCalculationMethod.fromDbValue(null),
        CnsCalculationMethod.shearwater,
      );
    });
  });
}
