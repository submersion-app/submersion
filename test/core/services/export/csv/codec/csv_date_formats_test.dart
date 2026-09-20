import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';

void main() {
  test('every date preference round trips through its header suffix', () {
    final date = DateTime.utc(2025, 3, 5);
    for (final f in DateFormatPreference.values) {
      expect(dateFormatForSuffix(f.displayName), f);
      final text = formatCsvDate(date, f);
      expect(parseCsvDate(text, f), date, reason: '${f.name}: $text');
    }
  });

  test('every time preference round trips through its header suffix', () {
    for (final f in TimeFormat.values) {
      expect(timeFormatForSuffix(f.displayName), f);
      final text = formatCsvTime(DateTime.utc(2025, 3, 5, 14, 7), f);
      expect(parseCsvTime(text, f), (hour: 14, minute: 7), reason: text);
    }
  });

  test('month names are English regardless of the default locale', () {
    expect(
      formatCsvDate(DateTime.utc(2025, 1, 9), DateFormatPreference.mmmDYYYY),
      'Jan 9, 2025',
    );
  });

  test('no suffix means ISO date and 24-hour time', () {
    expect(parseCsvDate('2025-03-05', null), DateTime.utc(2025, 3, 5));
    expect(parseCsvTime('09:05', null), (hour: 9, minute: 5));
  });

  test('unparseable text is null, not an exception', () {
    expect(parseCsvDate('05/03', DateFormatPreference.ddmmyyyy), isNull);
    expect(parseCsvTime('noon', null), isNull);
    expect(parseCsvDate('', null), isNull);
  });

  group('a spreadsheet rewrote the date column', () {
    // Excel redisplays a date column in its own format when the file is
    // saved, so a "MMM D, YYYY" export comes back as 29-Aug-26 (#2152).
    // Every fallback spells the month, so it reads the same whatever the
    // header names.
    test('reads a month-name date whatever format the header names', () {
      for (final f in [...DateFormatPreference.values, null]) {
        final name = f?.name ?? 'no suffix';
        expect(
          parseCsvDate('29-Aug-26', f),
          DateTime.utc(2026, 8, 29),
          reason: name,
        );
        expect(
          parseCsvDate('9-Sep-07', f),
          DateTime.utc(2007, 9, 9),
          reason: name,
        );
        expect(
          parseCsvDate('29 Aug 2026', f),
          DateTime.utc(2026, 8, 29),
          reason: name,
        );
        expect(
          parseCsvDate('August 29, 2026', f),
          DateTime.utc(2026, 8, 29),
          reason: name,
        );
        expect(
          parseCsvDate('2026-08-29', f),
          DateTime.utc(2026, 8, 29),
          reason: name,
        );
      }
    });

    test('the format the header names still wins', () {
      expect(
        parseCsvDate('03/04/1991', DateFormatPreference.mmddyyyy),
        DateTime.utc(1991, 3, 4),
      );
      expect(
        parseCsvDate('03/04/1991', DateFormatPreference.ddmmyyyy),
        DateTime.utc(1991, 4, 3),
      );
    });

    test('no fallback reads a day as a month', () {
      // The day and month of a numeric date can only be told apart by the
      // header, so a cell that contradicts it stays unreadable rather than
      // importing a dive on the wrong day.
      expect(parseCsvDate('29/08/2026', DateFormatPreference.mmddyyyy), isNull);
      expect(parseCsvDate('08/29/2026', DateFormatPreference.ddmmyyyy), isNull);
      expect(parseCsvDate('29-08-26', DateFormatPreference.mmmDYYYY), isNull);
      expect(parseCsvDate('26-08-29', DateFormatPreference.mmmDYYYY), isNull);
      // A two-digit leading field is a day, never the year 29.
      expect(parseCsvDate('29-08-26', null), isNull);
    });
  });
}
