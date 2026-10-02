import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_gradient_factor.dart';

/// The per-waypoint `<gradientfactor>` is GF99 as a whole percent. Shearwater
/// Cloud and Subsurface write integers. A decimal is read as a percent too:
/// no known writer emits a fraction of one, and reading "1.0" as 100% would
/// turn a 1% GF99 into a saturated one.
void main() {
  group('parseUddfGradientFactorPercent', () {
    test('reads whole percents as written', () {
      expect(parseUddfGradientFactorPercent('0'), 0);
      expect(parseUddfGradientFactorPercent('63'), 63);
      expect(parseUddfGradientFactorPercent(' 59 '), 59);
    });

    test('does not clamp a supersaturated value', () {
      expect(parseUddfGradientFactorPercent('120'), 120);
      expect(parseUddfGradientFactorPercent('120.4'), 120);
    });

    test('reads a decimal at or below one as a percent, not a fraction', () {
      expect(parseUddfGradientFactorPercent('1.0'), 1);
      expect(parseUddfGradientFactorPercent('0.63'), 1);
      expect(parseUddfGradientFactorPercent('0.4'), 0);
    });

    test('rounds a decimal percent to the nearest whole percent', () {
      expect(parseUddfGradientFactorPercent('63.4'), 63);
      expect(parseUddfGradientFactorPercent('63.6'), 64);
      expect(parseUddfGradientFactorPercent('0.0'), 0);
    });

    test('keeps an integer one as one percent, not a fraction', () {
      expect(parseUddfGradientFactorPercent('1'), 1);
    });

    test('reads blank and non-numeric text as absent', () {
      expect(parseUddfGradientFactorPercent(null), isNull);
      expect(parseUddfGradientFactorPercent(''), isNull);
      expect(parseUddfGradientFactorPercent('   '), isNull);
      expect(parseUddfGradientFactorPercent('n/a'), isNull);
      expect(parseUddfGradientFactorPercent('NaN'), isNull);
      expect(parseUddfGradientFactorPercent('Infinity'), isNull);
    });
  });
}
