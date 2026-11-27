import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/opening_hours/opening_status.dart';

const _summer = YearlyDateRange(start: MonthDay(4, 1), end: MonthDay(10, 31));
const _winter = YearlyDateRange(start: MonthDay(11, 1), end: MonthDay(3, 31));

OpeningSchedule _week(
  Map<int, DayHours> days, {
  String? name,
  YearlyDateRange? season,
}) => OpeningSchedule(name: name, season: season, days: days);

// 2026-11-28 is a Saturday.
DateTime _sat(int h, [int m = 0]) => DateTime(2026, 11, 28, h, m);

void main() {
  group('scheduleOn', () {
    final allYear = _week({}, name: 'All year');
    final summer = _week({}, name: 'Summer', season: _summer);
    final hours = OpeningHours(schedules: [allYear, summer]);

    test('a summer season inside an all-year schedule wins in July', () {
      expect(scheduleOn(hours, DateTime(2026, 7, 15)), summer);
    });

    test('the all-year schedule applies in December', () {
      expect(scheduleOn(hours, DateTime(2026, 12, 15)), allYear);
    });

    test('a wrapping winter season contains 15 Jan and 1 Nov, not 1 Apr', () {
      final winterOnly = OpeningHours(schedules: [_week({}, season: _winter)]);
      expect(scheduleOn(winterOnly, DateTime(2027, 1, 15)), isNotNull);
      expect(scheduleOn(winterOnly, DateTime(2026, 11, 1)), isNotNull);
      expect(scheduleOn(winterOnly, DateTime(2027, 4, 1)), isNull);
    });

    test('a 29 Feb season start in a non-leap year', () {
      final spring = OpeningHours(
        schedules: [
          _week(
            {},
            season: const YearlyDateRange(
              start: MonthDay(2, 29),
              end: MonthDay(3, 31),
            ),
          ),
        ],
      );
      expect(scheduleOn(spring, DateTime(2027, 3, 1)), isNotNull);
      expect(scheduleOn(spring, DateTime(2027, 2, 28)), isNull);
    });

    test('ties go to the earlier schedule', () {
      final a = _week({}, name: 'A', season: _summer);
      final b = _week({}, name: 'B', season: _summer);
      expect(
        scheduleOn(OpeningHours(schedules: [a, b]), DateTime(2026, 6, 1)),
        a,
      );
    });
  });

  group('openingStatusAt', () {
    final split = OpeningHours(
      schedules: [
        _week({
          DateTime.saturday: DayHours.ranges(const [
            TimeRange(480, 720),
            TimeRange(780, 1020),
          ]),
        }),
      ],
    );

    test('open inside a range', () {
      expect(openingStatusAt(split, _sat(10, 30)), OpenNow(closesAt: _sat(12)));
    });

    test('closed in the lunch gap', () {
      expect(
        openingStatusAt(split, _sat(12, 30)),
        ClosedNow(nextOpen: _sat(13), outOfSeason: false),
      );
    });

    test('the next opening can be days away', () {
      final satOnly = OpeningHours(
        schedules: [
          _week({
            DateTime.saturday: DayHours.ranges(const [TimeRange(600, 840)]),
          }),
        ],
      );
      // Tuesday 24 Nov 2026.
      expect(
        openingStatusAt(satOnly, DateTime(2026, 11, 24, 9)),
        ClosedNow(nextOpen: _sat(10), outOfSeason: false),
      );
    });

    test('out of season points at the season start', () {
      final summerOnly = OpeningHours(
        schedules: [
          _week({
            DateTime.monday: DayHours.ranges(const [TimeRange(540, 1020)]),
            DateTime.wednesday: DayHours.ranges(const [TimeRange(540, 1020)]),
          }, season: _summer),
        ],
      );
      // 1 Apr 2027 is a Thursday; first opening Monday 5 Apr.
      expect(
        openingStatusAt(summerOnly, DateTime(2026, 12, 15, 10)),
        ClosedNow(nextOpen: DateTime(2027, 4, 5, 9), outOfSeason: true),
      );
    });

    test('a schedule that never opens has no next opening', () {
      final shut = OpeningHours(schedules: [_week({})]);
      expect(
        openingStatusAt(shut, _sat(10)),
        const ClosedNow(nextOpen: null, outOfSeason: false),
      );
    });

    test('a range ending at midnight joins one starting at midnight', () {
      final late = OpeningHours(
        schedules: [
          _week({
            DateTime.friday: DayHours.ranges(const [TimeRange(1080, 1440)]),
            DateTime.saturday: DayHours.ranges(const [TimeRange(0, 120)]),
          }),
        ],
      );
      expect(
        openingStatusAt(late, DateTime(2026, 11, 27, 23)),
        OpenNow(closesAt: _sat(2)),
      );
    });

    test('always open has no closing time', () {
      expect(
        openingStatusAt(const OpeningHours(alwaysOpen: true), _sat(3)),
        const OpenNow(closesAt: null),
      );
    });

    test('a 24 hour day followed by a closed day closes at midnight', () {
      final sat24 = OpeningHours(
        schedules: [
          _week({DateTime.saturday: const DayHours.open24h()}),
        ],
      );
      expect(
        openingStatusAt(sat24, _sat(15)),
        OpenNow(closesAt: DateTime(2026, 11, 29)),
      );
    });

    test('a week of 24 hour days has no closing time', () {
      final everyDay = OpeningHours(
        schedules: [
          _week({
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              d: const DayHours.open24h(),
          }),
        ],
      );
      expect(
        openingStatusAt(everyDay, _sat(15)),
        const OpenNow(closesAt: null),
      );
    });

    test('a note alone is unknown', () {
      expect(
        openingStatusAt(const OpeningHours(note: 'Call ahead'), _sat(10)),
        const OpeningUnknown(),
      );
    });
  });
}
