import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1930: a failed query must reach the caller. Returning a safe
/// default instead let a provider complete with data, so each card showed its
/// empty state ("No data available") and never its error state, and a broken
/// query looked exactly like a diver with no dives.
void main() {
  group('InsightsRepository error handling', () {
    late InsightsRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = InsightsRepository();
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    final calls = <String, Future<Object?> Function(InsightsRepository r)>{
      'getSacVolumePerDive': (r) => r.getSacVolumePerDive(),
      'getSacPressurePerDive': (r) => r.getSacPressurePerDive(),
      'getGasMixDistribution': (r) => r.getGasMixDistribution(),
      'getSacVolumeRecords': (r) => r.getSacVolumeRecords(),
      'getSacPressureRecords': (r) => r.getSacPressureRecords(),
      'getSacVolumeByTankRole': (r) => r.getSacVolumeByTankRole(),
      'getSacPressureByTankRole': (r) => r.getSacPressureByTankRole(),
      'getDiveTypeDistribution': (r) => r.getDiveTypeDistribution(),
      'getDepthPerDive': (r) => r.getDepthPerDive(),
      'getBottomTimePerDive': (r) => r.getBottomTimePerDive(),
      'getDivesPerYear': (r) => r.getDivesPerYear(),
      'getYearStats': (r) => r.getYearStats(2026),
      'getDivesBySuitThickness': (r) => r.getDivesBySuitThickness(),
      'getCumulativeDiveCount': (r) => r.getCumulativeDiveCount(),
      'getVisibilityDistribution': (r) =>
          r.getVisibilityDistribution(scale: VisibilityScale.tropical),
      'getWaterTypeDistribution': (r) => r.getWaterTypeDistribution(),
      'getSiteTypeDistribution': (r) => r.getSiteTypeDistribution(),
      'getEntryMethodDistribution': (r) => r.getEntryMethodDistribution(),
      'getEntryExitMethodPairsForSite': (r) =>
          r.getEntryExitMethodPairsForSite(siteId: 'site-1'),
      'getSiteDiveStatistics': (r) => r.getSiteDiveStatistics(siteId: 'site-1'),
      'getTemperatureByMonth': (r) => r.getTemperatureByMonth(),
      'getDivesByWaterTempBand': (r) =>
          r.getDivesByWaterTempBand(unit: TemperatureUnit.celsius),
      'getWaterTempBandPerDive': (r) =>
          r.getWaterTempBandPerDive(unit: TemperatureUnit.celsius),
      'getTopBuddies': (r) => r.getTopBuddies(),
      'getSoloVsBuddyCount': (r) => r.getSoloVsBuddyCount(),
      'getTopDiveCenters': (r) => r.getTopDiveCenters(),
      'getCountriesVisited': (r) => r.getCountriesVisited(),
      'getRegionsExplored': (r) => r.getRegionsExplored(),
      'getDivesPerTrip': (r) => r.getDivesPerTrip(),
      'getUniqueSpeciesCount': (r) => r.getUniqueSpeciesCount(),
      'getMostCommonSightings': (r) => r.getMostCommonSightings(),
      'getBestSitesForMarineLife': (r) => r.getBestSitesForMarineLife(),
      'getSpeciesInsights': (r) => r.getSpeciesInsights(speciesId: 'test-id'),
      'getDivesByDayOfWeek': (r) => r.getDivesByDayOfWeek(),
      'getDivesByTimeOfDay': (r) => r.getDivesByTimeOfDay(),
      'getDivesBySeason': (r) => r.getDivesBySeason(),
      'getSurfaceIntervalStats': (r) => r.getSurfaceIntervalStats(),
      'getMostUsedGear': (r) => r.getMostUsedGear(),
      'getWeightPerDive': (r) => r.getWeightPerDive(),
      'getWaterTempPerDive': (r) => r.getWaterTempPerDive(),
      'getAscentDescentRates': (r) => r.getAscentDescentRates(),
      'getTimeAtDepthRanges': (r) => r.getTimeAtDepthRanges(),
      'scanRecordedDecoSignals': (r) => r.scanRecordedDecoSignals(),
      'getDecoObligationStats': (r) => r.getDecoObligationStats(),
      'countExcludedDives': (r) => r.countExcludedDives(),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      test('$name rethrows a database error instead of a safe default', () {
        // The original error, not a wrapper: the logger records it and the
        // provider surfaces it unchanged.
        expect(call(repository), throwsStateError);
      });
    }
  });
}
