import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

/// Dives per site type (issue #1765).
void main() {
  late StatisticsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id, {List<String> types = const []}) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    for (final type in types) {
      await db.customStatement(
        "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
        "VALUES ('$id-$type', '$id', '$type', 0)",
      );
    }
  }

  Future<void> insertDive(
    String id, {
    String? siteId,
    bool excludedFromStats = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            siteId: Value(siteId),
            excludedFromStats: Value(excludedFromStats),
            diveDateTime: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  }

  Future<Map<String, int>> counts({
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    final dist = await repository.getSiteTypeDistribution(filter: filter);
    return {for (final s in dist) s.label: s.count};
  }

  test("a dive counts once under each of its site's types", () async {
    await insertSite('lakeWreck', types: ['lake', 'wreck']);
    await insertSite('reef', types: ['reef']);
    await insertDive('d1', siteId: 'lakeWreck');
    await insertDive('d2', siteId: 'lakeWreck');
    await insertDive('d3', siteId: 'reef');

    expect(await counts(), {'lake': 2, 'wreck': 2, 'reef': 1});
  });

  test('dives at untyped sites and without a site are not counted', () async {
    await insertSite('bare');
    await insertDive('d1', siteId: 'bare');
    await insertDive('d2');

    expect(await counts(), isEmpty);
  });

  test('dives excluded from statistics are not counted', () async {
    await insertSite('reef', types: ['reef']);
    await insertDive('kept', siteId: 'reef');
    await insertDive('excluded', siteId: 'reef', excludedFromStats: true);

    expect(await counts(), {'reef': 1});
  });

  test('the view filter applies', () async {
    await insertSite('reef', types: ['reef']);
    await insertSite('lake', types: ['lake']);
    await insertDive('d1', siteId: 'reef');
    await insertDive('d2', siteId: 'lake');

    expect(await counts(filter: const DiveFilterState(siteId: 'reef')), {
      'reef': 1,
    });
  });

  test(
    'a custom type is labelled by its stored name, a built-in by its slug',
    () async {
      // Any profile's custom type: a shared site can carry one the current
      // diver's vocabulary does not include, so the page cannot resolve it.
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('other', 'Other', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO site_types (id, diver_id, name, is_built_in, sort_order, "
        "created_at, updated_at) "
        "VALUES ('mine_1a2b3c4d', 'other', 'Old mine', 0, 100, 0, 0)",
      );
      await insertSite('s', types: ['mine_1a2b3c4d', 'lake', 'gone']);
      await insertDive('d1', siteId: 's');

      // A link whose type row is gone falls back to its id.
      expect(await counts(), {'Old mine': 1, 'lake': 1, 'gone': 1});
    },
  );

  test('segments come most-dived first', () async {
    await insertSite('reef', types: ['reef']);
    await insertSite('wall', types: ['wall']);
    await insertDive('d1', siteId: 'wall');
    await insertDive('d2', siteId: 'reef');
    await insertDive('d3', siteId: 'reef');

    final dist = await repository.getSiteTypeDistribution();
    expect(dist.map((s) => s.label), ['reef', 'wall']);
  });
}
