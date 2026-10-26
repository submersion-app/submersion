/// A date written with its month as a word, such as `29. Sep 2024` from
/// my.divessi.com (#3629), split from whatever follows it.
///
/// [year] is the raw year text (two or four digits) for the caller to expand;
/// [rest] is the text after the date with its separator removed, empty when
/// the value is the date alone.
typedef MonthNameDate = ({int day, int month, String year, String rest});

/// The languages whose month names are read: the app's Latin-script
/// languages. A non-Latin script writes no month word the date patterns
/// below could match (`9月`).
const monthNameLocales = ['en', 'de', 'fr', 'es', 'it', 'nl', 'pt', 'hu'];

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

/// Month number for each lowercased name, without a trailing dot: every
/// full and short name intl's date symbols give [monthNameLocales], plus
/// English `sept`. Written out rather than read from
/// `package:intl/date_symbol_data_local.dart`, which would bundle every
/// locale's date symbols into the app; a test keeps the two in step. No name
/// means two different months.
const _monthsByName = <String, int>{
  // 1
  'ene': 1,
  'enero': 1,
  'gen': 1,
  'gennaio': 1,
  'jan': 1,
  'janeiro': 1,
  'januar': 1,
  'januari': 1,
  'january': 1,
  'január': 1,
  'janv': 1,
  'janvier': 1,
  // 2
  'feb': 2,
  'febbraio': 2,
  'febr': 2,
  'febrero': 2,
  'februar': 2,
  'februari': 2,
  'february': 2,
  'február': 2,
  'fev': 2,
  'fevereiro': 2,
  'févr': 2,
  'février': 2,
  // 3
  'maart': 3,
  'mar': 3,
  'march': 3,
  'mars': 3,
  'marzo': 3,
  'março': 3,
  'mrt': 3,
  'márc': 3,
  'március': 3,
  'mär': 3,
  'märz': 3,
  // 4
  'abr': 4,
  'abril': 4,
  'apr': 4,
  'april': 4,
  'aprile': 4,
  'avr': 4,
  'avril': 4,
  'ápr': 4,
  'április': 4,
  // 5
  'mag': 5,
  'maggio': 5,
  'mai': 5,
  'maio': 5,
  'may': 5,
  'mayo': 5,
  'mei': 5,
  'máj': 5,
  'május': 5,
  // 6
  'giu': 6,
  'giugno': 6,
  'juin': 6,
  'jun': 6,
  'june': 6,
  'junho': 6,
  'juni': 6,
  'junio': 6,
  'jún': 6,
  'június': 6,
  // 7
  'juil': 7,
  'juillet': 7,
  'jul': 7,
  'julho': 7,
  'juli': 7,
  'julio': 7,
  'july': 7,
  'júl': 7,
  'július': 7,
  'lug': 7,
  'luglio': 7,
  // 8
  'ago': 8,
  'agosto': 8,
  'août': 8,
  'aug': 8,
  'august': 8,
  'augustus': 8,
  'augusztus': 8,
  // 9
  'sep': 9,
  'sept': 9,
  'september': 9,
  'septembre': 9,
  'septiembre': 9,
  'set': 9,
  'setembro': 9,
  'settembre': 9,
  'szept': 9,
  'szeptember': 9,
  // 10
  'oct': 10,
  'october': 10,
  'octobre': 10,
  'octubre': 10,
  'okt': 10,
  'oktober': 10,
  'október': 10,
  'ott': 10,
  'ottobre': 10,
  'out': 10,
  'outubro': 10,
  // 11
  'nov': 11, 'november': 11, 'novembre': 11, 'novembro': 11, 'noviembre': 11,
  // 12
  'dec': 12,
  'december': 12,
  'dez': 12,
  'dezember': 12,
  'dezembro': 12,
  'dic': 12,
  'dicembre': 12,
  'diciembre': 12,
  'déc': 12,
  'décembre': 12,
};

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
