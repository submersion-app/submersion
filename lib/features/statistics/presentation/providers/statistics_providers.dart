import 'dart:async';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

/// Repository provider
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository();
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

  if (sacUnit == SacUnit.litersPerMin) {
    return repository.getSacVolumeTrend(diverId: currentDiverId);
  } else {
    return repository.getSacPressureTrend(diverId: currentDiverId);
  }
});

final gasMixDistributionProvider = FutureProvider<List<DistributionSegment>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getGasMixDistribution(diverId: currentDiverId);
});

/// SAC records provider that uses the appropriate calculation based on sacUnit setting
final sacRecordsProvider =
    FutureProvider<({RankingItem? best, RankingItem? worst})>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final sacUnit = ref.watch(sacUnitProvider);

      if (sacUnit == SacUnit.litersPerMin) {
        return repository.getSacVolumeRecords(diverId: currentDiverId);
      } else {
        return repository.getSacPressureRecords(diverId: currentDiverId);
      }
    });

/// Average SAC by tank role (back gas, stage, deco, etc.)
final sacByTankRoleProvider = FutureProvider<Map<String, double>>((ref) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getSacByTankRole(diverId: currentDiverId);
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
  return repository.getDiveTypeDistribution(diverId: currentDiverId);
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
  return repository.getDepthProgressionTrend(diverId: currentDiverId);
});

final bottomTimeTrendProvider = FutureProvider<List<TrendDataPoint>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getBottomTimeTrend(diverId: currentDiverId);
});

final divesPerYearProvider = FutureProvider<List<({int year, int count})>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesPerYear(diverId: currentDiverId);
});

final cumulativeDiveCountProvider = FutureProvider<List<TrendDataPoint>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getCumulativeDiveCount(diverId: currentDiverId);
});

// ============================================================================
// Conditions & Environment Providers
// ============================================================================

final visibilityDistributionProvider =
    FutureProvider<List<DistributionSegment>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getVisibilityDistribution(diverId: currentDiverId);
    });

final waterTypeDistributionProvider = FutureProvider<List<DistributionSegment>>(
  (ref) async {
    _keepAliveWithExpiry(ref);
    final repository = ref.watch(statisticsRepositoryProvider);
    final currentDiverId = ref.watch(currentDiverIdProvider);
    return repository.getWaterTypeDistribution(diverId: currentDiverId);
  },
);

final entryMethodDistributionProvider =
    FutureProvider<List<DistributionSegment>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      return repository.getEntryMethodDistribution(diverId: currentDiverId);
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
    FutureProvider<List<({String range, int minutes})>>((ref) async {
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
