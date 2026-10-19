import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/util/sun_times.dart';
import 'package:submersion/features/insights/domain/time_of_day_bucket.dart';

/// A wall clock on 1 March 2025; [day] moves it to a later date.
DateTime at(int hour, [int minute = 0, int day = 1]) =>
    DateTime.utc(2025, 3, day, hour, minute);

void main() {
  group('TimeOfDayBucket', () {
    test('keys are stable and listed in the order of the day', () {
      expect(TimeOfDayBucket.values.map((b) => b.key), [
        'Dawn',
        'Morning',
        'Afternoon',
        'Dusk',
        'Night',
      ]);
    });

    test('a key reads back as its bucket, anything else as nothing', () {
      for (final bucket in TimeOfDayBucket.values) {
        expect(TimeOfDayBucket.fromKey(bucket.key), bucket);
      }
      expect(TimeOfDayBucket.fromKey('Evening'), isNull);
    });
  });

  group('TimeOfDayClassifier.bucketFor', () {
    // Sunrise 06:49 and sunset 18:42, nothing like the fallback hours.
    TimeOfDayBucket bucket(DateTime entry, [DateTime? exit]) =>
        TimeOfDayClassifier.bucketFor(
          entry: entry,
          exit: exit,
          sunrise: at(6, 49),
          sunset: at(18, 42),
          nextSunrise: at(6, 48, 2),
        );

    test('dawn: in before sunrise, out after it', () {
      expect(bucket(at(6, 30), at(7, 15)), TimeOfDayBucket.dawn);
    });

    test('morning: in after sunrise and before midday', () {
      expect(bucket(at(6, 49), at(7, 30)), TimeOfDayBucket.morning);
      expect(bucket(at(11, 59), at(12, 45)), TimeOfDayBucket.morning);
    });

    test('afternoon: in from midday, out before sunset', () {
      expect(bucket(at(12), at(12, 50)), TimeOfDayBucket.afternoon);
      expect(bucket(at(18, 15), at(18, 35)), TimeOfDayBucket.afternoon);
    });

    test('dusk: in before sunset, out after it', () {
      expect(bucket(at(18, 15), at(19)), TimeOfDayBucket.dusk);
    });

    test('night: the whole dive is in darkness', () {
      expect(bucket(at(19, 30), at(20, 15)), TimeOfDayBucket.night);
      expect(bucket(at(18, 42), at(19, 30)), TimeOfDayBucket.night);
      // After midnight and out before sunrise.
      expect(bucket(at(5), at(5, 45)), TimeOfDayBucket.night);
    });

    test('a dive that ends exactly at sunrise or sunset did not cross it', () {
      expect(bucket(at(6), at(6, 49)), TimeOfDayBucket.night);
      expect(bucket(at(18), at(18, 42)), TimeOfDayBucket.afternoon);
    });

    test('crossing sunrise or sunset wins over the entry time', () {
      // A morning entry that runs past sunset is a dusk dive.
      expect(bucket(at(11), at(19)), TimeOfDayBucket.dusk);
      // Dawn is checked first, so a dive across both is a dawn dive.
      expect(bucket(at(5), at(19)), TimeOfDayBucket.dawn);
    });

    test('a dive past midnight is measured against the next sunrise', () {
      expect(bucket(at(23), at(1, 0, 2)), TimeOfDayBucket.night);
      expect(bucket(at(23), at(7, 0, 2)), TimeOfDayBucket.dawn);
    });

    test('without the next sunrise it is taken as a day after this one', () {
      TimeOfDayBucket noNext(DateTime entry, DateTime exit) =>
          TimeOfDayClassifier.bucketFor(
            entry: entry,
            exit: exit,
            sunrise: at(6, 49),
            sunset: at(18, 42),
          );
      expect(noNext(at(23), at(6, 40, 2)), TimeOfDayBucket.night);
      expect(noNext(at(23), at(7, 0, 2)), TimeOfDayBucket.dawn);
    });

    test('with no exit the entry alone decides, never dawn or dusk', () {
      expect(bucket(at(6, 30)), TimeOfDayBucket.night);
      expect(bucket(at(9)), TimeOfDayBucket.morning);
      expect(bucket(at(18, 15)), TimeOfDayBucket.afternoon);
      expect(bucket(at(21)), TimeOfDayBucket.night);
    });

    test('an exit at or before the entry is no exit at all', () {
      expect(bucket(at(6, 30), at(6, 30)), TimeOfDayBucket.night);
      expect(bucket(at(18, 15), at(17)), TimeOfDayBucket.afternoon);
    });
  });

  group('TimeOfDayClassifier.classify without a location', () {
    final classifier = TimeOfDayClassifier();

    TimeOfDayBucket bucket(DateTime entry, [DateTime? exit]) {
      final result = classifier.classify(entry: entry, exit: exit);
      expect(result.basis, SunTimesBasis.noLocation);
      return result.bucket;
    }

    test('06:00 stands in for sunrise', () {
      expect(bucket(at(5, 30), at(6, 30)), TimeOfDayBucket.dawn);
      expect(bucket(at(5), at(5, 45)), TimeOfDayBucket.night);
      expect(bucket(at(6), at(6, 45)), TimeOfDayBucket.morning);
    });

    test('18:00 stands in for sunset', () {
      expect(bucket(at(17, 30), at(18, 30)), TimeOfDayBucket.dusk);
      expect(bucket(at(17), at(17, 45)), TimeOfDayBucket.afternoon);
      expect(bucket(at(18), at(18, 45)), TimeOfDayBucket.night);
    });

    test('midday is still 12:00', () {
      expect(bucket(at(11, 59), at(12, 40)), TimeOfDayBucket.morning);
      expect(bucket(at(12), at(12, 40)), TimeOfDayBucket.afternoon);
    });

    test('a dive past midnight uses the next 06:00', () {
      expect(bucket(at(23), at(1, 0, 2)), TimeOfDayBucket.night);
      expect(bucket(at(4, 30), at(6, 30)), TimeOfDayBucket.dawn);
      expect(bucket(at(23), at(7, 0, 2)), TimeOfDayBucket.dawn);
    });

    test('with no exit the entry alone decides', () {
      expect(bucket(at(5, 30)), TimeOfDayBucket.night);
      expect(bucket(at(17, 59)), TimeOfDayBucket.afternoon);
    });

    test('half a coordinate, or one off the globe, is no location', () {
      for (final (latitude, longitude) in <(double?, double?)>[
        (12.15, null),
        (null, -68.27),
        (95.0, 10.0),
        (10.0, 200.0),
        (double.nan, 10.0),
      ]) {
        final result = classifier.classify(
          entry: at(9),
          latitude: latitude,
          longitude: longitude,
        );
        expect(result.basis, SunTimesBasis.noLocation);
        expect(result.bucket, TimeOfDayBucket.morning);
      }
    });

    test('the fallback is the same rule on the entry alone', () {
      TimeOfDayBucket bucket(int hour) =>
          classifier.classify(entry: at(hour)).bucket;
      expect(bucket(5), TimeOfDayBucket.night);
      expect(bucket(6), TimeOfDayBucket.morning);
      expect(bucket(12), TimeOfDayBucket.afternoon);
      expect(bucket(18), TimeOfDayBucket.night);
    });
  });

  group('TimeOfDayClassifier.classify at a site', () {
    // Bonaire on 1 March 2025: sunrise near 06:49, sunset near 18:42, and no
    // daylight saving. Each dive below lands in a different bucket than the
    // 06:00 / 18:00 fallback would give it.
    const latitude = 12.15;
    const longitude = -68.27;
    final classifier = TimeOfDayClassifier();

    TimeOfDayClassification classify(DateTime entry, [DateTime? exit]) =>
        classifier.classify(
          entry: entry,
          exit: exit,
          latitude: latitude,
          longitude: longitude,
        );

    test('buckets against the site sunrise and sunset', () {
      expect(classify(at(6, 20), at(7, 10)).bucket, TimeOfDayBucket.dawn);
      expect(classify(at(6, 5), at(6, 35)).bucket, TimeOfDayBucket.night);
      expect(classify(at(18, 5), at(18, 30)).bucket, TimeOfDayBucket.afternoon);
      expect(classify(at(18, 10), at(19)).bucket, TimeOfDayBucket.dusk);
      expect(classify(at(19, 30), at(20, 15)).bucket, TimeOfDayBucket.night);
      expect(classify(at(9), at(9, 50)).bucket, TimeOfDayBucket.morning);
    });

    test('reports that the site decided', () {
      expect(classify(at(9), at(9, 50)).basis, SunTimesBasis.site);
    });

    test('a dive past midnight is measured against the next sunrise', () {
      expect(classify(at(23), at(0, 30, 2)).bucket, TimeOfDayBucket.night);
      expect(classify(at(23), at(7, 30, 2)).bucket, TimeOfDayBucket.dawn);
    });

    test('daylight saving is on the site clock', () {
      // London, 21 June: sunrise 04:43 and sunset 21:21 British Summer Time.
      TimeOfDayBucket london(DateTime entry, DateTime exit) => classifier
          .classify(
            entry: entry,
            exit: exit,
            latitude: 51.5074,
            longitude: -0.1278,
          )
          .bucket;
      expect(
        london(DateTime.utc(2025, 6, 21, 20), DateTime.utc(2025, 6, 21, 21)),
        TimeOfDayBucket.afternoon,
      );
      expect(
        london(DateTime.utc(2025, 6, 21, 21), DateTime.utc(2025, 6, 21, 22)),
        TimeOfDayBucket.dusk,
      );
      expect(
        london(DateTime.utc(2025, 6, 21, 4), DateTime.utc(2025, 6, 21, 5)),
        TimeOfDayBucket.dawn,
      );
    });

    test('a dive across sunset and the next sunrise is Dusk', () {
      // Sunset was crossed first; reaching the next sunrise does not make an
      // afternoon entry a dawn dive.
      expect(classify(at(17), at(7, 30, 2)).bucket, TimeOfDayBucket.dusk);
    });

    test('0,0 coordinates are no location', () {
      final result = classifier.classify(
        entry: at(17, 40),
        exit: at(18, 30),
        latitude: 0,
        longitude: 0,
      );
      expect(result.basis, SunTimesBasis.noLocation);
      expect(result.bucket, TimeOfDayBucket.dusk);
    });

    test('a late daylight dive at high latitude is Afternoon', () {
      // Reykjavik, 1 June: sunset near 23:39 on a UTC clock with no daylight
      // saving. A 22:30 dive is still in daylight, so the rules make it
      // Afternoon; accepted deliberately on PR #3345 review.
      final result = classifier.classify(
        entry: DateTime.utc(2025, 6, 1, 22, 30),
        exit: DateTime.utc(2025, 6, 1, 23, 15),
        latitude: 64.1466,
        longitude: -21.9426,
      );
      expect(result.basis, SunTimesBasis.site);
      expect(result.bucket, TimeOfDayBucket.afternoon);
    });

    test('a next day with no sunrise takes the fallback sunrise', () {
      // Tromso: find the last day with a sunrise before polar night.
      const latitude = 69.65;
      const longitude = 18.96;
      var day = DateTime.utc(2025, 11, 1);
      while (SunCalculator.utcFor(
            day.year,
            day.month,
            day.day + 1,
            latitude,
            longitude,
          ) !=
          null) {
        day = DateTime.utc(day.year, day.month, day.day + 1);
      }
      // In after dark, out at 06:30 the next day: past the 06:00 fallback
      // sunrise, though long before the last real sunrise plus a day.
      final result = classifier.classify(
        entry: DateTime.utc(day.year, day.month, day.day, 23),
        exit: DateTime.utc(day.year, day.month, day.day + 1, 6, 30),
        latitude: latitude,
        longitude: longitude,
      );
      expect(result.basis, SunTimesBasis.site);
      expect(result.bucket, TimeOfDayBucket.dawn);
    });

    test('polar night falls back to the clock and says so', () {
      final result = classifier.classify(
        entry: DateTime.utc(2025, 12, 21, 12, 30),
        exit: DateTime.utc(2025, 12, 21, 13, 10),
        latitude: 69.65,
        longitude: 18.96,
      );
      expect(result.basis, SunTimesBasis.noSunEvent);
      expect(result.bucket, TimeOfDayBucket.afternoon);
    });

    test('polar day falls back to the clock too', () {
      final result = classifier.classify(
        entry: DateTime.utc(2025, 6, 21, 17, 30),
        exit: DateTime.utc(2025, 6, 21, 18, 30),
        latitude: 69.65,
        longitude: 18.96,
      );
      expect(result.basis, SunTimesBasis.noSunEvent);
      expect(result.bucket, TimeOfDayBucket.dusk);
    });

    test('classifying the same site twice gives the same answer', () {
      // The zone for a site is resolved once and reused.
      expect(classify(at(6, 20), at(7, 10)), classify(at(6, 20), at(7, 10)));
    });
  });
}
