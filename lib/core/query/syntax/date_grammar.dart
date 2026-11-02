/// The date phrases the typed language and Explore's sentences share
/// (#2365).
///
/// A small deterministic grammar over the words a diver types for a period
/// (`2025`, `2025-03`, `2025-03-14`, `14 march 2025`, `last 90 days`,
/// `since 2024`, ...).
/// Anything else is null rather than a guessed range. Pure Dart. Dates are
/// plain calendar values, which is what the date fields' day bounds read.
library;

import 'package:submersion/core/query/syntax/date_month_names.dart';

typedef DateRange = ({DateTime? start, DateTime? end});

const Map<String, int> _months = {
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sep': 9,
  'sept': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
};

/// The month (1 to 12) an English [word] names, in full or abbreviated as
/// the grammar reads it, or null.
int? monthOfWord(String word) => _months[word.toLowerCase()];

final RegExp _year = RegExp(r'^(\d{4})$');
final RegExp _isoMonth = RegExp(r'^(\d{4})-(\d{2})$');
final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _isoRange = RegExp(
  r'^(\d{4}-\d{2}-\d{2})\s+to\s+(\d{4}-\d{2}-\d{2})$',
);
// A month is any run with no space or digit, so that every app language fits.
final RegExp _monthYear = RegExp(r'^([^\s\d]+)\s+(\d{4})$');
final RegExp _dayMonthYear = RegExp(
  r'^(\d{1,2})(?:st|nd|rd|th|er)?(?:\s+of)?\s+([^\s\d]+)\s+(\d{4})$',
);
final RegExp _monthDayYear = RegExp(
  r'^([^\s\d]+)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(\d{4})$',
);
final RegExp _yearMonthDay = RegExp(r'^(\d{4})\s+([^\s\d]+)(?:\s+(\d{1,2}))?$');
final RegExp _chineseDate = RegExp(
  r'^(\d{4})\s*年(?:\s*(\d{1,2})\s*月(?:\s*(\d{1,2})\s*[日号])?)?$',
);
final RegExp _monthDot = RegExp(r'(?<=[^\s\d])\.');
final RegExp _periodRange = RegExp(r'^(.+)\s+to\s+(.+)$');
final RegExp _between = RegExp(r'^between\s+(.+)\s+and\s+(.+)$');
final RegExp _lastN = RegExp(
  r'^(?:last|past)\s+(\d{1,3})\s+(day|week|month|year)s?$',
);
final RegExp _since = RegExp(r'^since\s+(.+)$');
final RegExp _before = RegExp(r'^before\s+(.+)$');

