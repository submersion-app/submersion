import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/gas_calculators/domain/rock_bottom.dart';
import 'package:submersion/features/gas_calculators/domain/tank_spec.dart';

/// Vectors below were computed with python3 and are reproduced in the spec at
/// docs/superpowers/specs/2026-07-26-gas-calculators-weather-cns-units-design.md.
/// If one does not match, report BLOCKED. Do not edit the constant.

final _al80 = TankSpec.fromPreset(TankPresets.al80);
final _steel12 = TankSpec.fromPreset(TankPresets.steel12);

const _feetPerMeter = 3.28084;
const _cuftPerLiter = 0.0353147;

void main() {
  test('ambient pressure is 1 bar at the surface, 4 bar at 30 m', () {
    expect(ambientPressureAtDepth(0), closeTo(1.0, 1e-9));
    expect(ambientPressureAtDepth(30), closeTo(4.0, 1e-9));
  });

  group('computeRockBottom', () {
    test('Case A: 100 ft, 20 ft/min, 15+15 L/min, AL80', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 100 / _feetPerMeter,
          ascentRateMetersPerMin: 20 / _feetPerMeter,
          diverSacLitersPerMin: 15,
          buddySacLitersPerMin: 15,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _al80,
        ),
      );
      expect(r.totalLiters, closeTo(635.0, 1.0));
      expect(r.reserveBar, closeTo(57.2, 0.3));
    });

    test('Case B: realistic imperial stressed SAC 1.0+1.0 cuft/min', () {
      const sacL = 1.0 / _cuftPerLiter; // 28.32 L/min
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 100 / _feetPerMeter,
          ascentRateMetersPerMin: 20 / _feetPerMeter,
          diverSacLitersPerMin: sacL,
          buddySacLitersPerMin: sacL,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _al80,
        ),
      );
      expect(r.solveGasLiters, closeTo(229.3, 1.0));
      expect(r.ascentGasLiters, closeTo(656.7, 2.0));
      expect(r.safetyStopGasLiters, closeTo(254.9, 1.0));
      expect(r.finalAscentGasLiters, closeTo(58.1, 1.0));
      expect(r.totalLiters, closeTo(1198.8, 3.0));
      expect(r.reserveBar, closeTo(108.0, 0.5));
    });

    test('Case C: metric default 30 m, 9 m/min, 20+25 L/min, 12 L', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 9,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _steel12,
        ),
      );
      expect(r.totalLiters, closeTo(757.5, 2.0));
      expect(r.reserveBar, closeTo(63.1, 0.3));
    });

    test('solve time contributes gas proportional to depth pressure', () {
      RockBottomInputs at(double solve) => RockBottomInputs(
        depthMeters: 30,
        ascentRateMetersPerMin: 9,
        diverSacLitersPerMin: 20,
        buddySacLitersPerMin: 25,
        solveMinutes: solve,
        includeSafetyStop: true,
        tank: _steel12,
      );
      final zero = computeRockBottom(at(0));
      final one = computeRockBottom(at(1));
      // 45 L/min combined at 4 bar for 1 min = 180 L.
      expect(one.totalLiters - zero.totalLiters, closeTo(180, 0.5));
      expect(zero.solveGasLiters, 0);
    });

    test('disabling the safety stop removes stop and final-ascent gas', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 9,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 1,
          includeSafetyStop: false,
          tank: _steel12,
        ),
      );
      expect(r.safetyStopGasLiters, 0);
      expect(r.finalAscentGasLiters, 0);
    });

    test('a slower ascent rate needs more gas', () {
      RockBottomInputs at(double rate) => RockBottomInputs(
        depthMeters: 30,
        ascentRateMetersPerMin: rate,
        diverSacLitersPerMin: 20,
        buddySacLitersPerMin: 25,
        solveMinutes: 1,
        includeSafetyStop: true,
        tank: _steel12,
      );
      expect(
        computeRockBottom(at(3)).totalLiters,
        greaterThan(computeRockBottom(at(18)).totalLiters),
      );
    });

    test('the final ascent uses the user rate, not a hardcoded 9 m/min', () {
      final slow = computeRockBottom(
        RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 3,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 0,
          includeSafetyStop: true,
          tank: _steel12,
        ),
      );
      // 5 m at 3 m/min = 1.667 min at 1.25 bar on 45 L/min = 93.75 L.
      expect(slow.finalAscentGasLiters, closeTo(93.75, 0.5));
    });

    test('reserve pressure divides by water capacity, not free gas', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 100 / _feetPerMeter,
          ascentRateMetersPerMin: 20 / _feetPerMeter,
          diverSacLitersPerMin: 15,
          buddySacLitersPerMin: 15,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _al80,
        ),
      );
      // Dividing by free gas (2296 L) would give ~0.28 bar, the reported bug.
      expect(r.reserveBar, greaterThan(10));
    });

    test('a zero ascent rate does not produce infinity or NaN', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 0,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _steel12,
        ),
      );
      expect(r.totalLiters.isFinite, isTrue);
      expect(r.reserveBar.isFinite, isTrue);
    });

    test('total minutes accounts for every phase', () {
      final r = computeRockBottom(
        RockBottomInputs(
          depthMeters: 30,
          ascentRateMetersPerMin: 9,
          diverSacLitersPerMin: 20,
          buddySacLitersPerMin: 25,
          solveMinutes: 1,
          includeSafetyStop: true,
          tank: _steel12,
        ),
      );
      // 1 solve + 25/9 ascent + 3 stop + 5/9 final = 7.333 min.
      expect(r.totalMinutes, closeTo(1 + 25 / 9 + 3 + 5 / 9, 0.01));
    });
  });
}
