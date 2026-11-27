import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/presentation/opening_hours_summary.dart';

void main() {
  const mondayFirst = [1, 2, 3, 4, 5, 6, 7];
  const sundayFirst = [7, 1, 2, 3, 4, 5, 6];
  final weekday = DayHours.ranges(const [TimeRange(540, 1020)]);
  final weekend = DayHours.ranges(const [TimeRange(480, 960)]);
  final week = OpeningSchedule(
    days: {for (var d = 1; d <= 5; d++) d: weekday, 6: weekend, 7: weekend},
  );

  test('weekdays and the weekend collapse into two groups', () {
    final groups = groupDays(week, weekOrder: mondayFirst);
    expect(groups.map((g) => g.weekdays), [
      [1, 2, 3, 4, 5],
      [6, 7],
    ]);
    expect(groups.first.hours, weekday);
  });

  test('a Sunday-first week splits the weekend', () {
    final groups = groupDays(week, weekOrder: sundayFirst);
    expect(groups.map((g) => g.weekdays), [
      [7],
      [1, 2, 3, 4, 5],
      [6],
    ]);
  });

  test('a week closed every day is one group of seven', () {
    final groups = groupDays(const OpeningSchedule(), weekOrder: mondayFirst);
    expect(groups.single.weekdays, mondayFirst);
    expect(groups.single.hours.isClosed, isTrue);
  });

  test("today's schedule is listed first", () {
    const summer = OpeningSchedule(
      name: 'Summer',
      season: YearlyDateRange(start: MonthDay(4, 1), end: MonthDay(10, 31)),
    );
    const winter = OpeningSchedule(
      name: 'Winter',
      season: YearlyDateRange(start: MonthDay(11, 1), end: MonthDay(3, 31)),
    );
    const hours = OpeningHours(schedules: [summer, winter]);
    expect(schedulesInDisplayOrder(hours, DateTime(2026, 12, 1)), [
      winter,
      summer,
    ]);
    expect(schedulesInDisplayOrder(hours, DateTime(2026, 6, 1)), [
      summer,
      winter,
    ]);
  });
}
