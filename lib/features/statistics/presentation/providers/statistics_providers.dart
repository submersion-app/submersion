import 'dart:async';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/data/services/deco_classification_service.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';

/// Repository provider.
///
/// Watches the gas model so flipping the preference rebuilds the repository
/// and refreshes every gas statistic downstream of it (issue #828).
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository(gasModel: ref.watch(gasModelProvider));
});

/// Overview totals scoped by the Statistics filter. Kept separate from
/// diveStatisticsProvider so the home dashboard and dive-log summary (which
/// read diveStatisticsProvider) stay unfiltered.
final filteredDiveStatisticsProvider = FutureProvider<DiveStatistics>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return repository.getStatistics(diverId: currentDiverId, filter: filter);
});

/// Personal records (superlatives) scoped by the Statistics filter.
///
/// Split from diveRecordsProvider for the same reason
/// [filteredDiveStatisticsProvider] is split from diveStatisticsProvider: the
/// dive-log summary widget reads the unfiltered one and has no filter UI, so
/// the Statistics tab's scope must not reach it. Issue #1028: before this
/// split, the Statistics tab's records were the only panel on the page that
/// ignored the filter.
///
/// Takes the same dives tick as its unfiltered sibling (issue #217): a merge,
/// a bulk delete, or a sync pull rewrites the superlatives without going
/// through any notifier.
final filteredDiveRecordsProvider = FutureProvider<DiveRecords>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  return repository.getRecords(diverId: currentDiverId, filter: filter);
});

/// Adds keepAlive with a 5-minute expiry and subscribes to the statistics
/// change tick, so all stats providers stay cached across navigations but
/// refresh whenever any table they read is written.
///
/// This used to watch `statisticsVersionProvider`, a counter incremented from
/// exactly one line in the app, inside `PaginatedDiveListNotifier`. Merge,
/// consolidate, import, and sync pulls never bumped it, so the cache this doc
/// comment claimed was reactive stayed stale for up to five minutes: merge two
/// dives, open Statistics, and every chart still counted the merged-away dive
/// (issue #974).
void _keepAliveWithExpiry(Ref ref) {
  ref.invalidateSelfWhen(
    ref.watch(statisticsRepositoryProvider).watchStatisticsChanges(),
  );
  // Keep alive for 5 minutes after last listener detaches
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
}

// ============================================================================
// Gas Statistics Providers
// ============================================================================

/// SAC trend provider that uses the appropriate calculation based on sacUnit setting
final sacTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final sacUnit = ref.watch(sacUnitProvider);
  final filter = ref.watch(statisticsFilterProvider);

  if (sacUnit == SacUnit.litersPerMin) {
    return repository.getSacVolumeTrend(
      diverId: currentDiverId,
      filter: filter,
    );
  } else {
    return repository.getSacPressureTrend(
      diverId: currentDiverId,
      filter: filter,
    );
  }
});

final gasMixDistributionProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getGasMixDistribution(
    diverId: currentDiverId,
    filter: filter,
  );
});

/// SAC records provider that uses the appropriate calculation based on sacUnit setting
final sacRecordsProvider =
    FutureProvider<({RankingItem? best, RankingItem? worst})>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final sacUnit = ref.watch(sacUnitProvider);
      final filter = ref.watch(statisticsFilterProvider);

      if (sacUnit == SacUnit.litersPerMin) {
        return repository.getSacVolumeRecords(
          diverId: currentDiverId,
          filter: filter,
        );
      } else {
        return repository.getSacPressureRecords(
          diverId: currentDiverId,
          filter: filter,
        );
      }
    });

/// Average SAC by tank role (back gas, stage, deco, etc.)
final sacByTankRoleProvider = FutureProvider<Map<String, double>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final sacUnit = ref.watch(sacUnitProvider);
  final filter = ref.watch(statisticsFilterProvider);

  if (sacUnit == SacUnit.litersPerMin) {
    return repository.getSacVolumeByTankRole(
      diverId: currentDiverId,
      filter: filter,
    );
  } else {
    return repository.getSacPressureByTankRole(
      diverId: currentDiverId,
      filter: filter,
    );
  }
});

// ============================================================================
// Dive Type Distribution Provider
// ============================================================================

final diveTypeDistributionProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getDiveTypeDistribution(
    diverId: currentDiverId,
    filter: filter,
  );
});

// ============================================================================
// Dive Progression Providers
// ============================================================================

final depthProgressionTrendProvider = FutureProvider<List<TrendDataPoint>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getDepthProgressionTrend(
    diverId: currentDiverId,
    filter: filter,
  );
});

final bottomTimeTrendProvider = FutureProvider<List<TrendDataPoint>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getBottomTimeTrend(diverId: currentDiverId, filter: filter);
});

final divesPerYearProvider = FutureProvider<List<({int year, int count})>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getDivesPerYear(diverId: currentDiverId, filter: filter);
});

final divesBySuitThicknessProvider =
    FutureProvider<List<({double mm, int count})>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getDivesBySuitThickness(
        diverId: currentDiverId,
        filter: filter,
      );
    });

final cumulativeDiveCountProvider = FutureProvider<List<TrendDataPoint>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getCumulativeDiveCount(
    diverId: currentDiverId,
    filter: filter,
  );
});

// ============================================================================
// Conditions & Environment Providers
// ============================================================================

final visibilityDistributionProvider =
    FutureProvider<List<DistributionSegment>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      // Watched, not read: changing the calibration must re-bin the chart.
      final scale = ref.watch(
        settingsProvider.select((s) => s.visibilityScale),
      );
      return repository.getVisibilityDistribution(
        scale: scale,
        diverId: currentDiverId,
        filter: filter,
      );
    });

