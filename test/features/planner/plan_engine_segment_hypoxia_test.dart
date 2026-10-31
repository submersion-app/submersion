import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _hypoxic = GasMix(o2: 10, he: 70);

domain.DivePlan _ccrPlan(List<PlanSegment> segments) => domain.DivePlan(
  id: 'p',
  name: 'Segment hypoxia',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  mode: domain.PlanMode.ccr,
  tanks: const [
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
      gasMix: _hypoxic,
      role: TankRole.bailout,
    ),
  ],
  segments: segments,
  problemSolvingMinutes: 0,
  gfLow: 30,
  gfHigh: 70,
  setpointLow: 0.7,
  setpointHigh: 1.3,
  setpointSwitchDepth: 10,
);

PlanSegment _leg(
  String id,
  double depth,
  int seconds,
  int order, {
  GasMix gas = _air,
  String tank = 'dil',
  domain.PlanMode? mode,
  double? setpoint,
}) => PlanSegment(
  id: id,
  targetDepth: depth,
  durationSeconds: seconds,
  tankId: tank,
  gasMix: gas,
  order: order,
  diveModeOverride: mode,
  setpointBar: setpoint,
);

/// The two legs every variant shares: down on the diluent, then on the loop.
List<PlanSegment> _toTheBottom() => [
  _leg('desc', 20, 67, 0),
  _leg('bottom', 20, 300, 1),
];

/// [plan] as Saved plans > Import reads it: the overrides a segment carries
/// only reach the engine through the .subplan codec.
domain.DivePlan _imported(domain.DivePlan plan) =>
    subplanFromJson(planToSubplanJson(plan));

Iterable<PlanIssue> _hypoxia(PlanOutcome outcome) =>
    outcome.issues.where((i) => i.type == PlanIssueType.hypoxicGas);

