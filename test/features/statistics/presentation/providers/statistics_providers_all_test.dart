import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Smoke coverage for every Statistics-tab provider (issue #453). Each provider
/// is a thin delegate that reads the repository + current diver + active
/// [statisticsFilterProvider] and forwards to a single repository aggregate.
/// Reading each `.future` against an empty in-memory database exercises the
/// provider body (and the shared `_keepAliveWithExpiry` cache helper) and
/// asserts the whole surface resolves without throwing.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<ProviderContainer> makeContainer({
    DiveFilterState filter = const DiveFilterState(),
    SacUnit? sacUnit,
  }) async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(
      overrides: [
        ...overrides,
        statisticsFilterProvider.overrideWith((ref) => filter),
        if (sacUnit != null) sacUnitProvider.overrideWithValue(sacUnit),
      ].cast(),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('all Statistics providers resolve against an empty database', () async {
    final container = await makeContainer();

    // Every non-family Statistics provider is read here. On an empty database
    // each returns an empty/zero aggregate, but crucially the provider body
    // and its repository call both execute.
    expect(
      (await container.read(filteredDiveStatisticsProvider.future)).totalDives,
      0,
    );
    expect(await container.read(gasMixDistributionProvider.future), isEmpty);
    expect(await container.read(diveTypeDistributionProvider.future), isEmpty);
    expect(await container.read(depthProgressionTrendProvider.future), isEmpty);
    expect(await container.read(bottomTimeTrendProvider.future), isEmpty);
    expect(await container.read(divesPerYearProvider.future), isEmpty);
    expect(await container.read(cumulativeDiveCountProvider.future), isEmpty);
    expect(
      await container.read(visibilityDistributionProvider.future),
      isEmpty,
    );
    expect(await container.read(waterTypeDistributionProvider.future), isEmpty);
    expect(
      await container.read(entryMethodDistributionProvider.future),
      isEmpty,
    );
    expect(await container.read(temperatureByMonthProvider.future), isEmpty);
    expect(await container.read(topBuddiesProvider.future), isEmpty);
    final soloVsBuddy = await container.read(soloVsBuddyCountProvider.future);
    expect(soloVsBuddy.solo, 0);
    expect(soloVsBuddy.buddy, 0);
    expect(await container.read(topDiveCentersProvider.future), isEmpty);
    expect(await container.read(countriesVisitedProvider.future), isEmpty);
    expect(await container.read(regionsExploredProvider.future), isEmpty);
    expect(await container.read(divesPerTripProvider.future), isEmpty);
    expect(await container.read(uniqueSpeciesCountProvider.future), 0);
    expect(await container.read(mostCommonSightingsProvider.future), isEmpty);
    expect(
      await container.read(bestSitesForMarineLifeProvider.future),
      isEmpty,
    );
    expect(await container.read(divesByDayOfWeekProvider.future), isEmpty);
    expect(await container.read(divesByTimeOfDayProvider.future), isEmpty);
    expect(await container.read(divesBySeasonProvider.future), isEmpty);
    final surfaceInterval = await container.read(
      surfaceIntervalStatsProvider.future,
    );
    expect(surfaceInterval.avgMinutes, isNull);
    expect(await container.read(mostUsedGearProvider.future), isEmpty);
    expect(await container.read(weightTrendProvider.future), isEmpty);
    final ascentDescent = await container.read(
      ascentDescentRatesProvider.future,
    );
    expect(ascentDescent.avgAscent, isNull);
    expect(await container.read(timeAtDepthRangesProvider.future), isEmpty);
    expect(await container.read(divesBySuitThicknessProvider.future), isEmpty);
    final deco = await container.read(decoObligationStatsProvider.future);
    expect(deco.totalCount, 0);
  });

  test('SAC providers use the pressure-per-minute branch by default', () async {
    // MockSettingsNotifier defaults to SacUnit.pressurePerMin, so the else
    // branch of each SAC provider runs here.
    final container = await makeContainer();
    expect(await container.read(sacTrendProvider.future), isEmpty);
    final records = await container.read(sacRecordsProvider.future);
    expect(records.best, isNull);
    expect(await container.read(sacByTankRoleProvider.future), isEmpty);
  });

  test(
    'SAC providers use the liters-per-minute branch when configured',
    () async {
      final container = await makeContainer(sacUnit: SacUnit.litersPerMin);
      expect(await container.read(sacTrendProvider.future), isEmpty);
      final records = await container.read(sacRecordsProvider.future);
      expect(records.best, isNull);
      expect(await container.read(sacByTankRoleProvider.future), isEmpty);
    },
  );

  test('an active filter still resolves every aggregate', () async {
    // Drives the filter-threading path (non-empty DiveFilterState) through the
    // same providers so the filtered SQL branch is exercised too.
    final container = await makeContainer(
      filter: const DiveFilterState(favoritesOnly: true, minDepth: 5),
    );
    expect(
      (await container.read(filteredDiveStatisticsProvider.future)).totalDives,
      0,
    );
    expect(await container.read(topBuddiesProvider.future), isEmpty);
    expect(await container.read(divesPerYearProvider.future), isEmpty);
  });
}
