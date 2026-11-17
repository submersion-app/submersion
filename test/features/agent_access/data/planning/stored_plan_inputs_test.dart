import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/planning/stored_plan_inputs.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/plan_series.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

void main() {
  final at = DateTime.utc(2026, 11, 14, 9);
  DivePlan plan({int? gfLow, DateTime? start}) => DivePlan(
    id: 'p',
    name: 'Deep',
    createdAt: at,
    updatedAt: at,
    gfLow: gfLow,
    startDateTime: start,
    tanks: const [
      DiveTank(id: 't1', gasMix: GasMix(o2: 21), role: TankRole.backGas),
      DiveTank(id: 't2', gasMix: GasMix(o2: 50), role: TankRole.deco),
    ],
    segments: const [
      PlanSegment(
        id: 's',
        targetDepth: 30,
        durationSeconds: 1200,
        tankId: 't2',
        gasMix: GasMix(o2: 50),
      ),
    ],
  );

  test('every setting compute_plan takes is read from a saved plan', () {
    expect(
      planSettingValues(plan()).keys.toSet(),
      planSettingFields.keys.toSet(),
    );
  });

  test('a saved plan reads back as compute_plan inputs', () {
    final inputs = planInputsOf(
      plan(gfLow: 40, start: DateTime(2026, 11, 14, 9)),
      withStart: true,
    );
    expect(inputs['mode'], 'oc');
    expect(inputs['gf_low'], 40);
    // A setting the plan leaves to Settings is left out.
    expect(inputs.containsKey('gf_high'), isFalse);
    expect(inputs['start_date_time'], '2026-11-14T09:00:00.000Z');
    final tanks = (inputs['tanks']! as List).cast<Map>();
    expect(tanks.map((t) => t['o2_fraction']), [0.21, 0.5]);
    expect(tanks.last['role'], 'deco');
    final segment = (inputs['segments']! as List).cast<Map>().single;
    expect(segment['tank'], 1);
    expect(segment['target_depth_m'], 30.0);
  });

  test('a start is left out when the dive is timed by its interval', () {
    final inputs = planInputsOf(plan(start: at), withStart: false);
    expect(inputs.containsKey('start_date_time'), isFalse);
  });

  test('a setting value is read as the plan document holds it', () {
    expect(planSettingValues(plan(gfLow: 40))['gf_low'], 40);
    expect(planSettingValues(plan())['gf_low'], isNull);
  });

  group('a saved series as compute_plan inputs', () {
    // A dive on one tank of its own, `<id>-t`, as the planner saves them.
    DivePlan dive(String id, {DateTime? start, Duration? interval}) => DivePlan(
      id: id,
      name: id,
      createdAt: at,
      updatedAt: at,
      startDateTime: start,
      surfaceInterval: interval,
      tanks: [DiveTank(id: '$id-t', gasMix: const GasMix(o2: 32), volume: 12)],
      segments: [
        PlanSegment(
          id: '$id-s',
          targetDepth: 18,
          durationSeconds: 1800,
          tankId: '$id-t',
          gasMix: const GasMix(o2: 32),
        ),
      ],
    );
    StoredSeries series(StoredSeriesDive second, {DateTime? firstStart}) =>
        StoredSeries(
          id: 's',
          name: 's',
          dives: [
            StoredSeriesDive(plan: dive('a', start: firstStart)),
            second,
          ],
        );

    test('a later dive storing no interval takes the planner default', () {
      final inputs = seriesInputsOf(
        series(StoredSeriesDive(plan: dive('b')), firstStart: at),
        follow: null,
      );
      expect(
        inputs.last['surface_interval_s'],
        defaultSeriesSurfaceInterval.inSeconds,
      );
      expect(inputs.last.containsKey('start_date_time'), isFalse);
    });

    test('a pinned tank carries from none, keeping its own pressure', () {
      StoredSeriesDive linked({required bool pinned}) => StoredSeriesDive(
        plan: dive('b', interval: const Duration(hours: 2)),
        sourceTankIds: const {'b-t': 'a-t'},
        pinnedTankIds: pinned ? const {'b-t'} : const {},
      );
      expect(
        seriesInputsOf(
          series(linked(pinned: false)),
          follow: null,
        ).last['carries_from_tank'],
        [0],
      );
      expect(
        seriesInputsOf(
          series(linked(pinned: true)),
          follow: null,
        ).last['carries_from_tank'],
        [null],
      );
    });

    test('a later fixed start counts only on a series with a clock', () {
      final fixed = StoredSeriesDive(
        plan: dive(
          'b',
          start: at.add(const Duration(hours: 4)),
          interval: const Duration(hours: 2),
        ),
        fixedStart: true,
      );
      final untimed = seriesInputsOf(series(fixed), follow: null).last;
      expect(untimed.containsKey('start_date_time'), isFalse);
      expect(untimed['surface_interval_s'], 7200);

      final timed = seriesInputsOf(
        series(fixed, firstStart: at),
        follow: null,
      ).last;
      expect(timed['start_date_time'], isNotNull);
      expect(timed.containsKey('surface_interval_s'), isFalse);
    });

    test('a fixed start holding no start is timed by its interval', () {
      final inputs = seriesInputsOf(
        series(
          StoredSeriesDive(
            plan: dive('b', interval: const Duration(hours: 2)),
            fixedStart: true,
          ),
          firstStart: at,
        ),
        follow: null,
      );
      expect(inputs.last['surface_interval_s'], 7200);
      expect(inputs.last.containsKey('start_date_time'), isFalse);
    });
  });
}
