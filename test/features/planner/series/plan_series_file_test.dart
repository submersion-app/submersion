import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

import 'series_fixtures.dart';

/// A series in a `.subplan` file (issue #3565).
void main() {
  StoredSeries series() => StoredSeries(
    id: 's1',
    name: 'Reef day',
    followedDiveId: 'somebody-elses',
    dives: [
      StoredSeriesDive(
        plan: divePlanFromState(seriesDiveState(id: 'a')),
        name: 'Wreck',
      ),
      StoredSeriesDive(
        plan: divePlanFromState(
          seriesDiveState(id: 'b', surfaceInterval: const Duration(hours: 2)),
        ),
        fixedStart: true,
        settingOverrides: const {PlanSettingGroup.deco},
        sourceTankIds: const {'b-back': 'a-back', 'b-stage': 'a-stage'},
        pinnedTankIds: const {'b-stage'},
      ),
    ],
  );

  test('a series comes back whole, under new ids', () {
    final json = seriesToSubplanJson(series());
    final read = seriesFromSubplanJson(json)!;

    expect(read.id, isNot('s1'));
    expect(read.name, 'Reef day');
    expect(read.dives, hasLength(2));
    expect(read.dives[0].name, 'Wreck');
    final a = read.dives[0].plan;
    final b = read.dives[1];
    expect(a.id, isNot('a'));
    expect(b.plan.surfaceInterval, const Duration(hours: 2));
    expect(b.settingOverrides, {PlanSettingGroup.deco});
    expect(b.sourceTankIds, {
      b.plan.tanks[0].id: a.tanks[0].id,
      b.plan.tanks[1].id: a.tanks[1].id,
    });
    expect(b.pinnedTankIds, {b.plan.tanks[1].id});
  });

  test('what belongs to the sender stays out of the file', () {
    final read = seriesFromSubplanJson(seriesToSubplanJson(series()))!;

    expect(read.followedDiveId, isNull);
    expect(read.dives[1].fixedStart, isFalse);
  });

  test('a series file reads as its first dive to the single-plan reader', () {
    final plan = subplanFromJson(seriesToSubplanJson(series()));

    expect(plan.tanks, hasLength(2));
  });

  test('a single plan file holds no series, and stays an older version', () {
    final json = planToSubplanJson(series().dives.first.plan);

    expect(seriesFromSubplanJson(json), isNull);
    expect((jsonDecode(json) as Map)['version'], 2);
  });

  test('a series file says the version that added series', () {
    final json = seriesToSubplanJson(series());
    expect((jsonDecode(json) as Map)['version'], 4);
  });

  test('a series with no dives, or malformed, is a clean error', () {
    Map<String, dynamic> file() =>
        jsonDecode(seriesToSubplanJson(series())) as Map<String, dynamic>;

    final empty = file();
    (empty['series'] as Map)['dives'] = <Object>[];
    expect(
      () => seriesFromSubplanJson(jsonEncode(empty)),
      throwsFormatException,
    );

    final broken = file();
    (broken['series'] as Map)['dives'] = 'nonsense';
    expect(
      () => seriesFromSubplanJson(jsonEncode(broken)),
      throwsFormatException,
    );
  });

  test('a file from a newer version is refused', () {
    final file =
        jsonDecode(seriesToSubplanJson(series())) as Map<String, dynamic>;
    file['version'] = subplanVersion + 1;

    expect(
      () => seriesFromSubplanJson(jsonEncode(file)),
      throwsFormatException,
    );
  });
}
