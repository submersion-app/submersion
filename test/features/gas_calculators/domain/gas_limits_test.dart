import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';

// Salt water as DiveEnvironment models it: 1025 kg/m3 at a 1.0 bar surface.
const double _saltBarPerMeter = 1025 * 9.80665 / 100000;
double _saltDepthAt(double bar) => (bar - 1.0) / _saltBarPerMeter;
double _saltPressureAt(double meters) => 1.0 + meters * _saltBarPerMeter;

GasLimitsInputs _inputs({
  ModCalculatorMode mode = ModCalculatorMode.rec,
  double o2 = 32,
  double he = 0,
  double working = 1.4,
  double deco = 1.6,
  double flush = 1.6,
  double setpoint = 1.1,
  double minPpO2 = 0.18,
  double endLimit = 30,
  bool o2Narcotic = true,
  double? target,
  WaterType waterType = WaterType.salt,
}) => GasLimitsInputs(
  mode: mode,
  o2Percent: o2,
  hePercent: he,
  workingPpO2: working,
  decoPpO2: deco,
  flushPpO2: flush,
  setpointBar: setpoint,
  minPpO2: minPpO2,
  endLimitMeters: endLimit,
  o2Narcotic: o2Narcotic,
  targetDepthMeters: target,
  waterType: waterType,
);

