import 'package:meta/meta.dart';

/// Dives logged on one calendar date (month 1..12, day 1..31), across all
/// years.
typedef CalendarDayCount = ({int month, int day, int count});

/// Dives on each of the 366 calendar dates, regardless of year (issue
/// #3127): the Time patterns "Calendar days" matrix.
///
/// Built from per-date counts; every total, the coverage and the busiest
/// month and day of the month are derived here, so the query stays a plain
/// GROUP BY.
@immutable
class CalendarDayMatrix {
  const CalendarDayMatrix._({
    required List<List<int>> cells,
    required this.monthTotals,
    required this.dayTotals,
    required this.total,
    required this.coveredDays,
    required this.maxCount,
    required this.busiestMonths,
    required this.busiestDays,
  }) : _cells = cells;

  /// Counts [rows] by date. A row for a date that does not exist (30
  /// February, month 13) is ignored; two rows for one date add up.
  factory CalendarDayMatrix.fromCounts(Iterable<CalendarDayCount> rows) {
    final cells = List.generate(12, (_) => List.filled(31, 0));
    for (final r in rows) {
      if (!isValidDate(r.month, r.day)) continue;
      cells[r.month - 1][r.day - 1] += r.count;
    }
    // Everything derived is computed once here: the card reads maxCount for
    // each of its 372 cells.
    final monthTotals = List<int>.unmodifiable([
      for (final row in cells) row.fold<int>(0, (sum, c) => sum + c),
    ]);
    final dayTotals = List<int>.unmodifiable([
      for (var d = 0; d < 31; d++)
        cells.fold<int>(0, (sum, row) => sum + row[d]),
    ]);
    return CalendarDayMatrix._(
      cells: List.unmodifiable([
        for (final row in cells) List<int>.unmodifiable(row),
      ]),
      monthTotals: monthTotals,
      dayTotals: dayTotals,
      total: monthTotals.fold(0, (sum, t) => sum + t),
      coveredDays: cells.fold(
        0,
        (sum, row) => sum + row.where((c) => c > 0).length,
      ),
      maxCount: cells.fold(
        0,
        (m, row) => row.fold(m, (rm, c) => c > rm ? c : rm),
      ),
      busiestMonths: _argMax(monthTotals),
      busiestDays: _argMax(dayTotals),
    );
  }

  /// Every date a dive can fall on, 29 February included.
  static const int calendarDays = 366;

  static const List<int> _daysInMonth = [
    31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, //
  ];

  /// Whether [month] (1..12) has a day [day] (1..31) in a leap year.
  static bool isValidDate(int month, int day) =>
      month >= 1 && month <= 12 && day >= 1 && day <= _daysInMonth[month - 1];

  final List<List<int>> _cells;

  /// Dives per month, January first.
  final List<int> monthTotals;

  /// Dives per day of the month, day 1 first.
  final List<int> dayTotals;

  /// Dives on [month] / [day], or null when that date does not exist.
  int? count(int month, int day) =>
      isValidDate(month, day) ? _cells[month - 1][day - 1] : null;

  /// Every dive counted.
  final int total;

  bool get isEmpty => total == 0;

  /// Dates with at least one dive.
  final int coveredDays;

  /// [coveredDays] as a fraction of [calendarDays].
  double get coverage => coveredDays / calendarDays;

  /// The most dives on any one date.
  final int maxCount;

  /// Every month tied for the most dives (1-based, in calendar order);
  /// empty when there are no dives.
  final List<int> busiestMonths;

  /// Every day of the month tied for the most dives (1-based, ascending);
  /// empty when there are no dives.
  final List<int> busiestDays;

  static List<int> _argMax(List<int> totals) {
    final best = totals.fold(0, (m, t) => t > m ? t : m);
    if (best == 0) return const [];
    return List.unmodifiable([
      for (var i = 0; i < totals.length; i++)
        if (totals[i] == best) i + 1,
    ]);
  }
}
