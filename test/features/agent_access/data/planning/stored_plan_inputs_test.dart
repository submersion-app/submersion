import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/planning/stored_plan_inputs.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_plan_fields.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

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
}
