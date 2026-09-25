import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('maxOperatingDepthMeters, flat 1 bar per 10 m', () {
    test('EAN32 at 1.4 is exactly 33.75 m, unrounded', () {
      expect(maxOperatingDepthMeters(0.32, maxPpO2: 1.4), 33.75);
    });

    test('air at 1.4 and oxygen at 1.6', () {
      expect(
        maxOperatingDepthMeters(0.21, maxPpO2: 1.4),
        closeTo(56.667, 1e-3),
      );
      expect(maxOperatingDepthMeters(1.0, maxPpO2: 1.6), closeTo(6.0, 1e-12));
    });

    test('no oxygen has no MOD', () {
      expect(maxOperatingDepthMeters(0, maxPpO2: 1.4), 0);
      expect(maxOperatingDepthMeters(-0.1, maxPpO2: 1.4), 0);
    });
  });

  group('maxOperatingDepthMeters, with an environment', () {
    test('salt water (1025 kg/m3) is shallower than the flat model', () {
      final salt = DiveEnvironment.forConditions(waterType: WaterType.salt);
      final mod = maxOperatingDepthMeters(
        0.32,
        maxPpO2: 1.4,
        environment: salt,
      );
      // (4.375 - 1.0) / (1025 * 9.80665 / 100000)
      expect(mod, closeTo(33.5760, 1e-4));
      expect(mod, lessThan(33.75));
    });

    test('fresh water is deeper than the flat model', () {
      final fresh = DiveEnvironment.forConditions(waterType: WaterType.fresh);
      expect(
        maxOperatingDepthMeters(0.32, maxPpO2: 1.4, environment: fresh),
        greaterThan(33.75),
      );
    });
  });

  group('minimumOperatingDepthMeters', () {
    test('a normoxic mix can be breathed from the surface', () {
      expect(minimumOperatingDepthMeters(0.21, minPpO2: 0.18), 0);
    });

    test('Tx 10/70 needs 8 m at ppO2 0.18', () {
      expect(
        minimumOperatingDepthMeters(0.10, minPpO2: 0.18),
        closeTo(8.0, 1e-12),
      );
    });

    test('Tx 10/70 needs 6 m at ppO2 0.16', () {
      expect(
        minimumOperatingDepthMeters(0.10, minPpO2: 0.16),
        closeTo(6.0, 1e-12),
      );
    });

    test('no oxygen can never be breathed', () {
      expect(minimumOperatingDepthMeters(0, minPpO2: 0.18), double.infinity);
    });
  });

  group('the existing entry points share the one formula', () {
    test('O2ToxicityCalculator.calculateMod is bit-identical', () {
      for (final f in [0.21, 0.32, 0.36, 0.5, 1.0]) {
        for (final ppO2 in [1.2, 1.4, 1.6]) {
          expect(
            O2ToxicityCalculator.calculateMod(f, maxPpO2: ppO2),
            maxOperatingDepthMeters(f, maxPpO2: ppO2),
          );
        }
      }
    });

    test('GasMix.mod is bit-identical', () {
      for (final o2 in [21.0, 32.0, 36.0, 50.0, 100.0]) {
        expect(
          GasMix(o2: o2).mod(ppO2: 1.4),
          maxOperatingDepthMeters(o2 / 100, maxPpO2: 1.4),
        );
      }
    });

    test('ScrCalculator.calculateMod uses the maximum loop FO2', () {
      final maxFo2 = ScrCalculator.calculateMaxLoopFo2(
        injectionRateLpm: 10,
        supplyO2Percent: 40,
        minVo2: ScrCalculator.restingVo2,
      )!;
      expect(
        ScrCalculator.calculateMod(injectionRateLpm: 10, supplyO2Percent: 40),
        maxOperatingDepthMeters(maxFo2, maxPpO2: 1.4),
      );
    });
  });
}
