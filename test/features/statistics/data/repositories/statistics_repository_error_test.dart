import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('StatisticsRepository error handling', () {
    late StatisticsRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = StatisticsRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('all methods return safe defaults on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      // Methods that return empty list
      expect(await repository.getSacVolumeTrend(), isEmpty);
      expect(await repository.getSacPressureTrend(), isEmpty);
      expect(await repository.getGasMixDistribution(), isEmpty);
      expect(await repository.getDiveTypeDistribution(), isEmpty);
      expect(await repository.getDepthProgressionTrend(), isEmpty);
      expect(await repository.getBottomTimeTrend(), isEmpty);
      expect(await repository.getDivesPerYear(), isEmpty);
      expect(await repository.getCumulativeDiveCount(), isEmpty);
      expect(await repository.getVisibilityDistribution(), isEmpty);
      expect(await repository.getWaterTypeDistribution(), isEmpty);
      expect(await repository.getEntryMethodDistribution(), isEmpty);
      expect(await repository.getTemperatureByMonth(), isEmpty);
      expect(await repository.getTopBuddies(), isEmpty);
      expect(await repository.getTopDiveCenters(), isEmpty);
      expect(await repository.getCountriesVisited(), isEmpty);
      expect(await repository.getRegionsExplored(), isEmpty);
      expect(await repository.getDivesPerTrip(), isEmpty);
      expect(await repository.getMostCommonSightings(), isEmpty);
      expect(await repository.getBestSitesForMarineLife(), isEmpty);
      expect(await repository.getDivesByDayOfWeek(), isEmpty);
      expect(await repository.getDivesByTimeOfDay(), isEmpty);
      expect(await repository.getDivesBySeason(), isEmpty);
      expect(await repository.getMostUsedGear(), isEmpty);
      expect(await repository.getWeightTrend(), isEmpty);
      expect(await repository.getTimeAtDepthRanges(), isEmpty);

      // Methods that return zero
      expect(await repository.getUniqueSpeciesCount(), equals(0));

      // Methods that return record defaults
      final sacVolumeRecords = await repository.getSacVolumeRecords();
      expect(sacVolumeRecords.best, isNull);
      expect(sacVolumeRecords.worst, isNull);

      final sacPressureRecords = await repository.getSacPressureRecords();
      expect(sacPressureRecords.best, isNull);
      expect(sacPressureRecords.worst, isNull);

      // Methods that return empty map
      expect(await repository.getSacByTankRole(), isEmpty);

      // Methods that return tuple defaults
      final soloVsBuddy = await repository.getSoloVsBuddyCount();
      expect(soloVsBuddy.solo, equals(0));
      expect(soloVsBuddy.buddy, equals(0));

      final surfaceInterval = await repository.getSurfaceIntervalStats();
      expect(surfaceInterval.avgMinutes, isNull);
      expect(surfaceInterval.minMinutes, isNull);
      expect(surfaceInterval.maxMinutes, isNull);

      final ascentDescent = await repository.getAscentDescentRates();
      expect(ascentDescent.avgAscent, isNull);
      expect(ascentDescent.avgDescent, isNull);

      final decoStats = await repository.getDecoObligationStats();
      expect(decoStats.decoCount, equals(0));
      expect(decoStats.totalCount, equals(0));

      // Methods that return empty entity
      final speciesStats = await repository.getSpeciesStatistics(
        speciesId: 'test-id',
      );
      expect(speciesStats, equals(SpeciesStatistics.empty));
    });
  });
}
