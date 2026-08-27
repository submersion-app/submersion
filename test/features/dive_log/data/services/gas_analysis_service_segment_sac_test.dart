import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  late GasAnalysisService service;

  setUp(() {
    service = const GasAnalysisService();
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
    test('a stage tank prorates over its own stint, not the whole dive '
        '(#110)', () {
      // 60-minute dive: back gas for 50 minutes, then a deco tank for the
      // last 10. Neither has a pressure series, so both fall back to
      // start/end pressures. The deco tank's whole 50 bar drop belongs to
      // its 10-minute stint -- spreading it across the full dive would
      // understate its SAC six-fold, and would disagree with
      // calculateCylinderSac, which prorates over the usage range.
      const backGas = DiveTank(
        id: 't1',
        name: 'Back gas',
        role: TankRole.backGas,
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21, he: 0),
      );
      const decoTank = DiveTank(
        id: 't2',
        name: 'Deco 50',
        role: TankRole.deco,
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 50, he: 0),
      );
      final profile = flatProfile(60 * 60, 20.0);
      GasSwitchWithTank sw(String id, int ts, String tankId) =>
          GasSwitchWithTank(
            gasSwitch: GasSwitch(
              id: id,
              diveId: 'dive-1',
              timestamp: ts,
              tankId: tankId,
              createdAt: DateTime(2026),
            ),
            tankName: tankId,
            gasMix: 'mix',
            o2Fraction: 0.21,
          );

      final segments = service.calculateGasSwitchSegments(
        profile: profile,
        tanks: [backGas, decoTank],
        gasSwitches: [sw('gs1', 0, 't1'), sw('gs2', 50 * 60, 't2')],
        tankPressures: const {},
      );

      expect(segments, isNotNull);
      expect(segments!.length, 2);

      final deco = segments.last;
      expect(deco.tankId, 't2');
      // Full 50 bar over the 10-minute stint at 3.0 ata.
      expect(
        deco.sacRate,
        closeTo(50 / 10 / 3.0, 0.02),
        reason: 'whole-dive proration would charge only 50 * (10/60) bar here',
      );
    });

    test('fallback prorates against the whole dive, not the segment '
        '(#110)', () {
      // No per-sample pressure series (common on sidemount, where the
      // attributed tank's series is flat while the diver breathes the
      // other cylinder): the start/end-pressure fallback applies.
      const tank = DiveTank(
        id: 't1',
        name: 'Sidemount L',
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = flatProfile(30 * 60, 20.0);
      GasSwitchWithTank sw(String id, int ts) => GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: id,
          diveId: 'dive-1',
          timestamp: ts,
          tankId: 't1',
          createdAt: DateTime(2026),
        ),
        tankName: 'Sidemount L',
        gasMix: 'Air',
        o2Fraction: 0.21,
      );

      final segments = service.calculateGasSwitchSegments(
        profile: profile,
        tanks: [tank],
        gasSwitches: [sw('gs1', 0), sw('gs2', 600), sw('gs3', 1200)],
        tankPressures: const {},
      );

      expect(segments, isNotNull);
      expect(segments!.length, 3);
      // Each 10-minute third gets one third of the 100 bar drop:
      // 33.33 bar / 10 min / 3.0 atm. The old fallback divided the segment
      // by ITS OWN duration, charging every segment the whole cylinder and
      // inflating segment SAC by the number of segments.
      for (final s in segments) {
        expect(s.sacRate, closeTo(100 / 3 / 10 / 3.0, 0.02));
      }
      final totalConsumed = segments.fold<double>(
        0,
        (sum, s) => sum + s.gasConsumed,
      );
      expect(totalConsumed, closeTo(100, 1.0));
    });

    test('falls back to whole-dive proration when the gas switches name no '
        'known cylinder (#110)', () {
      // Every gas switch points at a tank id absent from the dive's tank list
      // (stale ids survive a re-import), so each segment resolves to the first
      // cylinder through the orElse fallback and no switch identifies that
      // cylinder's usage window. Proration must then widen to the whole dive
      // instead of collapsing onto the segment.
      const tank = DiveTank(
        id: 't1',
        name: 'Back gas',
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = flatProfile(30 * 60, 20.0);
      GasSwitchWithTank sw(String id, int ts, String tankId) =>
          GasSwitchWithTank(
            gasSwitch: GasSwitch(
              id: id,
              diveId: 'dive-1',
              timestamp: ts,
              tankId: tankId,
              createdAt: DateTime(2026),
            ),
            tankName: tankId,
            gasMix: 'Air',
            o2Fraction: 0.21,
          );

      final segments = service.calculateGasSwitchSegments(
        profile: profile,
        tanks: [tank],
        gasSwitches: [sw('gs1', 0, 'orphan-a'), sw('gs2', 15 * 60, 'orphan-b')],
        tankPressures: const {},
      );

      expect(segments, isNotNull);
      expect(segments!.length, 2);
      // Whole-dive window: each 15-minute half carries half of the 100 bar
      // drop, i.e. 50 bar / 15 min / 3.0 ata.
      for (final s in segments) {
        expect(s.sacRate, closeTo(50 / 15 / 3.0, 0.02));
      }
      // The cylinder is charged exactly once across the dive.
      expect(
        segments.fold<double>(0, (sum, s) => sum + s.gasConsumed),
        closeTo(100, 1.0),
      );
    });

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

    test('falls back to whole-dive proration when no gas switches identify '
        'the active cylinder (#110)', () {
      // A sidemount pair with no gas switches logged: neither cylinder is back
      // gas, so the usage window is indeterminate and every segment must
      // prorate against the whole dive.
      const left = DiveTank(
        id: 't1',
        name: 'Sidemount L',
        role: TankRole.sidemountLeft,
        startPressure: 200,
        endPressure: 80,
        gasMix: GasMix(o2: 21, he: 0),
      );
      const right = DiveTank(
        id: 't2',
        name: 'Sidemount R',
        role: TankRole.sidemountRight,
        startPressure: 200,
        endPressure: 90,
        gasMix: GasMix(o2: 21, he: 0),
      );
      final profile = <DiveProfilePoint>[];
      for (int t = 0; t <= 120; t += 10) {
        profile.add(DiveProfilePoint(timestamp: t, depth: t / 120 * 25));
      }
      for (int t = 130; t <= 2220; t += 10) {
        profile.add(DiveProfilePoint(timestamp: t, depth: 25.0));
      }
      for (int t = 2230; t <= 2520; t += 10) {
        profile.add(
          DiveProfilePoint(timestamp: t, depth: 25.0 * (1 - (t - 2220) / 300)),
        );
      }

      // No gasSwitches: the active-tank lookup falls through to the first
      // cylinder, which is not back gas, so the usage range is unknowable.
      final segments = service.calculatePhaseSegments(
        profile: profile,
        tanks: [left, right],
      );

      expect(segments, isNotNull);
      expect(segments!, isNotEmpty);
      const diveDurationSec = 2520;
      for (final seg in segments) {
        expect(seg.tankId, 't1');
        expect(seg.sacRate, greaterThan(0));
        // The 120 bar drop is spread across the whole dive, not the segment,
        // so each segment's share is strictly proportional to its length.
        final durationSec = seg.endTimestamp - seg.startTimestamp;
        expect(
          seg.gasConsumed,
          closeTo(120 * durationSec / diveDurationSec, 0.01),
          reason: 'segment must carry only its whole-dive share of the drop',
        );
      }
    });

    test(
      'uses transmitter pressure keyed under an orphaned tank id (#510)',
      () {
        // Same re-keyed-pressure condition as the per-cylinder path: the tank
        // carries no start/end pressure, so segment SAC can only come from the
        // time-series, which is stored under a stale tank id.
        const tank = DiveTank(
          id: 'current-tank',
          volume: 11.1,
          gasMix: GasMix(o2: 21, he: 0),
        );
        final profile = <DiveProfilePoint>[];
        for (int t = 0; t <= 120; t += 10) {
          profile.add(DiveProfilePoint(timestamp: t, depth: t / 120 * 25));
        }
        for (int t = 130; t <= 2220; t += 10) {
          profile.add(DiveProfilePoint(timestamp: t, depth: 25.0));
        }
        for (int t = 2230; t <= 2520; t += 10) {
          profile.add(
            DiveProfilePoint(
              timestamp: t,
              depth: 25.0 * (1 - (t - 2220) / 300),
            ),
          );
        }

        final tankPressures = {
          'stale-uuid': linearPressure('stale-uuid', 200, 80, 2520),
        };

        final segments = service.calculatePhaseSegments(
          profile: profile,
          tanks: [tank],
          tankPressures: tankPressures,
        );

        expect(segments, isNotNull);
        expect(segments!, isNotEmpty);
        for (final seg in segments) {
          expect(seg.sacRate, greaterThan(0));
        }
      },
    );
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
          gasVolume(
            tankSizeLiters: 12.0,
            pressureBar: 200,
            o2Percent: 21,
            model: GasModel.real,
          ) -
          gasVolume(
            tankSizeLiters: 12.0,
            pressureBar: 60,
            o2Percent: 21,
            model: GasModel.real,
          );
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
