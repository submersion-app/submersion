import 'dart:async';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';

/// Repository provider
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository();
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

/// Adds keepAlive with a 5-minute expiry and watches the statistics version
/// so all stats providers stay cached across navigations but refresh when
/// dives are mutated.
void _keepAliveWithExpiry(Ref ref) {
  // Watch version so we refetch when dives change
  ref.watch(statisticsVersionProvider);
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
      return repository.getVisibilityDistribution(
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
      return repository.getTemperatureByMonth(diverId: currentDiverId);
    });

// ============================================================================
// Social & Buddies Providers
// ============================================================================

final topBuddiesProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getTopBuddies(diverId: currentDiverId);
});

final soloVsBuddyCountProvider = FutureProvider<({int solo, int buddy})>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getSoloVsBuddyCount(diverId: currentDiverId);
});

final topDiveCentersProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getTopDiveCenters(diverId: currentDiverId);
});

// ============================================================================
// Geographic Providers
// ============================================================================

final countriesVisitedProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getCountriesVisited(diverId: currentDiverId);
});

final regionsExploredProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getRegionsExplored(diverId: currentDiverId);
});

final divesPerTripProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesPerTrip(diverId: currentDiverId);
});

// ============================================================================
// Marine Life Providers
// ============================================================================

final uniqueSpeciesCountProvider = FutureProvider<int>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getUniqueSpeciesCount(diverId: currentDiverId);
});

final mostCommonSightingsProvider = FutureProvider<List<RankingItem>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getMostCommonSightings(diverId: currentDiverId);
});

final bestSitesForMarineLifeProvider = FutureProvider<List<RankingItem>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getBestSitesForMarineLife(diverId: currentDiverId);
});

/// Per-species statistics (sightings, depth range, sites, first/last seen)
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
      return repository.getDivesByDayOfWeek(diverId: currentDiverId);
    });

final divesByTimeOfDayProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesByTimeOfDay(diverId: currentDiverId);
});

final divesBySeasonProvider = FutureProvider<List<({int month, int count})>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesBySeason(diverId: currentDiverId);
});

final surfaceIntervalStatsProvider =
    FutureProvider<
      ({double? avgMinutes, double? minMinutes, double? maxMinutes})
    >((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getSurfaceIntervalStats(diverId: currentDiverId);
    });

// ============================================================================
// Equipment Providers
// ============================================================================

final mostUsedGearProvider = FutureProvider<List<RankingItem>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getMostUsedGear(diverId: currentDiverId);
});

final weightTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getWeightTrend(diverId: currentDiverId);
});

// ============================================================================
// Profile Analysis Providers
// ============================================================================

final ascentDescentRatesProvider =
    FutureProvider<({double? avgAscent, double? avgDescent})>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getAscentDescentRates(diverId: currentDiverId);
    });

final timeAtDepthRangesProvider =
    FutureProvider<List<({int lowerDepth, int? upperDepth, int minutes})>>((
      ref,
    ) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getTimeAtDepthRanges(diverId: currentDiverId);
    });

final decoObligationStatsProvider =
    FutureProvider<({int decoCount, int totalCount})>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getDecoObligationStats(diverId: currentDiverId);
    });