void main() {
  const engine = PlanEngine(config: PlanEngineConfig(gasModel: GasModel.ideal));

  group('hypoxia is judged on what each segment breathes (#4008)', () {
    test('an imported OC ascent on hypoxic trimix blocks the plan', () {
      final plan = _imported(
        _ccrPlan([
          ..._toTheBottom(),
          _leg(
            'surface',
            0,
            400,
            2,
            gas: _hypoxic,
            tank: 'bo',
            mode: domain.PlanMode.oc,
          ),
        ]),
      );
      expect(plan.segments.last.diveModeOverride, domain.PlanMode.oc);

      final outcome = engine.compute(plan);

      final issue = _hypoxia(outcome).single;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.segmentId, plan.segments.last.id);
      expect(issue.atDepth, 0);
      // Tx10/70 at the surface, less alveolar water vapour.
      expect(issue.value, closeTo(0.09373, 0.0001));
      expect(issue.threshold, 0.16);
      expect(outcome.isDiveable, isFalse);
    });

    test('an imported 0.1 bar setpoint override blocks the plan', () {
      final plan = _imported(
        _ccrPlan([..._toTheBottom(), _leg('hold', 20, 300, 2, setpoint: 0.1)]),
      );
      expect(plan.segments.last.setpointBar, 0.1);

      final outcome = engine.compute(plan);

      final issue = _hypoxia(outcome).single;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.segmentId, plan.segments.last.id);
      expect(issue.atDepth, 20);
      expect(issue.value, closeTo(0.1, 1e-9));
      expect(outcome.isDiveable, isFalse);
    });

    test('an ordinary hold on the loop stays clean', () {
      final outcome = engine.compute(
        _imported(_ccrPlan([..._toTheBottom(), _leg('hold', 20, 300, 2)])),
      );

      expect(_hypoxia(outcome), isEmpty);
      expect(outcome.isDiveable, isTrue);
    });

    test('a hypoxic bailout gas at depth is breathable off the loop', () {
      final outcome = engine.compute(
        _imported(
          _ccrPlan([
            ..._toTheBottom(),
            _leg(
              'bail',
              20,
              60,
              2,
              gas: _hypoxic,
              tank: 'bo',
              mode: domain.PlanMode.oc,
            ),
          ]),
        ),
      );

      expect(_hypoxia(outcome), isEmpty);
    });

    test('a setpoint override at the limit is not hypoxic', () {
      final outcome = engine.compute(
        _imported(
          _ccrPlan([
            ..._toTheBottom(),
            _leg('hold', 20, 300, 2, setpoint: 0.16),
          ]),
        ),
      );

      expect(_hypoxia(outcome), isEmpty);
    });
  });

  group('hypoxia on a computed open-circuit ascent (#4008)', () {
    domain.DivePlan ocPlan({
      required List<DiveTank> tanks,
      required List<PlanSegment> segments,
    }) => domain.DivePlan(
      id: 'p',
      name: 'Computed ascent hypoxia',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tanks: tanks,
      segments: segments,
      gfLow: 30,
      gfHigh: 70,
    );

    test('a plan ending off the loop on hypoxic trimix is blocked', () {
      // Nothing authored breathes the bailout gas shallow: the descent is on
      // the loop, so only the computed ascent carries it to the surface.
      final plan = _imported(
        ocPlan(
          tanks: const [
            DiveTank(
              id: 'bo',
              volume: 24,
              startPressure: 230,
              gasMix: _hypoxic,
            ),
          ],
          segments: [
            _leg(
              'desc',
              30,
              100,
              0,
              gas: _hypoxic,
              tank: 'bo',
              mode: domain.PlanMode.ccr,
            ),
            _leg(
              'bail',
              30,
              120,
              1,
              gas: _hypoxic,
              tank: 'bo',
              mode: domain.PlanMode.oc,
            ),
          ],
        ),
      );

      final outcome = engine.compute(plan);

      final issue = _hypoxia(outcome).first;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(outcome.isDiveable, isFalse);
    });

    test('a stop on hypoxic trimix short of a hand-set MOD is blocked', () {
      // Air joins at 3 m only because the diver said so; the 6 m stop before
      // it is still on Tx10/70, whose inspired ppO2 there is under 0.16 bar.
      final outcome = engine.compute(
        ocPlan(
          tanks: const [
            DiveTank(
              id: 'air',
              volume: 12,
              startPressure: 200,
              gasMix: _air,
              decoSwitchDepth: 3,
            ),
            DiveTank(
              id: 'tx',
              volume: 24,
              startPressure: 230,
              gasMix: _hypoxic,
            ),
          ],
          segments: [
            _leg('desc', 45, 200, 0, tank: 'air'),
            _leg('bottom', 45, 1200, 1, gas: _hypoxic, tank: 'tx'),
          ],
        ),
      );

      final issue = _hypoxia(outcome).first;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.atDepth, greaterThanOrEqualTo(3));
      expect(outcome.isDiveable, isFalse);
    });

    test('a no-stop ascent that switches too shallow is blocked', () {
      // No stop falls on the hypoxic stretch and the surface is on air, so
      // only the arrival at the 3 m switch can see it.
      final outcome = engine.compute(
        ocPlan(
          tanks: const [
            DiveTank(
              id: 'air',
              volume: 12,
              startPressure: 200,
              gasMix: _air,
              decoSwitchDepth: 3,
            ),
            DiveTank(
              id: 'tx',
              volume: 24,
              startPressure: 230,
              gasMix: _hypoxic,
            ),
          ],
          segments: [
            _leg('desc', 12, 60, 0, tank: 'air'),
            _leg('bottom', 12, 60, 1, gas: _hypoxic, tank: 'tx'),
          ],
        ),
      );

      expect(outcome.stops, isEmpty);
      final issue = _hypoxia(outcome).single;
      expect(issue.atDepth, 3);
      expect(issue.atRuntime, isNull);
      expect(issue.value, lessThan(0.16));
      expect(outcome.isDiveable, isFalse);
    });

    test('a switch at a stop keeps the stop\'s runtime', () {
      final outcome = engine.compute(
        ocPlan(
          tanks: const [
            DiveTank(
              id: 'air',
              volume: 12,
              startPressure: 200,
              gasMix: _air,
              decoSwitchDepth: 6,
            ),
            DiveTank(
              id: 'tx',
              volume: 24,
              startPressure: 230,
              gasMix: _hypoxic,
            ),
          ],
          segments: [
            _leg('desc', 30, 120, 0, tank: 'air'),
            _leg('bottom', 30, 30 * 60, 1, gas: _hypoxic, tank: 'tx'),
          ],
        ),
      );

      expect(outcome.stops.map((s) => s.depthMeters), contains(6));
      final issue = _hypoxia(outcome).single;
      expect(issue.atDepth, 6);
      expect(issue.atRuntime, isNotNull);
    });

    test('an open-circuit ascent that switches in time stays clean', () {
      final outcome = engine.compute(
        ocPlan(
          tanks: const [
            DiveTank(id: 'air', volume: 12, startPressure: 200, gasMix: _air),
            DiveTank(
              id: 'tx',
              volume: 24,
              startPressure: 230,
              gasMix: _hypoxic,
            ),
          ],
          segments: [
            _leg('desc', 45, 200, 0, tank: 'air'),
            _leg('bottom', 45, 600, 1, gas: _hypoxic, tank: 'tx'),
          ],
        ),
      );

      expect(_hypoxia(outcome), isEmpty);
    });
  });
}
