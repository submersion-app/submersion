import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_dive_statistics.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Direct coverage for [siteDiveStatisticsProvider] (submersion-app/submersion#1018,
/// #1038). Widget tests for the site detail card override this provider with
/// a fixture, so its own body - the diver gate and the dives-tick
/// subscription - never runs there.
void main() {
  late db.AppDatabase database;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    database = DatabaseService.instance.database;

    await database
        .into(database.divers)
        .insert(
          db.DiversCompanion.insert(
            id: 'me',
            name: 'Me',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await database
        .into(database.diveSites)
        .insert(
          db.DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Blue Hole',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  ProviderContainer buildContainer({String? diverId = 'me'}) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
        // statisticsRepositoryProvider watches the gas model (issue #828),
        // which otherwise builds the real SettingsNotifier and leaves its
        // async load running past this container's disposal.
        gasModelProvider.overrideWith((ref) => GasModel.real),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> insertDive({
    required String id,
    String siteId = 'site-1',
    String? diverId = 'me',
    DateTime? diveDateTime,
    double? maxDepth,
    int? runtime,
  }) async {
    await database
        .into(database.dives)
        .insert(
          db.DivesCompanion.insert(
            id: id,
            diveDateTime:
                (diveDateTime ?? DateTime(2026, 1, 1)).millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
            diverId: Value(diverId),
            siteId: Value(siteId),
            maxDepth: Value(maxDepth),
            runtime: Value(runtime),
          ),
        );
  }

  test(
    'returns SiteDiveStatistics.empty when there is no current diver',
    () async {
      await insertDive(id: 'd1', maxDepth: 20, runtime: 1800);

      final container = buildContainer(diverId: null);
      final stats = await container.read(
        siteDiveStatisticsProvider('site-1').future,
      );

      expect(stats, equals(SiteDiveStatistics.empty));
    },
  );

  test('aggregates the dives logged at the requested site for the current '
      'diver', () async {
    await insertDive(id: 'd1', maxDepth: 10, runtime: 1200);
    await insertDive(id: 'd2', maxDepth: 20, runtime: 2400);

    final container = buildContainer();
    final stats = await container.read(
      siteDiveStatisticsProvider('site-1').future,
    );

    expect(stats.diveCount, equals(2));
    expect(stats.maxDepthReached, equals(20));
    expect(stats.minDepthReached, equals(10));
  });

  test(
    'scopes to the requested diver, excluding another diver\'s dives',
    () async {
      await database
          .into(database.divers)
          .insert(
            db.DiversCompanion.insert(
              id: 'other',
              name: 'Other Diver',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await insertDive(id: 'mine', maxDepth: 10, runtime: 1200);
      await insertDive(
        id: 'theirs',
        diverId: 'other',
        maxDepth: 99,
        runtime: 9999,
      );

      final container = buildContainer();
      final stats = await container.read(
        siteDiveStatisticsProvider('site-1').future,
      );

      expect(stats.diveCount, equals(1));
      expect(stats.maxDepthReached, equals(10));
    },
  );

  test('returns empty stats for a site with no matching dives', () async {
    final container = buildContainer();
    final stats = await container.read(
      siteDiveStatisticsProvider('site-1').future,
    );

    expect(stats, equals(SiteDiveStatistics.empty));
  });

  test('auto-refreshes after a dive is written directly to the DB (sync '
      'scenario), mirroring the watchDivesChanges tick used elsewhere '
      '(e.g. sitesWithCountsProvider)', () async {
    final container = buildContainer();

    // An active listener keeps the provider (and its dives-table-change
    // subscription) alive, mirroring a widget watching the stats card.
    final sub = container.listen(
      siteDiveStatisticsProvider('site-1'),
      (_, _) {},
    );
    addTearDown(sub.close);

    final initial = await container.read(
      siteDiveStatisticsProvider('site-1').future,
    );
    expect(initial.diveCount, equals(0));

    await insertDive(id: 'sync-dive', maxDepth: 15, runtime: 1500);

    var diveCount = 0;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final stats = await container.read(
        siteDiveStatisticsProvider('site-1').future,
      );
      diveCount = stats.diveCount;
      if (diveCount >= 1) break;
    }

    expect(
      diveCount,
      equals(1),
      reason:
          'siteDiveStatisticsProvider should auto-refresh after a direct '
          'dives-table write without any manual invalidation',
    );
  });
}
