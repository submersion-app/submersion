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
    expect(encodeOpeningHours(OpeningHours()), isNull);
    expect(encodeOpeningHours(OpeningHours(note: '  ')), isNull);
    expect(encodeOpeningHours(null), isNull);
  });

  test('always open alone is not empty', () {
    final encoded = encodeOpeningHours(OpeningHours(alwaysOpen: true));
    expect(decodeOpeningHours(encoded), OpeningHours(alwaysOpen: true));
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

  // A later version adds to v1, so this reader can show what it knows; a
  // save that leaves the hours alone must not rewrite them as v1 and drop
  // what it does not know (review).
  group('a newer version', () {
    String newer() {
      final map =
          jsonDecode(encodeOpeningHours(_specExample())!)
              as Map<String, dynamic>;
      map['v'] = 2;
      map['holidays'] = ['12-25'];
      return jsonEncode(map);
    }

    test('reads the fields this version knows', () {
      expect(decodeOpeningHours(newer()), _specExample());
    });

    test('is written back as stored while the hours are unedited', () {
      final raw = newer();
      expect(encodeOpeningHours(decodeOpeningHours(raw)), raw);
    });

    test('is written as this version once the hours are edited', () {
      final edited = decodeOpeningHours(newer())!.copyWith(note: 'Edited');
      final map = jsonDecode(encodeOpeningHours(edited)!) as Map;
      expect(map['v'], 1);
      expect(map['note'], 'Edited');
      expect(map.containsKey('holidays'), isFalse);
    });

    test('a v1 value is re-encoded, not kept as stored', () {
      final map =
          jsonDecode(encodeOpeningHours(_specExample())!)
              as Map<String, dynamic>;
      map['foo'] = 1;
      final hours = decodeOpeningHours(jsonEncode(map));
      expect(jsonDecode(encodeOpeningHours(hours)!), isNot(contains('foo')));
    });
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

  test('whole minutes written as decimals are read; fractions are not', () {
    const raw =
        '{"v":1,"schedules":[{"days":{"sat":[[540.0,720.0],[780.5,900]]}}]}';
    expect(
      decodeOpeningHours(
        raw,
      )!.schedules.single.dayHours(DateTime.saturday).ranges,
      const [TimeRange(540, 720)],
    );
  });

  test('a schedule and its hours keep their own copies (review)', () {
    final days = <int, DayHours>{DateTime.saturday: const DayHours.open24h()};
    final schedule = OpeningSchedule(days: days);
    final schedules = [schedule];
    final hours = OpeningHours(schedules: schedules);
    final before = OpeningHours(
      schedules: [
        OpeningSchedule(days: const {DateTime.saturday: DayHours.open24h()}),
      ],
    );

    days[DateTime.sunday] = const DayHours.open24h();
    schedules.add(OpeningSchedule());

    expect(hours, before);
    expect(
      () => hours.schedules.add(OpeningSchedule()),
      throwsUnsupportedError,
    );
    expect(
      () => schedule.days[DateTime.monday] = const DayHours.closed(),
      throwsUnsupportedError,
    );
  });
}
