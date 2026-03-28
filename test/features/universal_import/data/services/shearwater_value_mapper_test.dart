import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_value_mapper.dart';

void main() {
  group('ShearwaterValueMapper', () {
    group('unit conversions', () {
      test('converts PSI to bar', () {
        expect(ShearwaterValueMapper.psiToBar(2960), closeTo(204.1, 0.1));
      });
      test('converts Fahrenheit to Celsius', () {
        expect(
          ShearwaterValueMapper.fahrenheitToCelsius(72),
          closeTo(22.2, 0.1),
        );
        expect(ShearwaterValueMapper.fahrenheitToCelsius(32), closeTo(0, 0.1));
      });
      test('converts lbs to kg', () {
        expect(ShearwaterValueMapper.lbsToKg(14), closeTo(6.35, 0.01));
      });
      test('converts feet to meters', () {
        expect(ShearwaterValueMapper.feetToMeters(30), closeTo(9.14, 0.01));
      });
      test('converts mbar to bar', () {
        expect(ShearwaterValueMapper.mbarToBar(1015), closeTo(1.015, 0.001));
      });
    });

    group('conditions mapping', () {
      test('maps environment to waterType', () {
        expect(ShearwaterValueMapper.mapWaterType('Ocean/Sea'), WaterType.salt);
        expect(ShearwaterValueMapper.mapWaterType('Pool'), WaterType.fresh);
        expect(ShearwaterValueMapper.mapWaterType('Lake'), WaterType.fresh);
        expect(ShearwaterValueMapper.mapWaterType(null), isNull);
        expect(ShearwaterValueMapper.mapWaterType(''), isNull);
      });
      test('maps Brackish to WaterType.brackish', () {
        expect(
          ShearwaterValueMapper.mapWaterType('Brackish'),
          WaterType.brackish,
        );
      });
      test('maps weather to cloudCover', () {
        expect(ShearwaterValueMapper.mapCloudCover('Sunny'), CloudCover.clear);
        expect(
          ShearwaterValueMapper.mapCloudCover('Cloudy'),
          CloudCover.mostlyCloudy,
        );
        expect(ShearwaterValueMapper.mapCloudCover('Windy'), isNull);
      });
      test('maps conditions to currentStrength', () {
        expect(
          ShearwaterValueMapper.mapCurrentStrength('Current'),
          CurrentStrength.moderate,
        );
        expect(ShearwaterValueMapper.mapCurrentStrength('Surge'), isNull);
        expect(ShearwaterValueMapper.mapCurrentStrength(null), isNull);
      });
      test('maps visibility to enum', () {
        expect(
          ShearwaterValueMapper.mapVisibility('100', isImperial: true),
          Visibility.excellent,
        );
        expect(
          ShearwaterValueMapper.mapVisibility('30', isImperial: true),
          Visibility.moderate,
        );
        expect(
          ShearwaterValueMapper.mapVisibility('10', isImperial: true),
          Visibility.poor,
        );
        expect(
          ShearwaterValueMapper.mapVisibility('30', isImperial: false),
          Visibility.excellent,
        );
        expect(ShearwaterValueMapper.mapVisibility(null), isNull);
      });
    });

    group('buildExtraNotes', () {
      test('collects unmapped fields into structured notes', () {
        final notes = ShearwaterValueMapper.buildExtraNotes(
          weather: 'Windy',
          conditions: 'Surge',
          dress: 'Wet Suit',
          thermalComfort: 'Warm/Neutral',
          workload: 'Resting',
        );
        expect(notes, contains('[Shearwater Cloud]'));
        expect(notes, contains('Weather: Windy'));
        expect(notes, contains('Dress: Wet Suit'));
      });
      test('returns null when no extra fields present', () {
        final notes = ShearwaterValueMapper.buildExtraNotes();
        expect(notes, isNull);
      });
      test('includes gasNotes in extra notes', () {
        final notes = ShearwaterValueMapper.buildExtraNotes(gasNotes: 'EAN32');
        expect(notes, contains('Gas Notes: EAN32'));
      });
      test('includes issueNotes in extra notes', () {
        final notes = ShearwaterValueMapper.buildExtraNotes(
          issueNotes: 'Mask fog',
        );
        expect(notes, contains('Issue Notes: Mask fog'));
      });
      test('includes both gasNotes and issueNotes together', () {
        final notes = ShearwaterValueMapper.buildExtraNotes(
          gasNotes: 'EAN32',
          issueNotes: 'Mask fog',
        );
        expect(notes, contains('Gas Notes: EAN32'));
        expect(notes, contains('Issue Notes: Mask fog'));
      });
    });
  });
}
