/// A small deterministic grammar over the model's own words for a period.
///
/// The model is asked to phrase time in one of these shapes; anything else
/// becomes an unplaced chip rather than a guessed range. Pure Dart. Dates are
/// plain calendar values, which is what DiveFilterState's date axes read.
library;

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

final RegExp _year = RegExp(r'^(\d{4})$');
final RegExp _isoMonth = RegExp(r'^(\d{4})-(\d{2})$');
final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _isoRange = RegExp(
  r'^(\d{4}-\d{2}-\d{2})\s+to\s+(\d{4}-\d{2}-\d{2})$',
);
final RegExp _monthYear = RegExp(r'^([a-z]+)\s+(\d{4})$');
final RegExp _lastN = RegExp(
  r'^(?:last|past)\s+(\d{1,3})\s+(day|week|month|year)s?$',
);
final RegExp _since = RegExp(r'^since\s+(.+)$');
final RegExp _before = RegExp(r'^before\s+(.+)$');

DateRange? parseTimeText(String text, {required DateTime now}) {
  final t = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);

  DateRange? year(int y) => y < 1900 || y > 2200
      ? null
      : (start: DateTime(y, 1, 1), end: DateTime(y, 12, 31));
  DateRange? month(int y, int m) => m < 1 || m > 12 || y < 1900 || y > 2200
      ? null
      : (start: DateTime(y, m, 1), end: DateTime(y, m + 1, 0));

  var m = _year.firstMatch(t);
  if (m != null) return year(int.parse(m[1]!));
  m = _isoMonth.firstMatch(t);
  if (m != null) return month(int.parse(m[1]!), int.parse(m[2]!));
  m = _isoRange.firstMatch(t);
  if (m != null) {
    final a = _parseIso(m[1]!);
    final b = _parseIso(m[2]!);
    if (a == null || b == null || b.isBefore(a)) return null;
    return (start: a, end: b);
  }
  if (_isoDate.hasMatch(t)) {
    final d = _parseIso(t);
    return d == null ? null : (start: d, end: d);
  }
  // Open-ended forms first: "since 2022" also matches the month-year shape
  // below, whose unknown-month branch would swallow it.
  m = _since.firstMatch(t);
  if (m != null) {
    final inner = parseTimeText(m[1]!, now: now);
    if (inner?.start == null) return null;
    return (start: inner!.start, end: null);
  }
  m = _before.firstMatch(t);
  if (m != null) {
    final inner = parseTimeText(m[1]!, now: now);
    if (inner?.start == null) return null;
    return (start: null, end: inner!.start!.subtract(const Duration(days: 1)));
  }
  m = _monthYear.firstMatch(t);
  if (m != null) {
    final mo = _months[m[1]!];
    return mo == null ? null : month(int.parse(m[2]!), mo);
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
      'day' => today.subtract(Duration(days: n)),
      'week' => today.subtract(Duration(days: 7 * n)),
      'month' => DateTime(today.year, today.month - n, today.day),
      _ => DateTime(today.year - n, today.month, today.day),
    };
    return (start: start, end: today);
  }
  return null;
}

DateTime? _parseIso(String s) {
  final m = _isoDate.firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, mo, d);
  return date.month == mo ? date : null;
}
