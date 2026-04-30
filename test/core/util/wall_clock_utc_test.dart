import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';

void main() {
  group('parseExternalDateAsWallClockUtc', () {
    test('returns null for unparseable input', () {
      expect(parseExternalDateAsWallClockUtc('not a date'), isNull);
      expect(parseExternalDateAsWallClockUtc(''), isNull);
      expect(parseExternalDateAsWallClockUtc('xyz123'), isNull);
    });

    test('returns UTC for Z-suffixed strings, preserving the moment', () {
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00Z');
      expect(got, DateTime.utc(2024, 4, 12, 14, 32, 0));
      expect(got!.isUtc, isTrue);
    });

    test('returns UTC for +05:30 offset strings, preserving the moment', () {
      // 14:32 at +05:30 is 09:02 UTC (same absolute moment).
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00+05:30');
      expect(got, DateTime.utc(2024, 4, 12, 9, 2, 0));
      expect(got!.isUtc, isTrue);
    });

    test('returns UTC for -05:00 offset strings, preserving the moment', () {
      // 14:32 at -05:00 is 19:32 UTC (same absolute moment).
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00-05:00');
      expect(got, DateTime.utc(2024, 4, 12, 19, 32, 0));
      expect(got!.isUtc, isTrue);
    });

    test('returns UTC for +0000 no-colon offset strings', () {
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00+0000');
      expect(got, DateTime.utc(2024, 4, 12, 14, 32, 0));
      expect(got!.isUtc, isTrue);
    });

    test(
      'returns UTC for -0500 no-colon offset strings, preserving moment',
      () {
        // 14:32 at -05:00 is 19:32 UTC.
        final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00-0500');
        expect(got, DateTime.utc(2024, 4, 12, 19, 32, 0));
        expect(got!.isUtc, isTrue);
      },
    );

    test('reinterprets wall-clock components for offset-less strings '
        '(regardless of host local offset)', () {
      // The key invariant: 14:32 in, 14:32 out, no shift. This must hold on
      // any test host regardless of TZ.
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00');
      expect(got, DateTime.utc(2024, 4, 12, 14, 32, 0));
      expect(got!.isUtc, isTrue);
    });

    test('reinterprets date-only strings as wall-clock UTC midnight', () {
      // DateTime.tryParse accepts date-only and produces a local DateTime
      // at midnight; we reinterpret as UTC midnight.
      final got = parseExternalDateAsWallClockUtc('2024-04-12');
      expect(got, DateTime.utc(2024, 4, 12, 0, 0, 0));
      expect(got!.isUtc, isTrue);
    });

    test('preserves milliseconds for offset-less strings', () {
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00.123');
      expect(got, DateTime.utc(2024, 4, 12, 14, 32, 0, 123));
      expect(got!.millisecond, 123);
      expect(got.isUtc, isTrue);
    });

    test('preserves milliseconds for Z-suffixed strings', () {
      final got = parseExternalDateAsWallClockUtc('2024-04-12T14:32:00.456Z');
      expect(got, DateTime.utc(2024, 4, 12, 14, 32, 0, 456));
      expect(got!.millisecond, 456);
      expect(got.isUtc, isTrue);
    });

    test('preserves milliseconds across an offset-driven shift', () {
      // 14:32:00.789 at -05:00 -> 19:32:00.789 UTC.
      final got = parseExternalDateAsWallClockUtc(
        '2024-04-12T14:32:00.789-05:00',
      );
      expect(got, DateTime.utc(2024, 4, 12, 19, 32, 0, 789));
      expect(got!.millisecond, 789);
      expect(got.isUtc, isTrue);
    });
  });

  group('asWallClockUtc', () {
    test('reinterprets a local DateTime\'s components verbatim '
        '(regardless of input offset)', () {
      // Whether the source DateTime is local or UTC, the output's
      // components match the source's components exactly.
      final local = DateTime(2024, 4, 12, 14, 32, 5, 250);
      final got = asWallClockUtc(local);
      expect(got, DateTime.utc(2024, 4, 12, 14, 32, 5, 250));
      expect(got.isUtc, isTrue);
      expect(got.year, local.year);
      expect(got.month, local.month);
      expect(got.day, local.day);
      expect(got.hour, local.hour);
      expect(got.minute, local.minute);
      expect(got.second, local.second);
      expect(got.millisecond, local.millisecond);
    });

    test('reinterprets a UTC DateTime\'s components verbatim', () {
      // For a UTC input the result is byte-identical (same components,
      // already UTC).
      final utc = DateTime.utc(2024, 4, 12, 14, 32, 5, 250);
      final got = asWallClockUtc(utc);
      expect(got, utc);
      expect(got.isUtc, isTrue);
    });

    test('does not shift across timezone offsets', () {
      // Construct a non-UTC DateTime that, were it converted via toUtc(),
      // would land on different wall-clock digits. Verify asWallClockUtc
      // does NOT shift them.
      final local = DateTime(2024, 4, 12, 14, 32, 0);
      final shifted = local.toUtc();
      final wall = asWallClockUtc(local);
      // Wall-clock digits must match the input, NOT the toUtc() shift,
      // unless the test runner happens to be in UTC.
      expect(wall.year, 2024);
      expect(wall.month, 4);
      expect(wall.day, 12);
      expect(wall.hour, 14);
      expect(wall.minute, 32);
      expect(wall.second, 0);
      expect(wall.isUtc, isTrue);
      // If host is not UTC, shifted's hour != 14 — assert the wall result
      // followed the input, not the shift. If host IS UTC the two are
      // equal which is also fine.
      if (shifted.hour != 14) {
        expect(wall.hour, isNot(shifted.hour));
      }
    });
  });
}
