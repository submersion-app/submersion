import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_symbols.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Month names in the app language (#3457). English always reads; a language
/// adds its own, and only its own.
void main() {
  final now = DateTime(2026, 9, 19);
  final symbols = dateTimeSymbolMap();

  DateRange? read(String text, String? language) =>
      parseDateText(text, now: now, language: language);

  void expectDay(String text, String? language, DateTime day) {
    final range = read(text, language);
    expect(range?.start, day, reason: text);
    expect(range?.end, day, reason: text);
  }

  void expectMonth(String text, String? language, int year, int month) {
    final range = read(text, language);
    expect(range?.start, DateTime(year, month), reason: text);
    expect(range?.end, DateTime(year, month + 1, 0), reason: text);
  }

  test('every name of every month in every app language reads', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final language = locale.languageCode;
      final DateSymbols calendar = symbols[language]!;
      for (final names in [
        calendar.MONTHS,
        calendar.STANDALONEMONTHS,
        calendar.SHORTMONTHS,
        calendar.STANDALONESHORTMONTHS,
      ]) {
        for (final (index, name) in names.indexed) {
          // Chinese short forms are digits, which the year-first forms read.
          if (name.contains(RegExp(r'\d'))) continue;
          expectMonth('$name 2018', language, 2018, index + 1);
          expectDay('14 $name 2018', language, DateTime(2018, index + 1, 14));
        }
      }
    }
  });

  test('English reads in every app language', () {
    expectMonth('october 2018', 'es', 2018, 10);
    expectDay('14 october 2018', 'fr', DateTime(2018, 10, 14));
  });

  test('a language reads its own months, not another language', () {
    expectMonth('octubre 2018', 'es', 2018, 10);
    expect(read('octubre 2018', 'fr'), isNull);
    expect(read('octubre 2018', 'en'), isNull);
    expect(read('octubre 2018', null), isNull);
    expect(read('14 octubre 2018', null), isNull);
  });

  test('an unknown language reads English', () {
    expectMonth('october 2018', 'xx', 2018, 10);
    expect(read('octubre 2018', 'xx'), isNull);
  });

  test('a dotted abbreviation reads', () {
    expectMonth('janv. 2018', 'fr', 2018, 1);
    expectMonth('févr. 2018', 'fr', 2018, 2);
    expectMonth('okt. 2018', 'hu', 2018, 10);
    expectDay('14 dez. 2018', 'pt', DateTime(2018, 12, 14));
  });

  test('a month reads without its accents', () {
    expectMonth('fevrier 2018', 'fr', 2018, 2);
    expectMonth('aout 2018', 'fr', 2018, 8);
    expectMonth('marz 2018', 'de', 2018, 3);
    expectMonth('oktober 2018', 'hu', 2018, 10);
    expectMonth('marco 2018', 'pt', 2018, 3);
  });

  test('French writes the first of the month as 1er', () {
    expectDay('1er mai 2018', 'fr', DateTime(2018, 5, 1));
  });

  test('Hebrew attaches "in" to the month', () {
    expectDay('14 באוקטובר 2018', 'he', DateTime(2018, 10, 14));
    expectMonth('באוקטובר 2018', 'he', 2018, 10);
  });

  test('a translated month works inside the other forms', () {
    final since = read('since marzo 2020', 'es')!;
    expect(since.start, DateTime(2020, 3));
    expect(since.end, isNull);

    final before = read('before 1 marzo 2020', 'es')!;
    expect(before.start, isNull);
    expect(before.end, DateTime(2020, 2, 29));

    final to = read('marzo 2018 to junio 2019', 'es')!;
    expect(to.start, DateTime(2018, 3));
    expect(to.end, DateTime(2019, 6, 30));

    final between = read('between 20 octubre 2018 and 14 octubre 2018', 'es')!;
    expect(between.start, DateTime(2018, 10, 14));
    expect(between.end, DateTime(2018, 10, 20));
  });

  test('a day the month does not have stays out', () {
    expect(read('31 abril 2018', 'es'), isNull);
    expect(read('30 febrero 2018', 'es'), isNull);
  });

  group('Hungarian writes the year first', () {
    test('with or without the day', () {
      expectDay('2018 október 14', 'hu', DateTime(2018, 10, 14));
      expectMonth('2018 október', 'hu', 2018, 10);
      expectMonth('2018 okt', 'hu', 2018, 10);
    });

    test('and only Hungarian does', () {
      expect(read('2018 october', 'hu'), isNotNull);
      expect(read('2018 october', 'en'), isNull);
      expect(read('2018 october', null), isNull);
      expect(read('2018 october 14', 'de'), isNull);
    });

    test('a word that is no month stays out', () {
      expect(read('2018 ressel', 'hu'), isNull);
      expect(read('2018 február 30', 'hu'), isNull);
    });
  });

  group('Chinese marks the year, month and day', () {
    test('with or without spaces', () {
      expectDay('2018年10月14日', 'zh', DateTime(2018, 10, 14));
      expectDay('2018 年 10 月 14 日', 'zh', DateTime(2018, 10, 14));
      expectDay('2018年10月14号', 'zh', DateTime(2018, 10, 14));
      expectMonth('2018年10月', 'zh', 2018, 10);
    });

    test('a year alone covers it', () {
      final range = read('2018年', 'zh')!;
      expect(range.start, DateTime(2018));
      expect(range.end, DateTime(2018, 12, 31));
    });

    test('a date that does not exist stays out', () {
      expect(read('2018年13月', 'zh'), isNull);
      expect(read('2018年2月30日', 'zh'), isNull);
    });
  });
}
