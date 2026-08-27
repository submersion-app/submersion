import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/gas_density.dart';

void main() {
  group('gasDensityGPerL', () {
    test('air at 40 m matches the python vector', () {
      // python3: (0.21*32 + 0.79*28)/24.04 * 5.0 = 5.998336106489185
      expect(
        gasDensityGPerL(fO2: 0.21, fHe: 0.0, ambientPressureBar: 5.0),
        closeTo(5.998336106489185, 1e-9),
      );
    });

    test('air at 45 m exceeds the hard limit', () {
      // python3: 6.598169717138103
      final density = gasDensityGPerL(
        fO2: 0.21,
        fHe: 0.0,
        ambientPressureBar: 5.5,
      );
      expect(density, closeTo(6.598169717138103, 1e-9));
      expect(density, greaterThan(gasDensityCriticalGPerL));
    });

    test('Tx18/45 at 60 m sits just over the recommended limit', () {
      // python3: (0.18*32 + 0.37*28 + 0.45*4)/24.04 * 7.0 = 5.2179...
      // A well-known edge case: standard trimix at 60 m is marginally above
      // the 5.2 g/L recommendation but well under the 6.2 hard limit.
      final density = gasDensityGPerL(
        fO2: 0.18,
        fHe: 0.45,
        ambientPressureBar: 7.0,
      );
      expect(density, closeTo(5.218, 0.001));
      expect(density, lessThan(gasDensityCriticalGPerL));
    });

    test('thresholds are the published 5.2 / 6.2 g/L values', () {
      expect(gasDensityWarnGPerL, 5.2);
      expect(gasDensityCriticalGPerL, 6.2);
    });
  });
}
