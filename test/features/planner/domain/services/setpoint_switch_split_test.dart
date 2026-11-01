import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/setpoint_switch_split.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.ccr,
  double? switchDepth = 10,
}) => domain.DivePlan(
  id: 'p',
  name: 'p',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  mode: mode,
  setpointSwitchDepth: switchDepth,
);

PlanSegment _segment({domain.PlanMode? mode, double? setpoint}) => PlanSegment(
  id: 's',
  targetDepth: 20,
  durationSeconds: 1200,
  tankId: 't',
  gasMix: _air,
  order: 0,
  diveModeOverride: mode,
  setpointBar: setpoint,
);

List<(double, double, int)> _pieces(
  domain.DivePlan plan,
  PlanSegment segment,
  double start,
  double end,
  int seconds,
) => [
  for (final piece in splitAtSetpointSwitch(
    plan,
    segment,
    DecoSegment(startDepth: start, endDepth: end, durationSeconds: seconds),
  ))
    (piece.startDepth, piece.endDepth, piece.durationSeconds),
];

void main() {
  group('splitAtSetpointSwitch', () {
    test('cuts a descent at the time it reaches the switch', () {
      expect(_pieces(_plan(), _segment(), 0, 20, 1200), [
        (0.0, 10.0, 600),
        (10.0, 20.0, 600),
      ]);
    });

    test('cuts an ascent the same way', () {
      expect(_pieces(_plan(), _segment(), 40, 0, 400), [
        (40.0, 10.0, 300),
        (10.0, 0.0, 100),
      ]);
    });

    test('rounds a crossing to the nearest whole second', () {
      expect(_pieces(_plan(), _segment(), 0, 30, 100), [
        (0.0, 10.0, 33),
        (10.0, 30.0, 67),
      ]);
    });

    test('uses the default switch depth when the plan sets none', () {
      expect(_pieces(_plan(switchDepth: null), _segment(), 0, 20, 120), [
        (0.0, 10.0, 60),
        (10.0, 20.0, 60),
      ]);
    });

    test('leaves a ramp that only touches the switch alone', () {
      expect(_pieces(_plan(), _segment(), 0, 10, 600), [(0.0, 10.0, 600)]);
      expect(_pieces(_plan(), _segment(), 10, 20, 600), [(10.0, 20.0, 600)]);
    });

    test('leaves a ramp on one side of the switch alone', () {
      expect(_pieces(_plan(), _segment(), 12, 20, 600), [(12.0, 20.0, 600)]);
      expect(_pieces(_plan(), _segment(), 9, 3, 600), [(9.0, 3.0, 600)]);
    });

    test('leaves a level leg at the switch alone', () {
      expect(_pieces(_plan(), _segment(), 10, 10, 600), [(10.0, 10.0, 600)]);
    });

    test('does not cut when the crossing rounds to either end', () {
      expect(_pieces(_plan(), _segment(), 9.99, 30, 10), [(9.99, 30.0, 10)]);
      expect(_pieces(_plan(), _segment(), 0, 10.01, 10), [(0.0, 10.01, 10)]);
    });

    test('never cuts a leg with no time in it', () {
      expect(_pieces(_plan(), _segment(), 0, 20, 0), [(0.0, 20.0, 0)]);
    });

    test('a fixed per-segment setpoint has nothing to switch', () {
      expect(_pieces(_plan(), _segment(setpoint: 1.0), 0, 20, 1200), [
        (0.0, 20.0, 1200),
      ]);
    });

    test('an off-loop leg on a CCR plan has no setpoint', () {
      expect(
        _pieces(_plan(), _segment(mode: domain.PlanMode.oc), 0, 20, 1200),
        [(0.0, 20.0, 1200)],
      );
    });

    test('a semi-closed plan has no setpoint', () {
      expect(_pieces(_plan(mode: domain.PlanMode.scr), _segment(), 0, 20, 60), [
        (0.0, 20.0, 60),
      ]);
    });

    test('a CCR leg on another plan mode still switches', () {
      expect(
        _pieces(
          _plan(mode: domain.PlanMode.oc),
          _segment(mode: domain.PlanMode.ccr),
          0,
          20,
          120,
        ),
        [(0.0, 10.0, 60), (10.0, 20.0, 60)],
      );
    });
  });
}
