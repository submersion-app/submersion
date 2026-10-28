import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';

/// Issue #3127: dives on each of the 366 calendar dates, across all years.
void main() {
  test('empty input has no dives, no coverage and no busiest values', () {
    final m = CalendarDayMatrix.fromCounts(const []);

    expect(m.isEmpty, isTrue);
    expect(m.total, 0);
    expect(m.coveredDays, 0);
    expect(m.coverage, 0);
    expect(m.maxCount, 0);
    expect(m.busiestMonths, isEmpty);
    expect(m.busiestDays, isEmpty);
    expect(m.count(5, 6), 0);
  });

  test('29 February is a date; 30 February and 31 April are not', () {
    expect(CalendarDayMatrix.isValidDate(2, 29), isTrue);
    expect(CalendarDayMatrix.isValidDate(2, 30), isFalse);
    for (final month in [4, 6, 9, 11]) {
      expect(CalendarDayMatrix.isValidDate(month, 30), isTrue);
      expect(CalendarDayMatrix.isValidDate(month, 31), isFalse);
    }
    expect(CalendarDayMatrix.isValidDate(12, 31), isTrue);
    expect(CalendarDayMatrix.isValidDate(13, 1), isFalse);
    expect(CalendarDayMatrix.isValidDate(0, 1), isFalse);
    expect(CalendarDayMatrix.isValidDate(1, 0), isFalse);
  });

  test('there are 366 valid dates', () {
    var dates = 0;
    for (var month = 1; month <= 12; month++) {
      for (var day = 1; day <= 31; day++) {
        if (CalendarDayMatrix.isValidDate(month, day)) dates++;
      }
    }
    expect(dates, CalendarDayMatrix.calendarDays);
    expect(CalendarDayMatrix.calendarDays, 366);
  });

  test('totals, coverage and the largest cell', () {
    final m = CalendarDayMatrix.fromCounts(const [
      (month: 5, day: 6, count: 14),
      (month: 5, day: 7, count: 2),
      (month: 8, day: 6, count: 3),
      (month: 2, day: 29, count: 1),
    ]);

    expect(m.total, 20);
    expect(m.monthTotals, hasLength(12));
    expect(m.monthTotals[4], 16);
    expect(m.monthTotals[7], 3);
    expect(m.monthTotals[1], 1);
    expect(m.dayTotals, hasLength(31));
    expect(m.dayTotals[5], 17);
    expect(m.dayTotals[28], 1);
    expect(m.coveredDays, 4);
    expect(m.coverage, closeTo(4 / 366, 1e-9));
    expect(m.maxCount, 14);
    expect(m.count(5, 6), 14);
    expect(m.count(2, 29), 1);
    expect(m.count(1, 1), 0);
    expect(m.busiestMonths, [5]);
    expect(m.busiestDays, [6]);
    expect(m.isEmpty, isFalse);
  });

  test('a date that does not exist has no count, even from a stray row', () {
    final m = CalendarDayMatrix.fromCounts(const [
      (month: 2, day: 30, count: 9),
      (month: 4, day: 31, count: 9),
      (month: 13, day: 1, count: 9),
    ]);

    expect(m.total, 0);
    expect(m.count(2, 30), isNull);
    expect(m.count(4, 31), isNull);
  });

  test('two rows for one date add up', () {
    final m = CalendarDayMatrix.fromCounts(const [
      (month: 3, day: 3, count: 2),
      (month: 3, day: 3, count: 5),
    ]);

    expect(m.count(3, 3), 7);
    expect(m.coveredDays, 1);
  });

  test('ties name every busiest month and day, in calendar order', () {
    final m = CalendarDayMatrix.fromCounts(const [
      (month: 8, day: 2, count: 4),
      (month: 5, day: 1, count: 4),
    ]);

    expect(m.busiestMonths, [5, 8]);
    expect(m.busiestDays, [1, 2]);
  });

  test('the totals cannot be changed from outside', () {
    final m = CalendarDayMatrix.fromCounts(const []);

    expect(() => m.monthTotals[0] = 1, throwsUnsupportedError);
    expect(() => m.dayTotals[0] = 1, throwsUnsupportedError);
  });
}
