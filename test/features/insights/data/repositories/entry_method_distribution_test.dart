import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1427: the same site-fallback gap the water type chart had. A dive
/// that takes its entry method from its site was missing from the chart.
///
/// Issue #1998: a dive with no entry method anywhere is counted in its own
/// not-recorded bucket, so the recorded shares are of all dives.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertSite({required String id, String? entryMethod}) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            entryMethod: Value(entryMethod),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    return id;
  }

  Future<String> insertDive({
    required String id,
    String? siteId,
    String? entryMethod,
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
            entryMethod: Value(entryMethod),
            excludedFromStats: Value(excludedFromStats),
            diveDateTime: Value(DateTime(2026, 1, 1).millisecondsSinceEpoch),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
    return id;
  }

  Future<Map<String, int>> countsByLabel() async {
    final dist = await repository.getEntryMethodDistribution();
    return {for (final s in dist) s.label: s.count};
  }

  test('a dive with no entry method inherits its site entry method', () async {
    await insertSite(id: 'beach', entryMethod: 'shore');
    await insertDive(id: 'own', entryMethod: 'shore');
    await insertDive(id: 'inherited', siteId: 'beach');

    expect(await countsByLabel(), {'shore': 2});
  });

  test("the dive's own entry method wins over the site's", () async {
    // The site says shore, but this diver was dropped in from a boat.
    await insertSite(id: 'beach', entryMethod: 'shore');
    await insertDive(id: 'by-boat', siteId: 'beach', entryMethod: 'boat');

    expect(await countsByLabel(), {'boat': 1});
  });

  test('an empty entry method string falls back to the site', () async {
    await insertSite(id: 'beach', entryMethod: 'shore');
    await insertDive(id: 'blank', siteId: 'beach', entryMethod: '');

    expect(await countsByLabel(), {'shore': 1});
  });

  test(
    'a dive with no entry method anywhere is counted as not recorded',
    () async {
      await insertSite(id: 'unknown-site');
      await insertDive(id: 'sited', siteId: 'unknown-site');
      await insertDive(id: 'siteless');
      await insertDive(id: 'known', entryMethod: 'giantStride');

      expect(await countsByLabel(), {
        'giantStride': 1,
        kNotRecordedDistributionKey: 2,
      });
    },
  );

  test('percentages are shares of every dive, recorded or not', () async {
    await insertSite(id: 'beach', entryMethod: 'shore');
    await insertDive(id: 'a', siteId: 'beach');
    await insertDive(id: 'b', entryMethod: 'shore');
    await insertDive(id: 'c', entryMethod: 'boat');
    await insertDive(id: 'd'); // no entry method at all

    final dist = await repository.getEntryMethodDistribution();
    final byLabel = {for (final s in dist) s.label: s};
    expect(byLabel['shore']!.percentage, closeTo(50, 0.001));
    expect(byLabel['boat']!.percentage, closeTo(25, 0.001));
    expect(
      byLabel[kNotRecordedDistributionKey]!.percentage,
      closeTo(25, 0.001),
    );
  });

  test('the not recorded bucket comes last even when it is largest', () async {
    await insertDive(id: 'a', entryMethod: 'boat');
    await insertDive(id: 'b');
    await insertDive(id: 'c');

    final dist = await repository.getEntryMethodDistribution();
    expect(dist.map((s) => s.label), ['boat', kNotRecordedDistributionKey]);
  });

  test(
    'an inherited entry method still honours the statistics scope',
    () async {
      await insertSite(id: 'beach', entryMethod: 'shore');
      await insertDive(id: 'counted', siteId: 'beach');
      await insertDive(
        id: 'excluded',
        siteId: 'beach',
        excludedFromStats: true,
      );

      expect(await countsByLabel(), {'shore': 1});
    },
  );

  test('the view filter still applies to an inherited entry method', () async {
    await insertSite(id: 'beach', entryMethod: 'shore');
    await insertSite(id: 'marina', entryMethod: 'boat');
    await insertDive(id: 'in-filter', siteId: 'beach');
    await insertDive(id: 'out-of-filter', siteId: 'marina');

    final dist = await repository.getEntryMethodDistribution(
      filter: const DiveFilterState(siteId: 'beach'),
    );
    expect({for (final s in dist) s.label: s.count}, {'shore': 1});
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
    await insertSite(id: 'beach', entryMethod: 'shore');
    await insertDive(id: 'mine', siteId: 'beach', diverId: 'diver-a');
    await insertDive(id: 'theirs', siteId: 'beach');

    final dist = await repository.getEntryMethodDistribution(
      diverId: 'diver-a',
    );
    expect({for (final s in dist) s.label: s.count}, {'shore': 1});
  });

  group('getEntryExitMethodPairsForSite', () {
    test('does not inherit the site methods it exists to suggest', () async {
      // This query feeds the site-assign suggestion, so folding the site's own
      // entry method back in would make the site suggest itself from a single
      // dive that never recorded one.
      await insertSite(id: 'beach', entryMethod: 'shore');
      await insertDive(id: 'no-entry', siteId: 'beach');

      final pairs = await repository.getEntryExitMethodPairsForSite(
        siteId: 'beach',
      );
      expect(pairs, isEmpty);
    });
  });
}
