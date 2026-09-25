import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';

// Reference values computed independently of the app code:
//   ambient = 1.0 + depth * rho * 9.80665 / 100000  (salt 1025, fresh 1000)
//   density = sum(p_i * M_i) / (0.083144626 * (T + 273.15))
//   M: O2 31.998, N2 28.014, He 4.0026
GasDensityInputs _inputs({
  double o2 = 21,
  double he = 0,
  double depth = 40,
  double? setpoint,
  GasDensityTemperature temperature = GasDensityTemperature.twentyC,
  WaterType waterType = WaterType.salt,
}) => GasDensityInputs(
  o2Percent: o2,
  hePercent: he,
  depthMeters: depth,
  setpointBar: setpoint,
  temperature: temperature,
  waterType: waterType,
);

void main() {
  group('open circuit', () {
    test('air at 40 m in salt water, 20 C', () {
      final result = computeGasDensity(_inputs());
      expect(result.ambientPressureBar, closeTo(5.0207265, 1e-6));
      expect(result.densityGPerL, closeTo(5.942893303833008, 1e-9));
      expect(
        gasDensityLevelForDisplay(result.densityGPerL, 2),
        GasDensityLevel.warn,
      );
    });

    test('air at 40 m in salt water, 0 C', () {
      final result = computeGasDensity(
        _inputs(temperature: GasDensityTemperature.zeroC),
      );
      expect(result.densityGPerL, closeTo(6.37803101599358, 1e-9));
      expect(
        gasDensityLevelForDisplay(result.densityGPerL, 2),
        GasDensityLevel.critical,
      );
    });

    test('air at 40 m in fresh water, 20 C', () {
      final result = computeGasDensity(_inputs(waterType: WaterType.fresh));
      expect(result.ambientPressureBar, closeTo(4.92266, 1e-9));
      expect(result.densityGPerL, closeTo(5.82681473508796, 1e-9));
    });

    test('Tx 18/45 at 60 m in salt water', () {
      final warm = computeGasDensity(_inputs(o2: 18, he: 45, depth: 60));
      final cold = computeGasDensity(
        _inputs(
          o2: 18,
          he: 45,
          depth: 60,
          temperature: GasDensityTemperature.zeroC,
        ),
      );
      expect(warm.densityGPerL, closeTo(5.171085383811512, 1e-9));
      expect(
        gasDensityLevelForDisplay(warm.densityGPerL, 2),
        GasDensityLevel.ok,
      );
      expect(cold.densityGPerL, closeTo(5.549711441568166, 1e-9));
      expect(
        gasDensityLevelForDisplay(cold.densityGPerL, 2),
        GasDensityLevel.warn,
      );
    });

    test('partial pressures are the mix fractions of ambient pressure', () {
      final result = computeGasDensity(_inputs(o2: 18, he: 45, depth: 60));
      expect(result.pO2Bar, closeTo(0.18 * 7.03108975, 1e-9));
      expect(result.pHeBar, closeTo(0.45 * 7.03108975, 1e-9));
      expect(result.pN2Bar, closeTo(0.37 * 7.03108975, 1e-9));
      expect(result.loopO2Percent, closeTo(18, 1e-9));
      expect(result.loopHePercent, closeTo(45, 1e-9));
      expect(result.loopN2Percent, closeTo(37, 1e-9));
      expect(result.setpointCapped, isFalse);
      expect(result.diluentAboveSetpoint, isFalse);
    });

    test('helium beyond the room left by oxygen is clamped', () {
      final clamped = computeGasDensity(_inputs(o2: 30, he: 90));
      final exact = computeGasDensity(_inputs(o2: 30, he: 70));
      expect(clamped.densityGPerL, closeTo(exact.densityGPerL, 1e-12));
      expect(clamped.pN2Bar, 0);
    });

    test('a negative depth is treated as the surface', () {
      final result = computeGasDensity(_inputs(depth: -5));
      expect(result.ambientPressureBar, closeTo(1.0, 1e-12));
    });
  });

  group('closed circuit', () {
    test('SP 1.3 on diluent 18/45 at 60 m holds the setpoint', () {
      final warm = computeGasDensity(
        _inputs(o2: 18, he: 45, depth: 60, setpoint: 1.3),
      );
      final cold = computeGasDensity(
        _inputs(
          o2: 18,
          he: 45,
          depth: 60,
          setpoint: 1.3,
          temperature: GasDensityTemperature.zeroC,
        ),
      );
      expect(warm.pO2Bar, closeTo(1.3, 1e-12));
      expect(warm.pN2Bar, closeTo(2.5859795213414634, 1e-9));
      expect(warm.pHeBar, closeTo(3.145110228658536, 1e-9));
      expect(warm.densityGPerL, closeTo(5.195308230610188, 1e-9));
      expect(cold.densityGPerL, closeTo(5.575707881396216, 1e-9));
      expect(warm.setpointCapped, isFalse);
      expect(warm.diluentAboveSetpoint, isFalse);
    });

    test('loop fractions add up to 100 %', () {
      final result = computeGasDensity(
        _inputs(o2: 18, he: 45, depth: 60, setpoint: 1.3),
      );
      expect(
        result.loopO2Percent + result.loopHePercent + result.loopN2Percent,
        closeTo(100, 1e-9),
      );
    });

    test('a setpoint above ambient pressure gives a pure oxygen loop', () {
      final result = computeGasDensity(
        _inputs(o2: 18, he: 45, depth: 0, setpoint: 1.3),
      );
      expect(result.pO2Bar, closeTo(1.0, 1e-12));
      expect(result.pN2Bar, 0);
      expect(result.pHeBar, 0);
      expect(result.densityGPerL, closeTo(1.312800554344073, 1e-9));
      expect(result.setpointCapped, isTrue);
    });

    test('a setpoint equal to ambient pressure is not flagged as above it', () {
      // Fresh water at the surface is exactly 1.0 bar.
      final result = computeGasDensity(
        _inputs(
          o2: 18,
          he: 45,
          depth: 0,
          setpoint: 1.0,
          waterType: WaterType.fresh,
        ),
      );
      expect(result.ambientPressureBar, 1.0);
      expect(result.setpointCapped, isFalse);
      expect(result.pO2Bar, closeTo(1.0, 1e-12));
      expect(result.pN2Bar, 0);
      expect(result.pHeBar, 0);
    });

    test('a diluent richer than the setpoint sets the loop ppO2', () {
      // Air at 60 m carries ppO2 1.4765; a diluent flush cannot hold 1.3.
      final result = computeGasDensity(_inputs(depth: 60, setpoint: 1.3));
      expect(result.pO2Bar, closeTo(1.4765288474999998, 1e-9));
      expect(result.pN2Bar, closeTo(5.5545609025, 1e-9));
      expect(result.densityGPerL, closeTo(8.322503963106513, 1e-9));
      expect(result.diluentAboveSetpoint, isTrue);
      expect(
        gasDensityLevelForDisplay(result.densityGPerL, 2),
        GasDensityLevel.critical,
      );
    });

    test('a pure oxygen diluent leaves no inert gas', () {
      final result = computeGasDensity(
        _inputs(o2: 100, depth: 6, setpoint: 1.3),
      );
      expect(result.pN2Bar, 0);
      expect(result.pHeBar, 0);
      expect(result.pO2Bar, closeTo(result.ambientPressureBar, 1e-12));
    });
  });

  group('equivalent air density depth', () {
    // Air (21/79) at the pressure sum(p_i * M_i) / M_air, as a depth in the
    // same water. M_air = 0.21 * 31.998 + 0.79 * 28.014 = 28.85064.

    test('air is its own EADD', () {
      expect(computeGasDensity(_inputs()).eaddMeters, closeTo(40, 1e-9));
    });

    test('Tx 18/45 at 60 m in salt water', () {
      expect(
        computeGasDensity(_inputs(o2: 18, he: 45, depth: 60)).eaddMeters,
        closeTo(33.513157986465494, 1e-9),
      );
    });

    test('Tx 18/45 at 60 m in fresh water', () {
      expect(
        computeGasDensity(
          _inputs(o2: 18, he: 45, depth: 60, waterType: WaterType.fresh),
        ).eaddMeters,
        closeTo(33.418980401783344, 1e-9),
      );
    });

    test('CCR SP 1.3 on diluent 18/45 at 60 m uses the loop gas', () {
      expect(
        computeGasDensity(
          _inputs(o2: 18, he: 45, depth: 60, setpoint: 1.3),
        ).eaddMeters,
        closeTo(33.71674462534928, 1e-9),
      );
    });

    test('does not depend on the temperature', () {
      final warm = computeGasDensity(_inputs(o2: 18, he: 45, depth: 60));
      final cold = computeGasDensity(
        _inputs(
          o2: 18,
          he: 45,
          depth: 60,
          temperature: GasDensityTemperature.zeroC,
        ),
      );
      expect(cold.eaddMeters, closeTo(warm.eaddMeters, 1e-9));
    });

    test('a gas lighter than surface air gives 0, not a negative depth', () {
      // Heliox 21/79 at 10 m is lighter than air at the surface.
      expect(
        computeGasDensity(_inputs(o2: 21, he: 79, depth: 10)).eaddMeters,
        0,
      );
    });
  });

  group('level', () {
    test('follows the published 5.2 / 6.2 g/L limits', () {
      expect(gasDensityLevelFor(5.2), GasDensityLevel.ok);
      expect(gasDensityLevelFor(5.21), GasDensityLevel.warn);
      expect(gasDensityLevelFor(6.2), GasDensityLevel.warn);
      expect(gasDensityLevelFor(6.21), GasDensityLevel.critical);
    });

    test('on the displayed value agrees with the number shown', () {
      // 5.2004 renders as "5.20", which is on the limit, not above it.
      expect(gasDensityLevelForDisplay(5.2004, 2), GasDensityLevel.ok);
      expect(gasDensityLevelForDisplay(5.206, 2), GasDensityLevel.warn);
      expect(gasDensityLevelForDisplay(6.2004, 2), GasDensityLevel.warn);
      expect(gasDensityLevelForDisplay(6.206, 2), GasDensityLevel.critical);
    });
  });

  group('inputs copyWith', () {
    test('replaces only the given fields', () {
      final base = _inputs(o2: 18, he: 45, depth: 60, setpoint: 1.3);
      final copy = base.copyWith(depthMeters: 30);
      expect(copy.depthMeters, 30);
      expect(copy.o2Percent, 18);
      expect(copy.hePercent, 45);
      expect(copy.setpointBar, 1.3);
      expect(copy.temperature, base.temperature);
      expect(copy.waterType, base.waterType);
    });

    test('openCircuit clears the setpoint', () {
      final copy = _inputs(setpoint: 1.3).copyWith(openCircuit: true);
      expect(copy.setpointBar, isNull);
      expect(copy.isCcr, isFalse);
    });
  });

  group('temperature options', () {
    test('are 0 C and 20 C', () {
      expect(GasDensityTemperature.zeroC.celsius, 0);
      expect(GasDensityTemperature.twentyC.celsius, 20);
    });
  });
}
