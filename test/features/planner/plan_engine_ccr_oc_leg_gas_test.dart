import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Gas accounting for a segment a CCR plan breathes off the loop (#3898).
const _air = GasMix(o2: 21);
const _sac = 15.0;
const _o2Rate = 1.0;
const _loopVolume = 6.0;

const _diluentTank = DiveTank(
  id: 'dil',
  volume: 3,
  startPressure: 200,
  gasMix: _air,
  role: TankRole.diluent,
);
const _o2Tank = DiveTank(
  id: 'o2',
  volume: 3,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
);

DiveTank _bailout({double volume = 3, double pressure = 100}) => DiveTank(
  id: 'bo',
  volume: volume,
  startPressure: pressure,
  gasMix: _air,
  role: TankRole.bailout,
);

final _descent = PlanSegment.travel(
  id: 'descent',
  fromDepth: 0,
  targetDepth: 30,
  tankId: 'dil',
  gasMix: _air,
  order: 0,
  ratePerMinute: 18,
);

PlanSegment _hold({
  String tankId = 'bo',
  double depth = 30,
  int minutes = 20,
  domain.PlanMode? mode = domain.PlanMode.oc,
  int order = 1,
}) => PlanSegment.hold(
  id: 'hold-$order',
  depth: depth,
  durationMinutes: minutes,
  tankId: tankId,
  gasMix: _air,
  order: order,
  diveModeOverride: mode,
);

domain.DivePlan _plan({
  List<DiveTank>? tanks,
  List<PlanSegment>? segments,
  int problemSolvingMinutes = 0,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'mixed',
  mode: domain.PlanMode.ccr,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  problemSolvingMinutes: problemSolvingMinutes,
  tanks: tanks ?? [_diluentTank, _o2Tank, _bailout()],
  segments: segments ?? [_descent, _hold()],
);

PlanTankUsage _usage(PlanOutcome outcome, String id) =>
    outcome.tankUsages.firstWhere((u) => u.tankId == id);

double _pressureAt(domain.DivePlan plan, double depth) =>
    PlanEngine.environmentFor(plan).pressureAtDepth(depth);

void main() {
  const engine = PlanEngine();

  group('an authored OC leg in a CCR plan', () {
    test('is charged to its own cylinder at the OC consumption rate', () {
      final plan = _plan();
      final bailout = _usage(engine.compute(plan), 'bo');

      expect(
        bailout.litersUsed,
        closeTo(_sac * 20 * _pressureAt(plan, 30), 1e-6),
      );
    });

    test('reports the shortfall and raises gas out when it exceeds the '
        'cylinder', () {
      final outcome = engine.compute(_plan());
      final bailout = _usage(outcome, 'bo');

      expect(bailout.remainingPressure, lessThan(0));
      expect(
        outcome.issues.where(
          (i) => i.type == PlanIssueType.gasOut && i.segmentId == 'bo',
        ),
        hasLength(1),
      );
    });

    test('raises the reserve issue when the cylinder ends under reserve', () {
      final outcome = engine.compute(
        _plan(
          tanks: [_diluentTank, _o2Tank, _bailout(volume: 11.1, pressure: 207)],
          segments: [_descent, _hold(minutes: 30)],
        ),
      );
      final bailout = _usage(outcome, 'bo');

      expect(bailout.remainingPressure, inExclusiveRange(0, 50));
      expect(bailout.reserveViolation, isTrue);
      expect(
        outcome.issues.where(
          (i) =>
              i.type == PlanIssueType.gasReserveViolation &&
              i.segmentId == 'bo',
        ),
        hasLength(1),
      );
    });

    test('stops charging metabolic oxygen while off the loop', () {
      final outcome = engine.compute(_plan());

      expect(
        _usage(outcome, 'o2').litersUsed,
        closeTo(_o2Rate * (outcome.runtimeSeconds - 20 * 60) / 60.0, 1e-6),
      );
    });

    test('leaves the loop fill of the legs on the loop alone', () {
      final plan = _plan();

      expect(
        _usage(engine.compute(plan), 'dil').litersUsed,
        closeTo(
          _loopVolume * (_pressureAt(plan, 30) - _pressureAt(plan, 0)),
          1e-6,
        ),
      );
    });

    test('charges an ascent leg at the deco SAC, as open circuit does', () {
      final plan = _plan(
        segments: [
          _descent,
          _hold(tankId: 'dil', minutes: 5, mode: null),
          PlanSegment.travel(
            id: 'oc-ascent',
            fromDepth: 30,
            targetDepth: 15,
            tankId: 'bo',
            gasMix: _air,
            order: 2,
            ratePerMinute: 9,
            diveModeOverride: domain.PlanMode.oc,
          ),
        ],
      );
      const deco = PlanEngine(config: PlanEngineConfig(sacDeco: 11));

      expect(
        _usage(deco.compute(plan), 'bo').litersUsed,
        closeTo(11 * (15 / 9) * _pressureAt(plan, 22.5), 1e-6),
      );
    });

    test('charges the diluent cylinder when that is what it breathes', () {
      final plan = _plan(
        tanks: [_diluentTank, _o2Tank, _bailout()],
        segments: [
          _descent,
          _hold(tankId: 'dil'),
        ],
      );
      final loopFill =
          _loopVolume * (_pressureAt(plan, 30) - _pressureAt(plan, 0));

      expect(
        _usage(engine.compute(plan), 'dil').litersUsed,
        closeTo(loopFill + _sac * 20 * _pressureAt(plan, 30), 1e-6),
      );
    });

    test('is not dropped when its cylinder is no longer on the plan', () {
      final plan = _plan(
        segments: [
          _descent,
          _hold(tankId: 'gone'),
        ],
      );

      final outcome = engine.compute(plan);
      final total = outcome.tankUsages.fold<double>(
        0,
        (sum, u) => sum + u.litersUsed,
      );

      expect(total, greaterThan(_sac * 20 * _pressureAt(plan, 30)));
    });

    test('a rate-split leg is charged once, travel and hold apart', () {
      // Travel from 10 m to 30 m at the plan's descent rate, averaging 20 m,
      // then the rest of the segment level at 30 m.
      final plan = _plan(
        segments: [
          PlanSegment.travel(
            id: 'to-10',
            fromDepth: 0,
            targetDepth: 10,
            tankId: 'dil',
            gasMix: _air,
            order: 0,
            ratePerMinute: 18,
          ),
          const PlanSegment(
            id: 'split',
            targetDepth: 30,
            durationSeconds: 600,
            tankId: 'bo',
            gasMix: _air,
            order: 1,
            diveModeOverride: domain.PlanMode.oc,
            splitAtConfiguredRate: true,
          ),
        ],
      );
      final travelSeconds = PlanSegment.travelSeconds(
        metres: 20,
        ratePerMinute: engine.config.resolvedFor(plan).descentRate,
      );

      expect(
        _usage(engine.compute(plan), 'bo').litersUsed,
        closeTo(
          _sac * (travelSeconds / 60) * _pressureAt(plan, 20) +
              _sac * ((600 - travelSeconds) / 60) * _pressureAt(plan, 30),
          1e-6,
        ),
      );
    });

    test('a leg overridden to a semi-closed loop is off the CCR loop too', () {
      final plan = _plan(
        segments: [
          _descent,
          _hold(mode: domain.PlanMode.scr),
        ],
      );
      final outcome = engine.compute(plan);

      // Charged the way an SCR plan charges it: the loop's flow, not SAC.
      expect(
        _usage(outcome, 'bo').litersUsed,
        closeTo(engine.config.scrInjectionRateLpm * 20, 1e-6),
      );
      expect(
        _usage(outcome, 'o2').litersUsed,
        closeTo(_o2Rate * (outcome.runtimeSeconds - 20 * 60) / 60.0, 1e-6),
      );
    });
  });

  group('problem-solving time on a CCR plan', () {
    test('is charged to the OC cylinder when the bottom is off the loop', () {
      final plan = _plan(problemSolvingMinutes: 2);
      final baseline = _usage(engine.compute(_plan()), 'bo').litersUsed;

      expect(
        _usage(engine.compute(plan), 'bo').litersUsed,
        closeTo(
          baseline +
              _sac * engine.config.buddyFactor * 2 * _pressureAt(plan, 30),
          1e-6,
        ),
      );
    });

    test('is charged to the OC cylinder a bailout leaves the bottom on', () {
      List<PlanSegment> segments() => [
        _descent,
        _hold(tankId: 'dil', minutes: 5, mode: null),
        PlanSegment.travel(
          id: 'oc-ascent',
          fromDepth: 30,
          targetDepth: 15,
          tankId: 'bo',
          gasMix: _air,
          order: 2,
          ratePerMinute: 9,
          diveModeOverride: domain.PlanMode.oc,
        ),
      ];
      final plan = _plan(segments: segments(), problemSolvingMinutes: 2);
      final baseline = _usage(
        engine.compute(_plan(segments: segments())),
        'bo',
      ).litersUsed;

      expect(
        _usage(engine.compute(plan), 'bo').litersUsed,
        closeTo(
          baseline +
              _sac * engine.config.buddyFactor * 2 * _pressureAt(plan, 30),
          1e-6,
        ),
      );
    });

    test('charges nothing while the bottom stays on the loop', () {
      // The loop carries the diver up to 15 m before the OC leg starts, so
      // no off-loop leg touches max depth.
      List<PlanSegment> segments() => [
        _descent,
        _hold(tankId: 'dil', mode: null),
        PlanSegment.travel(
          id: 'loop-ascent',
          fromDepth: 30,
          targetDepth: 15,
          tankId: 'dil',
          gasMix: _air,
          order: 2,
          ratePerMinute: 9,
        ),
        _hold(depth: 15, minutes: 5, order: 3),
      ];

      expect(
        _usage(
          engine.compute(_plan(segments: segments(), problemSolvingMinutes: 2)),
          'bo',
        ).litersUsed,
        closeTo(
          _usage(engine.compute(_plan(segments: segments())), 'bo').litersUsed,
          1e-6,
        ),
      );
    });
  });

  group('a CCR plan with no OC leg', () {
    test('holds a carried bailout to nothing, however low its fill', () {
      final outcome = engine.compute(
        _plan(
          tanks: [_diluentTank, _o2Tank, _bailout(pressure: 30)],
          segments: [
            _descent,
            _hold(tankId: 'dil', mode: null),
          ],
        ),
      );
      final bailout = _usage(outcome, 'bo');

      expect(bailout.litersUsed, 0);
      expect(bailout.reserveViolation, isFalse);
      expect(outcome.issues.where((i) => i.segmentId == 'bo'), isEmpty);
    });

    test('still charges oxygen for the whole runtime', () {
      final outcome = engine.compute(
        _plan(
          segments: [
            _descent,
            _hold(tankId: 'dil', mode: null),
          ],
        ),
      );

      expect(
        _usage(outcome, 'o2').litersUsed,
        closeTo(_o2Rate * outcome.runtimeSeconds / 60.0, 1e-6),
      );
    });
  });
}
