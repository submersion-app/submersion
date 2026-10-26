import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/time_resolver.dart';

/// Dates written with the month as a word (#3629).
void main() {
  final resolver = TimeResolver(clock: () => DateTime(2026, 10, 25));

  group('parseDate', () {
    test('reads a month-name date', () {
      expect(resolver.parseDate('29. Sep 2024'), DateTime.utc(2024, 9, 29));
      expect(resolver.parseDate('Sep 29, 2024'), DateTime.utc(2024, 9, 29));
      expect(resolver.parseDate('3 März 2024'), DateTime.utc(2024, 3, 3));
    });

    test('expands a two-digit year like a numeric date', () {
      expect(resolver.parseDate('29-Sep-91'), DateTime.utc(1991, 9, 29));
      expect(resolver.parseDate('29-Sep-24'), DateTime.utc(2024, 9, 29));
    });

    test('a day that is not in the month gives null', () {
      expect(resolver.parseDate('30 Feb 2024'), isNull);
      expect(resolver.parseDate('32 Jan 2024'), isNull);
    });

    test('a month-name date followed by a time is not a plain date', () {
      expect(resolver.parseDate('29. Sep 2024 10:11'), isNull);
    });
  });

  group('combineDateTime', () {
    test('reads the my.divessi.com date and time (#3629)', () {
      expect(
        resolver.combineDateTime(dateTimeStr: '29. Sep 2024 10:11'),
        DateTime.utc(2024, 9, 29, 10, 11),
      );
      expect(
        resolver.combineDateTime(dateTimeStr: '07. Jul 2024 09:05'),
        DateTime.utc(2024, 7, 7, 9, 5),
      );
    });

    test('reads a month-first date with a 12-hour time', () {
      expect(
        resolver.combineDateTime(dateTimeStr: 'Sep 29, 2024 2:30 PM'),
        DateTime.utc(2024, 9, 29, 14, 30),
      );
    });

    test('reads a month-name date from a separate date column', () {
      expect(
        resolver.combineDateTime(dateStr: '29 Sep 2024', timeStr: '10:11'),
        DateTime.utc(2024, 9, 29, 10, 11),
      );
    });

    test('a month-name date alone in a date-time column is dated noon, as '
        'a date column with no time is', () {
      expect(
        resolver.combineDateTime(dateTimeStr: '29 Sep 2024'),
        DateTime.utc(2024, 9, 29, 12),
      );
    });

    test('a month-name date with an unreadable time gives null', () {
      expect(
        resolver.combineDateTime(dateTimeStr: '29. Sep 2024 late'),
        isNull,
      );
    });
  });
}
