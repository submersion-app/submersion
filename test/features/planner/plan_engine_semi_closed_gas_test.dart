import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _ean32 = GasMix(o2: 32);
const _ean50 = GasMix(o2: 50);

const _supply = DiveTank(
  id: 'supply',
  volume: 12,
  startPressure: 230,
  gasMix: _ean32,
  role: TankRole.diluent,
);

const _bailout = DiveTank(
  id: 'bailout',
  volume: 12,
  startPressure: 230,
  gasMix: _ean50,
);

/// Down to [depth] at 18 m/min, then [minutes] there.
List<PlanSegment> _segments({double depth = 40, int minutes = 35}) => [
  PlanSegment.travel(
    id: 'descent',
    fromDepth: 0,
    targetDepth: depth,
    tankId: 'supply',
    gasMix: _ean32,
    order: 0,
    ratePerMinute: 18,
  ),
  PlanSegment.hold(
    id: 'bottom',
    depth: depth,
    durationMinutes: minutes,
    tankId: 'supply',
    gasMix: _ean32,
    order: 1,
  ),
];

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.scr,
  List<DiveTank> tanks = const [_supply],
  List<PlanSegment>? segments,
  int problemSolvingMinutes = 0,
}) => domain.DivePlan(
  id: 'plan',
  name: 'Supply gas',
  mode: mode,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  problemSolvingMinutes: problemSolvingMinutes,
  tanks: tanks,
  segments: segments ?? _segments(),
);

double _liters(PlanOutcome outcome, String tankId) =>
    outcome.tankUsages.firstWhere((u) => u.tankId == tankId).litersUsed;

/// Open-circuit surface liters for the 40 m profile of [_segments] and
/// [outcome]'s computed ascent, leg by leg, at one [sac].
double _surfaceLiters(
  PlanOutcome outcome,
  DiveEnvironment environment,
  double sac,
) {
  double liters(int seconds, double depth) =>
      sac * (seconds / 60.0) * environment.pressureAtDepth(depth);

  final descent = outcome.segmentOutcomes[0];
  final bottom = outcome.segmentOutcomes[1];
  var total =
      liters(descent.endRuntime, 20) +
      liters(bottom.endRuntime - bottom.startRuntime, 40);
  var depth = 40.0;
  var clock = bottom.endRuntime;
  for (final stop in outcome.stops) {
    total +=
        liters(
          stop.arrivalRuntimeSeconds - clock,
          (depth + stop.depthMeters) / 2,
        ) +
        liters(stop.durationSeconds, stop.depthMeters);
    depth = stop.depthMeters;
    clock = stop.arrivalRuntimeSeconds + stop.durationSeconds;
  }
  return total + liters(outcome.runtimeSeconds - clock, depth / 2);
}

