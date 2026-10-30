import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id, String name, String? country) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: name,
            country: Value(country),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    required int at,
    int? number,
    String? siteId,
    double? depth,
    int? bottomSeconds,
    int? rating,
    String? tripId,
    bool favorite = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at),
            diveNumber: Value(number),
            siteId: Value(siteId),
            maxDepth: Value(depth),
            bottomTime: Value(bottomSeconds),
            rating: Value(rating),
            tripId: Value(tripId),
            isFavorite: Value(favorite),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  }

  Future<void> seed() async {
    await insertSite('s1', 'Blue Hole', 'Egypt');
    await insertSite('s2', 'arch', null);
    // Ties on every sort value, so the tiebreakers decide the order.
    await insertDive(
      'a',
      at: 1000,
      number: 1,
      siteId: 's1',
      depth: 30,
      bottomSeconds: 2400,
      rating: 4,
    );
    await insertDive(
      'b',
      at: 1000,
      number: 1,
      siteId: 's2',
      depth: 30,
      bottomSeconds: 2400,
      rating: 4,
    );
    await insertDive(
      'c',
      at: 3000,
      number: 3,
      siteId: 's1',
      depth: 12,
      bottomSeconds: 3600,
      rating: 5,
      favorite: true,
    );
    await insertDive('d', at: 2000, number: 2, depth: 45, rating: null);
    await insertDive(
      'e',
      at: 2000,
      number: 7,
      siteId: 's2',
      depth: 18,
      bottomSeconds: 1800,
      rating: 2,
    );
  }

  test('matches getDiveSummaries order for every sort and direction', () async {
    await seed();
    const filter = DiveFilterState(minDepth: 15);
    for (final field in DiveSortField.values) {
      for (final direction in SortDirection.values) {
        final sort = SortState(field: field, direction: direction);
        final index = await repository.getDiveScrubberIndex(
          filter: filter,
          sort: sort,
        );
        final summaries = await repository.getDiveSummaries(
          filter: filter,
          sort: sort,
          limit: 1000,
        );
        expect(
          index.map((e) => e.id).toList(),
          summaries.map((s) => s.id).toList(),
          reason: '$field $direction',
        );
      }
    }
  });

  test('carries the values the scrubber labels read', () async {
    await seed();
    final index = await repository.getDiveScrubberIndex(
      sort: const SortState(field: DiveSortField.date),
    );
    final c = index.firstWhere((e) => e.id == 'c');
    expect(c.siteName, 'Blue Hole');
    expect(c.diveNumber, 3);
    expect(c.maxDepth, 12);
    expect(c.bottomTime, const Duration(minutes: 60));
    expect(c.rating, 5);
    expect(c.sortTimestamp, 3000);
    expect(c.isFavorite, isTrue);

    final d = index.firstWhere((e) => e.id == 'd');
    expect(d.siteName, isNull);
    expect(d.bottomTime, isNull);
    expect(d.rating, isNull);
    expect(d.isFavorite, isFalse);
  });

  test('classifies each dive by the richest gas across its tanks', () async {
    Future<void> tank(String id, String dive, double o2, double he) => db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: id,
            diveId: dive,
            o2Percent: Value(o2),
            hePercent: Value(he),
          ),
        );
    await insertDive('air', at: 1000);
    await insertDive('nx', at: 2000);
    await insertDive('tx', at: 3000);
    await insertDive('none', at: 4000);
    await insertDive('o2-22', at: 5000);
    await insertDive('o2-22.5', at: 6000);
    await tank('t1', 'air', 21, 0);
    await tank('t2', 'nx', 21, 0);
    await tank('t3', 'nx', 50, 0);
    await tank('t4', 'tx', 18, 45);
    await tank('t5', 'tx', 50, 0);
    await tank('t6', 'o2-22', 22, 0);
    await tank('t7', 'o2-22.5', 22.5, 0);

    final index = await repository.getDiveScrubberIndex();
    expect(
      {for (final e in index) e.id: e.gas},
      {
        'air': DiveScrubberGas.air,
        'nx': DiveScrubberGas.nitrox,
        'tx': DiveScrubberGas.trimix,
        'none': null,
        'o2-22': DiveScrubberGas.air,
        'o2-22.5': DiveScrubberGas.nitrox,
      },
    );
  });

  test('reads the trip id the way the list does', () async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Red Sea',
            startDate: 0,
            endDate: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await insertDive('kept', at: 1000, tripId: 't1');
    // A dive can outlive its trip row, as a sync that lands out of order
    // leaves it.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await insertDive('dangling', at: 2000, tripId: 'gone');
    await db.customStatement('PRAGMA foreign_keys = ON');
    await insertDive('none', at: 3000);

    final index = await repository.getDiveScrubberIndex();
    final summaries = await repository.getDiveSummaries(limit: 1000);
    final listTrips = {for (final s in summaries) s.id: s.tripId};
    expect({for (final e in index) e.id: e.tripId}, listTrips);
    expect(listTrips, {'kept': 't1', 'dangling': null, 'none': null});
    expect(
      {for (final e in index) e.id: e.tripName},
      {'kept': 'Red Sea', 'dangling': null, 'none': null},
    );
  });
}
