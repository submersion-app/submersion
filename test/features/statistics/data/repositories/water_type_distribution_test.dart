import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1427: the water type chart counted only the value stored on the
/// dive, so a dive that inherits its water type from its site was missing.
///
/// Issue #1998: a dive with no water type anywhere is counted in its own
/// not-recorded bucket, so the recorded shares are of all dives.
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

  Future<String> insertSite({required String id, String? waterType}) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            waterType: Value(waterType),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    return id;
  }

  Future<String> insertDive({
    required String id,
    String? siteId,
    String? waterType,
    String? diverId,
    bool excludedFromStats = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            siteId: Value(siteId),
            waterType: Value(waterType),
            excludedFromStats: Value(excludedFromStats),
            diveDateTime: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    return id;
  }

  Future<Map<String, int>> countsByLabel() async {
    final dist = await repository.getWaterTypeDistribution();
    return {for (final s in dist) s.label: s.count};
  }

  test('a dive with no water type inherits its site water type', () async {
    await insertSite(id: 'reef', waterType: 'salt');
    await insertDive(id: 'own', waterType: 'salt');
    await insertDive(id: 'inherited', siteId: 'reef');

    expect(await countsByLabel(), {'salt': 2});
  });

  test("the dive's own water type wins over the site's", () async {
    // A quarry flooded with sea water, or simply a diver who corrected the
    // site's default: the value on the dive is the diver's explicit answer.
    await insertSite(id: 'quarry', waterType: 'fresh');
    await insertDive(id: 'corrected', siteId: 'quarry', waterType: 'salt');

    expect(await countsByLabel(), {'salt': 1});
  });

  test('an empty water type string falls back to the site', () async {
    // Older imports wrote '' rather than NULL.
    await insertSite(id: 'reef', waterType: 'salt');
    await insertDive(id: 'blank', siteId: 'reef', waterType: '');

    expect(await countsByLabel(), {'salt': 1});
  });

  test(
    'a dive with no water type anywhere is counted as not recorded',
    () async {
      await insertSite(id: 'unknown-site');
      await insertDive(id: 'sited', siteId: 'unknown-site');
      await insertDive(id: 'siteless');
      await insertDive(id: 'known', waterType: 'fresh');

      expect(await countsByLabel(), {
        'fresh': 1,
        kNotRecordedDistributionKey: 2,
      });
    },
  );

  test('percentages are shares of every dive, recorded or not', () async {
    await insertSite(id: 'reef', waterType: 'salt');
    await insertDive(id: 'a', siteId: 'reef');
    await insertDive(id: 'b', waterType: 'salt');
    await insertDive(id: 'c', waterType: 'fresh');
    await insertDive(id: 'd'); // no water type at all

    final dist = await repository.getWaterTypeDistribution();
    final byLabel = {for (final s in dist) s.label: s};
    expect(byLabel['salt']!.percentage, closeTo(50, 0.001));
    expect(byLabel['fresh']!.percentage, closeTo(25, 0.001));
    expect(
      byLabel[kNotRecordedDistributionKey]!.percentage,
      closeTo(25, 0.001),
    );
  });

  test('the not recorded bucket comes last even when it is largest', () async {
    await insertDive(id: 'a', waterType: 'fresh');
    await insertDive(id: 'b');
    await insertDive(id: 'c');

    final dist = await repository.getWaterTypeDistribution();
    expect(dist.map((s) => s.label), ['fresh', kNotRecordedDistributionKey]);
  });

  test('only unrecorded dives yield a single not recorded bucket', () async {
    await insertDive(id: 'a');
    await insertDive(id: 'b', waterType: '');

    final dist = await repository.getWaterTypeDistribution();
    expect(dist, hasLength(1));
    expect(dist.single.label, kNotRecordedDistributionKey);
    expect(dist.single.count, 2);
    expect(dist.single.percentage, closeTo(100, 0.001));
  });

  test('no dives yields no segments', () async {
    expect(await repository.getWaterTypeDistribution(), isEmpty);
  });

  test('an inherited water type still honours the statistics scope', () async {
    await insertSite(id: 'reef', waterType: 'salt');
    await insertDive(id: 'counted', siteId: 'reef');
    await insertDive(id: 'excluded', siteId: 'reef', excludedFromStats: true);

    expect(await countsByLabel(), {'salt': 1});
  });

  test('the view filter still applies to an inherited water type', () async {
    // The filter is an `AND dives.id IN (SELECT id FROM dives WHERE ...)`
    // subquery that names the dives table itself; it has to keep resolving now
    // that dive_sites is joined alongside.
    await insertSite(id: 'reef', waterType: 'salt');
    await insertSite(id: 'lake', waterType: 'fresh');
    await insertDive(id: 'in-filter', siteId: 'reef');
    await insertDive(id: 'out-of-filter', siteId: 'lake');

    final dist = await repository.getWaterTypeDistribution(
      filter: const DiveFilterState(siteId: 'reef'),
    );
    expect({for (final s in dist) s.label: s.count}, {'salt': 1});
  });

  test('the diver filter reads the dive, not the site', () async {
    // dive_sites carries its own diver_id, so an unqualified `diver_id = ?`
    // would be ambiguous once the site is joined in.
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver-a'),
            name: Value('A'),
            medicalNotes: Value(''),
            notes: Value(''),
            isDefault: Value(false),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await insertSite(id: 'reef', waterType: 'salt');
    await insertDive(id: 'mine', siteId: 'reef', diverId: 'diver-a');
    await insertDive(id: 'theirs', siteId: 'reef');

    final dist = await repository.getWaterTypeDistribution(diverId: 'diver-a');
    expect({for (final s in dist) s.label: s.count}, {'salt': 1});
  });
}
