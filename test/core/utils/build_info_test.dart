import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/build_info.dart';

void main() {
  group('parseBuildDate', () {
    test('reads a stamped YYYY-MM-DD as that calendar day', () {
      final date = parseBuildDate('2026-11-09');

      expect(date, isNotNull);
      expect(date!.year, 2026);
      expect(date.month, 11);
      expect(date.day, 9);
      expect(date.hour, 0);
      expect(date.minute, 0);
    });

    test('keeps the stamped day in local time, so no timezone shifts it', () {
      final date = parseBuildDate('2026-01-31')!;

      expect(date.isUtc, isFalse);
      expect(date.day, 31);
    });

    test('an unstamped build has no date', () {
      expect(parseBuildDate(''), isNull);
    });

    test('a value that is not a plain date has no date', () {
      for (final raw in [
        'not-a-date',
        '2026-11-9',
        '20261109',
        '2026-11-09T10:00:00Z',
        ' 2026-11-09',
        '2026-11-09 ',
      ]) {
        expect(parseBuildDate(raw), isNull, reason: raw);
      }
    });

    test(
      'a date that does not exist has no date, rather than rolling over',
      () {
        expect(parseBuildDate('2026-02-30'), isNull);
        expect(parseBuildDate('2026-13-01'), isNull);
        expect(parseBuildDate('2026-00-10'), isNull);
      },
    );
  });
}
