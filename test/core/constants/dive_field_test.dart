import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';

void main() {
  group('DiveFieldCategory', () {
    test('every DiveField has a category', () {
      for (final field in DiveField.values) {
        expect(
          field.category,
          isA<DiveFieldCategory>(),
          reason: '${field.name} should have a category',
        );
      }
    });
  });

  group('DiveField metadata', () {
    test('every field has a non-empty shortLabel', () {
      for (final field in DiveField.values) {
        expect(
          field.shortLabel.isNotEmpty,
          isTrue,
          reason: '${field.name} should have a shortLabel',
        );
      }
    });

    test('every field has a positive defaultWidth', () {
      for (final field in DiveField.values) {
        expect(
          field.defaultWidth,
          greaterThan(0),
          reason: '${field.name} should have a positive defaultWidth',
        );
      }
    });

    test('every field has minWidth <= defaultWidth', () {
      for (final field in DiveField.values) {
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: '${field.name} minWidth should be <= defaultWidth',
        );
      }
    });

    test('core fields are sortable', () {
      expect(DiveField.diveNumber.sortable, isTrue);
      expect(DiveField.dateTime.sortable, isTrue);
      expect(DiveField.maxDepth.sortable, isTrue);
      expect(DiveField.bottomTime.sortable, isTrue);
    });

    test('notes field is not sortable', () {
      expect(DiveField.notes.sortable, isFalse);
    });

    test('fields with icons return non-null IconData', () {
      expect(DiveField.maxDepth.icon, equals(Icons.arrow_downward));
      expect(DiveField.bottomTime.icon, equals(Icons.timer));
      expect(DiveField.waterTemp.icon, equals(Icons.thermostat));
    });

    test('fields without icons return null', () {
      expect(DiveField.sacRate.icon, isNull);
      expect(DiveField.gradientFactorLow.icon, isNull);
    });

    test('fieldsForCategory returns correct fields', () {
      final coreFields = DiveField.fieldsForCategory(DiveFieldCategory.core);
      expect(coreFields, contains(DiveField.diveNumber));
      expect(coreFields, contains(DiveField.dateTime));
      expect(coreFields, contains(DiveField.maxDepth));
      expect(coreFields, isNot(contains(DiveField.waterTemp)));
    });

    test('summaryFields returns only fields available on DiveSummary', () {
      const summaryFields = DiveField.summaryFields;
      expect(summaryFields, contains(DiveField.diveNumber));
      expect(summaryFields, contains(DiveField.maxDepth));
      expect(summaryFields, isNot(contains(DiveField.buddy)));
      expect(summaryFields, isNot(contains(DiveField.sacRate)));
    });
  });

  group('DiveField.displayName', () {
    test('every enum value has a non-empty displayName', () {
      for (final field in DiveField.values) {
        expect(
          field.displayName.isNotEmpty,
          isTrue,
          reason: '${field.name} should have a non-empty displayName',
        );
      }
    });

    test('returns expected display names for core fields', () {
      expect(DiveField.diveNumber.displayName, equals('Dive Number'));
      expect(DiveField.dateTime.displayName, equals('Date & Time'));
      expect(DiveField.siteName.displayName, equals('Site Name'));
      expect(DiveField.maxDepth.displayName, equals('Max Depth'));
      expect(DiveField.avgDepth.displayName, equals('Average Depth'));
      expect(DiveField.bottomTime.displayName, equals('Bottom Time'));
      expect(DiveField.runtime.displayName, equals('Runtime'));
    });

    test('returns expected display names for environment fields', () {
      expect(DiveField.waterTemp.displayName, equals('Water Temperature'));
      expect(DiveField.airTemp.displayName, equals('Air Temperature'));
      expect(DiveField.visibility.displayName, equals('Visibility'));
      expect(
        DiveField.currentDirection.displayName,
        equals('Current Direction'),
      );
      expect(DiveField.currentStrength.displayName, equals('Current Strength'));
      expect(DiveField.swellHeight.displayName, equals('Swell Height'));
      expect(DiveField.entryMethod.displayName, equals('Entry Method'));
      expect(DiveField.exitMethod.displayName, equals('Exit Method'));
      expect(DiveField.waterType.displayName, equals('Water Type'));
      expect(DiveField.altitude.displayName, equals('Altitude'));
      expect(DiveField.surfacePressure.displayName, equals('Surface Pressure'));
      expect(DiveField.windSpeed.displayName, equals('Wind Speed'));
      expect(DiveField.cloudCover.displayName, equals('Cloud Cover'));
      expect(DiveField.precipitation.displayName, equals('Precipitation'));
      expect(DiveField.humidity.displayName, equals('Humidity'));
      expect(DiveField.weatherDescription.displayName, equals('Weather'));
    });

    test('returns expected display names for gas and tank fields', () {
      expect(DiveField.primaryGas.displayName, equals('Primary Gas'));
      expect(DiveField.diluentGas.displayName, equals('Diluent Gas'));
      expect(DiveField.tankCount.displayName, equals('Tank Count'));
      expect(DiveField.startPressure.displayName, equals('Start Pressure'));
      expect(DiveField.endPressure.displayName, equals('End Pressure'));
      expect(DiveField.sacRate.displayName, equals('SAC Rate'));
      expect(DiveField.gasConsumed.displayName, equals('Gas Consumed'));
    });

    test('returns expected display names for equipment and weight', () {
      expect(DiveField.totalWeight.displayName, equals('Total Weight'));
      expect(DiveField.diveComputerModel.displayName, equals('Dive Computer'));
    });

    test('returns expected display names for deco fields', () {
      expect(DiveField.gradientFactorLow.displayName, equals('GF Low'));
      expect(DiveField.gradientFactorHigh.displayName, equals('GF High'));
      expect(DiveField.decoAlgorithm.displayName, equals('Deco Algorithm'));
      expect(DiveField.decoConservatism.displayName, equals('Conservatism'));
    });

    test('returns expected display names for physiology fields', () {
      expect(DiveField.cnsStart.displayName, equals('CNS Start'));
      expect(DiveField.cnsEnd.displayName, equals('CNS End'));
      expect(DiveField.otu.displayName, equals('OTU'));
    });

    test('returns expected display names for rebreather fields', () {
      expect(DiveField.diveMode.displayName, equals('Dive Mode'));
      expect(DiveField.setpointLow.displayName, equals('Setpoint Low'));
      expect(DiveField.setpointHigh.displayName, equals('Setpoint High'));
      expect(DiveField.setpointDeco.displayName, equals('Setpoint Deco'));
    });

    test('returns expected display names for people and location fields', () {
      expect(DiveField.buddy.displayName, equals('Buddy'));
      expect(DiveField.diveMaster.displayName, equals('Dive Master'));
      expect(DiveField.siteLocation.displayName, equals('Site Location'));
      expect(DiveField.diveCenterName.displayName, equals('Dive Center'));
      expect(DiveField.siteLatitude.displayName, equals('Latitude'));
      expect(DiveField.siteLongitude.displayName, equals('Longitude'));
    });

    test('returns expected display names for trip, rating, metadata', () {
      expect(DiveField.tripName.displayName, equals('Trip'));
      expect(DiveField.ratingStars.displayName, equals('Rating'));
      expect(DiveField.isFavorite.displayName, equals('Favorite'));
      expect(DiveField.notes.displayName, equals('Notes'));
      expect(DiveField.tags.displayName, equals('Tags'));
      expect(DiveField.importSource.displayName, equals('Import Source'));
      expect(DiveField.diveTypeName.displayName, equals('Dive Type'));
      expect(DiveField.surfaceInterval.displayName, equals('Surface Interval'));
    });
  });

  group('DiveField.icon (comprehensive)', () {
    test('icon returns expected non-null values for all icon fields', () {
      expect(DiveField.diveNumber.icon, equals(Icons.tag));
      expect(DiveField.dateTime.icon, equals(Icons.calendar_today));
      expect(DiveField.siteName.icon, equals(Icons.place));
      expect(DiveField.maxDepth.icon, equals(Icons.arrow_downward));
      expect(DiveField.avgDepth.icon, equals(Icons.compress));
      expect(DiveField.bottomTime.icon, equals(Icons.timer));
      expect(DiveField.runtime.icon, equals(Icons.timer_outlined));
      expect(DiveField.waterTemp.icon, equals(Icons.thermostat));
      expect(DiveField.airTemp.icon, equals(Icons.air));
      expect(DiveField.visibility.icon, equals(Icons.visibility));
      expect(DiveField.windSpeed.icon, equals(Icons.wind_power));
      expect(DiveField.buddy.icon, equals(Icons.people));
      expect(DiveField.diveMaster.icon, equals(Icons.school));
      expect(DiveField.ratingStars.icon, equals(Icons.star));
      expect(DiveField.isFavorite.icon, equals(Icons.favorite));
      expect(DiveField.notes.icon, equals(Icons.notes));
      expect(DiveField.tags.icon, equals(Icons.label));
      expect(DiveField.diveMode.icon, equals(Icons.settings));
      expect(DiveField.siteLocation.icon, equals(Icons.location_on));
      expect(DiveField.tripName.icon, equals(Icons.luggage));
      expect(DiveField.diveTypeName.icon, equals(Icons.category));
    });

    test('icon returns null for all null-icon fields', () {
      final nullIconFields = [
        DiveField.siteLatitude,
        DiveField.siteLongitude,
        DiveField.sacRate,
        DiveField.gasConsumed,
        DiveField.gradientFactorLow,
        DiveField.gradientFactorHigh,
        DiveField.decoAlgorithm,
        DiveField.decoConservatism,
        DiveField.cnsStart,
        DiveField.cnsEnd,
        DiveField.otu,
        DiveField.setpointLow,
        DiveField.setpointHigh,
        DiveField.setpointDeco,
        DiveField.primaryGas,
        DiveField.diluentGas,
        DiveField.tankCount,
        DiveField.startPressure,
        DiveField.endPressure,
        DiveField.totalWeight,
        DiveField.diveComputerModel,
        DiveField.diveCenterName,
        DiveField.currentDirection,
        DiveField.currentStrength,
        DiveField.swellHeight,
        DiveField.entryMethod,
        DiveField.exitMethod,
        DiveField.waterType,
        DiveField.altitude,
        DiveField.surfacePressure,
        DiveField.cloudCover,
        DiveField.precipitation,
        DiveField.humidity,
        DiveField.weatherDescription,
        DiveField.importSource,
        DiveField.surfaceInterval,
      ];
      for (final field in nullIconFields) {
        expect(
          field.icon,
          isNull,
          reason: '${field.name} should have a null icon',
        );
      }
    });

    test('every DiveField icon is accounted for (non-null or null)', () {
      // Ensures every field is covered by the icon getter without errors
      for (final field in DiveField.values) {
        // Just access the icon; no error means every switch case is covered
        field.icon;
      }
    });
  });

  group('DiveField displayName vs shortLabel', () {
    test('displayName differs from shortLabel where expected', () {
      expect(DiveField.bottomTime.displayName, equals('Bottom Time'));
      expect(DiveField.bottomTime.shortLabel, equals('BT'));
      expect(
        DiveField.bottomTime.displayName != DiveField.bottomTime.shortLabel,
        isTrue,
      );

      expect(DiveField.diveNumber.displayName, equals('Dive Number'));
      expect(DiveField.diveNumber.shortLabel, equals('#'));
      expect(
        DiveField.diveNumber.displayName != DiveField.diveNumber.shortLabel,
        isTrue,
      );

      expect(DiveField.avgDepth.displayName, equals('Average Depth'));
      expect(DiveField.avgDepth.shortLabel, equals('Avg D'));
      expect(
        DiveField.avgDepth.displayName != DiveField.avgDepth.shortLabel,
        isTrue,
      );

      expect(DiveField.sacRate.displayName, equals('SAC Rate'));
      expect(DiveField.sacRate.shortLabel, equals('SAC'));
      expect(
        DiveField.sacRate.displayName != DiveField.sacRate.shortLabel,
        isTrue,
      );

      expect(DiveField.diveMaster.displayName, equals('Dive Master'));
      expect(DiveField.diveMaster.shortLabel, equals('DM'));
      expect(
        DiveField.diveMaster.displayName != DiveField.diveMaster.shortLabel,
        isTrue,
      );
    });
  });
}
