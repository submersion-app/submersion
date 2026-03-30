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
}
