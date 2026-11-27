import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/opening_hours/opening_hours_codec.dart';

const _weekday = DayHours.closed();

OpeningHours _specExample() {
  final summerDay = DayHours.ranges(const [TimeRange(540, 1020)]);
  final summerWeekend = DayHours.ranges(const [
    TimeRange(480, 720),
    TimeRange(780, 1020),
  ]);
  final winterWeekend = DayHours.ranges(const [TimeRange(540, 960)]);
  return OpeningHours(
    note: 'Book slots by phone. Closed 25 Dec.',
    schedules: [
      OpeningSchedule(
        name: 'Summer',
        season: const YearlyDateRange(
          start: MonthDay(4, 1),
          end: MonthDay(10, 31),
        ),
        days: {
          DateTime.monday: summerDay,
          DateTime.tuesday: summerDay,
          DateTime.wednesday: summerDay,
          DateTime.thursday: summerDay,
          DateTime.friday: summerDay,
          DateTime.saturday: summerWeekend,
          DateTime.sunday: summerWeekend,
        },
      ),
      OpeningSchedule(
        name: 'Winter',
        season: const YearlyDateRange(
          start: MonthDay(11, 1),
          end: MonthDay(3, 31),
        ),
        days: {
          DateTime.monday: _weekday,
          DateTime.saturday: winterWeekend,
          DateTime.sunday: winterWeekend,
        },
      ),
    ],
  );
}

void main() {
  test('round trips the spec example', () {
    final hours = _specExample();
    expect(decodeOpeningHours(encodeOpeningHours(hours)), hours);
  });

  test('encodes the spec JSON shape', () {
    final json =
        jsonDecode(encodeOpeningHours(_specExample())!) as Map<String, dynamic>;
    expect(json['v'], 1);
    expect(json['alwaysOpen'], false);
    expect(json['note'], 'Book slots by phone. Closed 25 Dec.');
    final schedules = json['schedules'] as List;
    final summer = schedules[0] as Map<String, dynamic>;
    expect(summer['name'], 'Summer');
    expect(summer['season'], {'start': '04-01', 'end': '10-31'});
    final days = summer['days'] as Map<String, dynamic>;
    expect(days['sat'], [
      [480, 720],
      [780, 1020],
    ]);
    final winterDays =
        (schedules[1] as Map<String, dynamic>)['days'] as Map<String, dynamic>;
    expect(winterDays.containsKey('mon'), isFalse);
  });

  test('a "24h" day value decodes to open24h and encodes back', () {
    const raw =
        '{"v":1,"alwaysOpen":false,"schedules":[{"days":{"sun":"24h"}}]}';
    final hours = decodeOpeningHours(raw)!;
    expect(
      hours.schedules.single.dayHours(DateTime.sunday),
      const DayHours.open24h(),
    );
    expect(
      hours.schedules.single.dayHours(DateTime.monday).kind,
      DayHoursKind.closed,
    );
    final back = jsonDecode(encodeOpeningHours(hours)!) as Map;
    expect(((back['schedules'] as List).single as Map)['days'], {'sun': '24h'});
  });

  test('empty hours encode to null', () {
    expect(encodeOpeningHours(const OpeningHours()), isNull);
    expect(encodeOpeningHours(const OpeningHours(note: '  ')), isNull);
    expect(encodeOpeningHours(null), isNull);
  });

  test('always open alone is not empty', () {
    final encoded = encodeOpeningHours(const OpeningHours(alwaysOpen: true));
    expect(decodeOpeningHours(encoded), const OpeningHours(alwaysOpen: true));
  });

  test('a value that is not a JSON object decodes to null', () {
    for (final raw in ['garbage', '[]', '42', '', null]) {
      expect(decodeOpeningHours(raw), isNull, reason: '$raw');
    }
  });

  test('drops a malformed range and keeps the rest', () {
    const raw =
        '{"v":1,"schedules":[{"days":{"sat":[[600,500],[540,600],"x",[0,1441]]}}]}';
    final day = decodeOpeningHours(
      raw,
    )!.schedules.single.dayHours(DateTime.saturday);
    expect(day.ranges, const [TimeRange(540, 600)]);
  });

  test('drops an invalid season and treats the schedule as all year', () {
    const raw =
        '{"v":1,"schedules":[{"season":{"start":"02-30","end":"13-01"},'
        '"days":{"sat":[[540,600]]}}]}';
    expect(decodeOpeningHours(raw)!.schedules.single.season, isNull);
  });

  test('ignores unknown keys', () {
    final clean = encodeOpeningHours(_specExample())!;
    final map = jsonDecode(clean) as Map<String, dynamic>;
    map['foo'] = 1;
    ((map['schedules'] as List).first as Map<String, dynamic>)['bar'] = 'x';
    expect(decodeOpeningHours(jsonEncode(map)), _specExample());
  });

  group('YearlyDateRange', () {
    test('29 Feb is a valid month day', () {
      expect(const MonthDay(2, 29).isValid, isTrue);
      expect(const MonthDay(2, 30).isValid, isFalse);
      expect(const MonthDay(4, 31).isValid, isFalse);
    });

    test('a wrapping range is longer than its parts suggest', () {
      const winter = YearlyDateRange(
        start: MonthDay(11, 1),
        end: MonthDay(3, 31),
      );
      expect(winter.lengthInDays, 30 + 31 + 31 + 29 + 31);
    });
  });

  test('ranges are kept sorted', () {
    final day = DayHours.ranges(const [
      TimeRange(780, 900),
      TimeRange(480, 600),
    ]);
    expect(day.ranges.first.opensAt, 480);
  });

  test('copyWith changes only what it is given', () {
    expect(const MonthDay(4, 1).copyWith(day: 15), const MonthDay(4, 15));
    expect(const MonthDay(4, 1).copyWith(month: 5), const MonthDay(5, 1));
    final day = DayHours.ranges(const [TimeRange(480, 720)]);
    expect(
      day.copyWith(ranges: const [TimeRange(780, 900), TimeRange(480, 720)]),
      DayHours.ranges(const [TimeRange(480, 720), TimeRange(780, 900)]),
    );
    expect(day.copyWith(kind: DayHoursKind.open24h), const DayHours.open24h());
    expect(day.copyWith(kind: DayHoursKind.closed), const DayHours.closed());
  });
}
