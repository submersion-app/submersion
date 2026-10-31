import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// A CCR ramp crossing the setpoint switch breathes each setpoint for the time
/// it actually spends on that side of the switch, however many waypoints the
/// diver happened to draw it with (#4009).
const _air = GasMix(o2: 21);
const _tx1070 = GasMix(o2: 10, he: 70);
const _setpointLow = 0.7;
const _setpointHigh = 1.3;

const _tanks = [
  DiveTank(
    id: 'dil',
    volume: 3,
    startPressure: 200,
    gasMix: _air,
    role: TankRole.diluent,
  ),
  DiveTank(
    id: 'o2',
    volume: 3,
    startPressure: 200,
    gasMix: GasMix(o2: 100),
    role: TankRole.oxygenSupply,
  ),
  DiveTank(
    id: 'bo',
    volume: 40,
    startPressure: 230,
    gasMix: _tx1070,
    role: TankRole.bailout,
  ),
];

domain.DivePlan _plan(
  List<PlanSegment> segments, {
  double switchDepth = 10,
  domain.PlanMode mode = domain.PlanMode.ccr,
  double setpointLow = _setpointLow,
  double setpointHigh = _setpointHigh,
}) => domain.DivePlan(
  id: 'p',
  name: 'probe',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  mode: mode,
  tanks: _tanks,
  segments: segments,
  problemSolvingMinutes: 0,
  gfLow: 30,
  gfHigh: 70,
  setpointLow: setpointLow,
  setpointHigh: setpointHigh,
  setpointSwitchDepth: switchDepth,
);

PlanSegment _leg(
  String id,
  double depth,
  int seconds,
  int order, {
  domain.PlanMode? mode,
  double? setpoint,
}) => PlanSegment(
  id: id,
  targetDepth: depth,
  durationSeconds: seconds,
  tankId: 'dil',
  gasMix: _air,
  order: order,
  diveModeOverride: mode,
  setpointBar: setpoint,
);

const _engine = PlanEngine(config: PlanEngineConfig(gasModel: GasModel.ideal));

void _expectSameDive(PlanOutcome actual, PlanOutcome expected) {
  expect(actual.cnsEnd, closeTo(expected.cnsEnd, 1e-9));
  expect(actual.otuTotal, closeTo(expected.otuTotal, 1e-9));
  expect(actual.runtimeSeconds, expected.runtimeSeconds);
  expect(actual.totalDecoSeconds, expected.totalDecoSeconds);
  expect(actual.ttsAtBottom, expected.ttsAtBottom);
  expect(actual.ndlAtBottom, expected.ndlAtBottom);
  expect(
    actual.stops.map((s) => (s.depthMeters, s.durationSeconds)),
    expected.stops.map((s) => (s.depthMeters, s.durationSeconds)),
  );
  // The chart's replay walks the same legs, so it must land in the same place.
  final surfaced = actual.surfacedTissue.compartments;
  final reference = expected.surfacedTissue.compartments;
  for (var i = 0; i < surfaced.length; i++) {
    expect(
      surfaced[i].currentPN2,
      closeTo(reference[i].currentPN2, 1e-9),
      reason: 'N2 in compartment $i',
    );
    expect(
      surfaced[i].currentPHe,
      closeTo(reference[i].currentPHe, 1e-9),
      reason: 'He in compartment $i',
    );
  }
}

