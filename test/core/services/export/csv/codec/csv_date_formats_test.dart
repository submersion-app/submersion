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

    test('a two-digit year under the header format is not the year 91', () {
      // intl does not hold `yyyy` to four digits, so the header's own pattern
      // read 12/05/91 as the year 91 and the dive landed before 1950 (#2617).
      final cells = {
        DateFormatPreference.mmddyyyy: '12/05/91',
        DateFormatPreference.ddmmyyyy: '05/12/91',
        DateFormatPreference.ddmmyyyyDots: '05.12.91',
        DateFormatPreference.mmmDYYYY: 'Dec 5, 91',
        DateFormatPreference.dMMMYYYY: '5 Dec 91',
      };
      for (final MapEntry(key: format, value: cell) in cells.entries) {
        expect(
          parseCsvDate(cell, format),
          DateTime.utc(1991, 12, 5),
          reason: '${format.name}: $cell',
        );
      }
    });

    test('a two-digit year can still be a near-future date', () {
      // Equipment service due dates share this parser, so a two-digit year
      // keeps intl's window rather than refusing every future year.
      expect(
        parseCsvDate('05/12/27', DateFormatPreference.ddmmyyyy),
        DateTime.utc(2027, 12, 5),
      );
    });

    test('the header still decides the day and month of a two-digit year', () {
      expect(parseCsvDate('29/08/91', DateFormatPreference.mmddyyyy), isNull);
      expect(parseCsvDate('08/29/91', DateFormatPreference.ddmmyyyy), isNull);
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