final waterTypeDistributionProvider = FutureProvider<List<DistributionSegment>>(
  (ref) async {
    _keepAliveWithExpiry(ref);
    final repository = ref.watch(statisticsRepositoryProvider);
    final currentDiverId = ref.watch(currentDiverIdProvider);
    final filter = ref.watch(statisticsFilterProvider);
    return repository.getWaterTypeDistribution(
      diverId: currentDiverId,
      filter: filter,
    );
  },
);

final entryMethodDistributionProvider =
    FutureProvider<List<DistributionSegment>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getEntryMethodDistribution(
        diverId: currentDiverId,
        filter: filter,
      );
    });

final temperatureByMonthProvider =
    FutureProvider<
      List<({int month, double? minTemp, double? avgTemp, double? maxTemp})>
    >((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getTemperatureByMonth(
        diverId: currentDiverId,
        filter: filter,
      );
    });

// ============================================================================
// Social & Buddies Providers
// ============================================================================

final topBuddiesProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getTopBuddies(diverId: currentDiverId, filter: filter);
});

final soloVsBuddyCountProvider = FutureProvider<({int solo, int buddy})>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getSoloVsBuddyCount(
    diverId: currentDiverId,
    filter: filter,
  );
});

final topDiveCentersProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getTopDiveCenters(diverId: currentDiverId, filter: filter);
});

// ============================================================================
// Geographic Providers
// ============================================================================

final countriesVisitedProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getCountriesVisited(
    diverId: currentDiverId,
    filter: filter,
  );
});

final regionsExploredProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getRegionsExplored(diverId: currentDiverId, filter: filter);
});

final divesPerTripProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getDivesPerTrip(diverId: currentDiverId, filter: filter);
});

// ============================================================================
// Marine Life Providers
// ============================================================================

final uniqueSpeciesCountProvider = FutureProvider<int>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getUniqueSpeciesCount(
    diverId: currentDiverId,
    filter: filter,
  );
});

final mostCommonSightingsProvider = FutureProvider<List<RankingItem>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getMostCommonSightings(
    diverId: currentDiverId,
    filter: filter,
  );
});

final bestSitesForMarineLifeProvider = FutureProvider<List<RankingItem>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getBestSitesForMarineLife(
    diverId: currentDiverId,
    filter: filter,
  );
});

/// Per-species statistics (sightings, depth range, sites, first/last seen).
///
/// Deliberately UNFILTERED: its only consumer is the Marine Life
/// species-detail page (route `/species/:id`), which is not a Statistics-tab
/// surface and has no filter UI. Watching [statisticsFilterProvider] here
/// would silently scope each species' detail stats to whatever filter is
/// currently active on the (unrelated) Statistics tab.
final speciesStatisticsProvider =
    FutureProvider.family<SpeciesStatistics, String>((ref, speciesId) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getSpeciesStatistics(
        speciesId: speciesId,
        diverId: currentDiverId,
      );
    });

// ============================================================================
// Time Pattern Providers
// ============================================================================

final divesByDayOfWeekProvider =
    FutureProvider<List<({int dayOfWeek, int count})>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getDivesByDayOfWeek(
        diverId: currentDiverId,
        filter: filter,
      );
    });

final divesByTimeOfDayProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getDivesByTimeOfDay(
    diverId: currentDiverId,
    filter: filter,
  );
});

final divesBySeasonProvider = FutureProvider<List<({int month, int count})>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getDivesBySeason(diverId: currentDiverId, filter: filter);
});

final surfaceIntervalStatsProvider =
    FutureProvider<
      ({double? avgMinutes, double? minMinutes, double? maxMinutes})
    >((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getSurfaceIntervalStats(
        diverId: currentDiverId,
        filter: filter,
      );
    });

// ============================================================================
// Equipment Providers
// ============================================================================

final mostUsedGearProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getMostUsedGear(diverId: currentDiverId, filter: filter);
});

final weightTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getWeightTrend(diverId: currentDiverId, filter: filter);
});

// ============================================================================
// Profile Analysis Providers
// ============================================================================

final ascentDescentRatesProvider =
    FutureProvider<({double? avgAscent, double? avgDescent})>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getAscentDescentRates(
        diverId: currentDiverId,
        filter: filter,
      );
    });

final timeAtDepthRangesProvider =
    FutureProvider<List<({int lowerDepth, int? upperDepth, int minutes})>>((
      ref,
    ) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getTimeAtDepthRanges(
        diverId: currentDiverId,
        filter: filter,
      );
    });

/// Deco obligation counts: recorded signals first, the app's own analysis as
/// the fallback (#623).
///
/// A dive whose source recorded no deco columns is classified by the same
/// analysis that draws the DECO badge on its detail page, so the card and the
/// dive can no longer disagree. Dives with no profile at all stay unknown and
/// are excluded from the rate rather than counted as no-deco.
final decoObligationStatsProvider =
    FutureProvider<({int decoCount, int noDecoCount, int unknownCount})>((
      ref,
    ) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);

      final scan = await repository.scanRecordedDecoSignals(
        diverId: currentDiverId,
        filter: filter,
      );

      var deco = scan.recordedDeco.length;
      var noDeco = scan.recordedNoDeco.length;
      var unknown = scan.noProfile.length;

      final computed = await const DecoClassificationService().classify(
        ref,
        scan.needsCompute,
      );
      for (final diveId in scan.needsCompute.keys) {
        final hadDeco = computed[diveId];
        if (hadDeco == null) {
          unknown++;
        } else if (hadDeco) {
          deco++;
        } else {
          noDeco++;
        }
      }

      return (decoCount: deco, noDecoCount: noDeco, unknownCount: unknown);
    });
