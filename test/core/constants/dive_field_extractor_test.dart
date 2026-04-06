import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  final now = DateTime(2024, 6, 15, 10, 30);

  final testTag1 = Tag(
    id: 't1',
    name: 'training',
    createdAt: now,
    updatedAt: now,
  );
  final testTag2 = Tag(id: 't2', name: 'deep', createdAt: now, updatedAt: now);

  const testSite = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    country: 'Belize',
    region: 'Lighthouse Reef',
    location: GeoPoint(17.3156, -87.5340),
  );

  final testDiveCenter = DiveCenter(
    id: 'dc-1',
    name: 'Reef Divers',
    createdAt: now,
    updatedAt: now,
  );

  final testTrip = Trip(
    id: 'trip-1',
    name: 'Belize Adventure',
    startDate: DateTime(2024, 6, 10),
    endDate: DateTime(2024, 6, 20),
    createdAt: now,
    updatedAt: now,
  );

  const testTank = DiveTank(
    id: 'tank-1',
    volume: 12.0,
    startPressure: 200.0,
    endPressure: 50.0,
    gasMix: GasMix(o2: 32.0, he: 0.0),
    role: TankRole.backGas,
  );

  final testDive = Dive(
    id: 'dive-1',
    diveNumber: 42,
    dateTime: now,
    entryTime: DateTime(2024, 6, 15, 10, 35),
    maxDepth: 30.5,
    avgDepth: 18.2,
    bottomTime: const Duration(minutes: 45),
    runtime: const Duration(minutes: 52),
    waterTemp: 24.0,
    airTemp: 28.0,
    visibility: Visibility.good,
    currentDirection: CurrentDirection.north,
    currentStrength: CurrentStrength.light,
    swellHeight: 0.5,
    entryMethod: EntryMethod.giantStride,
    exitMethod: EntryMethod.ladder,
    waterType: WaterType.salt,
    altitude: 0.0,
    surfacePressure: 1.013,
    windSpeed: 12.0,
    cloudCover: CloudCover.partlyCloudy,
    precipitation: Precipitation.none,
    humidity: 65.0,
    weatherDescription: 'Clear skies',
    buddy: 'John Doe',
    diveMaster: 'Jane Smith',
    diveComputerModel: 'Shearwater Perdix',
    gradientFactorLow: 30,
    gradientFactorHigh: 70,
    decoAlgorithm: 'Buhlmann ZHL-16C',
    decoConservatism: 3,
    weightAmount: 6.0,
    weights: [
      const DiveWeight(
        id: 'w1',
        diveId: 'dive-1',
        weightType: WeightType.integrated,
        amountKg: 6.0,
      ),
    ],
    isFavorite: true,
    tags: [testTag1, testTag2],
    diveMode: DiveMode.oc,
    setpointLow: 0.7,
    setpointHigh: 1.3,
    setpointDeco: 1.6,
    importSource: 'Subsurface',
    notes: 'Great visibility',
    surfaceInterval: const Duration(minutes: 90),
    rating: 4,
    site: testSite,
    diveCenter: testDiveCenter,
    trip: testTrip,
    tanks: [testTank],
    diluentGas: const GasMix(o2: 21.0, he: 35.0),
  );

  group('DiveFieldExtractor - extractFromDive', () {
    test('diveNumber returns dive number', () {
      expect(DiveField.diveNumber.extractFromDive(testDive), 42);
    });

    test('dateTime returns effectiveEntryTime', () {
      // effectiveEntryTime = entryTime ?? dateTime
      expect(
        DiveField.dateTime.extractFromDive(testDive),
        DateTime(2024, 6, 15, 10, 35),
      );
    });

    test('siteName returns site name', () {
      expect(DiveField.siteName.extractFromDive(testDive), 'Blue Hole');
    });

    test('maxDepth returns max depth', () {
      expect(DiveField.maxDepth.extractFromDive(testDive), 30.5);
    });

    test('avgDepth returns avg depth', () {
      expect(DiveField.avgDepth.extractFromDive(testDive), 18.2);
    });

    test('bottomTime returns bottom time duration', () {
      expect(
        DiveField.bottomTime.extractFromDive(testDive),
        const Duration(minutes: 45),
      );
    });

    test('runtime returns effectiveRuntime', () {
      // effectiveRuntime falls back to runtime when set
      expect(
        DiveField.runtime.extractFromDive(testDive),
        const Duration(minutes: 52),
      );
    });

    test('waterTemp returns water temperature', () {
      expect(DiveField.waterTemp.extractFromDive(testDive), 24.0);
    });

    test('airTemp returns air temperature', () {
      expect(DiveField.airTemp.extractFromDive(testDive), 28.0);
    });

    test('visibility returns display name', () {
      expect(
        DiveField.visibility.extractFromDive(testDive),
        'Good (15-30m / 50-100ft)',
      );
    });

    test('currentDirection returns display name', () {
      expect(DiveField.currentDirection.extractFromDive(testDive), 'North');
    });

    test('currentStrength returns display name', () {
      expect(DiveField.currentStrength.extractFromDive(testDive), 'Light');
    });

    test('swellHeight returns swell height', () {
      expect(DiveField.swellHeight.extractFromDive(testDive), 0.5);
    });

    test('entryMethod returns display name', () {
      expect(DiveField.entryMethod.extractFromDive(testDive), 'Giant Stride');
    });

    test('exitMethod returns display name', () {
      expect(DiveField.exitMethod.extractFromDive(testDive), 'Ladder');
    });

    test('waterType returns display name', () {
      expect(DiveField.waterType.extractFromDive(testDive), 'Salt Water');
    });

    test('altitude returns altitude', () {
      expect(DiveField.altitude.extractFromDive(testDive), 0.0);
    });

    test('surfacePressure returns surface pressure', () {
      expect(DiveField.surfacePressure.extractFromDive(testDive), 1.013);
    });

    test('windSpeed returns wind speed', () {
      expect(DiveField.windSpeed.extractFromDive(testDive), 12.0);
    });

    test('cloudCover returns display name', () {
      expect(DiveField.cloudCover.extractFromDive(testDive), 'Partly Cloudy');
    });

    test('precipitation returns display name', () {
      expect(DiveField.precipitation.extractFromDive(testDive), 'None');
    });

    test('humidity returns humidity', () {
      expect(DiveField.humidity.extractFromDive(testDive), 65.0);
    });

    test('weatherDescription returns weather description', () {
      expect(
        DiveField.weatherDescription.extractFromDive(testDive),
        'Clear skies',
      );
    });

    test('primaryGas returns first tank gas mix name', () {
      expect(DiveField.primaryGas.extractFromDive(testDive), 'EAN32');
    });

    test('diluentGas returns diluent gas mix name', () {
      expect(DiveField.diluentGas.extractFromDive(testDive), 'Tx 21/35');
    });

    test('tankCount returns number of tanks', () {
      expect(DiveField.tankCount.extractFromDive(testDive), 1);
    });

    test('startPressure returns first tank start pressure', () {
      expect(DiveField.startPressure.extractFromDive(testDive), 200.0);
    });

    test('endPressure returns first tank end pressure', () {
      expect(DiveField.endPressure.extractFromDive(testDive), 50.0);
    });

    test('totalWeight returns total weight from weights list', () {
      expect(DiveField.totalWeight.extractFromDive(testDive), 6.0);
    });

    test('diveComputerModel returns computer model', () {
      expect(
        DiveField.diveComputerModel.extractFromDive(testDive),
        'Shearwater Perdix',
      );
    });

    test('gradientFactorLow returns GF low', () {
      expect(DiveField.gradientFactorLow.extractFromDive(testDive), 30);
    });

    test('gradientFactorHigh returns GF high', () {
      expect(DiveField.gradientFactorHigh.extractFromDive(testDive), 70);
    });

    test('decoAlgorithm returns algorithm name', () {
      expect(
        DiveField.decoAlgorithm.extractFromDive(testDive),
        'Buhlmann ZHL-16C',
      );
    });

    test('decoConservatism returns conservatism', () {
      expect(DiveField.decoConservatism.extractFromDive(testDive), 3);
    });

    test('cnsStart always returns null (not yet implemented)', () {
      expect(DiveField.cnsStart.extractFromDive(testDive), isNull);
    });

    test('cnsEnd always returns null (not yet implemented)', () {
      expect(DiveField.cnsEnd.extractFromDive(testDive), isNull);
    });

    test('otu always returns null (not yet implemented)', () {
      expect(DiveField.otu.extractFromDive(testDive), isNull);
    });

    test('diveMode returns uppercased mode name', () {
      expect(DiveField.diveMode.extractFromDive(testDive), 'OC');
    });

    test('setpointLow returns low setpoint', () {
      expect(DiveField.setpointLow.extractFromDive(testDive), 0.7);
    });

    test('setpointHigh returns high setpoint', () {
      expect(DiveField.setpointHigh.extractFromDive(testDive), 1.3);
    });

    test('setpointDeco returns deco setpoint', () {
      expect(DiveField.setpointDeco.extractFromDive(testDive), 1.6);
    });

    test('buddy returns buddy name', () {
      expect(DiveField.buddy.extractFromDive(testDive), 'John Doe');
    });

    test('diveMaster returns dive master name', () {
      expect(DiveField.diveMaster.extractFromDive(testDive), 'Jane Smith');
    });

    test('siteLocation returns site location string', () {
      expect(
        DiveField.siteLocation.extractFromDive(testDive),
        'Lighthouse Reef, Belize',
      );
    });

    test('diveCenterName returns dive center name', () {
      expect(DiveField.diveCenterName.extractFromDive(testDive), 'Reef Divers');
    });

    test('siteLatitude returns latitude', () {
      expect(DiveField.siteLatitude.extractFromDive(testDive), 17.3156);
    });

    test('siteLongitude returns longitude', () {
      expect(DiveField.siteLongitude.extractFromDive(testDive), -87.5340);
    });

    test('tripName returns trip name', () {
      expect(DiveField.tripName.extractFromDive(testDive), 'Belize Adventure');
    });

    test('ratingStars returns rating', () {
      expect(DiveField.ratingStars.extractFromDive(testDive), 4);
    });

    test('isFavorite returns favorite flag', () {
      expect(DiveField.isFavorite.extractFromDive(testDive), true);
    });

    test('notes returns notes text', () {
      expect(DiveField.notes.extractFromDive(testDive), 'Great visibility');
    });

    test('tags returns list of tag names', () {
      expect(DiveField.tags.extractFromDive(testDive), ['training', 'deep']);
    });

    test('importSource returns import source', () {
      expect(DiveField.importSource.extractFromDive(testDive), 'Subsurface');
    });

    test('diveTypeName returns formatted dive type', () {
      // Default diveTypeId is 'recreational', no diveType entity set
      expect(DiveField.diveTypeName.extractFromDive(testDive), 'Recreational');
    });

    test('surfaceInterval returns surface interval duration', () {
      expect(
        DiveField.surfaceInterval.extractFromDive(testDive),
        const Duration(minutes: 90),
      );
    });
  });

  group('DiveFieldExtractor - SAC rate and gas consumed', () {
    test('sacRate computes correctly with valid tank data', () {
      final result = DiveField.sacRate.extractFromDive(testDive);
      expect(result, isA<double>());
      // Calculation: gasLiters = 12.0 * (200.0 - 50.0) = 1800
      // minutes = 52 * 60 / 60 = 52.0
      // avgPressureAtm = (18.2 / 10.0) + 1.0 = 2.82
      // sacRate = 1800 / 52.0 / 2.82 = ~12.28
      expect((result as double), closeTo(12.28, 0.1));
    });

    test('gasConsumed computes correctly with valid tank data', () {
      final result = DiveField.gasConsumed.extractFromDive(testDive);
      expect(result, isA<double>());
      // Calculation: 12.0 * (200.0 - 50.0) = 1800.0
      expect(result, 1800.0);
    });

    test('sacRate returns null for dive with no tanks', () {
      final noTankDive = Dive(id: 'dive-empty', dateTime: now, tanks: const []);
      expect(DiveField.sacRate.extractFromDive(noTankDive), isNull);
    });

    test('gasConsumed returns null for dive with no tanks', () {
      final noTankDive = Dive(id: 'dive-empty', dateTime: now, tanks: const []);
      expect(DiveField.gasConsumed.extractFromDive(noTankDive), isNull);
    });

    test('sacRate returns null when tank has no volume', () {
      const noVolumeTank = DiveTank(
        id: 'tank-nv',
        startPressure: 200.0,
        endPressure: 50.0,
      );
      final dive = Dive(
        id: 'dive-nv',
        dateTime: now,
        runtime: const Duration(minutes: 45),
        avgDepth: 18.0,
        tanks: [noVolumeTank],
      );
      expect(DiveField.sacRate.extractFromDive(dive), isNull);
    });

    test('sacRate returns null when no avgDepth', () {
      final dive = Dive(
        id: 'dive-nod',
        dateTime: now,
        runtime: const Duration(minutes: 45),
        tanks: [testTank],
      );
      expect(DiveField.sacRate.extractFromDive(dive), isNull);
    });

    test('sacRate returns null when no runtime', () {
      final dive = Dive(
        id: 'dive-nor',
        dateTime: now,
        avgDepth: 18.0,
        tanks: [testTank],
      );
      expect(DiveField.sacRate.extractFromDive(dive), isNull);
    });

    test('gasConsumed returns null when pressure used is zero', () {
      const zeroPressureTank = DiveTank(
        id: 'tank-z',
        volume: 12.0,
        startPressure: 200.0,
        endPressure: 200.0,
      );
      final dive = Dive(id: 'dive-z', dateTime: now, tanks: [zeroPressureTank]);
      expect(DiveField.gasConsumed.extractFromDive(dive), isNull);
    });
  });

  group('DiveFieldExtractor - null / empty edge cases', () {
    final minimalDive = Dive(id: 'dive-min', dateTime: now);

    test('siteName returns null when no site', () {
      expect(DiveField.siteName.extractFromDive(minimalDive), isNull);
    });

    test('siteLocation returns null when no site', () {
      expect(DiveField.siteLocation.extractFromDive(minimalDive), isNull);
    });

    test('diveCenterName returns null when no dive center', () {
      expect(DiveField.diveCenterName.extractFromDive(minimalDive), isNull);
    });

    test('tripName returns null when no trip', () {
      expect(DiveField.tripName.extractFromDive(minimalDive), isNull);
    });

    test('notes returns null for empty notes', () {
      expect(DiveField.notes.extractFromDive(minimalDive), isNull);
    });

    test('tags returns empty list when no tags', () {
      expect(DiveField.tags.extractFromDive(minimalDive), <String>[]);
    });

    test('primaryGas returns null when no tanks', () {
      expect(DiveField.primaryGas.extractFromDive(minimalDive), isNull);
    });

    test('startPressure returns null when no tanks', () {
      expect(DiveField.startPressure.extractFromDive(minimalDive), isNull);
    });

    test('endPressure returns null when no tanks', () {
      expect(DiveField.endPressure.extractFromDive(minimalDive), isNull);
    });

    test('tankCount returns 0 when no tanks', () {
      expect(DiveField.tankCount.extractFromDive(minimalDive), 0);
    });

    test('totalWeight returns null when no weights (zero total)', () {
      // totalWeight returns null when > 0 check fails
      expect(DiveField.totalWeight.extractFromDive(minimalDive), isNull);
    });

    test('diluentGas returns null when not set', () {
      expect(DiveField.diluentGas.extractFromDive(minimalDive), isNull);
    });

    test('siteLatitude returns null when no site', () {
      expect(DiveField.siteLatitude.extractFromDive(minimalDive), isNull);
    });

    test('siteLongitude returns null when no site', () {
      expect(DiveField.siteLongitude.extractFromDive(minimalDive), isNull);
    });

    test('visibility returns null when not set', () {
      expect(DiveField.visibility.extractFromDive(minimalDive), isNull);
    });

    test('currentDirection returns null when not set', () {
      expect(DiveField.currentDirection.extractFromDive(minimalDive), isNull);
    });

    test('waterType returns null when not set', () {
      expect(DiveField.waterType.extractFromDive(minimalDive), isNull);
    });

    test('dateTime returns dateTime when entryTime is null', () {
      expect(DiveField.dateTime.extractFromDive(minimalDive), now);
    });

    test('diveMode defaults to OC', () {
      expect(DiveField.diveMode.extractFromDive(minimalDive), 'OC');
    });
  });

  group('DiveFieldExtractor - extractFromSummary', () {
    final testSummary = DiveSummary(
      id: 'sum-1',
      diveNumber: 42,
      dateTime: now,
      entryTime: DateTime(2024, 6, 15, 10, 35),
      maxDepth: 30.5,
      bottomTime: const Duration(minutes: 45),
      runtime: const Duration(minutes: 52),
      waterTemp: 24.0,
      rating: 4,
      isFavorite: true,
      diveTypeId: 'technical',
      tags: [testTag1, testTag2],
      siteName: 'Blue Hole',
      siteCountry: 'Belize',
      siteRegion: 'Lighthouse Reef',
      siteLatitude: 17.3156,
      siteLongitude: -87.5340,
      sortTimestamp: DateTime(2024, 6, 15, 10, 35).millisecondsSinceEpoch,
    );

    test('diveNumber returns dive number', () {
      expect(DiveField.diveNumber.extractFromSummary(testSummary), 42);
    });

    test('dateTime returns entryTime when available', () {
      expect(
        DiveField.dateTime.extractFromSummary(testSummary),
        DateTime(2024, 6, 15, 10, 35),
      );
    });

    test('siteName returns site name', () {
      expect(DiveField.siteName.extractFromSummary(testSummary), 'Blue Hole');
    });

    test('maxDepth returns max depth', () {
      expect(DiveField.maxDepth.extractFromSummary(testSummary), 30.5);
    });

    test('avgDepth returns null (not on summary)', () {
      expect(DiveField.avgDepth.extractFromSummary(testSummary), isNull);
    });

    test('bottomTime returns bottom time', () {
      expect(
        DiveField.bottomTime.extractFromSummary(testSummary),
        const Duration(minutes: 45),
      );
    });

    test('runtime returns runtime', () {
      expect(
        DiveField.runtime.extractFromSummary(testSummary),
        const Duration(minutes: 52),
      );
    });

    test('waterTemp returns water temperature', () {
      expect(DiveField.waterTemp.extractFromSummary(testSummary), 24.0);
    });

    test('ratingStars returns rating', () {
      expect(DiveField.ratingStars.extractFromSummary(testSummary), 4);
    });

    test('isFavorite returns favorite flag', () {
      expect(DiveField.isFavorite.extractFromSummary(testSummary), true);
    });

    test('diveTypeName capitalizes typeId', () {
      expect(
        DiveField.diveTypeName.extractFromSummary(testSummary),
        'Technical',
      );
    });

    test('tags returns list of tag names', () {
      expect(DiveField.tags.extractFromSummary(testSummary), [
        'training',
        'deep',
      ]);
    });

    test('siteLocation returns formatted location string', () {
      expect(
        DiveField.siteLocation.extractFromSummary(testSummary),
        'Lighthouse Reef, Belize',
      );
    });

    test('siteLatitude returns latitude', () {
      expect(DiveField.siteLatitude.extractFromSummary(testSummary), 17.3156);
    });

    test('siteLongitude returns longitude', () {
      expect(DiveField.siteLongitude.extractFromSummary(testSummary), -87.5340);
    });

    test('non-summary fields return null via default case', () {
      // Fields not available on DiveSummary should return null
      expect(DiveField.buddy.extractFromSummary(testSummary), isNull);
      expect(DiveField.diveMaster.extractFromSummary(testSummary), isNull);
      expect(DiveField.sacRate.extractFromSummary(testSummary), isNull);
      expect(DiveField.gasConsumed.extractFromSummary(testSummary), isNull);
      expect(DiveField.airTemp.extractFromSummary(testSummary), isNull);
      expect(
        DiveField.diveComputerModel.extractFromSummary(testSummary),
        isNull,
      );
      expect(DiveField.notes.extractFromSummary(testSummary), isNull);
      expect(DiveField.importSource.extractFromSummary(testSummary), isNull);
    });
  });

  group('DiveFieldExtractor - summary edge cases', () {
    test('dateTime falls back to dateTime when entryTime is null', () {
      final summaryNoEntry = DiveSummary(
        id: 'sum-2',
        dateTime: now,
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      expect(DiveField.dateTime.extractFromSummary(summaryNoEntry), now);
    });

    test('diveTypeName returns Recreational for empty diveTypeId', () {
      final summaryEmpty = DiveSummary(
        id: 'sum-3',
        dateTime: now,
        diveTypeId: '',
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      expect(
        DiveField.diveTypeName.extractFromSummary(summaryEmpty),
        'Recreational',
      );
    });

    test('diveTypeName handles underscore-separated IDs', () {
      final summaryUnderscore = DiveSummary(
        id: 'sum-4',
        dateTime: now,
        diveTypeId: 'deep_wreck',
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      expect(
        DiveField.diveTypeName.extractFromSummary(summaryUnderscore),
        'Deep wreck',
      );
    });

    test('siteLocation returns null when no region and no country', () {
      final summaryNoLoc = DiveSummary(
        id: 'sum-5',
        dateTime: now,
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      expect(DiveField.siteLocation.extractFromSummary(summaryNoLoc), isNull);
    });

    test('tags returns empty list when no tags', () {
      final summaryNoTags = DiveSummary(
        id: 'sum-6',
        dateTime: now,
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      expect(DiveField.tags.extractFromSummary(summaryNoTags), <String>[]);
    });
  });

  group('DiveFieldExtractor - exhaustive field coverage', () {
    test('every DiveField is handled by extractFromDive', () {
      for (final field in DiveField.values) {
        // Should not throw for any field
        expect(
          () => field.extractFromDive(testDive),
          returnsNormally,
          reason: '${field.name} should not throw in extractFromDive',
        );
      }
    });

    test('every DiveField is handled by extractFromSummary', () {
      final summary = DiveSummary(
        id: 'sum-all',
        dateTime: now,
        sortTimestamp: now.millisecondsSinceEpoch,
      );
      for (final field in DiveField.values) {
        // Should not throw for any field
        expect(
          () => field.extractFromSummary(summary),
          returnsNormally,
          reason: '${field.name} should not throw in extractFromSummary',
        );
      }
    });
  });
}
