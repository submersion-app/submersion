import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_dive_start_time.dart';

pigeon.ParsedDive _parsed({
  int year = 2026,
  int month = 3,
  int day = 14,
  int hour = 9,
  int minute = 30,
  int second = 15,
}) => pigeon.ParsedDive(
  fingerprint: 'fp',
  dateTimeYear: year,
  dateTimeMonth: month,
  dateTimeDay: day,
  dateTimeHour: hour,
  dateTimeMinute: minute,
  dateTimeSecond: second,
  maxDepthMeters: 20,
  avgDepthMeters: 10,
  durationSeconds: 2400,
  samples: const [],
  tanks: const [],
  gasMixes: const [],
  events: const [],
);

void main() {
  group('parsedDiveStartTime', () {
    test('returns the parsed components as wall-clock UTC', () {
      expect(
        parsedDiveStartTime(_parsed()),
        DateTime.utc(2026, 3, 14, 9, 30, 15),
      );
    });

    test('accepts the last day of a leap February', () {
      expect(
        parsedDiveStartTime(_parsed(year: 2024, month: 2, day: 29)),
        DateTime.utc(2024, 2, 29, 9, 30, 15),
      );
    });

    // libdc_download.c leaves the struct at its memset 0 when the parser
    // cannot report a datetime; DateTime.utc(0, 0, 0) would roll that back
    // to -0001-11-30 instead of failing (#1640).
    test('returns null for the all-zero date of a parser with no clock', () {
      expect(
        parsedDiveStartTime(
          _parsed(year: 0, month: 0, day: 0, hour: 0, minute: 0, second: 0),
        ),
        isNull,
      );
    });

    test('returns null for a year no dive can have been logged in', () {
      expect(parsedDiveStartTime(_parsed(year: 0)), isNull);
    });

    test('returns null for a component DateTime.utc would roll over', () {
      expect(parsedDiveStartTime(_parsed(month: 13)), isNull);
      expect(parsedDiveStartTime(_parsed(month: 2, day: 30)), isNull);
      expect(parsedDiveStartTime(_parsed(day: 0)), isNull);
      expect(parsedDiveStartTime(_parsed(hour: 24)), isNull);
      expect(parsedDiveStartTime(_parsed(minute: 60)), isNull);
      expect(parsedDiveStartTime(_parsed(second: -1)), isNull);
    });
  });
}
