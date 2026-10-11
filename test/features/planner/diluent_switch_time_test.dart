import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';

const _dilA = GasMix(o2: 18, he: 45);
const _dilATank = DiveTank(
  id: 'dilA',
  volume: 3.0,
  startPressure: 200,
  gasMix: _dilA,
  role: TankRole.diluent,
);
const _dilB = GasMix(o2: 10, he: 70);
const _dilBTank = DiveTank(
  id: 'dilB',
  volume: 11.1,
  startPressure: 200,
  gasMix: _dilB,
  role: TankRole.diluent,
);
const _bailoutTank = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.bailout,
);

PlanSegment _seg(
  String id,
  String tankId,
  GasMix mix, {
  int order = 0,
  int durationSeconds = 600,
  domain.PlanMode? diveModeOverride,
}) => PlanSegment(
  id: id,
  targetDepth: 40,
  durationSeconds: durationSeconds,
  tankId: tankId,
  gasMix: mix,
  order: order,
  diveModeOverride: diveModeOverride,
);

domain.DivePlan _plan({
  required List<PlanSegment> segments,
  List<DiveTank> tanks = const [_dilATank, _dilBTank, _bailoutTank],
  int gasSwitchStopSeconds = 120,
  domain.PlanMode mode = domain.PlanMode.ccr,
}) => domain.DivePlan(
  id: 'p',
  name: 'switch time',
  mode: mode,
  gfLow: 50,
  gfHigh: 80,
  tanks: tanks,
  segments: segments,
  gasSwitchStopSeconds: gasSwitchStopSeconds,
  createdAt: DateTime(2026, 10, 11),
  updatedAt: DateTime(2026, 10, 11),
);

void main() {
  test('nothing is added before the first segment -- no predecessor to '
      'switch from', () {
    final segments = [_seg('s1', 'dilA', _dilA)];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result[0].durationSeconds, 600);
  });

  test('a real diluent-to-diluent switch gets the configured time added, '
      'landing on the segment it starts', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'dilB', _dilB, order: 1),
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result[0].durationSeconds, 600, reason: 'first segment untouched');
    expect(result[1].durationSeconds, 600 + 120);
    // Nothing else about the segment changes -- same tank, same depth.
    expect(result[1].tankId, 'dilB');
    expect(result[1].targetDepth, segments[1].targetDepth);
  });

  test('staying on the same diluent adds nothing', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'dilA', _dilA, order: 1),
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result[1].durationSeconds, 600);
  });

  test('gasSwitchStopSeconds of 0 is a no-op', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'dilB', _dilB, order: 1),
    ];
    final result = withDiluentSwitchTime(
      segments,
      _plan(segments: segments, gasSwitchStopSeconds: 0),
    );
    expect(result[1].durationSeconds, 600);
  });

  test('a bailout leg in between does not reset which diluent counts as '
      'previous -- the last one actually breathed still does', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'bo', const GasMix(o2: 50), order: 1), // bailout, not dilA/B
      _seg('s3', 'dilB', _dilB, order: 2), // switches away from dilA
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result[1].durationSeconds, 600, reason: 'not a diluent segment');
    expect(
      result[2].durationSeconds,
      600 + 120,
      reason: 'still a switch from dilA, skipping over the bailout leg',
    );
  });

  test('an SCR segment (no CCR diluent slots) never counts as a switch', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'dilB', _dilB, order: 1),
    ];
    final result = withDiluentSwitchTime(
      segments,
      _plan(segments: segments, mode: domain.PlanMode.scr),
    );
    expect(result[1].durationSeconds, 600);
  });

  test('a per-segment CCR override is honoured even on an OC plan', () {
    final segments = [
      _seg(
        's1',
        'dilA',
        _dilA,
        order: 0,
        diveModeOverride: domain.PlanMode.ccr,
      ),
      _seg(
        's2',
        'dilB',
        _dilB,
        order: 1,
        diveModeOverride: domain.PlanMode.ccr,
      ),
    ];
    final result = withDiluentSwitchTime(
      segments,
      _plan(segments: segments, mode: domain.PlanMode.oc),
    );
    expect(result[1].durationSeconds, 600 + 120);
  });
}
