import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Regression guard for the final "filterable statistics" review (issue
/// #453): [dashboardQuickStatsProvider] backs the home dashboard, which has
/// no filter UI. Pre-fix, it inherited the Statistics tab's filter
/// transitively (via [topBuddiesProvider]/[countriesVisitedProvider]/
/// [uniqueSpeciesCountProvider], which are themselves correctly
/// filter-aware for the Statistics Social/Geographic/Marine-Life pages), so
/// an active Statistics filter would silently change the numbers shown on
/// the home tab.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertSite(String id, String country) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            country: Value(country),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    required String siteId,
    required double maxDepth,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            siteId: Value(siteId),
            maxDepth: Value(maxDepth),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertBuddy(String id) async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            name: Value('Buddy $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkBuddy(String diveId, String buddyId) async {
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion(
            id: Value('$diveId-$buddyId'),
            diveId: Value(diveId),
            buddyId: Value(buddyId),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> insertSighting(String diveId, String speciesId) async {
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion(
            id: Value(speciesId),
            commonName: Value(speciesId),
            category: const Value('fish'),
          ),
        );
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

  test('dashboardQuickStatsProvider ignores an active statisticsFilterProvider '
      'filter (issue #453 finding #2)', () async {
    // A minDepth:30 Statistics filter would keep only 'deep'. If any of
    // the three values bled the filter, activating it would drop
    // 'shallow's country/buddy-dive/species contribution.
    await insertSite('site-shallow', 'Wonderland');
    await insertSite('site-deep', 'Atlantis');
    await insertDive('shallow', siteId: 'site-shallow', maxDepth: 10);
    await insertDive('deep', siteId: 'site-deep', maxDepth: 40);
    await insertBuddy('buddy-1');
    await linkBuddy('shallow', 'buddy-1');
    await linkBuddy('deep', 'buddy-1');
    await insertSighting('shallow', 'clownfish');
    await insertSighting('deep', 'moray-eel');

    final noFilterContainer = makeContainer(const DiveFilterState());
    addTearDown(noFilterContainer.dispose);
    final unfiltered = await noFilterContainer.read(
      dashboardQuickStatsProvider.future,
    );

    // Sanity check: the seeded data gives the filter something to bite on
    // for all three values, so a false pass can't hide a real regression.
    expect(unfiltered.topBuddyDiveCount, 2);
    expect(unfiltered.countriesVisited, 2);
    expect(unfiltered.speciesDiscovered, 2);

    final activeFilterContainer = makeContainer(
      const DiveFilterState(minDepth: 30),
    );
    addTearDown(activeFilterContainer.dispose);
    final withActiveFilter = await activeFilterContainer.read(
      dashboardQuickStatsProvider.future,
    );

    const reason =
        'dashboardQuickStatsProvider must ignore statisticsFilterProvider; '
        'the home dashboard has no filter UI and must not be silently '
        'rescoped by the Statistics tab.';
    expect(
      withActiveFilter.topBuddyDiveCount,
      unfiltered.topBuddyDiveCount,
      reason: reason,
    );
    expect(
      withActiveFilter.topBuddyName,
      unfiltered.topBuddyName,
      reason: reason,
    );
    expect(
      withActiveFilter.countriesVisited,
      unfiltered.countriesVisited,
      reason: reason,
    );
    expect(
      withActiveFilter.speciesDiscovered,
      unfiltered.speciesDiscovered,
      reason: reason,
    );
  });
}
