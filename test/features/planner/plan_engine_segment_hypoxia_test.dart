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

domain.DivePlan _ccrPlan(
  List<PlanSegment> segments, {
  double setpointLow = 0.7,
}) => domain.DivePlan(
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
  setpointLow: setpointLow,
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

  group('hypoxia on a computed ascent (#4008)', () {
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

      final issue = _hypoxia(outcome).single;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.segmentId, isNull);
      expect(issue.atDepth, 0);
      expect(issue.value, closeTo(0.09373, 0.0001));
      expect(issue.atRuntime, greaterThan(220));
      expect(outcome.isDiveable, isFalse);
    });

    test('a loop ascent onto a hypoxic low setpoint is blocked', () {
      // The authored legs hold their own setpoint, so only the computed
      // ascent runs the plan's low one, from the 10 m switch up.
      final outcome = engine.compute(
        _ccrPlan([
          _leg('desc', 20, 67, 0, setpoint: 1.3),
          _leg('bottom', 20, 300, 1, setpoint: 1.3),
        ], setpointLow: 0.1),
      );

      final issue = _hypoxia(outcome).single;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.atDepth, 10);
      expect(issue.value, closeTo(0.1, 1e-9));
      expect(issue.atRuntime, greaterThan(367));
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

      final issue = _hypoxia(outcome).single;
      expect(issue.severity, PlanIssueSeverity.critical);
      expect(issue.atDepth, 6);
      expect(issue.value, lessThan(0.16));
      expect(issue.atRuntime, isNotNull);
      expect(outcome.isDiveable, isFalse);
    });

    test('a stop where the ascent begins is reported there', () {
      // The leg into it is on air, but air only joins at 3 m, so the computed
      // 6 m stop runs on Tx10/70. No span ends at a depth the ascent starts
      // from, so the arrival has to be read at the start of the first span.
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
            _leg('desc', 30, 120, 0, tank: 'air'),
            _leg('bottom', 30, 600, 1, gas: _hypoxic, tank: 'tx'),
            _leg('up', 6, 180, 2, tank: 'air'),
          ],
        ),
      );

      expect(outcome.stops.first.depthMeters, 6);
      final issue = _hypoxia(outcome).single;
      expect(issue.segmentId, isNull);
      expect(issue.atDepth, 6);
      expect(issue.value, lessThan(0.16));
      expect(issue.atRuntime, 120 + 600 + 180);
    });

    test('an ascent leaving hypoxic with no stop is timed from leaving', () {
      // Air only joins at 3 m, so the ascent leaves 5 m on Tx10/70, already
      // under the limit there, with nothing to hold.
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
            _leg('desc', 5, 60, 0, tank: 'air'),
            _leg('hold', 5, 60, 1, tank: 'air'),
          ],
        ),
      );

      expect(outcome.stops, isEmpty);
      final issue = _hypoxia(outcome).single;
      expect(issue.atDepth, 5);
      expect(issue.atRuntime, 120);
    });

    test('a no-stop ascent that switches too shallow is blocked', () {
      // No stop falls on the hypoxic stretch and the surface is on air, so
      // only the span ending at the 3 m switch can see it.
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
      // Timed where Tx10/70 crosses the limit, well short of the 3 m switch.
      expect(issue.atRuntime, inExclusiveRange(120, 170));
      expect(issue.value, lessThan(0.16));
      expect(outcome.isDiveable, isFalse);
    });

    test('a switch on a stop is judged on arrival there', () {
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

    test('authored and computed legs agree on a marginal gas', () {
      // 16% O2 reads 0.16 bar at a 1 bar surface before water vapour and just
      // under it after, so a path skipping the vapour would disagree here.
      const marginal = GasMix(o2: 16);
      const tanks = [
        DiveTank(id: 'tx', volume: 24, startPressure: 230, gasMix: marginal),
      ];
      final descent = _leg(
        'desc',
        20,
        67,
        0,
        gas: marginal,
        tank: 'tx',
        mode: domain.PlanMode.ccr,
      );
      PlanIssue reported(PlanSegment last) => _hypoxia(
        engine.compute(ocPlan(tanks: tanks, segments: [descent, last])),
      ).single;

      final authored = reported(
        _leg('up', 0, 133, 1, gas: marginal, tank: 'tx'),
      );
      final computed = reported(
        _leg('hold', 20, 60, 1, gas: marginal, tank: 'tx'),
      );

      expect(authored.segmentId, 'up');
      expect(computed.segmentId, isNull);
      expect(authored.atDepth, 0);
      expect(computed.atDepth, 0);
      expect(authored.value, closeTo(0.14997, 0.0001));
      expect(computed.value, closeTo(authored.value!, 1e-9));
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
