import 'package:intl/date_symbol_data_local.dart';

/// A date written with its month as a word, such as `29. Sep 2024` from
/// my.divessi.com (#3629), split from whatever follows it.
///
/// [year] is the raw year text (two or four digits) for the caller to expand;
/// [rest] is the text after the date with its separator removed, empty when
/// the value is the date alone.
typedef MonthNameDate = ({int day, int month, String year, String rest});

/// The languages whose month names are read: the app's Latin-script
/// languages. A non-Latin script never reaches the `\p{L}` word as a month
/// name the table could hold anyway (`9月`).
const _monthNameLocales = ['en', 'de', 'fr', 'es', 'it', 'nl', 'pt', 'hu'];

/// Day, month word, year: `29. Sep 2024`, `29-Sep-24`, `29 September 2024`.
/// The year must end the value or be followed by a separator, so the hour
/// of `29 Sep 10:11` is never taken for a two-digit year.
final _dayFirst = RegExp(
  r'^(\d{1,2})[.\s/-]+(\p{L}+)[.,\s/-]+(\d{4}|\d{2})(?=$|[\s,T])',
  unicode: true,
);

/// Month word, day, year: `Sep 29, 2024`, `September 29 2024`.
final _monthFirst = RegExp(
  r'^(\p{L}+)[.\s/-]+(\d{1,2})(?:,\s*|[.\s/-]+)(\d{4}|\d{2})(?=$|[\s,T])',
  unicode: true,
);

/// What separates the date from a time after it.
final _restSeparator = RegExp(r'^[\s,]*T?\s*');

/// Month number for each lowercased name, without a trailing dot. A name two
/// languages give to different months would be ambiguous, so it is left out.
final Map<String, int> _monthsByName = () {
  final symbols = dateTimeSymbolMap();
  final months = <String, int>{};
  final ambiguous = <String>{};
  for (final locale in _monthNameLocales) {
    final s = symbols[locale];
    if (s == null) continue;
    for (final names in [
      s.MONTHS,
      s.STANDALONEMONTHS,
      s.SHORTMONTHS,
      s.STANDALONESHORTMONTHS,
    ]) {
      for (var i = 0; i < names.length; i++) {
        final name = _normalized(names[i]);
        final existing = months[name];
        if (existing != null && existing != i + 1) ambiguous.add(name);
        months[name] = i + 1;
      }
    }
  }
  // English writes September `Sept` as often as `Sep`.
  months.putIfAbsent('sept', () => 9);
  return {
    for (final entry in months.entries)
      if (!ambiguous.contains(entry.key)) entry.key: entry.value,
  };
}();

String _normalized(String name) {
  final lower = name.trim().toLowerCase();
  return lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
}

/// The month (1 to 12) [name] means in any of the app's Latin-script
/// languages, short or full, with or without a trailing dot, or null.
int? monthFromName(String name) => _monthsByName[_normalized(name)];

/// Splits a leading month-name date off [value], or returns null if [value]
/// does not start with one. The day is not checked against the month.
MonthNameDate? matchMonthNameDate(String value) {
  final s = value.trim();
  final dayFirst = _dayFirst.firstMatch(s);
  if (dayFirst != null) {
    final month = monthFromName(dayFirst.group(2)!);
    if (month != null) {
      return (
        day: int.parse(dayFirst.group(1)!),
        month: month,
        year: dayFirst.group(3)!,
        rest: _rest(s, dayFirst.end),
      );
    }
  }
  final monthFirst = _monthFirst.firstMatch(s);
  if (monthFirst != null) {
    final month = monthFromName(monthFirst.group(1)!);
    if (month != null) {
      return (
        day: int.parse(monthFirst.group(2)!),
        month: month,
        year: monthFirst.group(3)!,
        rest: _rest(s, monthFirst.end),
      );
    }
  }
  return null;
}

String _rest(String s, int end) =>
    s.substring(end).replaceFirst(_restSeparator, '').trim();