void main() {
  group('Rec', () {
    test('EAN32: MOD on the flat model, contingency at 1.6', () {
      final r = computeGasLimits(_inputs());
      expect(r.modMeters, 33.75);
      expect(r.secondaryModMeters, closeTo(40.0, 1e-9));
      expect(r.secondaryPpO2, 1.6);
      expect(r.minDepthMeters, isNull);
      expect(r.mndMeters, isNull);
      expect(r.beyondRecreationalLimit, isFalse);
    });

    test('EAD at the MOD, from the N2 partial pressure', () {
      final r = computeGasLimits(_inputs());
      // P = 4.375 bar, pN2 = 0.68 * 4.375
      const expected = (0.68 * 4.375 / airN2Fraction - 1) * 10;
      expect(r.atMod.depthMeters, 33.75);
      expect(r.atMod.pO2Bar, closeTo(1.4, 1e-12));
      expect(r.atMod.eadMeters, closeTo(expected, 1e-9));
      expect(r.atMod.densityGPerL, isNull);
      expect(r.atMod.eaddMeters, isNull);
    });

    test('air at 1.4 lies beyond the recreational limit', () {
      final r = computeGasLimits(_inputs(o2: 21));
      expect(r.modMeters, closeTo(56.667, 1e-3));
      expect(r.beyondRecreationalLimit, isTrue);
    });

    test('helium and a water type are ignored', () {
      final plain = computeGasLimits(_inputs());
      final noisy = computeGasLimits(
        _inputs(he: 30, waterType: WaterType.fresh),
      );
      expect(noisy.modMeters, plain.modMeters);
      expect(noisy.atMod.pHeBar, 0);
    });

    test('O2 is clamped to the nitrox range 21-40 %', () {
      expect(computeGasLimits(_inputs(o2: 50)).o2Percent, 40);
      expect(computeGasLimits(_inputs(o2: 10)).o2Percent, 21);
    });

    test('a target depth deeper than the MOD is flagged', () {
      final r = computeGasLimits(_inputs(target: 36));
      expect(r.atTarget, isNotNull);
      expect(r.atTarget!.pO2Bar, closeTo(0.32 * 4.6, 1e-12));
      expect(r.targetBeyondMod, isTrue);
      expect(computeGasLimits(_inputs(target: 30)).targetBeyondMod, isFalse);
    });
  });

  group('OC Tec', () {
    GasLimitsInputs tx2135({double? target, bool o2Narcotic = true}) => _inputs(
      mode: ModCalculatorMode.ocTec,
      o2: 21,
      he: 35,
      target: target,
      o2Narcotic: o2Narcotic,
    );

    test('MOD and deco MOD follow the salt-water environment', () {
      final r = computeGasLimits(tx2135());
      expect(r.modMeters, closeTo(_saltDepthAt(1.4 / 0.21), 1e-9));
      expect(r.secondaryModMeters, closeTo(_saltDepthAt(1.6 / 0.21), 1e-9));
      expect(r.secondaryPpO2, 1.6);
    });

    test('a normoxic mix has no minimum depth', () {
      expect(computeGasLimits(tx2135()).minDepthMeters, 0);
    });

    test('Tx 10/70 needs the minimum ppO2 before it is breathable', () {
      final r = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 10, he: 70),
      );
      expect(r.minDepthMeters, closeTo(_saltDepthAt(1.8), 1e-9));
      final r16 = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 10, he: 70, minPpO2: 0.16),
      );
      expect(r16.minDepthMeters, closeTo(_saltDepthAt(1.6), 1e-9));
    });

    test('END with O2 narcotic and EAD at the MOD', () {
      final r = computeGasLimits(tx2135());
      const p = 1.4 / 0.21;
      expect(r.atMod.endMeters, closeTo(_saltDepthAt(0.65 * p), 1e-9));
      expect(
        r.atMod.eadMeters,
        closeTo(_saltDepthAt(0.44 * p / airN2Fraction), 1e-9),
      );
      expect(r.atMod.narcoticDepthMeters, r.atMod.endMeters);
      expect(r.atMod.exceedsEndLimit, isTrue);
    });

    test('END of air equals its depth: air is the reference', () {
      // With O2 narcotic, air is 100 % narcotic gas, so END is the depth at
      // which air has the same (N2 + O2) pressure: for air, the depth
      // itself. No 0.79 normalization, which belongs to the N2-only EAD.
      final r = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 21, he: 0, target: 40),
      );
      expect(r.atTarget!.endMeters, closeTo(40, 1e-9));
    });

    test('the narcotic depth follows the O2-narcotic setting', () {
      final r = computeGasLimits(tx2135(o2Narcotic: false));
      expect(r.atMod.narcoticDepthMeters, r.atMod.eadMeters);
    });

    test('MND is where the narcotic depth reaches the END limit', () {
      final r = computeGasLimits(tx2135());
      // (N2 + O2) pressure = END limit as a pressure in the same water.
      final expected = _saltDepthAt(_saltPressureAt(30) / 0.65);
      expect(r.mndMeters, closeTo(expected, 1e-3));
    });

    test('MND without O2 narcotic uses the N2 fraction', () {
      final r = computeGasLimits(tx2135(o2Narcotic: false));
      final expected = _saltDepthAt(_saltPressureAt(30) * airN2Fraction / 0.44);
      expect(r.mndMeters, closeTo(expected, 1e-3));
    });

    test('heliox has no narcotic limit when O2 is not narcotic', () {
      final r = computeGasLimits(
        _inputs(
          mode: ModCalculatorMode.ocTec,
          o2: 21,
          he: 79,
          o2Narcotic: false,
        ),
      );
      expect(r.mndMeters, isNull);
    });

    test('density and EADD at the MOD come from the density calculator', () {
      final r = computeGasLimits(tx2135());
      final density = computeGasDensity(
        GasDensityInputs(
          o2Percent: 21,
          hePercent: 35,
          depthMeters: r.modMeters,
          setpointBar: null,
          temperature: GasDensityTemperature.zeroC,
          waterType: WaterType.salt,
        ),
      );
      expect(r.atMod.densityGPerL, closeTo(density.densityGPerL, 1e-12));
      expect(r.atMod.eaddMeters, closeTo(density.eaddMeters, 1e-12));
      expect(
        r.atMod.densityLevel,
        gasDensityLevelForDisplay(density.densityGPerL, 2),
      );
    });

    test('a target shallower than the minimum depth is flagged', () {
      final r = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 10, he: 70, target: 5),
      );
      expect(r.targetShallowerThanMinDepth, isTrue);
    });

    test('fresh water gives a deeper MOD than salt water', () {
      final salt = computeGasLimits(tx2135());
      final fresh = computeGasLimits(
        _inputs(
          mode: ModCalculatorMode.ocTec,
          o2: 21,
          he: 35,
          waterType: WaterType.fresh,
        ),
      );
      expect(fresh.modMeters, greaterThan(salt.modMeters));
    });
  });

  group('CCR Tec', () {
    GasLimitsInputs ccr({
      double setpoint = 1.1,
      double flush = 1.6,
      double? target,
    }) => _inputs(
      mode: ModCalculatorMode.ccrTec,
      o2: 21,
      he: 35,
      setpoint: setpoint,
      flush: flush,
      target: target,
    );

    test('the MOD is the diluent MOD at the flush ppO2', () {
      final r = computeGasLimits(ccr());
      expect(r.modMeters, closeTo(_saltDepthAt(1.6 / 0.21), 1e-9));
      expect(r.secondaryModMeters, isNull);
    });

    test('the MOD column is the flushed diluent, not the loop', () {
      // Flush 1.1 below setpoint 1.3: at the diluent MOD the diluent itself
      // is at 1.1 bar. The setpoint only applies at a target depth.
      final r = computeGasLimits(ccr(setpoint: 1.3, flush: 1.1));
      expect(r.modMeters, closeTo(_saltDepthAt(1.1 / 0.21), 1e-9));
      expect(r.atMod.pO2Bar, closeTo(1.1, 1e-9));
      expect(r.atMod.diluentAboveSetpoint, isFalse);
      expect(r.atMod.setpointCapped, isFalse);
      const p = 1.1 / 0.21;
      expect(
        r.atMod.eadMeters,
        closeTo(_saltDepthAt(0.44 * p / airN2Fraction), 1e-9),
      );
    });

    test('at a shallower target the loop holds the setpoint', () {
      final r = computeGasLimits(ccr(target: 40));
      final p = _saltPressureAt(40);
      final pN2 = (p - 1.1) * 0.44 / 0.79;
      expect(r.atTarget!.pO2Bar, closeTo(1.1, 1e-12));
      expect(r.atTarget!.pN2Bar, closeTo(pN2, 1e-9));
      expect(
        r.atTarget!.eadMeters,
        closeTo(_saltDepthAt(pN2 / airN2Fraction), 1e-9),
      );
    });

    test('a setpoint above the flush ppO2 is a valid combination', () {
      // Setpoint 1.3 with a 1.1 flush: a target within the diluent MOD is
      // fine, the loop runs at the setpoint there.
      final r = computeGasLimits(ccr(setpoint: 1.3, flush: 1.1, target: 40));
      expect(r.targetBeyondMod, isFalse);
      expect(r.atTarget!.pO2Bar, closeTo(1.3, 1e-12));
    });

    test('a target below the diluent MOD is flagged with the flush ppO2', () {
      final r = computeGasLimits(ccr(setpoint: 1.3, flush: 1.1, target: 70));
      expect(r.targetBeyondMod, isTrue);
      // A flush at 70 m gives the diluent's own ppO2 there.
      expect(r.flushPpO2AtTarget, closeTo(0.21 * _saltPressureAt(70), 1e-9));
      expect(r.flushPpO2AtTarget, greaterThan(1.1));
    });

    test('with a target depth the MND is the loop\'s', () {
      // O2 narcotic: a loop at 1.3 carries more O2 than the diluent at
      // moderate depths, so it reaches the END limit shallower.
      final diluent = computeGasLimits(ccr(setpoint: 1.3));
      final loop = computeGasLimits(ccr(setpoint: 1.3, target: 30));
      expect(loop.mndMeters, lessThan(diluent.mndMeters!));
      // And it agrees with the narcosis check at the target.
      final atMnd = computeGasLimits(
        ccr(setpoint: 1.3, target: loop.mndMeters! + 0.5),
      );
      expect(atMnd.atTarget!.exceedsEndLimit, isTrue);
    });

    test('without a target the MND is the flushed diluent\'s', () {
      final low = computeGasLimits(ccr(setpoint: 0.7));
      final high = computeGasLimits(ccr(setpoint: 1.3));
      final oc = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 21, he: 35),
      );
      expect(low.mndMeters, closeTo(high.mndMeters!, 1e-6));
      expect(low.mndMeters, closeTo(oc.mndMeters!, 1e-6));
    });

    test('OC and Rec have no flush ppO2', () {
      expect(computeGasLimits(_inputs(target: 30)).flushPpO2AtTarget, isNull);
    });
  });

  group('CCR Tec, hypoxic diluent', () {
    test('a shallow target is not hypoxic: the loop holds the setpoint', () {
      final r = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ccrTec, o2: 10, he: 70, target: 5),
      );
      // The diluent itself may not be flushed above its minimum depth ...
      expect(r.minDepthMeters, greaterThan(5));
      // ... but the breathed loop at 5 m is at the setpoint, not hypoxic.
      expect(r.targetShallowerThanMinDepth, isFalse);
      expect(r.atTarget!.pO2Bar, greaterThanOrEqualTo(1.1));
    });
  });

  group('inputs are held to the ranges the calculator offers', () {
    test('Tec O2 cannot drop below the slider floor', () {
      final r = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 1, he: 0),
      );
      expect(r.o2Percent, tecMinO2Percent);
    });

    test('a target depth is capped at the mode maximum', () {
      final rec = computeGasLimits(_inputs(target: 100));
      expect(rec.atTarget!.depthMeters, recTargetMaxMeters);
      final tec = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 21, he: 35, target: 200),
      );
      expect(tec.atTarget!.depthMeters, tecTargetMaxMeters);
    });
  });

  group('GasLimitsInputs.copyWith', () {
    test('replaces only the given fields and can clear the target', () {
      final base = _inputs(target: 30);
      final copy = base.copyWith(o2Percent: 36);
      expect(copy.o2Percent, 36);
      expect(copy.targetDepthMeters, 30);
      expect(copy.mode, base.mode);
      expect(base.copyWith(clearTargetDepth: true).targetDepthMeters, isNull);
    });
  });

  group('depths are never negative', () {
    test('EAD and END of a rich mix near the surface clamp at 0', () {
      final r = computeGasLimits(
        _inputs(mode: ModCalculatorMode.ocTec, o2: 50, he: 30, target: 0),
      );
      expect(r.atTarget!.eadMeters, 0);
      expect(r.atTarget!.endMeters, 0);
    });
  });
}
