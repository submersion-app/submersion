import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late InsightsRepository repo;

  Future<void> dive(
    String id,
    DateTime wallClock, {
    String? tripId,
    String? siteId,
    double? depth,
    String? diverId,
    bool excluded = false,
    bool planned = false,
    bool draft = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(wallClock.millisecondsSinceEpoch),
          tripId: Value(tripId),
          siteId: Value(siteId),
          maxDepth: Value(depth),
          diverId: Value(diverId),
          excludedFromStats: Value(excluded),
          isPlanned: Value(planned),
          isDraft: Value(draft),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = InsightsRepository();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Bonaire May 2026',
            startDate: 0,
            endDate: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 's1',
            name: 'Invisibles',
            latitude: const Value(12.0776),
            longitude: const Value(-68.2802),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    for (final sp in ['a', 'b']) {
      await db
          .into(db.species)
          .insert(
            SpeciesCompanion.insert(id: sp, commonName: sp, category: 'fish'),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test(
    'returns trip name, site name, depth and species, newest first',
    () async {
      await dive('old', DateTime.utc(2026, 5, 3, 9), tripId: 't1', depth: 20);
      await dive(
        'new',
        DateTime.utc(2026, 5, 7, 9),
        tripId: 't1',
        siteId: 's1',
        depth: 29.7,
      );
      for (final (id, diveId, speciesId) in [
        ('g1', 'new', 'a'),
        ('g2', 'new', 'b'),
        ('g3', 'old', 'a'),
      ]) {
        await db
            .into(db.sightings)
            .insert(
              SightingsCompanion.insert(
                id: id,
                diveId: diveId,
                speciesId: speciesId,
              ),
            );
      }

      final dives = await repo.getOutingDives();
      expect(dives.map((d) => d.id), ['new', 'old']);
      final newest = dives.first;
      expect(newest.tripId, 't1');
      expect(newest.tripName, 'Bonaire May 2026');
      expect(newest.siteName, 'Invisibles');
      expect(newest.siteLatitude, 12.0776);
      expect(newest.siteLongitude, -68.2802);
      expect(dives.last.siteLatitude, isNull);
      expect(newest.maxDepth, 29.7);
      expect(newest.speciesIds, {'a', 'b'});
      expect(dives.last.speciesIds, {'a'});
      expect(dives.last.siteName, isNull);
    },
  );

  test(
    'leaves out planned, draft and excluded dives and other divers',
    () async {
      for (final id in ['me', 'you']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: 0,
                updatedAt: 0,
              ),
            );
      }
      await dive('kept', DateTime.utc(2026, 5, 3), diverId: 'me');
      await dive(
        'excluded',
        DateTime.utc(2026, 5, 3),
        diverId: 'me',
        excluded: true,
      );
      await dive(
        'planned',
        DateTime.utc(2026, 5, 3),
        diverId: 'me',
        planned: true,
      );
      await dive('draft', DateTime.utc(2026, 5, 3), diverId: 'me', draft: true);
      await dive('theirs', DateTime.utc(2026, 5, 3), diverId: 'you');

      final dives = await repo.getOutingDives(diverId: 'me');
      expect(dives.map((d) => d.id), ['kept']);
    },
  );

  test('decodes the stored wall clock', () async {
    await dive('late', DateTime.utc(2026, 5, 7, 23, 30));
    final d = (await repo.getOutingDives()).single;
    expect(d.dateTime.isUtc, isTrue);
    expect((d.dateTime.year, d.dateTime.month, d.dateTime.day), (2026, 5, 7));
    expect(d.dateTime.hour, 23);
  });

  test('reads at most the limit, newest first', () async {
    for (var i = 1; i <= 5; i++) {
      await dive('d$i', DateTime.utc(2026, 1, i));
    }
    final dives = await repo.getOutingDives(limit: 3);
    expect(dives.map((d) => d.id), ['d5', 'd4', 'd3']);
  });

  test('dives for trips return every in-scope dive on those trips', () async {
    await dive('a', DateTime.utc(2026, 5, 3, 9), tripId: 't1', depth: 20);
    await dive('b', DateTime.utc(2025, 1, 1, 9), tripId: 't1');
    await dive(
      'skipped',
      DateTime.utc(2025, 1, 2, 9),
      tripId: 't1',
      excluded: true,
    );
    await dive('other', DateTime.utc(2025, 1, 3, 9));
    final dives = await repo.getOutingDivesForTrips(['t1']);
    expect(dives.map((d) => d.id), unorderedEquals(['a', 'b']));
    expect(dives.first.tripName, 'Bonaire May 2026');
    expect(await repo.getOutingDivesForTrips(const []), isEmpty);
  });
}
