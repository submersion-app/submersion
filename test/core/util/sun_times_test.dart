import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/core/util/sun_times.dart';

void main() {
  // Published sunrise and sunset tables round to the minute and differ by a
  // minute or two between sources, so every comparison allows three.
  Matcher near(DateTime expected) => predicate<DateTime>(
    (actual) => actual.difference(expected).inMinutes.abs() <= 3,
    'within 3 minutes of $expected',
  );

  group('SunCalculator.utcFor', () {
    test('a mid-latitude summer day (London, June solstice)', () {
      final sun = SunCalculator.utcFor(2025, 6, 21, 51.5074, -0.1278)!;
      expect(sun.sunrise, near(DateTime.utc(2025, 6, 21, 3, 43)));
      expect(sun.sunset, near(DateTime.utc(2025, 6, 21, 20, 21)));
    });

    test('the equator at an equinox has a twelve hour day', () {
      final sun = SunCalculator.utcFor(2025, 3, 20, 0, 0)!;
      expect(sun.sunrise, near(DateTime.utc(2025, 3, 20, 6, 4)));
      expect(sun.sunset, near(DateTime.utc(2025, 3, 20, 18, 11)));
    });

    test('a southern summer day (Sydney, December solstice)', () {
      // 05:41 and 20:05 on the local clock, eleven hours ahead of UTC, so
      // the sunrise instant falls on the previous UTC day.
      final sun = SunCalculator.utcFor(2025, 12, 21, -33.8688, 151.2093)!;
      expect(sun.sunrise, near(DateTime.utc(2025, 12, 20, 18, 41)));
      expect(sun.sunset, near(DateTime.utc(2025, 12, 21, 9, 5)));
    });

    test('sunrise comes before sunset and both are UTC', () {
      final sun = SunCalculator.utcFor(2025, 3, 1, 12.15, -68.27)!;
      expect(sun.sunrise.isUtc, isTrue);
      expect(sun.sunset.isUtc, isTrue);
      expect(sun.sunrise.isBefore(sun.sunset), isTrue);
    });

    test('polar night has no sunrise or sunset', () {
      expect(SunCalculator.utcFor(2025, 12, 21, 69.65, 18.96), isNull);
    });

    test('polar day has no sunrise or sunset', () {
      expect(SunCalculator.utcFor(2025, 6, 21, 69.65, 18.96), isNull);
    });

    test('coordinates that are not on the globe give nothing', () {
      expect(SunCalculator.utcFor(2025, 6, 21, 95, 0), isNull);
      expect(SunCalculator.utcFor(2025, 6, 21, 0, 200), isNull);
      expect(SunCalculator.utcFor(2025, 6, 21, double.nan, 0), isNull);
      expect(SunCalculator.utcFor(2025, 6, 21, 0, double.infinity), isNull);
    });
  });

  group('SunCalculator.wallClockFor', () {
    SunTimes? wall(DateTime date, double latitude, double longitude) =>
        SunCalculator.wallClockFor(
          date,
          latitude,
          longitude,
          SiteTimeZone.wallClockConverterFor(latitude, longitude),
        );

    test('reads on the site clock, daylight saving included', () {
      // London is on British Summer Time in June.
      final sun = wall(DateTime.utc(2025, 6, 21), 51.5074, -0.1278)!;
      expect(sun.sunrise, near(DateTime.utc(2025, 6, 21, 4, 43)));
      expect(sun.sunset, near(DateTime.utc(2025, 6, 21, 21, 21)));
    });

    test('only the calendar day of the date is read', () {
      final morning = wall(DateTime.utc(2025, 6, 21, 1), 51.5074, -0.1278)!;
      final evening = wall(DateTime.utc(2025, 6, 21, 23), 51.5074, -0.1278)!;
      expect(morning.sunrise, evening.sunrise);
      expect(morning.sunset, evening.sunset);
    });

    test('two sites in one time zone have different sunrise clocks', () {
      // Vigo and Mahon are both on Europe/Madrid, 13 degrees of longitude
      // apart: the sun is about 52 minutes later in the west.
      final vigo = wall(DateTime.utc(2025, 3, 20), 42.24, -8.72)!;
      final mahon = wall(DateTime.utc(2025, 3, 20), 39.89, 4.27)!;
      expect(
        SiteTimeZone.zoneIdFor(42.24, -8.72),
        SiteTimeZone.zoneIdFor(39.89, 4.27),
      );
      final lag = vigo.sunrise.difference(mahon.sunrise).inMinutes;
      expect(lag, inInclusiveRange(45, 60));
    });

    test(
      'stays on the dive date where the clock is a day ahead of the sun',
      () {
        // Kiritimati keeps UTC+14 at 157 degrees west, so the sun times for
        // a local date fall on the previous UTC day.
        final sun = wall(DateTime.utc(2025, 3, 20), 1.87, -157.4)!;
        expect((sun.sunrise.month, sun.sunrise.day), (3, 20));
        expect(sun.sunrise.hour, 6);
        expect((sun.sunset.month, sun.sunset.day), (3, 20));
        expect(sun.sunset.hour, 18);
      },
    );

    test('polar day and night give nothing', () {
      expect(wall(DateTime.utc(2025, 12, 21), 69.65, 18.96), isNull);
      expect(wall(DateTime.utc(2025, 6, 21), 69.65, 18.96), isNull);
    });
  });
}
