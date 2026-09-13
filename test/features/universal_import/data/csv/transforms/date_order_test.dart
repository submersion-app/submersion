import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/date_order.dart';

void main() {
  group('dateOrderForLocale', () {
    test('US English reads month first', () {
      expect(dateOrderForLocale('en_US'), DateOrder.monthFirst);
    });

    test('UK English reads day first', () {
      expect(dateOrderForLocale('en_GB'), DateOrder.dayFirst);
    });

    test('accepts a hyphenated tag as the platform reports it', () {
      expect(dateOrderForLocale('en-AU'), DateOrder.dayFirst);
    });

    test('uses the language alone when there is no region', () {
      expect(dateOrderForLocale('de'), DateOrder.dayFirst);
      expect(dateOrderForLocale('en'), DateOrder.monthFirst);
    });

    test('the region decides for a language the region does not speak', () {
      // An English-language device set to France writes dates the French way;
      // plain "en" would say month first.
      expect(dateOrderForLocale('en_FR'), DateOrder.dayFirst);
      expect(dateOrderForLocale('en-BR'), DateOrder.dayFirst);
      expect(dateOrderForLocale('en_DE'), DateOrder.dayFirst);
    });

    test('a month-first region the data does not list is month first', () {
      expect(dateOrderForLocale('en_PH'), DateOrder.monthFirst);
      expect(dateOrderForLocale('es_PR'), DateOrder.monthFirst);
    });

    test('ignores a script and an encoding suffix', () {
      expect(dateOrderForLocale('en_GB.UTF-8'), DateOrder.dayFirst);
      expect(dateOrderForLocale('en_Latn_FR'), DateOrder.dayFirst);
    });

    test('an unknown locale keeps the historical month-first reading', () {
      expect(dateOrderForLocale('xx'), DateOrder.monthFirst);
      expect(dateOrderForLocale(''), DateOrder.monthFirst);
      expect(dateOrderForLocale(null), DateOrder.monthFirst);
    });
  });

  group('detectColumnDateOrder', () {
    test('a first field above 12 anywhere means day first', () {
      // Issue #1828: a UK logbook where most rows are ambiguous.
      final order = detectColumnDateOrder([
        '03/04/1991',
        '15/04/1991',
        '01/02/1992',
      ], localeOrder: DateOrder.monthFirst);

      expect(order, DateOrder.dayFirst);
    });

    test('a second field above 12 anywhere means month first', () {
      final order = detectColumnDateOrder([
        '03/04/1991',
        '04/15/1991',
      ], localeOrder: DateOrder.dayFirst);

      expect(order, DateOrder.monthFirst);
    });

    test('an ambiguous slash column follows the locale', () {
      final values = ['03/04/1991', '01/02/1992'];

      expect(
        detectColumnDateOrder(values, localeOrder: DateOrder.dayFirst),
        DateOrder.dayFirst,
      );
      expect(
        detectColumnDateOrder(values, localeOrder: DateOrder.monthFirst),
        DateOrder.monthFirst,
      );
    });

    test('an ambiguous dotted or dashed column makes no decision', () {
      // Dots and dashes have always read day first; the device locale is not
      // a reason to start reading 03.04.1991 as 4 March.
      expect(
        detectColumnDateOrder([
          '03.04.1991',
          '01-02-1992',
        ], localeOrder: DateOrder.monthFirst),
        isNull,
      );
    });

    test('evidence decides a dotted column too', () {
      expect(
        detectColumnDateOrder(['04.15.1991'], localeOrder: DateOrder.dayFirst),
        DateOrder.monthFirst,
      );
    });

    test('a field above 31 is not evidence of a day', () {
      // "91-04-15" is a year-first date with a two-digit year, not day 91.
      expect(
        detectColumnDateOrder([
          '91/04/15',
          '03/04/1991',
        ], localeOrder: DateOrder.monthFirst),
        DateOrder.monthFirst,
      );
    });

    test('conflicting evidence falls back like an ambiguous column', () {
      expect(
        detectColumnDateOrder([
          '15/04/1991',
          '04/15/1991',
        ], localeOrder: DateOrder.dayFirst),
        DateOrder.dayFirst,
      );
    });

    test('reads the date part of a combined date-time value', () {
      expect(
        detectColumnDateOrder([
          '03/04/1991 09:00',
          '15/04/1991 14:30:00',
        ], localeOrder: DateOrder.monthFirst),
        DateOrder.dayFirst,
      );
    });

    test('reads the date part after any whitespace separator', () {
      // A tab or a non-breaking space between date and time must not hide
      // the evidence (the parser already accepts both).
      expect(
        detectColumnDateOrder([
          '03/04/1991\t09:00',
          '15/04/1991 10:00',
        ], localeOrder: DateOrder.monthFirst),
        DateOrder.dayFirst,
      );
    });

    test('two-digit years count as evidence as well', () {
      expect(
        detectColumnDateOrder(['15/04/91'], localeOrder: DateOrder.monthFirst),
        DateOrder.dayFirst,
      );
    });

    test('a column with no year-last dates makes no decision', () {
      expect(
        detectColumnDateOrder([
          '1991-04-15',
          null,
          '',
          'not a date',
        ], localeOrder: DateOrder.dayFirst),
        isNull,
      );
    });
  });
}
