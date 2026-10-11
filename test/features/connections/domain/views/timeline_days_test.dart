import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

void main() {
  final DayRange span = (
    start: DateTime(2019, 1, 1),
    end: DateTime(2022, 12, 31),
  );

  test('calendarDay drops the time of day', () {
    expect(calendarDay(DateTime(2020, 5, 6, 23, 59)), DateTime(2020, 5, 6));
  });

  test('dayIndex and dayAt agree across a leap year and a DST change', () {
    expect(dayIndex(DateTime(2019, 1, 1), DateTime(2020, 12, 31)), 730);
    expect(dayAt(DateTime(2019, 1, 1), 730), DateTime(2020, 12, 31));
    // March and late October hold DST changes in most zones that have them.
    expect(dayIndex(DateTime(2024, 3, 1), DateTime(2024, 4, 1)), 31);
    expect(dayAt(DateTime(2024, 3, 1), 31), DateTime(2024, 4, 1));
    expect(dayAt(DateTime(2024, 10, 20), 14), DateTime(2024, 11, 3));
  });

  test('clampDays holds a range inside the span, start never after end', () {
    expect(clampDays((start: DateTime(2010), end: DateTime(2030)), span), span);
    expect(clampDays((start: DateTime(2030), end: DateTime(2010)), span), (
      start: DateTime(2019, 1, 1),
      end: DateTime(2019, 1, 1),
    ));
    expect(
      clampDays((
        start: DateTime(2020, 2, 3, 10),
        end: DateTime(2021, 4, 5, 22),
      ), span),
      (start: DateTime(2020, 2, 3), end: DateTime(2021, 4, 5)),
    );
  });

  test('filteredDays reads a missing date as the span end it stands for', () {
    expect(filteredDays(const DiveFilterState(), span), span);
    expect(
      filteredDays(DiveFilterState(startDate: DateTime(2020, 6, 1)), span),
      (start: DateTime(2020, 6, 1), end: DateTime(2022, 12, 31)),
    );
    expect(
      filteredDays(DiveFilterState(startDate: DateTime(2001)), span),
      span,
    );
  });

  test('filterWithDays clears the dates for the whole span', () {
    final filter = DiveFilterState(
      startDate: DateTime(2020),
      endDate: DateTime(2021),
    );
    final whole = filterWithDays(filter, span, span);
    expect(whole.startDate, isNull);
    expect(whole.endDate, isNull);
  });

  test('filterWithDays leaves an end at the span edge open', () {
    // An open end keeps dives logged later on the map; a date at the last
    // dive day would silently drop them.
    final toEnd = filterWithDays(const DiveFilterState(), (
      start: DateTime(2020, 3, 4),
      end: DateTime(2022, 12, 31),
    ), span);
    expect(toEnd.startDate, DateTime(2020, 3, 4));
    expect(toEnd.endDate, isNull);
    final fromStart = filterWithDays(const DiveFilterState(), (
      start: DateTime(2019, 1, 1),
      end: DateTime(2020, 3, 4),
    ), span);
    expect(fromStart.startDate, isNull);
    expect(fromStart.endDate, DateTime(2020, 3, 4));
  });

  test('filterWithDays writes both days for a range inside the span', () {
    final one = filterWithDays(const DiveFilterState(), (
      start: DateTime(2021, 7, 7),
      end: DateTime(2021, 7, 7),
    ), span);
    expect(one.startDate, DateTime(2021, 7, 7));
    expect(one.endDate, DateTime(2021, 7, 7));
  });
}
