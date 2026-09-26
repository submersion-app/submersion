import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';

import '../../../../helpers/test_database.dart';

/// Statistics, the paginated list and its count must select the same dives
/// for every phase 1 Explore axis (the three-path rule).
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    double? waterTemp,
    double? visibilityMeters,
    WaterType? waterType,
    String? siteId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
          waterTemp: Value(waterTemp),
          visibilityMeters: Value(visibilityMeters),
          waterType: Value(waterType?.name),
          siteId: Value(siteId),
        ),
      );

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  Future<void> insertSpecies(String id) => db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(id),
          category: Value(SpeciesCategory.turtle.name),
        ),
      );

  Future<void> insertSighting(String diveId, String speciesId) => db
      .into(db.sightings)
      .insert(
        SightingsCompanion(
          id: Value('$diveId-$speciesId'),
          diveId: Value(diveId),
          speciesId: Value(speciesId),
        ),
      );

  Future<Set<String>> statisticsIds(DiveFilterState filter) async {
    final q = buildFilteredDiveIdSubquery(filter);
    final rows = await db
        .customSelect(
          q.subquery,
          variables: q.params.map((p) => Variable(p)).toList(),
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<Set<String>> listIds(DiveFilterState filter) async =>
      (await repo.getDiveSummaries(filter: filter)).map((s) => s.id).toSet();

  Future<void> expectParity(
    DiveFilterState filter,
    Set<String> expected,
  ) async {
    expect(await statisticsIds(filter), expected, reason: 'statistics');
    expect(await listIds(filter), expected, reason: 'list');
    expect(
      await repo.getDiveCount(filter: filter),
      expected.length,
      reason: 'count',
    );
  }

  test('water temperature bounds', () async {
    await insertDive('cold', waterTemp: 8);
    await insertDive('warm', waterTemp: 27);
    await insertDive('none');
    await expectParity(const DiveFilterState(maxWaterTemp: 15), {'cold'});
    await expectParity(const DiveFilterState(minWaterTemp: 20), {'warm'});
    await expectParity(
      const DiveFilterState(minWaterTemp: 5, maxWaterTemp: 30),
      {'cold', 'warm'},
    );
  });

  test('visibility bounds', () async {
    await insertDive('clear', visibilityMeters: 30);
    await insertDive('murky', visibilityMeters: 4);
    await insertDive('none');
    await expectParity(const DiveFilterState(minVisibility: 20), {'clear'});
    await expectParity(const DiveFilterState(maxVisibility: 5), {'murky'});
  });

  test('water types', () async {
    await insertDive('salt', waterType: WaterType.salt);
    await insertDive('fresh', waterType: WaterType.fresh);
    await insertDive('none');
    await expectParity(const DiveFilterState(waterTypes: [WaterType.salt]), {
      'salt',
    });
    await expectParity(
      const DiveFilterState(waterTypes: [WaterType.salt, WaterType.fresh]),
      {'salt', 'fresh'},
    );
  });

  test('species ids match any sighting', () async {
    await insertSpecies('turtle');
    await insertSpecies('shark');
    await insertDive('t');
    await insertDive('s');
    await insertDive('n');
    await insertSighting('t', 'turtle');
    await insertSighting('s', 'shark');
    await expectParity(const DiveFilterState(speciesIds: ['turtle', 'ray']), {
      't',
    });
    await expectParity(const DiveFilterState(speciesIds: ['turtle', 'shark']), {
      't',
      's',
    });
  });

  test('site id set, alone and with siteId', () async {
    await insertSite('s1');
    await insertSite('s2');
    await insertDive('a', siteId: 's1');
    await insertDive('b', siteId: 's2');
    await insertDive('c');
    await expectParity(const DiveFilterState(siteIds: ['s1', 's2']), {
      'a',
      'b',
    });
    await expectParity(
      const DiveFilterState(siteIds: ['s1', 's2'], siteId: 's2'),
      {'b'},
    );
  });

  test('a species filter ticks on a sighting write alone', () async {
    // The list follows exactly the tables the compiled filter reads (#2365),
    // so this proves both halves: the species axis compiles to a query that
    // names `sightings`, and a sighting write with no dives write fires it.
    await insertSpecies('turtle');
    await insertDive('t');
    final tables = diveFilterTablesTouched(
      const DiveFilterState(speciesIds: ['turtle']),
    );
    expect(tables, contains('sightings'));
    final ticks = <void>[];
    final sub = repo.watchTables(tables).listen(ticks.add);
    await insertSighting('t', 'turtle');
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });
}
