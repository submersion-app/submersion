import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('InsightsRepository error handling', () {
    late InsightsRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = InsightsRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('all methods return safe defaults on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      // Methods that return empty list
      expect(await repository.getSacVolumePerDive(), isEmpty);
      expect(await repository.getSacPressurePerDive(), isEmpty);
      expect(await repository.getGasMixDistribution(), isEmpty);
      expect(await repository.getDiveTypeDistribution(), isEmpty);
      expect(await repository.getDepthPerDive(), isEmpty);
      expect(await repository.getBottomTimePerDive(), isEmpty);
      expect(await repository.getDivesPerYear(), isEmpty);
      expect(await repository.getCumulativeDiveCount(), isEmpty);
      expect(
        await repository.getVisibilityDistribution(
          scale: VisibilityScale.tropical,
        ),
        isEmpty,
      );
      expect(await repository.getWaterTypeDistribution(), isEmpty);
      expect(await repository.getEntryMethodDistribution(), isEmpty);
      expect(await repository.getTemperatureByMonth(), isEmpty);
      expect(await repository.getWaterTempPerDive(), isEmpty);
      expect(
        await repository.getDivesByWaterTempBand(unit: TemperatureUnit.celsius),
        isEmpty,
      );
      expect(
        await repository.getWaterTempBandPerDive(unit: TemperatureUnit.celsius),
        isEmpty,
      );
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
      expect(await repository.getWeightPerDive(), isEmpty);
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
      expect(await repository.getSacVolumeByTankRole(), isEmpty);
      expect(await repository.getSacPressureByTankRole(), isEmpty);

      // Methods that return tuple defaults
      final soloVsBuddy = await repository.getSoloVsBuddyCount();
      expect(soloVsBuddy.solo, equals(0));
      expect(soloVsBuddy.buddy, equals(0));
      expect(soloVsBuddy.notRecorded, equals(0));

      final surfaceInterval = await repository.getSurfaceIntervalStats();
      expect(surfaceInterval.avgMinutes, isNull);
      expect(surfaceInterval.minMinutes, isNull);
      expect(surfaceInterval.maxMinutes, isNull);

      final ascentDescent = await repository.getAscentDescentRates();
      expect(ascentDescent.avgAscent, isNull);
      expect(ascentDescent.avgDescent, isNull);

      final decoStats = await repository.getDecoObligationStats();
      expect(decoStats.decoCount, equals(0));
      expect(decoStats.noDecoCount, equals(0));
      expect(decoStats.unknownCount, equals(0));

      // Methods that return empty entity
      final speciesStats = await repository.getSpeciesInsights(
        speciesId: 'test-id',
      );
      expect(speciesStats, equals(SpeciesInsights.empty));
    });
  });
}
