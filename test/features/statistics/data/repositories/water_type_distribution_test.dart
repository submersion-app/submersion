import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1427: the water type chart counted only the value stored on the
/// dive, so a dive that inherits its water type from its site was missing.
/// Issue #1998: a dive with no water type anywhere is its own "not recorded"
/// share rather than being left out of the percentages.
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

  test('a dive with no water type anywhere counts as not recorded', () async {
    // Issue #1998: dropping these dives made the recorded shares add up to
    // 100% on their own, overstating every one of them.
    await insertSite(id: 'unknown-site');
    await insertDive(id: 'sited', siteId: 'unknown-site');
    await insertDive(id: 'siteless');
    await insertDive(id: 'known', waterType: 'fresh');

    expect(await countsByLabel(), {
      'fresh': 1,
      DistributionSegment.notRecordedKey: 2,
    });
  });

  test('percentages are shares of every dive in scope', () async {
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
      byLabel[DistributionSegment.notRecordedKey]!.percentage,
      closeTo(25, 0.001),
    );
  });

  test('the not recorded share comes last even when it is largest', () async {
    await insertDive(id: 'known', waterType: 'salt');
    await insertDive(id: 'blank-1');
    await insertDive(id: 'blank-2');

    final dist = await repository.getWaterTypeDistribution();
    expect(dist.map((s) => s.label), [
      'salt',
      DistributionSegment.notRecordedKey,
    ]);
  });

  test('no recorded water type at all yields no distribution', () async {
    // A chart that is 100% "not recorded" says nothing, so the page keeps
    // its empty state instead.
    await insertDive(id: 'blank-1');
    await insertDive(id: 'blank-2');

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
