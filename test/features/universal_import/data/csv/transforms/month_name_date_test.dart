import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/month_name_date.dart';

void main() {
  group('monthFromName', () {
    test('reads English short and full names in any case', () {
      expect(monthFromName('Sep'), 9);
      expect(monthFromName('sept'), 9);
      expect(monthFromName('SEPTEMBER'), 9);
      expect(monthFromName('Jan.'), 1);
    });

    test("reads the app's other Latin-script languages", () {
      expect(monthFromName('Okt'), 10); // de
      expect(monthFromName('März'), 3); // de
      expect(monthFromName('Dez.'), 12); // de
      expect(monthFromName('févr.'), 2); // fr
      expect(monthFromName('août'), 8); // fr
      expect(monthFromName('ene'), 1); // es
      expect(monthFromName('dic'), 12); // es, it
      expect(monthFromName('mrt'), 3); // nl
      expect(monthFromName('out'), 10); // pt
      expect(monthFromName('szept.'), 9); // hu
    });

    test('no name means two different months', () {
      // Every name in the table is checked against every language: a word
      // two languages give to different months would be dropped, so the
      // ones a diver is likely to meet must all still read.
      for (final (name, month) in const [
        ('mar', 3),
        ('mai', 5),
        ('jun', 6),
        ('jul', 7),
        ('set', 9),
        ('dec', 12),
      ]) {
        expect(monthFromName(name), month, reason: name);
      }
    });

    test('a word that is not a month gives null', () {
      expect(monthFromName('Scuba'), isNull);
      expect(monthFromName(''), isNull);
    });
  });

  group('matchMonthNameDate', () {
    test('reads the my.divessi.com form, a dotted day before the month', () {
      final date = matchMonthNameDate('29. Sep 2024 10:11');
      expect(date, isNotNull);
      expect(date!.day, 29);
      expect(date.month, 9);
      expect(date.year, '2024');
      expect(date.rest, '10:11');
    });

    test('reads day-first forms with spaces, dashes and dots', () {
      for (final value in const [
        '29 Sep 2024',
        '29-Sep-2024',
        '29.Sep.2024',
        '29 September 2024',
        '29. Sept. 2024',
      ]) {
        final date = matchMonthNameDate(value);
        expect(date, isNotNull, reason: value);
        expect((date!.day, date.month, date.year), (29, 9, '2024'));
        expect(date.rest, isEmpty, reason: value);
      }
    });

    test('reads month-first forms', () {
      for (final value in const [
        'Sep 29, 2024',
        'September 29 2024',
        'Sep. 29, 2024',
      ]) {
        final date = matchMonthNameDate(value);
        expect(date, isNotNull, reason: value);
        expect((date!.day, date.month, date.year), (29, 9, '2024'));
      }
    });

    test('keeps a two-digit year as written for the caller to expand', () {
      final date = matchMonthNameDate('29-Sep-24 14:05');
      expect(date!.year, '24');
      expect(date.rest, '14:05');
    });

    test('splits off a time after a comma or an ISO T', () {
      expect(matchMonthNameDate('Sep 29, 2024, 2:00 PM')!.rest, '2:00 PM');
      expect(matchMonthNameDate('29 Sep 2024T10:11')!.rest, '10:11');
    });

    test('does not take the hour of a time for a two-digit year', () {
      expect(matchMonthNameDate('29 Sep 10:11'), isNull);
      expect(matchMonthNameDate('Sep 29 10:11'), isNull);
    });

    test('a word that is not a month, or a numeric date, gives null', () {
      expect(matchMonthNameDate('29 Scuba 2024'), isNull);
      expect(matchMonthNameDate('29.09.2024'), isNull);
      expect(matchMonthNameDate('2024-09-29 10:11'), isNull);
      expect(matchMonthNameDate(''), isNull);
    });
  });
}
