import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

domain.DiveProfilePoint p(int t, double depth, {double? temp}) =>
    domain.DiveProfilePoint(timestamp: t, depth: depth, temperature: temp);

void main() {
  group('despike', () {
    test('replaces the single-sample spike with neighbor interpolation', () {
      // 20 -> 55 -> 20 at 10 s: 3.5 m/s both ways, opposite signs.
      final points = [p(0, 20), p(10, 20), p(20, 55), p(30, 20), p(40, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[2].depth, 20); // midpoint of neighbors 20 and 20
      expect(out.length, points.length);
      expect(points[2].depth, 55); // input untouched
    });

    test('leaves genuine fast-but-possible movement alone', () {
      // 2.5 m/s is below the 3.0 threshold.
      final points = [p(0, 20), p(10, 45), p(20, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[1].depth, 45);
    });

    test('returns a copy unchanged when fewer than 3 samples', () {
      final points = [p(0, 20), p(10, 55)];
      final out = ProfileRepairService.despike(points);
      expect(out.map((q) => q.depth), [20, 55]);
    });

    test('skips windows with non-increasing timestamps', () {
      // The middle sample shares a timestamp with its neighbor: dt1 == 0.
      final points = [p(0, 20), p(0, 55), p(10, 20)];
      final out = ProfileRepairService.despike(points);
      expect(out[1].depth, 55); // guard `continue` leaves it untouched
    });
  });

  group('fillGaps', () {
    test('interpolates a 120 s hole at the median interval', () {
      // Median 10 s; hole 100->220 gets 11 synthetic samples at 110..210.
      final points = [
        for (var t = 0; t <= 100; t += 10) p(t, 20),
        for (var t = 220; t <= 300; t += 10) p(t, 30),
      ];
      final out = ProfileRepairService.fillGaps(points);
      final inserted = out.where((q) => q.timestamp > 100 && q.timestamp < 220);
      expect(inserted, hasLength(11));
      // Linear: at t=160 (halfway), depth = (20+30)/2 = 25.
      expect(
        inserted.firstWhere((q) => q.timestamp == 160).depth,
        closeTo(25.0, 1e-9),
      );
    });

    test('holes longer than gapFillMaxSeconds are left alone', () {
      final points = [p(0, 20), p(400, 20), p(410, 20)];
      final out = ProfileRepairService.fillGaps(points);
      expect(out.length, points.length);
    });

    test('leaves short profiles (fewer than 3 points) untouched', () {
      final points = [p(0, 20), p(200, 30)];
      final out = ProfileRepairService.fillGaps(points);
      expect(out.length, 2);
    });

    test('returns the input when no positive intervals exist', () {
      // All identical timestamps -> the intervals list is empty.
      final points = [p(0, 20), p(0, 21), p(0, 22)];
      final out = ProfileRepairService.fillGaps(points);
      expect(out.length, 3);
    });
  });

  group('smoothTemperature', () {
    test('clamps a single-sample 8 C jump, depth untouched', () {
      final points = [
        p(0, 20, temp: 20),
        p(10, 20, temp: 12), // 8 C jump down and back
        p(20, 20, temp: 20),
      ];
      final out = ProfileRepairService.smoothTemperature(points);
      expect(out[1].temperature, closeTo(20.0, 1e-9));
      expect(out[1].depth, 20);
    });

    test('leaves short profiles (fewer than 3 points) untouched', () {
      final points = [p(0, 20, temp: 20), p(10, 20, temp: 12)];
      final out = ProfileRepairService.smoothTemperature(points);
      expect(out[1].temperature, 12);
    });

    test('skips windows with a missing temperature reading', () {
      final points = [
        p(0, 20, temp: null),
        p(10, 20, temp: 12),
        p(20, 20, temp: 20),
      ];
      final out = ProfileRepairService.smoothTemperature(points);
      expect(out[1].temperature, 12); // a == null -> continue, no clamp
    });
  });

  group('convertTemperature', () {
    test('kelvin scale: 295.15 -> 22 C', () {
      final out = ProfileRepairService.convertTemperature([
        p(0, 20, temp: 295.15),
      ], kelvinScale: true);
      expect(out.single.temperature, closeTo(22.0, 1e-9));
    });

    test('fahrenheit scale: 72 F -> 22.2 C', () {
      final out = ProfileRepairService.convertTemperature([
        p(0, 20, temp: 72),
      ], kelvinScale: false);
      expect(out.single.temperature, closeTo((72 - 32) * 5 / 9, 1e-9));
    });

    test('leaves samples without a temperature untouched', () {
      final out = ProfileRepairService.convertTemperature([
        p(0, 20, temp: null),
      ], kelvinScale: true);
      expect(out.single.temperature, isNull);
    });
  });

  group('DB-backed instance methods', () {
    late DiveRepository diveRepo;
    late ProfileRepairService service;

    setUp(() async {
      QualityScanScheduler.enabled = false;
      await setUpTestDatabase();
      diveRepo = DiveRepository();
      service = ProfileRepairService(diveRepository: diveRepo);
    });
    tearDown(() async {
      QualityScanScheduler.enabled = true;
      await tearDownTestDatabase();
    });

    Future<void> seedDive({List<domain.DiveProfilePoint> profile = const []}) =>
        diveRepo.createDive(
          domain.Dive(
            id: 'd1',
            dateTime: DateTime.utc(2026, 7, 1, 10),
            maxDepth: 5,
            avgDepth: 5,
            profile: profile,
          ),
        );

    test('currentPrimaryProfile returns the stored primary samples', () async {
      await seedDive(profile: [p(0, 0), p(60, 20), p(120, 10)]);
      final out = await service.currentPrimaryProfile('d1');
      expect(out.map((q) => q.depth), [0, 20, 10]);
    });

    test(
      'applyEdited swaps the primary series; undo restores the original',
      () async {
        await seedDive(profile: [p(0, 0), p(60, 20), p(120, 10)]);
        await service.applyEdited('d1', [p(0, 0), p(60, 18)]);
        expect(
          (await service.currentPrimaryProfile('d1')).map((q) => q.depth),
          [0, 18],
        );
        await service.undo('d1');
        expect(
          (await service.currentPrimaryProfile('d1')).map((q) => q.depth),
          [0, 20, 10],
        );
      },
    );

    test(
      'recomputeMetrics writes max/avg depth from the primary profile',
      () async {
        await seedDive(profile: [p(0, 0), p(60, 30), p(120, 30)]);
        await service.recomputeMetrics('d1');
        final dive = (await diveRepo.getDiveById('d1'))!;
        expect(dive.maxDepth, 30);
        expect(dive.avgDepth, closeTo(20.0, 1e-9));
      },
    );

    test('recomputeMetrics is a no-op for an unknown dive', () async {
      await service.recomputeMetrics('missing'); // dive == null -> returns
    });

    test(
      'recomputeMetrics leaves metrics alone when the profile is empty',
      () async {
        await seedDive(profile: const []);
        await service.recomputeMetrics('d1');
        final dive = (await diveRepo.getDiveById('d1'))!;
        expect(dive.maxDepth, 5); // both computed metrics null -> unchanged
      },
    );
  });
}