void main() {
  const engine = PlanEngine();

  group('constant-mass-flow supply (#3972)', () {
    test('draws the injection rate for the whole time on the loop', () {
      final outcome = engine.compute(_plan());

      expect(
        _liters(outcome, 'supply'),
        closeTo(12.0 * outcome.runtimeSeconds / 60.0, 1e-6),
      );
    });

    test('follows the injection rate the diver set', () {
      final outcome = const PlanEngine(
        config: PlanEngineConfig(scrInjectionRateLpm: 8),
      ).compute(_plan());

      expect(
        _liters(outcome, 'supply'),
        closeTo(8.0 * outcome.runtimeSeconds / 60.0, 1e-6),
      );
    });

    test('costs the same per minute at any depth', () {
      final shallow = engine.compute(
        _plan(segments: _segments(depth: 12, minutes: 20)),
      );
      final deeper = engine.compute(
        _plan(segments: _segments(depth: 24, minutes: 20)),
      );

      expect(
        _liters(shallow, 'supply') / shallow.runtimeSeconds,
        closeTo(_liters(deeper, 'supply') / deeper.runtimeSeconds, 1e-9),
      );
    });

    test('problem-solving time runs at the injection rate too', () {
      final plain = engine.compute(_plan(problemSolvingMinutes: 0));
      final withTime = engine.compute(_plan(problemSolvingMinutes: 3));

      expect(
        _liters(withTime, 'supply') - _liters(plain, 'supply'),
        closeTo(12.0 * 3, 1e-6),
      );
    });
  });

  group('passive supply (#3972)', () {
    /// A dive short enough to owe no stops either way, so the two plans fly
    /// the same profile.
    List<PlanSegment> noDeco() => _segments(depth: 18, minutes: 20);

    test('draws the pSCR ratio of what open circuit would', () {
      final loop = engine.compute(
        _plan(mode: domain.PlanMode.pscr, segments: noDeco()),
      );
      final openCircuit = engine.compute(
        _plan(mode: domain.PlanMode.oc, segments: noDeco()),
      );

      expect(loop.stops, isEmpty);
      expect(openCircuit.stops, isEmpty);
      expect(
        _liters(loop, 'supply'),
        closeTo(_liters(openCircuit, 'supply') * 100 / 1000, 1e-6),
      );
    });

    test('follows the pSCR ratio the diver set', () {
      final loop = const PlanEngine(
        config: PlanEngineConfig(pscrRatio: 200),
      ).compute(_plan(mode: domain.PlanMode.pscr, segments: noDeco()));
      final openCircuit = engine.compute(
        _plan(mode: domain.PlanMode.oc, segments: noDeco()),
      );

      expect(
        _liters(loop, 'supply'),
        closeTo(_liters(openCircuit, 'supply') * 200 / 1000, 1e-6),
      );
    });

    test('still scales with depth, unlike a fixed flow', () {
      final shallow = engine.compute(
        _plan(
          mode: domain.PlanMode.pscr,
          segments: _segments(depth: 12, minutes: 20),
        ),
      );
      final deeper = engine.compute(
        _plan(
          mode: domain.PlanMode.pscr,
          segments: _segments(depth: 24, minutes: 20),
        ),
      );

      expect(
        _liters(deeper, 'supply') / deeper.runtimeSeconds,
        greaterThan(_liters(shallow, 'supply') / shallow.runtimeSeconds),
      );
    });

    test('charges every leg of a computed ascent at the ratio', () {
      final plan = _plan(mode: domain.PlanMode.pscr);
      final outcome = engine.compute(plan);
      final environment = PlanEngine.environmentFor(plan);
      const sac = 15.0;

      expect(outcome.stops, isNotEmpty);
      expect(
        _liters(outcome, 'supply'),
        closeTo(_surfaceLiters(outcome, environment, sac) * 100 / 1000, 1e-6),
      );
    });

    test('problem-solving time runs at the ratio too', () {
      PlanOutcome outcomeWith(int minutes) => engine.compute(
        _plan(mode: domain.PlanMode.pscr, problemSolvingMinutes: minutes),
      );
      final environment = PlanEngine.environmentFor(_plan());
      const config = PlanEngineConfig();

      expect(
        _liters(outcomeWith(3), 'supply') - _liters(outcomeWith(0), 'supply'),
        closeTo(
          config.sacBottom *
              config.buddyFactor *
              3 *
              environment.pressureAtDepth(40) *
              100 /
              1000,
          1e-6,
        ),
      );
    });
  });

  test('a leg off the loop is still charged at SAC', () {
    final plan = _plan(
      tanks: const [_supply, _bailout],
      segments: [
        ..._segments(depth: 18, minutes: 20),
        PlanSegment.travel(
          id: 'off-loop',
          fromDepth: 18,
          targetDepth: 0,
          tankId: 'bailout',
          gasMix: _ean50,
          diveModeOverride: domain.PlanMode.oc,
          order: 2,
          ratePerMinute: 9,
        ),
      ],
    );
    final outcome = engine.compute(plan);
    final onLoop = outcome.segmentOutcomes[1].endRuntime;
    final offLoop = outcome.segmentOutcomes[2];

    expect(outcome.stops, isEmpty);
    expect(_liters(outcome, 'supply'), closeTo(12.0 * onLoop / 60.0, 1e-6));
    expect(
      _liters(outcome, 'bailout'),
      closeTo(
        15.0 *
            ((offLoop.endRuntime - offLoop.startRuntime) / 60.0) *
            PlanEngine.environmentFor(plan).pressureAtDepth(9),
        1e-6,
      ),
    );
  });

  test('an open-circuit plan is charged exactly as before', () {
    final plan = _plan(mode: domain.PlanMode.oc);
    final outcome = engine.compute(plan);

    expect(outcome.stops, isNotEmpty);
    expect(
      outcome.tankUsages.fold<double>(0, (sum, u) => sum + u.litersUsed),
      closeTo(
        _surfaceLiters(outcome, PlanEngine.environmentFor(plan), 15.0),
        1e-6,
      ),
    );
  });
}
