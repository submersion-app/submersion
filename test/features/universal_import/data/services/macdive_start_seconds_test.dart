import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/services/macdive_start_seconds.dart';

/// MacDive stores a dive's start to the minute, but the identifier it keeps
/// beside it (`YYYYMMDDHHMMSS-<serial>`) still carries the seconds the
/// computer reported (#2509).
void main() {
  group('MacDiveStartSeconds.restore', () {
    group('an absolute instant (SQLite ZRAWDATE)', () {
      test('takes the seconds from an identifier in a whole-hour zone', () {
        // 10:30:17 at UTC-5 is 15:30:17 UTC; MacDive kept 15:30:00.
        final restored = MacDiveStartSeconds.restore(
          DateTime.utc(2025, 1, 2, 15, 30),
          '20250102103017-1234567890',
        );
        expect(restored, DateTime.utc(2025, 1, 2, 15, 30, 17));
      });

      test('takes the seconds from an identifier east of UTC', () {
        // 10:30:17 at UTC+10 is 00:30:17 UTC.
        final restored = MacDiveStartSeconds.restore(
          DateTime.utc(2025, 1, 2, 0, 30),
          '20250102103017-1234567890',
        );
        expect(restored, DateTime.utc(2025, 1, 2, 0, 30, 17));
      });

      test('takes the seconds in a zone offset by 30 or 45 minutes', () {
        // 10:30:17 at UTC+5:45 is 04:45:17 UTC.
        final nepal = MacDiveStartSeconds.restore(
          DateTime.utc(2025, 1, 2, 4, 45),
          '20250102103017-1234567890',
        );
        expect(nepal, DateTime.utc(2025, 1, 2, 4, 45, 17));

        // 10:30:17 at UTC-3:30 is 14:00:17 UTC.
        final newfoundland = MacDiveStartSeconds.restore(
          DateTime.utc(2025, 1, 2, 14),
          '20250102103017-1234567890',
        );
        expect(newfoundland, DateTime.utc(2025, 1, 2, 14, 0, 17));
      });

      test('works across a date boundary', () {
        // 23:59:41 on Jan 1 at UTC-8 is 07:59:41 UTC on Jan 2.
        final restored = MacDiveStartSeconds.restore(
          DateTime.utc(2025, 1, 2, 7, 59),
          '20250101235941-1234567890',
        );
        expect(restored, DateTime.utc(2025, 1, 2, 7, 59, 41));
      });
    });

    group('a wall-clock time (XML <date>)', () {
      test('takes the seconds when the identifier names the same minute', () {
        final restored = MacDiveStartSeconds.restore(
          DateTime.utc(2025, 1, 2, 10, 30),
          '20250102103017-ABC123',
        );
        expect(restored, DateTime.utc(2025, 1, 2, 10, 30, 17));
      });
    });

    group('leaves the start unchanged', () {
      final start = DateTime.utc(2025, 1, 2, 15, 30);

      test('with no identifier', () {
        expect(MacDiveStartSeconds.restore(start, null), start);
      });

      test('for an identifier whose seconds are zero', () {
        expect(
          MacDiveStartSeconds.restore(start, '20250102103000-1234567890'),
          start,
        );
      });

      test('for an unpadded identifier such as a Suunto Cobra writes', () {
        expect(
          MacDiveStartSeconds.restore(start, '2015122911130-822199'),
          start,
        );
        expect(MacDiveStartSeconds.restore(start, '20097198230-822199'), start);
      });

      test('for an identifier that is not a timestamp', () {
        expect(MacDiveStartSeconds.restore(start, 'dive-uuid-1'), start);
        expect(
          MacDiveStartSeconds.restore(start, '20250102103017ABCDEF'),
          start,
        );
      });

      test('for digits that are not a real date and time', () {
        // Month 13 and second 75 would silently roll over in DateTime.
        expect(
          MacDiveStartSeconds.restore(start, '20251302103017-1234567890'),
          start,
        );
        expect(
          MacDiveStartSeconds.restore(start, '20250102103075-1234567890'),
          start,
        );
      });

      test('when the identifier names a different minute', () {
        // Five minutes off is no time zone: the identifier describes some
        // other moment, so it cannot vouch for this start's seconds.
        expect(
          MacDiveStartSeconds.restore(start, '20250102103517-1234567890'),
          start,
        );
      });

      test('when the identifier is further away than any time zone', () {
        expect(
          MacDiveStartSeconds.restore(start, '20250104103017-1234567890'),
          start,
        );
      });

      test('when the start already has seconds', () {
        final precise = DateTime.utc(2025, 1, 2, 15, 30, 9);
        expect(
          MacDiveStartSeconds.restore(precise, '20250102103017-1234567890'),
          precise,
        );
      });
    });
  });
}
