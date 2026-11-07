import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/first_day_of_week.dart';

void main() {
  group('resolveFirstWeekday', () {
    test('an explicit choice ignores the region', () {
      for (final region in ['US', 'CH', 'EG', null]) {
        expect(
          resolveFirstWeekday(FirstDayOfWeek.monday, region),
          DateTime.monday,
        );
        expect(
          resolveFirstWeekday(FirstDayOfWeek.sunday, region),
          DateTime.sunday,
        );
        expect(
          resolveFirstWeekday(FirstDayOfWeek.saturday, region),
          DateTime.saturday,
        );
      }
    });

    test('automatic follows the region', () {
      expect(resolveFirstWeekday(FirstDayOfWeek.auto, 'CH'), DateTime.monday);
      expect(resolveFirstWeekday(FirstDayOfWeek.auto, 'US'), DateTime.sunday);
      expect(resolveFirstWeekday(FirstDayOfWeek.auto, 'EG'), DateTime.saturday);
    });

    test('automatic without a region leaves the default to the caller', () {
      expect(resolveFirstWeekday(FirstDayOfWeek.auto, null), isNull);
      expect(resolveFirstWeekday(FirstDayOfWeek.auto, ''), isNull);
    });
  });

  group('firstWeekdayForRegion', () {
    test('follows the region, not the language', () {
      // English and Portuguese each start on different days by country.
      expect(firstWeekdayForRegion('US'), DateTime.sunday);
      expect(firstWeekdayForRegion('GB'), DateTime.monday);
      expect(firstWeekdayForRegion('BR'), DateTime.sunday);
      expect(firstWeekdayForRegion('AO'), DateTime.monday);
    });

    test('reads Saturday and Friday regions', () {
      expect(firstWeekdayForRegion('AE'), DateTime.saturday);
      expect(firstWeekdayForRegion('MV'), DateTime.friday);
    });

    test('ignores case', () {
      expect(firstWeekdayForRegion('us'), DateTime.sunday);
      expect(firstWeekdayForRegion('ch'), DateTime.monday);
    });

    test('an unlisted region starts on Monday', () {
      expect(firstWeekdayForRegion('DE'), DateTime.monday);
      expect(firstWeekdayForRegion('ZZ'), DateTime.monday);
    });
  });

  group('Material index conversion', () {
    test('maps DateTime.weekday onto 0 = Sunday .. 6 = Saturday', () {
      expect(materialWeekdayIndex(DateTime.sunday), 0);
      expect(materialWeekdayIndex(DateTime.monday), 1);
      expect(materialWeekdayIndex(DateTime.saturday), 6);
    });

    test('round-trips every weekday', () {
      for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
        expect(weekdayFromMaterialIndex(materialWeekdayIndex(day)), day);
      }
    });
  });

  group('firstNamedRegion', () {
    test('takes the first locale that names a region', () {
      expect(firstNamedRegion(['CH', 'US']), 'CH');
    });

    test('looks past a bare language to a later region', () {
      // A browser reporting ['de', 'de-CH'] still names Switzerland.
      expect(firstNamedRegion([null, 'CH']), 'CH');
      expect(firstNamedRegion(['', 'US']), 'US');
    });

    test('is null when no locale names a region', () {
      expect(firstNamedRegion(const []), isNull);
      expect(firstNamedRegion([null, '']), isNull);
    });
  });

  group('dateOnWeekday', () {
    test('falls on every weekday it is asked for', () {
      for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
        expect(dateOnWeekday(day).weekday, day);
      }
    });
  });

  group('weekdaysFrom', () {
    test('starts on the given day and wraps around', () {
      expect(weekdaysFrom(DateTime.monday), [1, 2, 3, 4, 5, 6, 7]);
      expect(weekdaysFrom(DateTime.sunday), [7, 1, 2, 3, 4, 5, 6]);
      expect(weekdaysFrom(DateTime.saturday), [6, 7, 1, 2, 3, 4, 5]);
    });
  });
}
