import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/presentation/editing/opening_hours_validation.dart';

void main() {
  OpeningHours sat(List<TimeRange> ranges) => OpeningHours(
    schedules: [
      OpeningSchedule(days: {DateTime.saturday: DayHours.ranges(ranges)}),
    ],
  );

  test('a range that closes before it opens is invalid', () {
    expect(invalidOpeningDays(sat(const [TimeRange(600, 500)])), {
      (0, DateTime.saturday),
    });
  });

  test('overlapping ranges are invalid', () {
    expect(
      invalidOpeningDays(sat(const [TimeRange(480, 720), TimeRange(700, 800)])),
      {(0, DateTime.saturday)},
    );
  });

  test('touching ranges are fine', () {
    expect(
      invalidOpeningDays(sat(const [TimeRange(480, 720), TimeRange(720, 800)])),
      isEmpty,
    );
  });

  test('no hours are fine', () {
    expect(invalidOpeningDays(const OpeningHours()), isEmpty);
  });
}
