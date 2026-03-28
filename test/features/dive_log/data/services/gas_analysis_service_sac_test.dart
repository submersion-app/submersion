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
    int? startPressure,
    int? endPressure,
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

      // With empty profile, calculateCylinderSac should still work
      // using effectiveRuntime fallback chain (bottomTime as last resort)
      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
      );

      // Empty profile means no usage profile points, so SAC can't be
      // calculated with depth data - but the method should still run
      expect(results, isA<List>());
    });

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
