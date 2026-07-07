import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  late GasAnalysisService service;

  setUp(() {
    service = GasAnalysisService();
  });

  Dive makeDive({
    Duration? bottomTime,
    Duration? runtime,
    DateTime? entryTime,
    DateTime? exitTime,
    double? avgDepth,
    List<DiveTank> tanks = const [],
    List<DiveProfilePoint> profile = const [],
  }) {
    return Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 3, 28, 10, 0),
      entryTime: entryTime,
      exitTime: exitTime,
      bottomTime: bottomTime,
      runtime: runtime,
      avgDepth: avgDepth,
      tanks: tanks,
      profile: profile,
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
  }

  DiveTank makeTank({
    String id = 'tank-1',
    double? volume,
    double? startPressure,
    double? endPressure,
  }) {
    return DiveTank(
      id: id,
      volume: volume,
      startPressure: startPressure,
      endPressure: endPressure,
    );
  }

  List<DiveProfilePoint> makeProfile(int durationSeconds) {
    return List.generate(
      durationSeconds ~/ 10 + 1,
      (i) => DiveProfilePoint(
        timestamp: i * 10,
        depth: i < 3
            ? (i * 10.0).clamp(0, 20)
            : i > durationSeconds ~/ 10 - 3
            ? ((durationSeconds ~/ 10 - i) * 6.0).clamp(0, 20)
            : 20.0,
      ),
    );
  }

  group('calculateCylinderSac', () {
    test('uses effectiveRuntime (explicit runtime) for diveEnd', () {
      final dive = makeDive(
        runtime: const Duration(minutes: 42),
        bottomTime: const Duration(minutes: 35),
        avgDepth: 20.0,
        tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
        profile: makeProfile(42 * 60),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
      // Usage duration should be based on runtime (42 min), not bottomTime
      expect(results.first.usageDuration?.inMinutes, 42);
    });

    test('uses entryTime/exitTime when runtime is null', () {
      final entry = DateTime(2026, 3, 28, 10, 0);
      final exit = DateTime(2026, 3, 28, 10, 40);
      final dive = makeDive(
        entryTime: entry,
        exitTime: exit,
        bottomTime: const Duration(minutes: 35),
        avgDepth: 20.0,
        tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
        profile: makeProfile(40 * 60),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
      // effectiveRuntime falls back to exitTime-entryTime = 40 min
      expect(results.first.usageDuration?.inMinutes, 40);
    });

    test('falls back to profile when no runtime or timestamps', () {
      const profileDuration = 38 * 60; // 38 minutes
      final dive = makeDive(
        bottomTime: const Duration(minutes: 35),
        avgDepth: 20.0,
        tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
        profile: makeProfile(profileDuration),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
      // Falls back to profile-based runtime via calculateRuntimeFromProfile,
      // then bottomTime if profile calc returns null
      expect(results.first.usageDuration?.inSeconds, greaterThan(0));
    });

    test('falls back to bottomTime as last resort', () {
      final dive = makeDive(
        bottomTime: const Duration(minutes: 35),
        avgDepth: 20.0,
        tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
        // Empty profile - no way to calculate runtime from it
        profile: const [],
      );

      // With empty profile, calculateCylinderSac still runs using the
      // effectiveRuntime fallback chain (bottomTime as last resort).
      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
    });

    test('computes SAC from start/end pressures when the dive has no profile '
        '(older/manually-logged dives) using the dive average depth', () {
      // Regression for #510: SAC by cylinder must show on profileless dives
      // that still carry an average depth and tank start/end pressures.
      final dive = makeDive(
        runtime: const Duration(minutes: 40),
        bottomTime: const Duration(minutes: 40),
        avgDepth: 18.0,
        tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
        profile: const [], // no depth samples, as in older manual entries
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
      expect(
        results.first.sacRate,
        isNotNull,
        reason: 'basic SAC branch must fall back to dive.avgDepth',
      );
      expect(results.first.sacRate!, greaterThan(0));
      expect(results.first.hasValidSac, isTrue);
      // Depth data was inferred from the dive, not per-sample.
      expect(results.first.hasTimeSeriesData, isFalse);
    });

    test(
      'still yields no SAC when a profileless dive also lacks an average depth',
      () {
        // Without any depth reference the ambient-pressure correction is
        // undefined, so SAC stays null (the cylinder row is still returned).
        final dive = makeDive(
          runtime: const Duration(minutes: 40),
          bottomTime: const Duration(minutes: 40),
          tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
          profile: const [],
        );

        final results = service.calculateCylinderSac(
          dive: dive,
          profile: dive.profile,
        );

        expect(results, hasLength(1));
        expect(results.first.sacRate, isNull);
        expect(results.first.hasValidSac, isFalse);
      },
    );

    test('computes SAC rate from start/end pressures', () {
      final dive = makeDive(
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: [makeTank(startPressure: 200, endPressure: 30, volume: 11.1)],
        profile: makeProfile(42 * 60),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
      expect(results.first.sacRate, isNotNull);
      expect(results.first.sacRate!, greaterThan(0));
      expect(results.first.startPressure, 200);
      expect(results.first.endPressure, 30);
    });

    test(
      'uses transmitter pressure keyed under an orphaned tank id (#510)',
      () {
        // Regression for #510. Air-integration dives re-keyed by a reparse /
        // consolidation (issue #276) store their pressure series under a tank
        // id that no longer matches the current dive tank. The overall SAC
        // curve tolerates this; per-cylinder SAC must too, instead of coming
        // out blank. The tank has NO start/end pressure, so the ONLY way to a
        // SAC value is via the (mis-keyed) time-series data.
        final dive = makeDive(
          runtime: const Duration(minutes: 40),
          avgDepth: 18.0,
          tanks: [makeTank(id: 'current-tank', volume: 11.1)],
          profile: makeProfile(40 * 60),
        );

        // Pressure series keyed under an id that is NOT dive.tanks[0].id.
        final orphanPressures = <String, List<TankPressurePoint>>{
          'stale-uuid': [
            for (var t = 0; t <= 40 * 60; t += 60)
              TankPressurePoint(
                id: 'p$t',
                tankId: 'stale-uuid',
                timestamp: t,
                // Linear drain 200 -> 60 bar over the dive.
                pressure: 200 - (140 * t / (40 * 60)),
              ),
          ],
        };

        final results = service.calculateCylinderSac(
          dive: dive,
          profile: dive.profile,
          tankPressures: orphanPressures,
        );

        expect(results, hasLength(1));
        expect(
          results.first.sacRate,
          isNotNull,
          reason: 'orphaned time-series pressure must still drive SAC',
        );
        expect(results.first.sacRate!, greaterThan(0));
        expect(results.first.hasValidSac, isTrue);
        expect(results.first.hasTimeSeriesData, isTrue);
      },
    );

    test('still prefers an exact tank-id match over orphaned series', () {
      // When the pressure series IS correctly keyed, nothing changes.
      final dive = makeDive(
        runtime: const Duration(minutes: 40),
        avgDepth: 18.0,
        tanks: [makeTank(id: 'tank-A', volume: 11.1)],
        profile: makeProfile(40 * 60),
      );

      final pressures = <String, List<TankPressurePoint>>{
        'tank-A': [
          for (var t = 0; t <= 40 * 60; t += 60)
            TankPressurePoint(
              id: 'a$t',
              tankId: 'tank-A',
              timestamp: t,
              pressure: 210 - (150 * t / (40 * 60)),
            ),
        ],
      };

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        tankPressures: pressures,
      );

      expect(results.first.hasTimeSeriesData, isTrue);
      expect(results.first.hasValidSac, isTrue);
    });

    test(
      'orphan-to-tank pairing is deterministic when tanks share an order',
      () {
        // Two current tanks with the DEFAULT order (0) and two orphaned
        // series. The pairing must be stable regardless of Dart's unstable
        // sort: orphans by earliest sample then key, tanks by order then id.
        // Expected: tank-a (id-first) <- early series, tank-b <- late series.
        const tankA = DiveTank(
          id: 'tank-a',
          volume: 11.1,
          gasMix: GasMix(o2: 21, he: 0),
        );
        const tankB = DiveTank(
          id: 'tank-b',
          volume: 11.1,
          gasMix: GasMix(o2: 21, he: 0),
        );
        final dive = makeDive(
          runtime: const Duration(minutes: 40),
          avgDepth: 18.0,
          tanks: const [tankB, tankA], // list order deliberately reversed
          profile: makeProfile(40 * 60),
        );

        List<TankPressurePoint> series(String key, int firstTs, double drain) {
          return [
            for (var t = firstTs; t <= 40 * 60; t += 60)
              TankPressurePoint(
                id: '$key-$t',
                tankId: key,
                timestamp: t,
                pressure: 200 - drain * (t - firstTs) / (40 * 60 - firstTs),
              ),
          ];
        }

        // Iteration order reversed vs. the expected time order to prove the
        // sort (not map order) decides the pairing.
        final pressures = <String, List<TankPressurePoint>>{
          'z-late': series('z-late', 600, 20), // small drain -> low SAC
          'y-early': series('y-early', 0, 150), // big drain -> high SAC
        };

        final results = service.calculateCylinderSac(
          dive: dive,
          profile: dive.profile,
          tankPressures: pressures,
        );

        final byId = {for (final r in results) r.tankId: r};
        expect(byId['tank-a']!.hasValidSac, isTrue);
        expect(byId['tank-b']!.hasValidSac, isTrue);
        // tank-a adopted the early, big-drain series -> higher SAC than tank-b.
        expect(byId['tank-a']!.sacRate!, greaterThan(byId['tank-b']!.sacRate!));
      },
    );

    test('returns empty list for dive with no tanks', () {
      final dive = makeDive(
        runtime: const Duration(minutes: 42),
        avgDepth: 20.0,
        tanks: const [],
        profile: makeProfile(42 * 60),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, isEmpty);
    });

    test('skips tank with missing pressures', () {
      final dive = makeDive(
        runtime: const Duration(minutes: 42),
        avgDepth: 20.0,
        tanks: [makeTank(startPressure: null, endPressure: null)],
        profile: makeProfile(42 * 60),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      expect(results, hasLength(1));
      expect(results.first.sacRate, isNull);
    });

    test('uses profile timestamp when effectiveRuntime is null', () {
      // Dive with NO runtime, NO timestamps, NO bottomTime,
      // single-point profile so calculateRuntimeFromProfile returns null.
      // effectiveRuntime will be null, diveEnd falls to profile.lastOrNull.
      final dive = makeDive(
        avgDepth: 20.0,
        tanks: [makeTank(startPressure: 200, endPressure: 50, volume: 11.1)],
        profile: [const DiveProfilePoint(timestamp: 0, depth: 10)],
      );

      // Pass longer profile to calculateCylinderSac directly
      final externalProfile = makeProfile(40 * 60);
      final results = service.calculateCylinderSac(
        dive: dive,
        profile: externalProfile,
      );

      // diveEnd = null ?? lastProfile.timestamp ?? 0
      expect(results, hasLength(1));
      expect(results.first.usageDuration?.inSeconds, greaterThan(0));
    });

    test('handles multi-tank dive without gas switches', () {
      final dive = makeDive(
        runtime: const Duration(minutes: 42),
        avgDepth: 20.0,
        tanks: [
          makeTank(
            id: 'tank-1',
            startPressure: 200,
            endPressure: 50,
            volume: 11.1,
          ),
          const DiveTank(
            id: 'tank-2',
            volume: 7.0,
            startPressure: 200,
            endPressure: 170,
            role: TankRole.stage,
          ),
        ],
        profile: makeProfile(42 * 60),
      );

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      // Without gas switches, only back gas tank gets a range
      expect(results.length, greaterThanOrEqualTo(1));
    });
  });
}