/// The period [text] names, or null. English always reads; [language] adds
/// the month names and date order of that app language.
DateRange? parseDateText(
  String text, {
  required DateTime now,
  String? language,
}) {
  final t = text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(_monthDot, '');
  if (t.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);

  DateRange? year(int y) => y < 1900 || y > 2200
      ? null
      : (start: DateTime(y, 1, 1), end: DateTime(y, 12, 31));
  DateRange? month(int y, int m) => m < 1 || m > 12 || y < 1900 || y > 2200
      ? null
      : (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 0));
  DateRange? day(int y, int? mo, int d) {
    if (mo == null) return null;
    final whole = month(y, mo);
    if (whole == null || d < 1 || d > whole.end!.day) return null;
    final date = DateTime(y, mo, d);
    return (start: date, end: date);
  }

  DateRange? yearFirst(int y, int? mo, String? d) {
    if (mo == null) return null;
    return d == null ? month(y, mo) : day(y, mo, int.parse(d));
  }

  int? monthOf(String word) =>
      _months[word] ??
      (language == null ? null : monthInLanguage(word, language));

  var m = _year.firstMatch(t);
  if (m != null) return year(int.parse(m[1]!));
  m = _isoMonth.firstMatch(t);
  if (m != null) return month(int.parse(m[1]!), int.parse(m[2]!));
  m = _isoRange.firstMatch(t);
  if (m != null) {
    final a = parseIsoDay(m[1]!);
    final b = parseIsoDay(m[2]!);
    if (a == null || b == null || b.isBefore(a)) return null;
    return (start: a, end: b);
  }
  if (_isoDate.hasMatch(t)) {
    final d = parseIsoDay(t);
    return d == null ? null : (start: d, end: d);
  }
  // Before the open-ended forms: "since 2018 to 2020" would otherwise read
  // as an open bound over a closed range.
  final between = _between.firstMatch(t);
  m = between ?? _periodRange.firstMatch(t);
  if (m != null) {
    // Both periods must be closed: "since 2018" has no end to span from.
    final first = parseDateText(m[1]!, now: now, language: language);
    final last = parseDateText(m[2]!, now: now, language: language);
    if ((first, last) case (
      (start: final DateTime from, end: DateTime _),
      (start: DateTime _, end: final DateTime to),
    )) {
      if (!to.isBefore(from)) return (start: from, end: to);
      // "between" has no direction, unlike "to", which is likely a slip.
      if (between != null) {
        return parseDateText(
          'between ${m[2]} and ${m[1]}',
          now: now,
          language: language,
        );
      }
    }
    return null;
  }
  // Open-ended forms first: "since 2022" also matches the month-year shape
  // below, whose unknown-month branch would swallow it.
  m = _since.firstMatch(t);
  if (m != null) {
    final inner = parseDateText(m[1]!, now: now, language: language);
    if (inner?.start == null) return null;
    return (start: inner!.start, end: null);
  }
  m = _before.firstMatch(t);
  if (m != null) {
    final inner = parseDateText(m[1]!, now: now, language: language);
    final first = inner?.start;
    if (first == null) return null;
    // Calendar arithmetic: see the Duration note under "last N days".
    return (start: null, end: DateTime(first.year, first.month, first.day - 1));
  }
  m = _monthYear.firstMatch(t);
  if (m != null) {
    final mo = monthOf(m[1]!);
    return mo == null ? null : month(int.parse(m[2]!), mo);
  }
  m = _dayMonthYear.firstMatch(t);
  if (m != null) return day(int.parse(m[3]!), monthOf(m[2]!), int.parse(m[1]!));
  m = _monthDayYear.firstMatch(t);
  if (m != null) return day(int.parse(m[3]!), monthOf(m[1]!), int.parse(m[2]!));
  // Only Hungarian: elsewhere `2018 may` is a year and a word.
  m = language == 'hu' ? _yearMonthDay.firstMatch(t) : null;
  if (m != null) return yearFirst(int.parse(m[1]!), monthOf(m[2]!), m[3]);
  m = _chineseDate.firstMatch(t);
  if (m != null) {
    final y = int.parse(m[1]!);
    final mo = m[2];
    return mo == null ? year(y) : yearFirst(y, int.parse(mo), m[3]);
  }
  switch (t) {
    case 'this year':
      return year(today.year);
    case 'last year':
      return year(today.year - 1);
    case 'this month':
      return month(today.year, today.month);
    case 'last month':
      return today.month == 1
          ? month(today.year - 1, 12)
          : month(today.year, today.month - 1);
  }
  m = _lastN.firstMatch(t);
  if (m != null) {
    final n = int.parse(m[1]!);
    final start = switch (m[2]!) {
      // Calendar arithmetic, never a Duration: a 24 h span from a local
      // midnight lands a day early across a spring-forward change.
      'day' => DateTime(today.year, today.month, today.day - n),
      'week' => DateTime(today.year, today.month, today.day - 7 * n),
      // Month and year steps keep the day of month, clamped to the target
      // month's length: DateTime would roll "February 31" into March.
      'month' => _sameDayIn(today.year, today.month - n, today.day),
      _ => _sameDayIn(today.year - n, today.month, today.day),
    };
    return (start: start, end: today);
  }
  return null;
}

/// A padded `yyyy-mm-dd` as a calendar day, or null when it is not one or
/// names an impossible day (2025-02-30). Shared with the JSON codec.
/// Day [day] of the month [year]-[month] (month may be out of range and is
/// normalized), clamped to that month's last day.
DateTime _sameDayIn(int year, int month, int day) {
  final first = DateTime(year, month, 1);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, day < lastDay ? day : lastDay);
}

DateTime? parseIsoDay(String s) {
  final m = _isoDate.firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, mo, d);
  return date.month == mo ? date : null;
}
