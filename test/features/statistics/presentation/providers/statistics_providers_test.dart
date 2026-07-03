import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Regression guard for the final "filterable statistics" review (issue
/// #453): [speciesStatisticsProvider]'s only consumer is the Marine Life
/// species-detail page (route `/species/:id`), which has no filter UI and is
/// not a Statistics-tab surface. If the provider watched
/// [statisticsFilterProvider], an active Statistics-tab filter would
/// silently rescope that page's per-species stats.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id, {double? maxDepth}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            maxDepth: Value(maxDepth),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSpecies(String id) async {
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion(
            id: Value(id),
            commonName: Value(id),
            category: const Value('fish'),
          ),
        );
  }

  Future<void> insertSighting(String diveId, String speciesId) async {
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: '$diveId-$speciesId',
            diveId: diveId,
            speciesId: speciesId,
          ),
        );
  }

  ProviderContainer makeContainer(DiveFilterState filter) => ProviderContainer(
    overrides: [
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      statisticsFilterProvider.overrideWith((ref) => filter),
    ],
  );

  test('speciesStatisticsProvider ignores an active statisticsFilterProvider '
      'filter (issue #453 finding #1)', () async {
    await insertSpecies('clownfish');
    // A minDepth:30 Statistics filter would keep only 'deep'. If the
    // provider were filter-aware, activating it would drop 'shallow's
    // sighting from the result.
    await insertDive('shallow', maxDepth: 10);
    await insertDive('deep', maxDepth: 40);
    await insertSighting('shallow', 'clownfish');
    await insertSighting('deep', 'clownfish');

    final noFilterContainer = makeContainer(const DiveFilterState());
    addTearDown(noFilterContainer.dispose);
    final unfiltered = await noFilterContainer.read(
      speciesStatisticsProvider('clownfish').future,
    );

    // Sanity check: the seeded data actually gives a filter something to
    // bite on, so a false pass (both reads trivially equal because
    // filtering never kicked in either way) can't hide a real regression.
    expect(unfiltered.diveCount, 2);
    expect(unfiltered.totalSightings, 2);

    final activeFilterContainer = makeContainer(
      const DiveFilterState(minDepth: 30),
    );
    addTearDown(activeFilterContainer.dispose);
    final withActiveFilter = await activeFilterContainer.read(
      speciesStatisticsProvider('clownfish').future,
    );

    const reason =
        'speciesStatisticsProvider must ignore statisticsFilterProvider; '
        'a filtered result here would mean the species-detail page (which '
        'has no filter UI) is silently scoped by the Statistics tab.';
    expect(
      withActiveFilter.totalSightings,
      unfiltered.totalSightings,
      reason: reason,
    );
    expect(withActiveFilter.diveCount, unfiltered.diveCount, reason: reason);
    expect(
      withActiveFilter.minDepthMeters,
      unfiltered.minDepthMeters,
      reason: reason,
    );
    expect(
      withActiveFilter.maxDepthMeters,
      unfiltered.maxDepthMeters,
      reason: reason,
    );
  });
}
