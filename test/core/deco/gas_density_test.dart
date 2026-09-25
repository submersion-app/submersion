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

  group('gasDensityFromPartialPressures', () {
    // Reference: sum(p_i * M_i) / (R * T), R = 0.083144626 L bar/(mol K),
    // M = O2 31.998, N2 28.014, He 4.0026 g/mol.

    test('air at 1 bar and 20 C', () {
      // (0.21*31.998 + 0.79*28.014) / (0.083144626 * 293.15)
      // = 1.1836719852859956
      expect(
        gasDensityFromPartialPressures(
          pO2Bar: 0.21,
          pN2Bar: 0.79,
          pHeBar: 0,
          temperatureC: 20,
        ),
        closeTo(1.1836719852859956, 1e-9),
      );
    });

    test('air at 1 bar and 0 C', () {
      // same numerator / (0.083144626 * 273.15) = 1.270340261711842
      expect(
        gasDensityFromPartialPressures(
          pO2Bar: 0.21,
          pN2Bar: 0.79,
          pHeBar: 0,
          temperatureC: 0,
        ),
        closeTo(1.270340261711842, 1e-9),
      );
    });

    test('colder gas is denser by the ratio of absolute temperatures', () {
      final warm = gasDensityFromPartialPressures(
        pO2Bar: 1.2,
        pN2Bar: 2.5,
        pHeBar: 3.1,
        temperatureC: 20,
      );
      final cold = gasDensityFromPartialPressures(
        pO2Bar: 1.2,
        pN2Bar: 2.5,
        pHeBar: 3.1,
        temperatureC: 0,
      );
      expect(cold / warm, closeTo(293.15 / 273.15, 1e-12));
    });

    test('pure oxygen at 1 bar and 20 C', () {
      // 31.998 / (0.083144626 * 293.15) = 1.312800554344073
      expect(
        gasDensityFromPartialPressures(
          pO2Bar: 1.0,
          pN2Bar: 0,
          pHeBar: 0,
          temperatureC: 20,
        ),
        closeTo(1.312800554344073, 1e-9),
      );
    });

    test('no gas has no density', () {
      expect(
        gasDensityFromPartialPressures(
          pO2Bar: 0,
          pN2Bar: 0,
          pHeBar: 0,
          temperatureC: 20,
        ),
        0,
      );
    });

    test('rejects a temperature at or below absolute zero', () {
      expect(
        () => gasDensityFromPartialPressures(
          pO2Bar: 0.21,
          pN2Bar: 0.79,
          pHeBar: 0,
          temperatureC: -273.15,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative partial pressure', () {
      expect(
        () => gasDensityFromPartialPressures(
          pO2Bar: -0.1,
          pN2Bar: 0.79,
          pHeBar: 0,
          temperatureC: 20,
        ),
        throwsArgumentError,
      );
    });
  });
}
