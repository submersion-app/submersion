import 'package:intl/date_time_patterns.dart';

/// Which field comes first in a numeric date written with the year last.
///
/// `03/04/1991` is 4 March when read [monthFirst] and 3 April when read
/// [dayFirst]. Nothing in the single value says which, so the order is decided
/// for a whole column by [detectColumnDateOrder].
enum DateOrder { monthFirst, dayFirst }

/// A numeric date with the year last, split into its parts.
///
/// [first] and [second] are the two leading fields in the order written;
/// [year] is the raw year text (two or four digits); [separator] is the `/`,
/// `.` or `-` between them.
typedef YearLastDate = ({int first, int second, String year, String separator});

/// `d/M/yy`, `dd.MM.yyyy`, `M-d-yyyy` and the like. The backreference makes
/// the two separators match, so `03/04-1991` is not a date.
final _yearLastPattern = RegExp(r'^(\d{1,2})([./-])(\d{1,2})\2(\d{2}|\d{4})$');

/// Where the date ends in a combined date-time value: any whitespace (a tab
/// or a non-breaking space as well as a space) or an ISO `T`.
final _dateTimeBoundary = RegExp(r'\s|T');

/// Splits [value] as a year-last numeric date, or returns null if it is
/// anything else (including a date followed by a time).
YearLastDate? matchYearLastDate(String value) {
  final match = _yearLastPattern.firstMatch(value.trim());
  if (match == null) return null;
  return (
    first: int.parse(match.group(1)!),
    second: int.parse(match.group(3)!),
    year: match.group(4)!,
    separator: match.group(2)!,
  );
}

/// Regions whose numeric dates put the month first: the United States and
/// its territories, the Philippines and the Micronesian states. Everywhere
/// else a year-last numeric date starts with the day.
const _monthFirstRegions = {
  'US',
  'AS',
  'GU',
  'MP',
  'PR',
  'UM',
  'VI',
  'PH',
  'FM',
  'MH',
  'PW',
};

/// The order a locale writes its short numeric dates in.
///
/// An exact CLDR locale is read from the `yMd` skeleton that intl ships
/// (`M/d/y` for en_US, `dd/MM/y` for en_GB), which needs no async locale
/// initialisation. intl only carries a few regional variants, so a locale it
/// does not list is decided by its region, which is what sets the date
/// convention: an English-language device in France writes 15/04/1991, not
/// 4/15/1991. Without a region the language decides. An unknown locale gives
/// [DateOrder.monthFirst], which is how slash dates were always read before
/// the order became configurable.
///
/// Accepts `en_GB`, `en-GB`, a script (`zh_Hans_CN`) and a POSIX encoding
/// suffix (`en_GB.UTF-8`).
DateOrder dateOrderForLocale(String? localeTag) {
  if (localeTag == null) return DateOrder.monthFirst;
  final parts = localeTag
      .split(RegExp('[.@]'))
      .first
      .split(RegExp('[-_]'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return DateOrder.monthFirst;

  final language = parts.first.toLowerCase();
  final region = parts
      .skip(1)
      .where((part) => RegExp(r'^[A-Za-z]{2}$').hasMatch(part))
      .map((part) => part.toUpperCase())
      .firstOrNull;

  final patterns = dateTimePatternMap();
  final exact = region == null ? null : patterns['${language}_$region'];
  final pattern = exact?['yMd'];
  if (pattern != null) return _orderOfPattern(pattern);

  if (region != null) {
    return _monthFirstRegions.contains(region)
        ? DateOrder.monthFirst
        : DateOrder.dayFirst;
  }

  final languagePattern = patterns[language]?['yMd'];
  return languagePattern == null
      ? DateOrder.monthFirst
      : _orderOfPattern(languagePattern);
}

/// Whether a CLDR date pattern such as `dd/MM/y` has the day before the month.
DateOrder _orderOfPattern(String pattern) {
  final day = pattern.indexOf('d');
  final month = pattern.indexOf(RegExp('[ML]'));
  if (day < 0 || month < 0) return DateOrder.monthFirst;
  return day < month ? DateOrder.dayFirst : DateOrder.monthFirst;
}

/// Decides how a whole column of dates should be read.
///
/// A leading field of 13 to 31 can only be a day, so any such value makes the
/// column [DateOrder.dayFirst]; a second field of 13 to 31 makes it
/// [DateOrder.monthFirst]. Values above 31 prove nothing (they are not a day
/// or a month), and ISO or other year-first values are ignored.
///
/// When the column has no such evidence, or contradicts itself, a column
/// written with slashes follows [localeOrder]. A column written only with dots
/// or dashes returns null, keeping the day-first reading those separators
/// have always had: the device locale is no reason to start reading
/// `03.04.1991` as 4 March.
///
/// Combined date-time values are accepted; only the part before the first
/// space or `T` is read.
DateOrder? detectColumnDateOrder(
  Iterable<String?> values, {
  required DateOrder localeOrder,
}) {
  var dayFirstEvidence = false;
  var monthFirstEvidence = false;
  var hasSlashes = false;

  for (final value in values) {
    if (value == null) continue;
    final date = matchYearLastDate(value.trim().split(_dateTimeBoundary).first);
    if (date == null) continue;
    if (date.separator == '/') hasSlashes = true;
    if (_canOnlyBeDay(date.first) && date.second <= 12) {
      dayFirstEvidence = true;
    }
    if (_canOnlyBeDay(date.second) && date.first <= 12) {
      monthFirstEvidence = true;
    }
  }

  if (dayFirstEvidence && !monthFirstEvidence) return DateOrder.dayFirst;
  if (monthFirstEvidence && !dayFirstEvidence) return DateOrder.monthFirst;
  return hasSlashes ? localeOrder : null;
}

bool _canOnlyBeDay(int field) => field > 12 && field <= 31;
