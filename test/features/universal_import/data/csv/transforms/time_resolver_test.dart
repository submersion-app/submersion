import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/time_resolver.dart';

void main() {
  late TimeResolver resolver;

  setUp(() {
    resolver = const TimeResolver();
  });

  // ---------------------------------------------------------------------------
  group('parseTime', () {
    test('parses 24-hour HH:mm -> 14:30', () {
      final result = resolver.parseTime('14:30');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
      expect(result.second, 0);
    });

    test('parses 24-hour H:mm -> 9:17', () {
      final result = resolver.parseTime('9:17');
      expect(result, isNotNull);
      expect(result!.hour, 9);
      expect(result.minute, 17);
    });

    test('parses 24-hour with seconds HH:mm:ss -> 14:30:45', () {
      final result = resolver.parseTime('14:30:45');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
      expect(result.second, 45);
    });

    test('parses 12-hour AM/PM "2:00 PM" -> 14:00 (fixes #63)', () {
      final result = resolver.parseTime('2:00 PM');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 0);
    });

    test(
      'parses 12-hour with seconds "02:00:00 PM" -> 14:00:00 (fixes #63)',
      () {
        final result = resolver.parseTime('02:00:00 PM');
        expect(result, isNotNull);
        expect(result!.hour, 14);
        expect(result.minute, 0);
        expect(result.second, 0);
      },
    );

    test('parses 12-hour AM "11:30:00 AM" -> 11:30', () {
      final result = resolver.parseTime('11:30:00 AM');
      expect(result, isNotNull);
      expect(result!.hour, 11);
      expect(result.minute, 30);
      expect(result.second, 0);
    });

    test('parses 12:00 PM -> noon (12)', () {
      final result = resolver.parseTime('12:00 PM');
      expect(result, isNotNull);
      expect(result!.hour, 12);
      expect(result.minute, 0);
    });

    test('parses 12:00 AM -> midnight (0)', () {
      final result = resolver.parseTime('12:00 AM');
      expect(result, isNotNull);
      expect(result!.hour, 0);
      expect(result.minute, 0);
    });

    test('returns null for unparseable', () {
      expect(resolver.parseTime(null), isNull);
      expect(resolver.parseTime(''), isNull);
      expect(resolver.parseTime('not-a-time'), isNull);
      expect(resolver.parseTime('99:99'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('parseDate', () {
    test('parses yyyy-MM-dd -> UTC', () {
      final result = resolver.parseDate('2023-07-15');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.isUtc, isTrue);
    });

    test('parses MM/dd/yyyy', () {
      final result = resolver.parseDate('07/15/2023');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
    });

    test('parses dd.MM.yyyy', () {
      final result = resolver.parseDate('15.07.2023');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
    });

    test('returns null for unparseable', () {
      expect(resolver.parseDate(null), isNull);
      expect(resolver.parseDate(''), isNull);
      expect(resolver.parseDate('not-a-date'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('combineDateTime', () {
    test('combines date+time as UTC wall-time', () {
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        timeStr: '09:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 9);
      expect(result.minute, 0);
    });

    test('time not shifted by UTC offset (issue #60)', () {
      // Wall-clock "09:17" should remain hour=9, not shifted by any offset.
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        timeStr: '09:17',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.hour, 9);
      expect(result.minute, 17);
    });

    test('handles date only -> defaults to noon', () {
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.hour, 12);
      expect(result.minute, 0);
    });

    test('parses single dateTime column', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15 14:30:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });

    test(
      'ISO 8601 with offset extracts wall-clock (09:17:19-04:00 -> hour 9)',
      () {
        final result = resolver.combineDateTime(
          dateTimeStr: '2023-07-15T09:17:19-04:00',
          interpretation: TimeInterpretation.localWallClock,
        );
        expect(result, isNotNull);
        // Wall-clock extraction: hour should be 9, not shifted to UTC (13)
        expect(result!.hour, 9);
        expect(result.minute, 17);
        expect(result.second, 19);
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('resolveInformalTimes', () {
    test('assigns defaults for am/pm/night tokens', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'pm'},
        {'date': '2023-07-15', 'time': 'night'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect(result[0]['_informalTime'], isTrue);
      expect(result[1]['_informalTime'], isTrue);
      expect(result[2]['_informalTime'], isTrue);

      final dt0 = result[0]['dateTime'] as DateTime;
      final dt1 = result[1]['dateTime'] as DateTime;
      final dt2 = result[2]['dateTime'] as DateTime;

      expect(dt0.hour, 9); // first am -> 09:00
      expect(dt1.hour, 14); // first pm -> 14:00
      expect(dt2.hour, 19); // first night -> 19:00
    });

    test('increments for multiple dives on same date', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'am'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      final dt0 = result[0]['dateTime'] as DateTime;
      final dt1 = result[1]['dateTime'] as DateTime;
      final dt2 = result[2]['dateTime'] as DateTime;

      expect(dt0.hour, 9); // first am
      expect(dt1.hour, 11); // second am
      expect(dt2.hour, 12); // third am
    });

    test('assigns noon default for empty time values', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': ''},
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect(result[0]['_informalTime'], isTrue);
      final dt = result[0]['dateTime'] as DateTime;
      expect(dt.hour, 12);
    });

    test('passes through valid times unchanged', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': '09:30'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect(result[0].containsKey('_informalTime'), isFalse);
      expect(result[0].containsKey('dateTime'), isFalse);
    });

    test('handles morning/afternoon/evening synonyms', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'morning'},
        {'date': '2023-07-15', 'time': 'afternoon'},
        {'date': '2023-07-15', 'time': 'evening'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect(result[0]['_informalTime'], isTrue);
      expect(result[1]['_informalTime'], isTrue);
      expect(result[2]['_informalTime'], isTrue);

      final dt0 = result[0]['dateTime'] as DateTime;
      final dt1 = result[1]['dateTime'] as DateTime;
      final dt2 = result[2]['dateTime'] as DateTime;

      expect(dt0.hour, 9); // morning -> 09:00
      expect(dt1.hour, 14); // afternoon -> 14:00
      expect(dt2.hour, 19); // evening -> 19:00
    });
  });

  // ---------------------------------------------------------------------------
  group('isInformalToken', () {
    test('returns true for known tokens', () {
      expect(resolver.isInformalToken('am'), isTrue);
      expect(resolver.isInformalToken('pm'), isTrue);
      expect(resolver.isInformalToken('AM'), isTrue);
      expect(resolver.isInformalToken('morning'), isTrue);
      expect(resolver.isInformalToken('afternoon'), isTrue);
      expect(resolver.isInformalToken('evening'), isTrue);
      expect(resolver.isInformalToken('night'), isTrue);
    });

    test('returns true for empty/null', () {
      expect(resolver.isInformalToken(null), isTrue);
      expect(resolver.isInformalToken(''), isTrue);
      expect(resolver.isInformalToken('  '), isTrue);
    });

    test('returns false for valid times', () {
      expect(resolver.isInformalToken('09:30'), isFalse);
      expect(resolver.isInformalToken('14:00:00'), isFalse);
      expect(resolver.isInformalToken('2:00 PM'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('parseDate - additional formats', () {
    test('parses M/d/yyyy (single-digit month and day)', () {
      final result = resolver.parseDate('7/5/2023');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 5);
      expect(result.isUtc, isTrue);
    });

    test('parses d.M.yyyy (single-digit day and month)', () {
      final result = resolver.parseDate('5.7.2023');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 5);
      expect(result.isUtc, isTrue);
    });

    test('parses yyyy/MM/dd', () {
      final result = resolver.parseDate('2023/07/15');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.isUtc, isTrue);
    });

    test('parses dd-MM-yyyy', () {
      final result = resolver.parseDate('15-07-2023');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.isUtc, isTrue);
    });

    test('parses MM-dd-yyyy', () {
      final result = resolver.parseDate('03-25-2023');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 3);
      expect(result.day, 25);
      expect(result.isUtc, isTrue);
    });

    test('parses ISO 8601 date via fallback (DateTime.parse)', () {
      // Full ISO 8601 datetime string -- parseDate should extract the date part.
      final result = resolver.parseDate('2023-07-15T09:17:19Z');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 0); // midnight UTC -- date only
      expect(result.isUtc, isTrue);
    });

    test('parses ISO 8601 date with offset via fallback', () {
      final result = resolver.parseDate('2023-07-15T09:17:19-04:00');
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      // Date portion is extracted; exact day depends on UTC conversion of the
      // parsed value, but the year/month should be correct.
      expect(result.isUtc, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('combineDateTime - TimeInterpretation.utc', () {
    test('stores wall-clock components directly as UTC', () {
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        timeStr: '14:30',
        interpretation: TimeInterpretation.utc,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });

    test('dateTime string with utc interpretation', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15 09:00:00',
        interpretation: TimeInterpretation.utc,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 9);
      expect(result.minute, 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('combineDateTime - TimeInterpretation.specificOffset', () {
    test('preserves wall-clock components as UTC with specific offset', () {
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        timeStr: '09:17',
        interpretation: TimeInterpretation.specificOffset,
        specificOffset: const Duration(hours: -4),
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      // Wall-clock is preserved as-is in UTC encoding.
      expect(result.hour, 9);
      expect(result.minute, 17);
    });

    test('dateTime string with specificOffset interpretation', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15 14:30:00',
        interpretation: TimeInterpretation.specificOffset,
        specificOffset: const Duration(hours: 5, minutes: 30),
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });

    test('date-only with specificOffset defaults to noon', () {
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        interpretation: TimeInterpretation.specificOffset,
        specificOffset: const Duration(hours: 2),
      );
      expect(result, isNotNull);
      expect(result!.hour, 12);
      expect(result.minute, 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('combineDateTime - dateTimeStr combined formats', () {
    test('parses "yyyy-MM-dd HH:mm" (no seconds)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15 14:30',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 14);
      expect(result.minute, 30);
      expect(result.second, 0);
    });

    test('parses "yyyy-MM-dd H:mm:ss" (single-digit hour)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15 9:17:19',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.hour, 9);
      expect(result.minute, 17);
      expect(result.second, 19);
    });

    test('parses "yyyy-MM-dd H:mm" (single-digit hour, no seconds)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15 9:17',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.hour, 9);
      expect(result.minute, 17);
    });

    test('parses "MM/dd/yyyy HH:mm:ss"', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '07/15/2023 14:30:45',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 14);
      expect(result.minute, 30);
      expect(result.second, 45);
    });

    test('parses "MM/dd/yyyy HH:mm"', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '07/15/2023 14:30',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });

    test('returns null for unparseable dateTimeStr', () {
      final result = resolver.combineDateTime(
        dateTimeStr: 'not-a-date-time',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNull);
    });

    test('dateTimeStr takes precedence over dateStr/timeStr', () {
      final result = resolver.combineDateTime(
        dateStr: '2020-01-01',
        timeStr: '08:00',
        dateTimeStr: '2023-07-15 14:30:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      // dateTimeStr wins -- date and time from the combined string.
      expect(result!.year, 2023);
      expect(result.hour, 14);
    });

    test('empty dateTimeStr falls through to dateStr/timeStr', () {
      final result = resolver.combineDateTime(
        dateStr: '2023-07-15',
        timeStr: '09:00',
        dateTimeStr: '  ',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.year, 2023);
      expect(result.hour, 9);
    });

    test('pure ISO 8601 without offset via dateTimeStr', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15T14:30:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });
  });

  // ---------------------------------------------------------------------------
  group('combineDateTime - ISO 8601 with offset (wall-clock extraction)', () {
    test('extracts wall-clock from positive offset (+05:30)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15T14:30:00+05:30',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      // Wall-clock at +05:30 should be 14:30.
      expect(result.hour, 14);
      expect(result.minute, 30);
      expect(result.second, 0);
    });

    test('extracts wall-clock from Z suffix (UTC)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15T09:17:19Z',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      // Z means UTC; wall-clock == UTC components.
      expect(result.hour, 9);
      expect(result.minute, 17);
      expect(result.second, 19);
    });

    test('extracts wall-clock from +00:00 offset', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15T09:17:19+00:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 9);
      expect(result.minute, 17);
      expect(result.second, 19);
    });

    test('extracts wall-clock from large negative offset (-12:00)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15T06:00:00-12:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 6);
      expect(result.minute, 0);
    });

    test('extracts wall-clock with half-hour offset (-09:30)', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2023-07-15T22:45:00-09:30',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 22);
      expect(result.minute, 45);
    });
  });

  // ---------------------------------------------------------------------------
  group('ResolvedTime', () {
    test('toString pads single-digit values', () {
      const t = ResolvedTime(9, 5, 3);
      expect(t.toString(), '09:05:03');
    });

    test('toString formats double-digit values', () {
      const t = ResolvedTime(14, 30, 45);
      expect(t.toString(), '14:30:45');
    });

    test('toString formats midnight', () {
      const t = ResolvedTime(0, 0, 0);
      expect(t.toString(), '00:00:00');
    });
  });

  // ---------------------------------------------------------------------------
  group('_bucketFor behavior via resolveInformalTimes', () {
    test('"morning" maps to am bucket (starts at hour 9)', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'morning'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      final dt = result[0]['dateTime'] as DateTime;
      expect(dt.hour, 9); // am bucket default start
    });

    test('"evening" maps to night bucket (starts at hour 19)', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'evening'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      final dt = result[0]['dateTime'] as DateTime;
      expect(dt.hour, 19); // night bucket default start
    });
  });

  // ---------------------------------------------------------------------------
  group('_defaultsForBucket cycling via resolveInformalTimes', () {
    test('am bucket cycles: 9, 11, 12, then wraps back to 9', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'am'}, // 4th wraps
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect((result[0]['dateTime'] as DateTime).hour, 9);
      expect((result[1]['dateTime'] as DateTime).hour, 11);
      expect((result[2]['dateTime'] as DateTime).hour, 12);
      // 4th dive wraps around to index 3 % 3 = 0 -> hour 9
      expect((result[3]['dateTime'] as DateTime).hour, 9);
    });

    test('pm bucket cycles: 14, 16, 17, then wraps back to 14', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'pm'},
        {'date': '2023-07-15', 'time': 'pm'},
        {'date': '2023-07-15', 'time': 'pm'},
        {'date': '2023-07-15', 'time': 'pm'}, // 4th wraps
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect((result[0]['dateTime'] as DateTime).hour, 14);
      expect((result[1]['dateTime'] as DateTime).hour, 16);
      expect((result[2]['dateTime'] as DateTime).hour, 17);
      expect((result[3]['dateTime'] as DateTime).hour, 14);
    });

    test('night bucket cycles: 19, 21, 22, then wraps back to 19', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'night'},
        {'date': '2023-07-15', 'time': 'night'},
        {'date': '2023-07-15', 'time': 'night'},
        {'date': '2023-07-15', 'time': 'night'}, // 4th wraps
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect((result[0]['dateTime'] as DateTime).hour, 19);
      expect((result[1]['dateTime'] as DateTime).hour, 21);
      expect((result[2]['dateTime'] as DateTime).hour, 22);
      expect((result[3]['dateTime'] as DateTime).hour, 19);
    });

    test('empty bucket cycles: 12, 14, 16, then wraps back to 12', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': ''},
        {'date': '2023-07-15', 'time': ''},
        {'date': '2023-07-15', 'time': ''},
        {'date': '2023-07-15', 'time': ''}, // 4th wraps
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect((result[0]['dateTime'] as DateTime).hour, 12);
      expect((result[1]['dateTime'] as DateTime).hour, 14);
      expect((result[2]['dateTime'] as DateTime).hour, 16);
      expect((result[3]['dateTime'] as DateTime).hour, 12);
    });

    test('counters are per-date so different dates start fresh', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-16', 'time': 'am'}, // new date resets counter
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect((result[0]['dateTime'] as DateTime).hour, 9); // first am on day 15
      expect(
        (result[1]['dateTime'] as DateTime).hour,
        11,
      ); // second am on day 15
      expect((result[2]['dateTime'] as DateTime).hour, 9); // first am on day 16
    });

    test('mixed tokens on same date use independent counters per bucket', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': 'am'},
        {'date': '2023-07-15', 'time': 'pm'},
        {'date': '2023-07-15', 'time': 'am'}, // second am
        {'date': '2023-07-15', 'time': 'pm'}, // second pm
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect((result[0]['dateTime'] as DateTime).hour, 9); // 1st am
      expect((result[1]['dateTime'] as DateTime).hour, 14); // 1st pm
      expect((result[2]['dateTime'] as DateTime).hour, 11); // 2nd am
      expect((result[3]['dateTime'] as DateTime).hour, 16); // 2nd pm
    });
  });

  // ---------------------------------------------------------------------------
  group('parseTime - ISO 8601 fallback path', () {
    test('parses valid raw time via ISO fallback (e.g. 08:30:00)', () {
      // "08:30:00" passes _looksLikeRawTime and is parsed via DateTime.parse
      // as "1970-01-01T08:30:00".
      final result = resolver.parseTime('08:30:00');
      expect(result, isNotNull);
      expect(result!.hour, 8);
      expect(result.minute, 30);
      expect(result.second, 0);
    });

    test('rejects out-of-range hour via _looksLikeRawTime', () {
      // 25:00 has hour > 23, so _looksLikeRawTime returns false.
      final result = resolver.parseTime('25:00');
      expect(result, isNull);
    });

    test('rejects out-of-range minute via _looksLikeRawTime', () {
      // 12:60 has minute > 59.
      final result = resolver.parseTime('12:60');
      expect(result, isNull);
    });

    test('rejects out-of-range second via _looksLikeRawTime', () {
      // 12:30:60 has second > 59.
      final result = resolver.parseTime('12:30:60');
      expect(result, isNull);
    });

    test('rejects non-matching pattern via _looksLikeRawTime', () {
      // "abc:de" does not match the numeric pattern.
      final result = resolver.parseTime('abc:de');
      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('resolveInformalTimes - null date handling', () {
    test('assigns fallback 1970-01-01 when date is unparseable', () {
      final rows = <Map<String, dynamic>>[
        {'date': 'not-a-date', 'time': 'am'},
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect(result[0]['_informalTime'], isTrue);
      final dt = result[0]['dateTime'] as DateTime;
      // With an unparseable date, fallback is 1970-01-01 at the default hour.
      expect(dt.year, 1970);
      expect(dt.hour, 9); // am bucket default
    });
  });

  // ---------------------------------------------------------------------------
  group('resolveInformalTimes - null time value', () {
    test('treats null time as informal and assigns empty bucket default', () {
      final rows = <Map<String, dynamic>>[
        {'date': '2023-07-15', 'time': null},
      ];

      final result = resolver.resolveInformalTimes(rows);

      expect(result[0]['_informalTime'], isTrue);
      final dt = result[0]['dateTime'] as DateTime;
      expect(dt.hour, 12); // empty bucket default start
    });
  });

  // ---------------------------------------------------------------------------
  group('combineDateTime - returns null for null date', () {
    test('returns null when dateStr is null and no dateTimeStr', () {
      final result = resolver.combineDateTime(
        dateStr: null,
        timeStr: '09:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNull);
    });

    test('returns null when dateStr is unparseable and no dateTimeStr', () {
      final result = resolver.combineDateTime(
        dateStr: 'not-a-date',
        timeStr: '09:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNull);
    });
  });
}
