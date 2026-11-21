import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// The read queries behind the Home panels (issue #4824).
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  /// A wall clock flagged as UTC, the way dive_date_time stores it.
  int utc(int year, int month, int day, [int hour = 9, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

  Future<void> diver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          medicalNotes: const Value(''),
          notes: const Value(''),
          isDefault: const Value(false),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> dive(
    String id, {
    required int start,
    String? diverId,
    double? maxDepth,
    int? runtimeSeconds,
    double avgDepth = 10,
    int? startPressure,
    double? volume,
    String? siteId,
    String? name,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            siteId: Value(siteId),
            name: Value(name),
            diveDateTime: Value(start),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            runtime: Value(runtimeSeconds),
            bottomTime: Value(runtimeSeconds),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    if (startPressure != null) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('tank-$id'),
              diveId: Value(id),
              startPressure: Value(startPressure.toDouble()),
              endPressure: const Value(50),
              volume: Value(volume ?? 12),
              tankRole: const Value('backGas'),
              o2Percent: const Value(21.0),
              hePercent: const Value(0.0),
              tankOrder: const Value(0),
            ),
          );
    }
  }

  Future<void> species(String id, String name) => db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(name),
          category: const Value('fish'),
        ),
      );

  Future<void> sighting(String id, String diveId, String speciesId) => db
      .into(db.sightings)
      .insert(
        SightingsCompanion.insert(id: id, diveId: diveId, speciesId: speciesId),
      );

  group('getDailyDiveCounts', () {
    test('groups dives by their calendar day within the range', () async {
      await diver('me');
      await diver('other');
      await dive('a', start: utc(2026, 3, 4, 9), diverId: 'me');
      await dive('b', start: utc(2026, 3, 4, 14), diverId: 'me');
      await dive('c', start: utc(2026, 3, 5), diverId: 'me');
      await dive('x', start: utc(2026, 3, 4), diverId: 'other');
      await dive('old', start: utc(2024, 3, 4), diverId: 'me');

      final counts = await repository.getDailyDiveCounts(
        diverId: 'me',
        from: DateTime(2025, 11, 21),
        to: DateTime(2026, 11, 20),
      );

      expect(counts, {DateTime(2026, 3, 4): 2, DateTime(2026, 3, 5): 1});
    });

    test('a 23:30 dive stays on its own day', () async {
      await dive('late', start: utc(2026, 5, 6, 23, 30));
      final counts = await repository.getDailyDiveCounts(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(counts, {DateTime(2026, 5, 6): 1});
    });

    test('both ends of the range are included', () async {
      await dive('first', start: utc(2026, 1, 1, 0, 5));
      await dive('last', start: utc(2026, 1, 31, 23, 55));
      final counts = await repository.getDailyDiveCounts(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      expect(counts.length, 2);
    });
  });

  group('getRecentSacPerDive', () {
    test('returns the newest dives with a SAC, oldest first', () async {
      for (var i = 1; i <= 5; i++) {
        await dive(
          'd$i',
          start: utc(2026, 1, i),
          runtimeSeconds: 3000,
          startPressure: 200,
        );
      }
      await dive('noTank', start: utc(2026, 1, 9), runtimeSeconds: 3000);

      final series = await repository.getRecentSacPerDive(limit: 3);

      expect(series.length, 3);
      expect(series.map((p) => p.date.day), [3, 4, 5]);
      expect(series.every((p) => p.value > 0), isTrue);
    });

    test('no dives gives an empty series', () async {
      expect(await repository.getRecentSacPerDive(limit: 30), isEmpty);
    });

    test('the per-dive SAC queries limit to the newest dives in SQL', () async {
      for (var i = 1; i <= 5; i++) {
        await dive(
          'd$i',
          start: utc(2026, 1, i),
          runtimeSeconds: 3000,
          startPressure: 200,
        );
      }
      final volume = await repository.getSacVolumePerDive(limit: 2);
      final pressure = await repository.getSacPressurePerDive(limit: 2);
      expect(volume.map((p) => p.date.day), [4, 5]);
      expect(pressure.map((p) => p.date.day), [4, 5]);
      // No limit still reads them all.
      expect(await repository.getSacVolumePerDive(), hasLength(5));
    });

    test('a dive whose tank has no volume does not use up the limit', () async {
      for (var i = 1; i <= 3; i++) {
        await dive(
          'd$i',
          start: utc(2026, 1, i),
          runtimeSeconds: 3000,
          startPressure: 200,
        );
      }
      await db.customStatement(
        "UPDATE dive_tanks SET volume = NULL WHERE dive_id = 'd3'",
      );
      final volume = await repository.getSacVolumePerDive(limit: 2);
      expect(volume.map((p) => p.date.day), [1, 2]);
    });
  });

  group('getAveragesSince', () {
    test('averages only dives on or after the date', () async {
      await dive(
        'old',
        start: utc(2024, 1, 1),
        maxDepth: 50,
        runtimeSeconds: 6000,
      );
      await dive(
        'a',
        start: utc(2026, 6, 1),
        maxDepth: 20,
        runtimeSeconds: 3000,
      );
      await dive(
        'b',
        start: utc(2026, 7, 1),
        maxDepth: 30,
        runtimeSeconds: 2400,
      );

      final avg = await repository.getAveragesSince(
        since: DateTime(2025, 11, 20),
      );

      expect(avg.diveCount, 2);
      expect(avg.maxDepth, 25);
      expect(avg.runtimeSeconds, 2700);
    });

    test('no dives gives nulls and a zero count', () async {
      final avg = await repository.getAveragesSince(since: DateTime(2020));
      expect(avg.diveCount, 0);
      expect(avg.maxDepth, isNull);
      expect(avg.runtimeSeconds, isNull);
    });
  });

  group('species', () {
    setUp(() async {
      await species('turtle', 'Green turtle');
      await species('angel', 'French angelfish');
      await species('moray', 'Spotted moray');
      await dive('old', start: utc(2024, 1, 1));
      await dive('a', start: utc(2026, 6, 1));
      await dive('b', start: utc(2026, 7, 1));
      await sighting('s1', 'old', 'turtle');
      await sighting('s2', 'a', 'turtle');
      await sighting('s3', 'b', 'turtle');
      await sighting('s4', 'b', 'angel');
      await sighting('s5', 'old', 'moray');
    });

    test('counts species first seen on or after the date', () async {
      final n = await repository.getSpeciesFirstSeenSince(
        since: DateTime(2026, 1, 1),
      );
      expect(n, 1); // the angelfish; the turtle was first seen in 2024
    });

    test('ranks species over the most recent dives by dive count', () async {
      final rows = await repository.getRecentSpeciesSightings(
        recentDives: 2,
        limit: 5,
      );
      expect(rows.map((r) => (r.name, r.diveCount)).toList(), [
        ('Green turtle', 2),
        ('French angelfish', 1),
      ]);
    });
  });

  group('getDeepestDiveOfYear', () {
    test('names the deepest dive of the year by its site', () async {
      await db
          .into(db.diveSites)
          .insert(
            const DiveSitesCompanion(
              id: Value('hole'),
              name: Value('Blue Hole'),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      await dive('shallow', start: utc(2026, 2, 1), maxDepth: 18);
      await dive('deep', start: utc(2026, 3, 1), maxDepth: 42, siteId: 'hole');
      await dive('older', start: utc(2025, 6, 1), maxDepth: 60);

      expect(await repository.getDeepestDiveOfYear(2026), (
        id: 'deep',
        site: 'Blue Hole',
      ));
    });

    test(
      'takes the dive name without a site; null for an empty year',
      () async {
        await dive(
          'named',
          start: utc(2026, 4, 1),
          maxDepth: 25,
          name: 'Night drift',
        );
        expect(await repository.getDeepestDiveOfYear(2026), (
          id: 'named',
          site: 'Night drift',
        ));
        expect(await repository.getDeepestDiveOfYear(2024), isNull);
      },
    );
  });

  test('year stats carry the average maximum depth', () async {
    await dive('a', start: utc(2026, 2, 1), maxDepth: 20);
    await dive('b', start: utc(2026, 3, 1), maxDepth: 30);
    final stats = await repository.getYearStats(2026);
    expect(stats.avgMaxDepth, 25);
  });
}
