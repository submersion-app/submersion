import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  group('DiveEnvironment', () {
    test('standard reproduces legacy 1 bar surface and 10 m/bar exactly', () {
      const env = DiveEnvironment.standard;
      expect(env.surfacePressureBar, 1.0);
      expect(env.barPerMeter, closeTo(0.1, 1e-9));
      expect(env.pressureAtDepth(30.0), closeTo(4.0, 1e-7));
      expect(env.depthAtPressure(4.0), closeTo(30.0, 1e-6));
    });

    test('salt water is denser than standard', () {
      const env = DiveEnvironment(
        waterDensityKgM3: DiveEnvironment.saltWaterDensity,
      );
      // python3: 1025 * 9.80665 / 100000 = 0.1005181625
      expect(env.barPerMeter, closeTo(0.1005181625, 1e-9));
      expect(env.pressureAtDepth(30.0), closeTo(4.015544875, 1e-7));
    });

    test('fresh water is lighter than standard', () {
      const env = DiveEnvironment(
        waterDensityKgM3: DiveEnvironment.freshWaterDensity,
      );
      // python3: 1000 * 9.80665 / 100000 = 0.0980665
      expect(env.barPerMeter, closeTo(0.0980665, 1e-9));
      expect(env.pressureAtDepth(30.0), closeTo(3.941995, 1e-6));
    });

    test('forConditions with altitude uses barometric pressure', () {
      final env = DiveEnvironment.forConditions(altitudeMeters: 2000.0);
      // python3 ISA: 1.01325 * (1 - 0.0000225577*2000)^5.25588
      //            = 0.794951974352912
      expect(env.surfacePressureBar, closeTo(0.7950, 0.001));
      expect(env.surfacePressureBar, lessThan(1.0));
    });

    test('forConditions maps water types to densities', () {
      expect(
        DiveEnvironment.forConditions(
          waterType: WaterType.fresh,
        ).waterDensityKgM3,
        DiveEnvironment.freshWaterDensity,
      );
      expect(
        DiveEnvironment.forConditions(
          waterType: WaterType.salt,
        ).waterDensityKgM3,
        DiveEnvironment.saltWaterDensity,
      );
      expect(
        DiveEnvironment.forConditions(
          waterType: WaterType.brackish,
        ).waterDensityKgM3,
        DiveEnvironment.brackishWaterDensity,
      );
      expect(
        DiveEnvironment.forConditions().waterDensityKgM3,
        DiveEnvironment.en13319Density,
      );
    });

    test('forConditions: explicit surface pressure wins over altitude', () {
      final env = DiveEnvironment.forConditions(
        altitudeMeters: 2000.0,
        surfacePressureBar: 0.9,
      );
      expect(env.surfacePressureBar, 0.9);
    });

    test('forConditions: null altitude keeps legacy 1.0 bar', () {
      expect(DiveEnvironment.forConditions().surfacePressureBar, 1.0);
    });
  });
}
