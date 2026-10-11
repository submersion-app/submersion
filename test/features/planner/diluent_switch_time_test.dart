import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';

// dilA carries less total inert gas (37% He+N2... wait, O2 18 => 82% inert)
// than dilB (O2 10 => 90% inert), so dilB is always the conservative choice
// between the two in these fixtures.
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
  double targetDepth = 40,
  int order = 0,
  int durationSeconds = 600,
  domain.PlanMode? diveModeOverride,
}) => PlanSegment(
  id: id,
  targetDepth: targetDepth,
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
    expect(result, segments);
  });

  test('a real diluent-to-diluent switch inserts a flat stop leg of its own, '
      'at the depth the switching segment starts from, costed on whichever '
      'diluent carries more total inert gas', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0, targetDepth: 60),
      _seg('s2', 'dilB', _dilB, order: 1, targetDepth: 100),
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result, hasLength(3));
    expect(result[0], segments[0], reason: 'first segment untouched');

    final stop = result[1];
    expect(stop.id, isNot(segments[0].id));
    expect(stop.id, isNot(segments[1].id));
    expect(stop.targetDepth, 60, reason: 'the depth s1 ends at');
    expect(stop.durationSeconds, 120);
    // dilB (O2 10%) carries more total inert gas than dilA (O2 18%).
    expect(stop.tankId, 'dilB');
    expect(stop.gasMix, _dilB);

    expect(
      result[2],
      segments[1],
      reason:
          'the switching segment itself '
          'keeps its own authored duration, not stretched',
    );
  });

  test('the stop is costed on the OLD diluent when it carries more inert gas '
      'than the new one', () {
    final segments = [
      _seg('s1', 'dilB', _dilB, order: 0), // more inert gas (O2 10%)
      _seg('s2', 'dilA', _dilA, order: 1), // less inert gas (O2 18%)
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result[1].tankId, 'dilB');
    expect(result[1].gasMix, _dilB);
  });

  test('staying on the same diluent adds nothing', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'dilA', _dilA, order: 1),
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result, segments);
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
    expect(result, segments);
  });

  test('a bailout leg in between does not reset which diluent counts as '
      'previous -- the last one actually breathed still does', () {
    final segments = [
      _seg('s1', 'dilA', _dilA, order: 0),
      _seg('s2', 'bo', const GasMix(o2: 50), order: 1), // bailout, not dilA/B
      _seg('s3', 'dilB', _dilB, order: 2), // switches away from dilA
    ];
    final result = withDiluentSwitchTime(segments, _plan(segments: segments));
    expect(result, hasLength(4));
    expect(result[1], segments[1], reason: 'not a diluent segment');
    expect(
      result[2].durationSeconds,
      120,
      reason: 'still a switch from dilA, skipping over the bailout leg',
    );
    expect(result[3], segments[2]);
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
    expect(result, segments);
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
    expect(result, hasLength(3));
    expect(result[1].durationSeconds, 120);
  });
}
