import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/statistics_repository.dart';

/// Repository provider
final statisticsRepositoryProvider = Provider<StatisticsRepository>((ref) {
  return StatisticsRepository();
});

// ============================================================================
// Gas Statistics Providers
// ============================================================================

final sacTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getSacTrend(diverId: currentDiverId);
});

final gasMixDistributionProvider = FutureProvider<List<DistributionSegment>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getGasMixDistribution(diverId: currentDiverId);
});

final sacRecordsProvider = FutureProvider<({RankingItem? best, RankingItem? worst})>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getSacRecords(diverId: currentDiverId);
});

// ============================================================================
// Dive Progression Providers
// ============================================================================

final depthProgressionTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDepthProgressionTrend(diverId: currentDiverId);
});

final bottomTimeTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getBottomTimeTrend(diverId: currentDiverId);
});

final divesPerYearProvider = FutureProvider<List<({int year, int count})>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesPerYear(diverId: currentDiverId);
});

final cumulativeDiveCountProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getCumulativeDiveCount(diverId: currentDiverId);
});

// ============================================================================
// Conditions & Environment Providers
// ============================================================================

final visibilityDistributionProvider = FutureProvider<List<DistributionSegment>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getVisibilityDistribution(diverId: currentDiverId);
});

final waterTypeDistributionProvider = FutureProvider<List<DistributionSegment>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getWaterTypeDistribution(diverId: currentDiverId);
});

final entryMethodDistributionProvider = FutureProvider<List<DistributionSegment>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getEntryMethodDistribution(diverId: currentDiverId);
});

final temperatureByMonthProvider = FutureProvider<List<({int month, double? minTemp, double? avgTemp, double? maxTemp})>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getTemperatureByMonth(diverId: currentDiverId);
});

// ============================================================================
// Social & Buddies Providers
// ============================================================================

final topBuddiesProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getTopBuddies(diverId: currentDiverId);
});

final soloVsBuddyCountProvider = FutureProvider<({int solo, int buddy})>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getSoloVsBuddyCount(diverId: currentDiverId);
});

final topDiveCentersProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getTopDiveCenters(diverId: currentDiverId);
});

// ============================================================================
// Geographic Providers
// ============================================================================

final countriesVisitedProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getCountriesVisited(diverId: currentDiverId);
});

final regionsExploredProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getRegionsExplored(diverId: currentDiverId);
});

final divesPerTripProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesPerTrip(diverId: currentDiverId);
});

// ============================================================================
// Marine Life Providers
// ============================================================================

final uniqueSpeciesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getUniqueSpeciesCount(diverId: currentDiverId);
});

final mostCommonSightingsProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getMostCommonSightings(diverId: currentDiverId);
});

final bestSitesForMarineLifeProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getBestSitesForMarineLife(diverId: currentDiverId);
});

// ============================================================================
// Time Pattern Providers
// ============================================================================

final divesByDayOfWeekProvider = FutureProvider<List<({int dayOfWeek, int count})>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesByDayOfWeek(diverId: currentDiverId);
});

final divesByTimeOfDayProvider = FutureProvider<List<DistributionSegment>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesByTimeOfDay(diverId: currentDiverId);
});

final divesBySeasonProvider = FutureProvider<List<({int month, int count})>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDivesBySeason(diverId: currentDiverId);
});

final surfaceIntervalStatsProvider = FutureProvider<({double? avgMinutes, double? minMinutes, double? maxMinutes})>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getSurfaceIntervalStats(diverId: currentDiverId);
});

// ============================================================================
// Equipment Providers
// ============================================================================

final mostUsedGearProvider = FutureProvider<List<RankingItem>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getMostUsedGear(diverId: currentDiverId);
});

final weightTrendProvider = FutureProvider<List<TrendDataPoint>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getWeightTrend(diverId: currentDiverId);
});

// ============================================================================
// Profile Analysis Providers
// ============================================================================

final ascentDescentRatesProvider = FutureProvider<({double? avgAscent, double? avgDescent})>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getAscentDescentRates(diverId: currentDiverId);
});

final timeAtDepthRangesProvider = FutureProvider<List<({String range, int minutes})>>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getTimeAtDepthRanges(diverId: currentDiverId);
});

final decoObligationStatsProvider = FutureProvider<({int decoCount, int totalCount})>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  return repository.getDecoObligationStats(diverId: currentDiverId);
});
