import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const units = UnitFormatter(AppSettings());

  group('DiveFieldFormatter - null values', () {
    test('all fields return "--" for null', () {
      for (final field in DiveField.values) {
        expect(
          field.formatValue(null, units),
          '--',
          reason: '${field.name}.formatValue(null) should return "--"',
        );
      }
    });
  });

  group('DiveFieldFormatter - depth fields', () {
    test('maxDepth formats with depth unit', () {
      final result = DiveField.maxDepth.formatValue(30.5, units);
      expect(result, units.formatDepth(30.5));
    });

    test('avgDepth formats with depth unit', () {
      final result = DiveField.avgDepth.formatValue(18.2, units);
      expect(result, units.formatDepth(18.2));
    });

    test('swellHeight formats with depth unit', () {
      final result = DiveField.swellHeight.formatValue(0.5, units);
      expect(result, units.formatDepth(0.5));
    });
  });

  group('DiveFieldFormatter - temperature fields', () {
    test('waterTemp formats with temperature unit', () {
      final result = DiveField.waterTemp.formatValue(24.0, units);
      expect(result, units.formatTemperature(24.0));
    });

    test('airTemp formats with temperature unit', () {
      final result = DiveField.airTemp.formatValue(28.0, units);
      expect(result, units.formatTemperature(28.0));
    });
  });

  group('DiveFieldFormatter - duration fields', () {
    test('bottomTime formats as minutes for < 1 hour', () {
      final result = DiveField.bottomTime.formatValue(
        const Duration(minutes: 45),
        units,
      );
      expect(result, '45min');
    });

    test('runtime formats as hours and minutes for >= 1 hour', () {
      final result = DiveField.runtime.formatValue(
        const Duration(minutes: 75),
        units,
      );
      expect(result, '1h 15m');
    });

    test('surfaceInterval formats correctly', () {
      final result = DiveField.surfaceInterval.formatValue(
        const Duration(minutes: 90),
        units,
      );
      expect(result, '1h 30m');
    });

    test('duration returns "--" for zero duration', () {
      final result = DiveField.bottomTime.formatValue(Duration.zero, units);
      expect(result, '--');
    });

    test('duration returns "--" for non-Duration value', () {
      final result = DiveField.bottomTime.formatValue('not a duration', units);
      expect(result, '--');
    });

    test('duration formats exact hour correctly', () {
      final result = DiveField.runtime.formatValue(
        const Duration(hours: 1),
        units,
      );
      expect(result, '1h 0m');
    });
  });

  group('DiveFieldFormatter - dateTime', () {
    test('dateTime formats with bullet separator', () {
      final dt = DateTime(2024, 6, 15, 10, 30);
      final result = DiveField.dateTime.formatValue(dt, units);
      expect(result, units.formatDateTimeBullet(dt));
    });
  });

  group('DiveFieldFormatter - pressure fields', () {
    test('startPressure formats with pressure unit', () {
      final result = DiveField.startPressure.formatValue(200.0, units);
      expect(result, units.formatPressure(200.0));
    });

    test('endPressure formats with pressure unit', () {
      final result = DiveField.endPressure.formatValue(50.0, units);
      expect(result, units.formatPressure(50.0));
    });

    test('surfacePressure formats as barometric pressure', () {
      final result = DiveField.surfacePressure.formatValue(1.013, units);
      expect(result, units.formatBarometricPressure(1.013));
    });
  });

  group('DiveFieldFormatter - altitude', () {
    test('altitude formats with altitude unit', () {
      final result = DiveField.altitude.formatValue(300.0, units);
      expect(result, units.formatAltitude(300.0));
    });
  });

  group('DiveFieldFormatter - gas fields', () {
    test('sacRate formats with volume symbol and per-minute', () {
      final result = DiveField.sacRate.formatValue(12.3, units);
      expect(result, '12.3 ${units.volumeSymbol}/min');
    });

    test('sacRate returns "--" for non-double', () {
      final result = DiveField.sacRate.formatValue('invalid', units);
      expect(result, '--');
    });

    test('gasConsumed formats with volume unit', () {
      final result = DiveField.gasConsumed.formatValue(1800.0, units);
      expect(result, units.formatVolume(1800.0));
    });
  });

  group('DiveFieldFormatter - weight', () {
    test('totalWeight formats with weight unit', () {
      final result = DiveField.totalWeight.formatValue(6.0, units);
      expect(result, units.formatWeight(6.0));
    });
  });

  group('DiveFieldFormatter - wind speed', () {
    test('windSpeed formats with wind speed unit', () {
      final result = DiveField.windSpeed.formatValue(12.0, units);
      expect(result, units.formatWindSpeed(12.0));
    });
  });

  group('DiveFieldFormatter - humidity', () {
    test('humidity formats as percentage', () {
      final result = DiveField.humidity.formatValue(65.0, units);
      expect(result, '65%');
    });

    test('humidity returns "--" for non-double', () {
      final result = DiveField.humidity.formatValue('invalid', units);
      expect(result, '--');
    });
  });

  group('DiveFieldFormatter - gradient factors', () {
    test('gradientFactorLow formats as percentage', () {
      final result = DiveField.gradientFactorLow.formatValue(30, units);
      expect(result, '30%');
    });

    test('gradientFactorHigh formats as percentage', () {
      final result = DiveField.gradientFactorHigh.formatValue(70, units);
      expect(result, '70%');
    });

    test('gradientFactor returns "--" for non-int', () {
      final result = DiveField.gradientFactorLow.formatValue('invalid', units);
      expect(result, '--');
    });
  });

  group('DiveFieldFormatter - setpoints', () {
    test('setpointLow formats with 2 decimal places in bar', () {
      final result = DiveField.setpointLow.formatValue(0.7, units);
      expect(result, '0.70 bar');
    });

    test('setpointHigh formats with 2 decimal places in bar', () {
      final result = DiveField.setpointHigh.formatValue(1.3, units);
      expect(result, '1.30 bar');
    });

    test('setpointDeco formats with 2 decimal places in bar', () {
      final result = DiveField.setpointDeco.formatValue(1.6, units);
      expect(result, '1.60 bar');
    });

    test('setpoint returns "--" for non-double', () {
      final result = DiveField.setpointLow.formatValue('invalid', units);
      expect(result, '--');
    });
  });

  group('DiveFieldFormatter - CNS', () {
    test('cnsStart formats with 1 decimal place percentage', () {
      final result = DiveField.cnsStart.formatValue(45.5, units);
      expect(result, '45.5%');
    });

    test('cnsEnd formats with 1 decimal place percentage', () {
      final result = DiveField.cnsEnd.formatValue(78.3, units);
      expect(result, '78.3%');
    });

    test('cns returns "--" for non-double', () {
      final result = DiveField.cnsStart.formatValue('invalid', units);
      expect(result, '--');
    });
  });

  group('DiveFieldFormatter - boolean', () {
    test('isFavorite returns "Yes" for true', () {
      final result = DiveField.isFavorite.formatValue(true, units);
      expect(result, 'Yes');
    });

    test('isFavorite returns "No" for false', () {
      final result = DiveField.isFavorite.formatValue(false, units);
      expect(result, 'No');
    });

    test('isFavorite returns "--" for non-bool', () {
      final result = DiveField.isFavorite.formatValue('invalid', units);
      expect(result, '--');
    });
  });

  group('DiveFieldFormatter - tags', () {
    test('tags formats as comma-separated list', () {
      final result = DiveField.tags.formatValue([
        'training',
        'deep',
        'night',
      ], units);
      expect(result, 'training, deep, night');
    });

    test('tags returns "--" for empty list', () {
      final result = DiveField.tags.formatValue(<String>[], units);
      expect(result, '--');
    });

    test('tags returns "--" for non-list', () {
      final result = DiveField.tags.formatValue('invalid', units);
      expect(result, '--');
    });
  });

  group('DiveFieldFormatter - special formats', () {
    test('diveNumber formats with # prefix', () {
      final result = DiveField.diveNumber.formatValue(42, units);
      expect(result, '#42');
    });

    test('tankCount formats as plain string', () {
      final result = DiveField.tankCount.formatValue(2, units);
      expect(result, '2');
    });
  });

  group('DiveFieldFormatter - string pass-through (default case)', () {
    test('siteName passes through as string', () {
      final result = DiveField.siteName.formatValue('Blue Hole', units);
      expect(result, 'Blue Hole');
    });

    test('buddy passes through as string', () {
      final result = DiveField.buddy.formatValue('John Doe', units);
      expect(result, 'John Doe');
    });

    test('diveMaster passes through as string', () {
      final result = DiveField.diveMaster.formatValue('Jane Smith', units);
      expect(result, 'Jane Smith');
    });

    test('diveComputerModel passes through as string', () {
      final result = DiveField.diveComputerModel.formatValue(
        'Shearwater Perdix',
        units,
      );
      expect(result, 'Shearwater Perdix');
    });

    test('decoAlgorithm passes through as string', () {
      final result = DiveField.decoAlgorithm.formatValue(
        'Buhlmann ZHL-16C',
        units,
      );
      expect(result, 'Buhlmann ZHL-16C');
    });

    test('visibility passes through as string', () {
      final result = DiveField.visibility.formatValue('Good', units);
      expect(result, 'Good');
    });

    test('diveMode passes through as string', () {
      final result = DiveField.diveMode.formatValue('OC', units);
      expect(result, 'OC');
    });

    test('importSource passes through as string', () {
      final result = DiveField.importSource.formatValue('Subsurface', units);
      expect(result, 'Subsurface');
    });

    test('notes passes through as string', () {
      final result = DiveField.notes.formatValue('Great dive!', units);
      expect(result, 'Great dive!');
    });

    test('siteLocation passes through as string', () {
      final result = DiveField.siteLocation.formatValue(
        'Lighthouse Reef, Belize',
        units,
      );
      expect(result, 'Lighthouse Reef, Belize');
    });

    test('tripName passes through as string', () {
      final result = DiveField.tripName.formatValue('Belize Trip', units);
      expect(result, 'Belize Trip');
    });

    test('diveTypeName passes through as string', () {
      final result = DiveField.diveTypeName.formatValue('Recreational', units);
      expect(result, 'Recreational');
    });

    test('waterType passes through as string', () {
      final result = DiveField.waterType.formatValue('Salt Water', units);
      expect(result, 'Salt Water');
    });

    test('weatherDescription passes through as string', () {
      final result = DiveField.weatherDescription.formatValue(
        'Clear skies',
        units,
      );
      expect(result, 'Clear skies');
    });

    test('decoConservatism passes through as string', () {
      final result = DiveField.decoConservatism.formatValue(3, units);
      expect(result, '3');
    });

    test('ratingStars passes through as string', () {
      final result = DiveField.ratingStars.formatValue(4, units);
      expect(result, '4');
    });
  });

  group('DiveFieldFormatter - exhaustive coverage', () {
    test('every DiveField handles non-null value without throwing', () {
      // Map each field to a value of the appropriate type
      final testValues = <DiveField, dynamic>{
        DiveField.diveNumber: 1,
        DiveField.dateTime: DateTime(2024, 1, 1),
        DiveField.siteName: 'Site',
        DiveField.maxDepth: 10.0,
        DiveField.avgDepth: 5.0,
        DiveField.bottomTime: const Duration(minutes: 30),
        DiveField.runtime: const Duration(minutes: 35),
        DiveField.waterTemp: 22.0,
        DiveField.airTemp: 25.0,
        DiveField.visibility: 'Good',
        DiveField.currentDirection: 'North',
        DiveField.currentStrength: 'Light',
        DiveField.swellHeight: 0.5,
        DiveField.entryMethod: 'Shore',
        DiveField.exitMethod: 'Shore',
        DiveField.waterType: 'Salt',
        DiveField.altitude: 0.0,
        DiveField.surfacePressure: 1.013,
        DiveField.windSpeed: 5.0,
        DiveField.cloudCover: 'Clear',
        DiveField.precipitation: 'None',
        DiveField.humidity: 50.0,
        DiveField.weatherDescription: 'Sunny',
        DiveField.primaryGas: 'Air',
        DiveField.diluentGas: 'Air',
        DiveField.tankCount: 1,
        DiveField.startPressure: 200.0,
        DiveField.endPressure: 50.0,
        DiveField.sacRate: 15.0,
        DiveField.gasConsumed: 1800.0,
        DiveField.totalWeight: 6.0,
        DiveField.diveComputerModel: 'Model',
        DiveField.gradientFactorLow: 30,
        DiveField.gradientFactorHigh: 70,
        DiveField.decoAlgorithm: 'Buhlmann',
        DiveField.decoConservatism: 0,
        DiveField.cnsStart: 10.0,
        DiveField.cnsEnd: 20.0,
        DiveField.otu: 15.0,
        DiveField.diveMode: 'OC',
        DiveField.setpointLow: 0.7,
        DiveField.setpointHigh: 1.3,
        DiveField.setpointDeco: 1.6,
        DiveField.buddy: 'Buddy',
        DiveField.diveMaster: 'DM',
        DiveField.siteLocation: 'Somewhere',
        DiveField.diveCenterName: 'Center',
        DiveField.siteLatitude: 0.0,
        DiveField.siteLongitude: 0.0,
        DiveField.tripName: 'Trip',
        DiveField.ratingStars: 3,
        DiveField.isFavorite: true,
        DiveField.notes: 'Note',
        DiveField.tags: <String>['tag1'],
        DiveField.importSource: 'Source',
        DiveField.diveTypeName: 'Recreational',
        DiveField.surfaceInterval: const Duration(minutes: 60),
      };

      for (final field in DiveField.values) {
        final value = testValues[field];
        expect(
          value,
          isNotNull,
          reason: '${field.name} must have a test value in testValues map',
        );
        expect(
          () => field.formatValue(value, units),
          returnsNormally,
          reason: '${field.name}.formatValue should not throw',
        );
        final result = field.formatValue(value, units);
        expect(
          result,
          isA<String>(),
          reason: '${field.name}.formatValue should return a String',
        );
        expect(
          result.isNotEmpty,
          isTrue,
          reason: '${field.name}.formatValue should return non-empty string',
        );
      }
    });
  });
}
