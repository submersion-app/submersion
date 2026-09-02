import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository stats;
  late DiveRepository diveRepo;

  setUp(() async {
    await setUpTestDatabase();
    stats = StatisticsRepository();
    diveRepo = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('a multi-type dive counts toward each of its types', () async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['night', 'wreck'],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'b',
        dateTime: DateTime(2026, 1, 2),
        diveTypeIds: const ['night'],
      ),
    );

    final dist = await stats.getDiveTypeDistribution();
    // The repository emits the dive-type id as a stable key; the presentation
    // layer resolves it to localized display text.
    final byLabel = {for (final s in dist) s.label: s.count};
    expect(byLabel['night'], 2); // both dives
    expect(byLabel['wreck'], 1); // only dive 'a'
  });

  test("totalDurationSeconds sums each type's dive durations", () async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['night', 'wreck'],
        bottomTime: const Duration(minutes: 30),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'b',
        dateTime: DateTime(2026, 1, 2),
        diveTypeIds: const ['night'],
        bottomTime: const Duration(minutes: 45),
      ),
    );

    final dist = await stats.getDiveTypeDistribution();
    final byLabel = {for (final s in dist) s.label: s.totalDurationSeconds};
    // 'night' is on both dives, so its total is the sum of both durations;
    // 'wreck' only carries dive 'a'.
    expect(byLabel['night'], (30 + 45) * 60);
    expect(byLabel['wreck'], 30 * 60);
  });

  test('totalDurationSeconds resolves the whole effectiveRuntime chain, not '
      'just runtime and bottom_time', () async {
    // Each dive below can only be measured at a different step of
    // `Dive.effectiveRuntime`, so a query that stops at
    // COALESCE(runtime, bottom_time) reports the middle two as zero.
    await diveRepo.createDive(
      domain.Dive(
        id: 'explicit-runtime',
        dateTime: DateTime(2026, 2, 1),
        diveTypeIds: const ['night'],
        runtime: const Duration(minutes: 25),
        bottomTime: const Duration(minutes: 20),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'entry-exit-only',
        dateTime: DateTime(2026, 2, 2),
        diveTypeIds: const ['night'],
        entryTime: DateTime.utc(2026, 2, 2, 10),
        exitTime: DateTime.utc(2026, 2, 2, 10, 40),
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'profile-only',
        dateTime: DateTime(2026, 2, 3),
        diveTypeIds: const ['night'],
        profile: [
          for (var t = 0; t <= 1800; t += 10)
            domain.DiveProfilePoint(
              timestamp: t,
              depth: t == 0 || t == 1800 ? 0 : 18,
            ),
        ],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'bottom-time-only',
        dateTime: DateTime(2026, 2, 4),
        diveTypeIds: const ['night'],
        bottomTime: const Duration(minutes: 45),
      ),
    );

    final dist = await stats.getDiveTypeDistribution();
    final byLabel = {for (final s in dist) s.label: s.totalDurationSeconds};
    // runtime wins over bottom_time (25, not 20), then exit - entry (40),
    // then the profile span (30), then bottom_time (45).
    expect(byLabel['night'], (25 + 40 + 30 + 45) * 60);
  });

  test(
    'totalDurationSeconds is zero when no dive of the type is timed',
    () async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'untimed',
          dateTime: DateTime(2026, 2, 5),
          diveTypeIds: const ['wreck'],
        ),
      );

      final dist = await stats.getDiveTypeDistribution();
      final byLabel = {for (final s in dist) s.label: s.totalDurationSeconds};
      // SUM over an all-NULL column is NULL, which surfaces as no time logged
      // rather than a missing segment.
      expect(byLabel['wreck'], 0);
    },
  );

  test('isDiveTypeInUse is true when a type is on any dive', () async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime(2026, 1, 1),
        diveTypeIds: const ['cave', 'deep'],
      ),
    );
    final typeRepo = DiveTypeRepository();
    expect(await typeRepo.isDiveTypeInUse('deep'), isTrue);
    expect(await typeRepo.isDiveTypeInUse('wreck'), isFalse);
  });
}
