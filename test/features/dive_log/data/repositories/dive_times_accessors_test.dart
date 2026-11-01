import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  List<domain.DiveProfilePoint> profileOf(int seconds) => [
    for (var t = 0; t <= seconds; t += 10)
      domain.DiveProfilePoint(
        timestamp: t,
        depth: t == 0 || t == seconds ? 0 : 18,
      ),
  ];

  test('getDiveTimes maps fields and profile span fallback', () async {
    await repository.createDive(
      domain.Dive(
        id: 'a',
        dateTime: DateTime.utc(2026, 5, 1, 10),
        entryTime: DateTime.utc(2026, 5, 1, 10, 5),
        bottomTime: const Duration(minutes: 40),
        profile: profileOf(600),
      ),
    );

    final times = await repository.getDiveTimes('a');
    expect(times, isNotNull);
    expect(times!.id, 'a');
    expect(times.entryTime, DateTime.utc(2026, 5, 1, 10, 5));
    expect(times.bottomTime, const Duration(minutes: 40));
    expect(times.profileSpan, const Duration(seconds: 600));
    // No runtime and no exit time: falls through to the profile span,
    // mirroring Dive.effectiveRuntime resolution order.
    expect(times.effectiveRuntime, const Duration(seconds: 600));

    expect(await repository.getDiveTimes('missing'), isNull);
  });

  test('profile span is null for dives without samples', () async {
    await repository.createDive(
      domain.Dive(id: 'bare', dateTime: DateTime.utc(2026, 5, 2, 10)),
    );
    final times = await repository.getDiveTimes('bare');
    expect(times!.profileSpan, isNull);
    expect(times.effectiveRuntime, isNull);
  });

  test('getPreviousDiveTimes walks back by effective start', () async {
    await repository.createDive(
      domain.Dive(id: 'p1', dateTime: DateTime.utc(2026, 5, 1, 9)),
    );
    await repository.createDive(
      domain.Dive(
        id: 'p2',
        dateTime: DateTime.utc(2026, 5, 1, 11),
        entryTime: DateTime.utc(2026, 5, 1, 11, 2),
      ),
    );
    await repository.createDive(
      domain.Dive(id: 'p3', dateTime: DateTime.utc(2026, 5, 1, 14)),
    );

    expect((await repository.getPreviousDiveTimes('p3'))?.id, 'p2');
    expect((await repository.getPreviousDiveTimes('p2'))?.id, 'p1');
    expect(await repository.getPreviousDiveTimes('p1'), isNull);
  });

  group('a plan that was never dived (#3924)', () {
    final real = domain.Dive(
      id: 'real',
      dateTime: DateTime.utc(2026, 5, 1, 8),
      exitTime: DateTime.utc(2026, 5, 1, 9),
    );
    final plan = domain.Dive(
      id: 'plan',
      dateTime: DateTime.utc(2026, 5, 1, 11),
      exitTime: DateTime.utc(2026, 5, 1, 12),
      isPlanned: true,
    );
    final laterReal = domain.Dive(
      id: 'later-real',
      dateTime: DateTime.utc(2026, 5, 1, 14),
    );
    final laterPlan = domain.Dive(
      id: 'later-plan',
      dateTime: DateTime.utc(2026, 5, 1, 13),
      isPlanned: true,
    );

    test('getDiveTimes says which dives are undived plans', () async {
      await repository.createDive(real);
      await repository.createDive(plan);

      expect((await repository.getDiveTimes('real'))!.isUndivedPlan, isFalse);
      expect((await repository.getDiveTimes('plan'))!.isUndivedPlan, isTrue);
    });

    group('mirrored from a logged dive', () {
      final source = real.copyWith(outingId: 'outing');
      final mirror = plan.copyWith(
        dateTime: DateTime.utc(2026, 5, 1, 8),
        exitTime: DateTime.utc(2026, 5, 1, 9),
        outingId: 'outing',
      );

      test('is not an undived plan', () async {
        await repository.createDive(source);
        await repository.createDive(mirror);

        expect((await repository.getDiveTimes('plan'))!.isUndivedPlan, isFalse);
      });

      test('is the previous dive of a logged dive', () async {
        await repository.createDive(
          source.copyWith(
            id: 'other-day',
            dateTime: DateTime.utc(2026, 4, 1, 8),
            exitTime: DateTime.utc(2026, 4, 1, 9),
          ),
        );
        await repository.createDive(mirror);
        await repository.createDive(laterReal);

        expect(
          (await repository.getPreviousDiveTimes('later-real'))?.id,
          'plan',
        );
        expect(
          await repository.getSurfaceInterval('later-real'),
          const Duration(hours: 5),
        );
      });

      test('looks past a plan nobody dived', () async {
        await repository.createDive(source);
        await repository.createDive(
          mirror.copyWith(
            dateTime: DateTime.utc(2026, 5, 1, 13),
            exitTime: DateTime.utc(2026, 5, 1, 13, 30),
          ),
        );
        await repository.createDive(plan.copyWith(id: 'stale'));

        expect((await repository.getPreviousDiveTimes('plan'))?.id, 'real');
      });

      test(
        'counts toward the executed range and the most recent dive',
        () async {
          await repository.createDive(source);
          await repository.createDive(mirror);
          const diver = 'mirror-diver';
          await db.customStatement(
            "INSERT INTO divers (id, name, created_at, updated_at) "
            "VALUES ('$diver', '$diver', 0, 0)",
          );
          await db.customStatement(
            "UPDATE dives SET diver_id = '$diver' WHERE id = 'plan'",
          );

          final range = await repository.getExecutedDiveTimesInRange(
            DateTime.utc(2026, 5, 1),
            DateTime.utc(2026, 5, 2),
            diverId: diver,
          );
          final latest = await repository.getMostRecentDiveTimes(
            diverId: diver,
            notAfter: DateTime.utc(2026, 5, 2),
          );

          expect(range.map((d) => d.id), ['plan']);
          expect(latest?.id, 'plan');
        },
      );
    });

    test('is not the previous dive of a logged dive', () async {
      await repository.createDive(real);
      await repository.createDive(plan);
      await repository.createDive(laterReal);

      expect((await repository.getPreviousDiveTimes('later-real'))?.id, 'real');
    });

    test('leaves the surface interval of a logged dive alone', () async {
      await repository.createDive(real);
      await repository.createDive(plan);
      await repository.createDive(laterReal);

      expect(
        await repository.getSurfaceInterval('later-real'),
        const Duration(hours: 5),
      );
    });

    test(
      'gives a logged dive no previous dive when it is all there is',
      () async {
        await repository.createDive(plan);
        await repository.createDive(laterReal);

        expect(await repository.getPreviousDiveTimes('later-real'), isNull);
        expect(await repository.getSurfaceInterval('later-real'), isNull);
      },
    );

    test('is still the previous dive of a later plan', () async {
      await repository.createDive(plan);
      await repository.createDive(laterPlan);

      expect((await repository.getPreviousDiveTimes('later-plan'))?.id, 'plan');
      expect(
        await repository.getSurfaceInterval('later-plan'),
        const Duration(hours: 1),
      );
    });
  });

  group('getEarlierDivesRevision (#3924)', () {
    Future<void> touch(String id, int updatedAt) => db.customStatement(
      "UPDATE dives SET updated_at = $updatedAt WHERE id = '$id'",
    );

    final start = DateTime.utc(2026, 5, 3, 12);
    Future<int> revision() => repository.getEarlierDivesRevision('current');

    Future<void> createEarlier(String id, {required Duration before}) =>
        repository.createDive(
          domain.Dive(
            id: id,
            dateTime: start.subtract(before),
            entryTime: start.subtract(before),
          ),
        );

    setUp(() async {
      await repository.createDive(
        domain.Dive(id: 'current', dateTime: start, entryTime: start),
      );
      await touch('current', 9000);
    });

    test('is zero with no dive in the lookback', () async {
      expect(await revision(), 0);
      expect(await repository.getEarlierDivesRevision('missing'), 0);
    });

    test('moves when an earlier dive is written', () async {
      await createEarlier('earlier', before: const Duration(hours: 5));
      await touch('earlier', 100);
      final before = await revision();

      await touch('earlier', 200);

      expect(await revision(), isNot(before));
    });

    test('moves on a write stamped older than the last', () async {
      // A peer's clock ran ahead, then a local edit stamped an earlier time.
      await createEarlier('earlier', before: const Duration(hours: 5));
      await touch('earlier', 2000);
      final before = await revision();

      await touch('earlier', 1000);

      expect(await revision(), isNot(before));
    });

    test('moves on a dive with no entry time', () async {
      await repository.createDive(
        domain.Dive(
          id: 'no-entry',
          dateTime: start.subtract(const Duration(hours: 49)),
        ),
      );
      await touch('no-entry', 100);
      final before = await revision();

      await touch('no-entry', 200);

      expect(await revision(), isNot(before));
    });

    test(
      'moves on an earlier profile, which never re-stamps its dive',
      () async {
        await createEarlier('earlier', before: const Duration(hours: 5));
        final before = await revision();

        await ProfileSeriesRepository().insertSeries(
          diveId: 'earlier',
          samples: const [ProfileSample(timestamp: 60, depth: 20)],
          now: 500,
        );

        expect(await revision(), isNot(before));
      },
    );

    test('moves when an earlier dive is deleted', () async {
      await createEarlier('earlier', before: const Duration(hours: 5));
      final before = await revision();

      await repository.deleteDive('earlier');

      expect(await revision(), isNot(before));
    });

    test('ignores dives outside it, later ones and the dive itself', () async {
      await createEarlier('too-old', before: const Duration(hours: 73));
      await repository.createDive(
        domain.Dive(
          id: 'later',
          dateTime: start.add(const Duration(hours: 1)),
          entryTime: start.add(const Duration(hours: 1)),
        ),
      );
      await touch('too-old', 100);
      await touch('later', 200);
      await touch('current', 300);

      expect(await revision(), 0);
    });
  });

  test('getDiveTimesInRange matches getDivesInRange ids and order', () async {
    await repository.createDive(
      domain.Dive(id: 'r1', dateTime: DateTime.utc(2026, 6, 1, 8)),
    );
    await repository.createDive(
      domain.Dive(
        id: 'r2',
        dateTime: DateTime.utc(2026, 6, 1, 12),
        entryTime: DateTime.utc(2026, 6, 1, 12, 30),
      ),
    );
    await repository.createDive(
      domain.Dive(id: 'r3', dateTime: DateTime.utc(2026, 6, 2, 9)),
    );
    await repository.createDive(
      domain.Dive(id: 'outside', dateTime: DateTime.utc(2026, 6, 9, 9)),
    );

    final start = DateTime.utc(2026, 6, 1);
    final end = DateTime.utc(2026, 6, 3);
    final legacy = await repository.getDivesInRange(start, end);
    final slim = await repository.getDiveTimesInRange(start, end);

    expect(slim.map((t) => t.id).toList(), legacy.map((d) => d.id).toList());
    expect(slim.map((t) => t.id), isNot(contains('outside')));
  });

  test('getSurfaceInterval semantics unchanged', () async {
    // Previous dive: entry 10:00, runtime 60m -> exit 11:00.
    await repository.createDive(
      domain.Dive(
        id: 's1',
        dateTime: DateTime.utc(2026, 6, 1, 10),
        entryTime: DateTime.utc(2026, 6, 1, 10),
        runtime: const Duration(minutes: 60),
      ),
    );
    // Current dive: entry 13:00 -> surface interval 2h.
    await repository.createDive(
      domain.Dive(
        id: 's2',
        dateTime: DateTime.utc(2026, 6, 1, 13),
        entryTime: DateTime.utc(2026, 6, 1, 13),
      ),
    );

    expect(await repository.getSurfaceInterval('s2'), const Duration(hours: 2));
    expect(await repository.getSurfaceInterval('s1'), isNull);
  });

  test('surface interval uses profile span when runtime absent', () async {
    // Previous dive has no runtime/exit; 600 s profile -> exit 10:10.
    await repository.createDive(
      domain.Dive(
        id: 'ps1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        entryTime: DateTime.utc(2026, 7, 1, 10),
        profile: profileOf(600),
      ),
    );
    await repository.createDive(
      domain.Dive(
        id: 'ps2',
        dateTime: DateTime.utc(2026, 7, 1, 11),
        entryTime: DateTime.utc(2026, 7, 1, 11),
      ),
    );

    expect(
      await repository.getSurfaceInterval('ps2'),
      const Duration(minutes: 50),
    );
  });

  test('getDiveForAnalysis matches getDiveById on analysis fields', () async {
    await repository.createDive(
      domain.Dive(
        id: 'g1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        gradientFactorLow: 45,
        gradientFactorHigh: 80,
        altitude: 300.0,
        profile: profileOf(300),
      ),
    );

    final full = await repository.getDiveById('g1');
    final lean = await repository.getDiveForAnalysis('g1');

    expect(lean, isNotNull);
    expect(lean!.id, full!.id);
    expect(lean.gradientFactorLow, full.gradientFactorLow);
    expect(lean.gradientFactorHigh, full.gradientFactorHigh);
    expect(lean.altitude, full.altitude);
    expect(lean.diveMode, full.diveMode);
    expect(lean.entryTime, full.entryTime);
    expect(lean.dateTime, full.dateTime);
    expect(lean.tanks.length, full.tanks.length);
    expect(lean.profile.length, full.profile.length);
    expect(lean.profile.first.depth, full.profile.first.depth);
    expect(lean.profile.last.timestamp, full.profile.last.timestamp);
    // Display joins deliberately not hydrated on the lean path.
    expect(lean.tags, isEmpty);
    expect(lean.equipment, isEmpty);
  });
}
