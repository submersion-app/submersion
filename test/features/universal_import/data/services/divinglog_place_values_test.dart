import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_place_values.dart';

void main() {
  group('waterType', () {
    test('reads the three water codes', () {
      expect(DivingLogPlaceValues.waterType(1), WaterType.salt);
      expect(DivingLogPlaceValues.waterType(2), WaterType.fresh);
      expect(DivingLogPlaceValues.waterType(3), WaterType.brackish);
    });

    test('leaves an unset or unknown code empty', () {
      expect(DivingLogPlaceValues.waterType(null), isNull);
      expect(DivingLogPlaceValues.waterType(0), isNull);
      expect(DivingLogPlaceValues.waterType(4), isNull);
    });
  });

  group('difficulty', () {
    test('reads the level names in any case', () {
      expect(
        DivingLogPlaceValues.difficulty('Beginner'),
        SiteDifficulty.beginner,
      );
      expect(
        DivingLogPlaceValues.difficulty(' intermediate '),
        SiteDifficulty.intermediate,
      );
      expect(
        DivingLogPlaceValues.difficulty('ADVANCED'),
        SiteDifficulty.advanced,
      );
      expect(
        DivingLogPlaceValues.difficulty('Technical'),
        SiteDifficulty.technical,
      );
    });

    test('reads Easy and Novice as beginner', () {
      expect(DivingLogPlaceValues.difficulty('Easy'), SiteDifficulty.beginner);
      expect(
        DivingLogPlaceValues.difficulty('Novice'),
        SiteDifficulty.beginner,
      );
    });

    test('leaves a label it does not know empty', () {
      expect(DivingLogPlaceValues.difficulty('Spicy'), isNull);
      expect(DivingLogPlaceValues.difficulty(''), isNull);
      expect(DivingLogPlaceValues.difficulty(null), isNull);
    });
  });

  group('rating', () {
    test('reads a star count', () {
      expect(DivingLogPlaceValues.rating(2), 2.0);
      expect(DivingLogPlaceValues.rating(5), 5.0);
    });

    test('reads zero as unrated rather than as no stars', () {
      expect(DivingLogPlaceValues.rating(0), isNull);
      expect(DivingLogPlaceValues.rating(null), isNull);
    });

    test('clamps a rating above five', () {
      expect(DivingLogPlaceValues.rating(9), 5.0);
    });
  });

  group('altitudeMeters', () {
    test('reads Sea Level as zero metres', () {
      expect(DivingLogPlaceValues.altitudeMeters('Sea Level'), 0.0);
      expect(DivingLogPlaceValues.altitudeMeters(' sea level '), 0.0);
    });

    test('reads a bare number as metres', () {
      expect(
        DivingLogPlaceValues.altitudeMeters('310.5'),
        closeTo(310.5, 1e-9),
      );
    });

    test('reads a metre or foot unit', () {
      expect(DivingLogPlaceValues.altitudeMeters('450 m'), closeTo(450, 1e-9));
      expect(
        DivingLogPlaceValues.altitudeMeters('1000 ft'),
        closeTo(1000 / 3.28084, 1e-6),
      );
      expect(
        DivingLogPlaceValues.altitudeMeters('1000feet'),
        closeTo(1000 / 3.28084, 1e-6),
      );
    });

    test('keeps a site below sea level', () {
      expect(
        DivingLogPlaceValues.altitudeMeters('-430 m'),
        closeTo(-430, 1e-9),
      );
    });

    test('reads a numeric zero as not recorded', () {
      // Diving Log writes 0 into fields it never filled in; only the
      // explicit Sea Level text says the site is at zero.
      expect(DivingLogPlaceValues.altitudeMeters('0'), isNull);
    });

    test('leaves text it cannot read empty', () {
      expect(DivingLogPlaceValues.altitudeMeters('1004 mbar'), isNull);
      expect(DivingLogPlaceValues.altitudeMeters('high'), isNull);
      expect(DivingLogPlaceValues.altitudeMeters('NaN'), isNull);
      expect(DivingLogPlaceValues.altitudeMeters(''), isNull);
      expect(DivingLogPlaceValues.altitudeMeters(null), isNull);
    });
  });
}