void main() {
  const calculator = O2ToxicityCalculator();

  double cnsAt(double ppO2, int seconds) =>
      calculator.calculateCnsForSegment(ppO2, seconds);
  double otuAt(double ppO2, int seconds) =>
      calculator.calculateOtuForSegment(ppO2, seconds);

  group('an authored CCR ramp over the setpoint switch', () {
    test('charges each setpoint for its side of the switch', () {
      final outcome = _engine.compute(_plan([_leg('ramp', 20, 1200, 0)]));

      final authored = outcome.segmentOutcomes.single;
      expect(
        authored.cns,
        closeTo(cnsAt(_setpointLow, 600) + cnsAt(_setpointHigh, 600), 1e-9),
      );
      expect(
        authored.otu,
        closeTo(otuAt(_setpointLow, 600) + otuAt(_setpointHigh, 600), 1e-9),
      );
    });

    test('reports the same dive as a waypoint at the switch', () {
      _expectSameDive(
        _engine.compute(_plan([_leg('ramp', 20, 1200, 0)])),
        _engine.compute(
          _plan([_leg('low', 10, 600, 0), _leg('high', 20, 600, 1)]),
        ),
      );
    });

    test('owes the same deco as a waypoint at the switch', () {
      final ramp = _engine.compute(
        _plan([_leg('ramp', 40, 1200, 0)], switchDepth: 20),
      );
      final waypoint = _engine.compute(
        _plan([
          _leg('low', 20, 600, 0),
          _leg('high', 40, 600, 1),
        ], switchDepth: 20),
      );

      _expectSameDive(ramp, waypoint);
      expect(
        ramp.segmentOutcomes.single.ttsAtEnd,
        waypoint.segmentOutcomes.last.ttsAtEnd,
      );
      expect(
        ramp.segmentOutcomes.single.ndlAtEnd,
        waypoint.segmentOutcomes.last.ndlAtEnd,
      );
    });

    test('an authored ascent crosses it going up', () {
      final bottom = _leg('bottom', 30, 1200, 1);
      _expectSameDive(
        _engine.compute(
          _plan([
            _leg('descent', 30, 300, 0),
            bottom,
            _leg('up', 5, 500, 2),
          ], switchDepth: 15),
        ),
        _engine.compute(
          _plan([
            _leg('descent', 30, 300, 0),
            bottom,
            _leg('upHigh', 15, 300, 2),
            _leg('upLow', 5, 200, 3),
          ], switchDepth: 15),
        ),
      );
    });

    test('a ramp stays one authored leg in the outcome and the table', () {
      final outcome = _engine.compute(_plan([_leg('ramp', 20, 1200, 0)]));

      expect(outcome.segmentOutcomes.map((s) => s.segmentId), ['ramp']);
      expect(outcome.segmentOutcomes.single.startRuntime, 0);
      expect(outcome.segmentOutcomes.single.endRuntime, 1200);
      expect(outcome.tissueTimeline, hasLength(1));
    });

    test('an OTU limit is reached where the high setpoint reaches it', () {
      final lowOtu = otuAt(_setpointLow, 600);
      const secondsPastSwitch = 240;
      final limit = lowOtu + otuAt(_setpointHigh, secondsPastSwitch);
      final outcome = PlanEngine(
        config: PlanEngineConfig(gasModel: GasModel.ideal, otuLimit: limit),
      ).compute(_plan([_leg('ramp', 20, 1200, 0)]));

      final issue = outcome.issues.singleWhere(
        (i) => i.type == PlanIssueType.otuHigh,
      );
      expect(issue.atRuntime, closeTo(600 + secondsPastSwitch, 2));
    });

    test('a crossing between two whole seconds lands on the nearest', () {
      final outcome = _engine.compute(_plan([_leg('ramp', 30, 100, 0)]));

      final authored = outcome.segmentOutcomes.single;
      expect(
        authored.cns,
        closeTo(cnsAt(_setpointLow, 33) + cnsAt(_setpointHigh, 67), 1e-9),
      );
    });
  });

  group('a CCR ramp that does not change setpoint', () {
    test('ending at the switch stays on the low setpoint', () {
      final outcome = _engine.compute(_plan([_leg('ramp', 10, 600, 0)]));

      expect(
        outcome.segmentOutcomes.single.cns,
        closeTo(cnsAt(_setpointLow, 600), 1e-9),
      );
    });

    test('leaving the switch stays on the high setpoint', () {
      final outcome = _engine.compute(
        _plan([_leg('down', 10, 60, 0), _leg('ramp', 20, 600, 1)]),
      );

      expect(
        outcome.segmentOutcomes.last.cns - outcome.segmentOutcomes.first.cns,
        closeTo(cnsAt(_setpointHigh, 600), 1e-9),
      );
    });

    test('a fixed per-segment setpoint holds for the whole ramp', () {
      final outcome = _engine.compute(
        _plan([_leg('ramp', 20, 1200, 0, setpoint: 1.0)]),
      );

      expect(
        outcome.segmentOutcomes.single.cns,
        closeTo(cnsAt(1.0, 1200), 1e-9),
      );
    });

    test('an open-circuit leg on a CCR plan is not the loop', () {
      final outcome = _engine.compute(
        _plan([_leg('ramp', 20, 1200, 0, mode: domain.PlanMode.oc)]),
      );

      final ppO2 =
          PlanEngine.environmentFor(_plan(const [])).pressureAtDepth(10) * 0.21;
      expect(
        outcome.segmentOutcomes.single.cns,
        closeTo(cnsAt(ppO2, 1200), 1e-9),
      );
    });
  });

  group('the bailout walk over the same ramp', () {
    test('loads the tissues a waypoint at the switch would', () {
      const solver = BailoutSolver(
        config: PlanEngineConfig(gasModel: GasModel.ideal),
      );
      // 7000 s samples every 175 s, so the sample from 6825 s to the end holds
      // the crossing at 6930 s, 70 s from the end, with its mean short of it.
      final ramp = solver.solve(
        _plan(
          [_leg('ramp', 100, 7000, 0)],
          switchDepth: 99,
          setpointLow: 0.4,
          setpointHigh: 1.6,
        ),
      )!;
      final waypoint = solver.solve(
        _plan(
          [_leg('low', 99, 6930, 0), _leg('high', 100, 70, 1)],
          switchDepth: 99,
          setpointLow: 0.4,
          setpointHigh: 1.6,
        ),
      )!;

      expect(ramp.points.last.runtimeSeconds, 7000);
      expect(ramp.points.last.ttsSeconds, waypoint.points.last.ttsSeconds);
      expect(
        ramp.points.last.litersRequired,
        closeTo(waypoint.points.last.litersRequired, 1e-6),
      );
    });
  });
}
