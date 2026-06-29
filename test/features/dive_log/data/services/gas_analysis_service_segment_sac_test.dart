import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  late GasAnalysisService service;

  setUp(() {
    service = GasAnalysisService();
  });

  // Helper to generate a flat profile at a given depth
  List<DiveProfilePoint> flatProfile(int seconds, double depth) {
    return List.generate(
      seconds ~/ 10 + 1,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: depth),
    );
  }

  List<TankPressurePoint> linearPressure(
    String tankId,
    double start,
    double end,
    int durationSec,
  ) {
    const step = 30;
    final points = <TankPressurePoint>[];
    for (int t = 0; t <= durationSec; t += step) {
      final frac = t / durationSec;
      points.add(
        TankPressurePoint(
          id: 'pp-$tankId-$t',
          tankId: tankId,
          timestamp: t,
          pressure: start + (end - start) * frac,
        ),
      );
    }
    return points;
  }

  group('calculateGasSwitchSegments', () {
    test('computes SAC with Z-factor for segments with tank volume', () {
      const tank = DiveTank(
        id: 't1',
        name: 'AL80',
        volume: 11.1,
        startPressure: 200,
        endPressure: 50,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = flatProfile(42 * 60, 20.0);
      final gasSwitches = [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'gs1',
            diveId: 'dive-1',
            timestamp: 0,
            tankId: 't1',
            createdAt: DateTime(2026),
          ),
          tankName: 'AL80',
          gasMix: 'Air',
          o2Fraction: 0.21,
        ),
      ];
      final tankPressures = {'t1': linearPressure('t1', 200, 50, 42 * 60)};

      final segments = service.calculateGasSwitchSegments(
        profile: profile,
        tanks: [tank],
        gasSwitches: gasSwitches,
        tankPressures: tankPressures,
      );

      expect(segments, isNotNull);
      expect(segments!, isNotEmpty);

      // Segment SAC is in bar/min at surface (pressure-based)
      // 150 bar used / 42 min / 3.0 atm = 1.19 bar/min (ideal)
      // With Z-factor: slightly lower
      final totalSac = segments.first.sacRate;
      expect(totalSac, greaterThan(0.9));
      expect(totalSac, lessThan(1.19));
    });

    test('uses proportional fallback when no time-series pressure', () {
      const tank = DiveTank(
        id: 't1',
        volume: 12.0,
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 32, he: 0),
      );
      final profile = flatProfile(50 * 60, 15.0);
      final gasSwitches = [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'gs1',
            diveId: 'dive-1',
            timestamp: 0,
            tankId: 't1',
            createdAt: DateTime(2026),
          ),
          tankName: 'Tank',
          gasMix: 'EAN32',
          o2Fraction: 0.32,
        ),
      ];

      final segments = service.calculateGasSwitchSegments(
        profile: profile,
        tanks: [tank],
        gasSwitches: gasSwitches,
        // No tankPressures - will use proportional fallback
      );

      expect(segments, isNotNull);
      expect(segments!, isNotEmpty);
      // SAC should be positive and reasonable
      expect(segments.first.sacRate, greaterThan(0));
      expect(segments.first.sacRate, lessThan(30));
    });

    test('falls back to simple formula when tank has no volume', () {
      const tank = DiveTank(
        id: 't1',
        // No volume - can't use Z-factor correction
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = flatProfile(50 * 60, 20.0);
      final gasSwitches = [
        GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: 'gs1',
            diveId: 'dive-1',
            timestamp: 0,
            tankId: 't1',
            createdAt: DateTime(2026),
          ),
          tankName: 'Tank',
          gasMix: 'Air',
          o2Fraction: 0.21,
        ),
      ];

      final segments = service.calculateGasSwitchSegments(
        profile: profile,
        tanks: [tank],
        gasSwitches: gasSwitches,
      );

      expect(segments, isNotNull);
      expect(segments!, isNotEmpty);
      // Without volume, falls back to pressureUsed / durationMin / ambientAtm
      // 100 bar / 50 min / 3.0 atm ≈ 0.667 bar/min
      expect(segments.first.sacRate, closeTo(0.667, 0.05));
    });
  });

  group('calculatePhaseSegments', () {
    test('computes SAC with Z-factor using time-series data', () {
      const tank = DiveTank(
        id: 't1',
        volume: 11.1,
        startPressure: 200,
        endPressure: 80,
        gasMix: GasMix(o2: 21, he: 0),
      );
      // Profile: descend, bottom at 25m, ascend
      final profile = <DiveProfilePoint>[];
      // 2 min descent
      for (int t = 0; t <= 120; t += 10) {
        profile.add(DiveProfilePoint(timestamp: t, depth: t / 120 * 25));
      }
      // 35 min at 25m
      for (int t = 130; t <= 2220; t += 10) {
        profile.add(DiveProfilePoint(timestamp: t, depth: 25.0));
      }
      // 5 min ascent
      for (int t = 2230; t <= 2520; t += 10) {
        profile.add(
          DiveProfilePoint(timestamp: t, depth: 25.0 * (1 - (t - 2220) / 300)),
        );
      }

      final tankPressures = {'t1': linearPressure('t1', 200, 80, 2520)};

      final segments = service.calculatePhaseSegments(
        profile: profile,
        tanks: [tank],
        tankPressures: tankPressures,
      );

      expect(segments, isNotNull);
      expect(segments!, isNotEmpty);
      // All segment SAC rates should be positive
      for (final seg in segments) {
        expect(seg.sacRate, greaterThan(0));
      }
    });
  });

  group('_calculateSacFromTimeSeries (via calculateCylinderSac)', () {
    test('uses Z-factor correction with time-series pressure data', () {
      const tank = DiveTank(
        id: 't1',
        volume: 12.0,
        startPressure: 200,
        endPressure: 60,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = flatProfile(50 * 60, 20.0);
      final tankPressures = {'t1': linearPressure('t1', 200, 60, 50 * 60)};

      final dive = Dive(
        id: 'dive-ts',
        dateTime: DateTime(2026),
        runtime: const Duration(minutes: 50),
        avgDepth: 20.0,
        tanks: const [tank],
        profile: profile,
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: profile,
        tankPressures: tankPressures,
      );

      expect(results, hasLength(1));
      expect(results.first.sacRate, isNotNull);

      // Verify Z-factor correction: with Z, SAC should be lower than ideal
      // Ideal: (200-60) / 50 / 3.0 = 0.933 bar/min
      // With Z-factor, the effective surface liters used is less,
      // so SAC in bar/min equivalent should be lower
      final sacRate = results.first.sacRate!;
      expect(sacRate, lessThan(0.933));
      expect(sacRate, greaterThan(0.7));

      // Verify volumetric SAC matches gasVolume() calculation
      final expectedGasUsed =
          gasVolume(tankSizeLiters: 12.0, pressureBar: 200, o2Percent: 21) -
          gasVolume(tankSizeLiters: 12.0, pressureBar: 60, o2Percent: 21);
      final expectedSacLpm = expectedGasUsed / 50 / 3.0;
      expect(results.first.sacVolume, closeTo(expectedSacLpm, 0.1));
    });

    test('falls back to pressure-based SAC when tank has no volume', () {
      const tank = DiveTank(
        id: 't1',
        // No volume — triggers fallback in _calculateSacFromTimeSeries
        startPressure: 200,
        endPressure: 60,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = flatProfile(50 * 60, 20.0);
      final tankPressures = {'t1': linearPressure('t1', 200, 60, 50 * 60)};

      final dive = Dive(
        id: 'dive-no-vol-ts',
        dateTime: DateTime(2026),
        runtime: const Duration(minutes: 50),
        avgDepth: 20.0,
        tanks: const [tank],
        profile: profile,
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: profile,
        tankPressures: tankPressures,
      );

      expect(results, hasLength(1));
      expect(results.first.sacRate, isNotNull);
      // Pressure-based: (200-60) / 50 / 3.0 ≈ 0.933 bar/min
      expect(results.first.sacRate!, closeTo(0.933, 0.01));
      // sacVolume should be null (no tank volume)
      expect(results.first.sacVolume, isNull);
    });

    test(
      'calculateCylinderSac non-time-series branch uses Z-corrected SAC when volume available',
      () {
        const tank = DiveTank(
          id: 't1',
          volume: 12.0,
          startPressure: 200,
          endPressure: 60,
          gasMix: GasMix(o2: 21, he: 0),
        );
        // Minimal profile for avgDepth, but no tankPressures → non-time-series
        final profile = flatProfile(50 * 60, 20.0);

        final dive = Dive(
          id: 'dive-no-ts',
          dateTime: DateTime(2026),
          runtime: const Duration(minutes: 50),
          avgDepth: 20.0,
          tanks: const [tank],
          profile: profile,
        );

        final results = service.calculateCylinderSac(
          dive: dive,
          profile: profile,
          // No tankPressures → skips time-series branch
        );

        expect(results, hasLength(1));
        expect(results.first.sacRate, isNotNull);
        // Z-corrected: should be close to but not identical to simple pressure math
        expect(results.first.sacRate!, closeTo(0.933, 0.05));
        expect(results.first.sacVolume, isNotNull);
      },
    );

    test(
      'calculateCylinderSac non-time-series branch falls back to pressure-based when no volume',
      () {
        const tank = DiveTank(
          id: 't1',
          // No volume
          startPressure: 200,
          endPressure: 60,
          gasMix: GasMix(o2: 21, he: 0),
        );
        final profile = flatProfile(50 * 60, 20.0);

        final dive = Dive(
          id: 'dive-no-ts-no-vol',
          dateTime: DateTime(2026),
          runtime: const Duration(minutes: 50),
          avgDepth: 20.0,
          tanks: const [tank],
          profile: profile,
        );

        final results = service.calculateCylinderSac(
          dive: dive,
          profile: profile,
        );

        expect(results, hasLength(1));
        expect(results.first.sacRate, isNotNull);
        // Simple pressure-based: (200-60) / 50 / 3.0 ≈ 0.933 bar/min
        expect(results.first.sacRate!, closeTo(0.933, 0.01));
        expect(results.first.sacVolume, isNull);
      },
    );

    test(
      'calculateCylinderSac returns null sacRate when endPressure >= startPressure (no gas used)',
      () {
        const tank = DiveTank(
          id: 't1',
          volume: 12.0,
          startPressure: 100,
          endPressure: 100, // zero gas used
          gasMix: GasMix(o2: 21, he: 0),
        );
        final profile = flatProfile(50 * 60, 20.0);

        final dive = Dive(
          id: 'dive-no-gas-used',
          dateTime: DateTime(2026),
          runtime: const Duration(minutes: 50),
          avgDepth: 20.0,
          tanks: const [tank],
          profile: profile,
        );

        final results = service.calculateCylinderSac(
          dive: dive,
          profile: profile,
        );

        expect(results, hasLength(1));
        expect(results.first.sacRate, isNull);
      },
    );
  });
}
