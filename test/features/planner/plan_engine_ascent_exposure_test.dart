import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _oxygen = GasMix(o2: 100);
const _ean32 = GasMix(o2: 32);
const _air = GasMix();
const _ean50 = GasMix(o2: 50);
const _diluent = GasMix(o2: 18, he: 45);

DiveTank _tank(String id, GasMix gas, {TankRole role = TankRole.backGas}) =>
    DiveTank(id: id, volume: 12, startPressure: 200, gasMix: gas, role: role);

domain.DivePlan _plan({
  required double depth,
  required int minutes,
  required GasMix gas,
  required List<DiveTank> tanks,
  domain.PlanMode mode = domain.PlanMode.oc,
  double? ascentRate,
  double? setpointSwitchDepth,
  double? altitude,
  WaterType? waterType,
}) => domain.DivePlan(
  id: 'exposure',
  name: 'Exposure',
  mode: mode,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  altitude: altitude,
  waterType: waterType,
  ascentRate: ascentRate,
  problemSolvingMinutes: 0,
  setpointSwitchDepth: setpointSwitchDepth,
  tanks: tanks,
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: tanks.first.id,
      gasMix: gas,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: tanks.first.id,
      gasMix: gas,
      order: 1,
    ),
  ],
);

/// [plan] with [legs] appended, each `(depth, seconds)` a waypoint breathed on
/// the plan's last gas, so the engine has no ascent left to compute.
domain.DivePlan _authored(
  domain.DivePlan plan,
  List<(double, int)> legs, {
  GasMix? gas,
  String? tankId,
}) {
  final last = plan.segments.last;
  return plan.copyWith(
    segments: [
      ...plan.segments,
      for (final (i, (depth, seconds)) in legs.indexed)
        PlanSegment(
          id: 'authored-$i',
          targetDepth: depth,
          durationSeconds: seconds,
          tankId: tankId ?? last.tankId,
          gasMix: gas ?? last.gasMix,
          order: plan.segments.length + i,
        ),
    ],
  );
}

/// Every leg of [outcome]'s computed ascent as `(depth, seconds)` waypoints,
/// timed off the outcome's own stop arrivals and runtime.
List<(double, int)> _computedAscent(PlanOutcome outcome) {
  final legs = <(double, int)>[];
  var end = outcome.segmentOutcomes.last.endRuntime;
  for (final stop in outcome.stops) {
    legs.add((stop.depthMeters, stop.arrivalRuntimeSeconds - end));
    legs.add((stop.depthMeters, stop.durationSeconds));
    end = stop.arrivalRuntimeSeconds + stop.durationSeconds;
  }
  legs.add((0, outcome.runtimeSeconds - end));
  return legs;
}

void main() {
  const engine = PlanEngine();
  const o2Calc = O2ToxicityCalculator();

  group('open-circuit computed ascent exposure', () {
    test('a slow implicit ascent matches the same authored ascent (#3897)', () {
      final plan = _plan(
        depth: 6,
        minutes: 35,
        gas: _oxygen,
        tanks: [_tank('o2', _oxygen)],
        ascentRate: 1,
      );

      final implicit = engine.compute(plan);
      final explicit = engine.compute(_authored(plan, [(0, 360)]));

      expect(implicit.stops, isEmpty);
      expect(implicit.runtimeSeconds, explicit.runtimeSeconds);
      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
      expect(explicit.cnsEnd, closeTo(81.30543579678768, 1e-9));
    });

    test('the missing travel no longer hides the CNS warning (#3897)', () {
      final outcome = engine.compute(
        _plan(
          depth: 6,
          minutes: 35,
          gas: _oxygen,
          tanks: [_tank('o2', _oxygen)],
          ascentRate: 1,
        ),
      );

      expect(
        outcome.issues.map((issue) => issue.type),
        contains(PlanIssueType.cnsWarning),
      );
    });

    test('a no-stop ascent at the default rate is counted', () {
      final plan = _plan(
        depth: 30,
        minutes: 15,
        gas: _ean32,
        tanks: [_tank('back', _ean32)],
      );

      final implicit = engine.compute(plan);
      expect(implicit.stops, isEmpty);
      final explicit = engine.compute(
        _authored(plan, _computedAscent(implicit)),
      );

      expect(implicit.cnsEnd, greaterThan(implicit.segmentOutcomes.last.cns));
      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });

    test('a no-stop ascent charges each gas for its own stretch', () {
      final plan = _plan(
        depth: 30,
        minutes: 10,
        gas: _air,
        tanks: [
          _tank('back', _air),
          _tank('deco', _ean50, role: TankRole.deco),
        ],
      );

      final implicit = engine.compute(plan);
      expect(implicit.stops, isEmpty);
      final ascent = implicit.schedule
          .where((row) => row.kind == PlanScheduleRowKind.ascent)
          .toList();
      expect(ascent, hasLength(2), reason: 'splits at the EAN50 switch depth');

      final explicit = engine.compute(
        _authored(
          _authored(plan, [
            (ascent.first.depthMeters, ascent.first.durationSeconds),
          ]),
          [(0, ascent.last.durationSeconds)],
          gas: _ean50,
          tankId: 'deco',
        ),
      );

      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });

    test('travel to, between and off the stops all count', () {
      final outcome = engine.compute(
        _plan(
          depth: 35,
          minutes: 40,
          gas: _ean32,
          tanks: [_tank('back', _ean32)],
        ),
      );
      expect(outcome.stops.length, greaterThan(1));

      final environment = PlanEngine.environmentFor(
        _plan(
          depth: 35,
          minutes: 40,
          gas: _ean32,
          tanks: [_tank('back', _ean32)],
        ),
      );

      var expectedCns = outcome.segmentOutcomes.last.cns;
      var expectedOtu = outcome.segmentOutcomes.last.otu;
      void travel(double from, double to, int seconds) {
        final ppO2 = environment.pressureAtDepth((from + to) / 2) * 0.32;
        expectedCns += o2Calc.calculateCnsForSegment(ppO2, seconds);
        expectedOtu += o2Calc.calculateOtuForSegment(ppO2, seconds);
      }

      var depth = 35.0;
      var end = outcome.segmentOutcomes.last.endRuntime;
      for (final stop in outcome.stops) {
        travel(depth, stop.depthMeters, stop.arrivalRuntimeSeconds - end);
        final ppO2 = environment.pressureAtDepth(stop.depthMeters) * 0.32;
        expectedCns += o2Calc.calculateCnsForSegment(
          ppO2,
          stop.durationSeconds,
        );
        expectedOtu += o2Calc.calculateOtuForSegment(
          ppO2,
          stop.durationSeconds,
        );
        depth = stop.depthMeters;
        end = stop.arrivalRuntimeSeconds + stop.durationSeconds;
      }
      travel(depth, 0, outcome.runtimeSeconds - end);

      expect(outcome.cnsEnd, closeTo(expectedCns, 1e-9));
      expect(outcome.otuTotal, closeTo(expectedOtu, 1e-9));
    });

    test('a switch set between two stops divides the leg between them', () {
      const switchDepth = 10.0;
      final plan = _plan(
        depth: 45,
        minutes: 25,
        gas: _air,
        tanks: [
          _tank('back', _air),
          const DiveTank(
            id: 'deco',
            volume: 12,
            startPressure: 200,
            gasMix: _ean50,
            role: TankRole.deco,
            decoSwitchDepth: switchDepth,
          ),
        ],
      );
      final outcome = engine.compute(plan);
      expect(outcome.stops.first.depthMeters, greaterThan(switchDepth));

      var expectedCns = outcome.segmentOutcomes.last.cns;
      var expectedOtu = outcome.segmentOutcomes.last.otu;
      void breathe(double ppO2, int seconds) {
        expectedCns += o2Calc.calculateCnsForSegment(ppO2, seconds);
        expectedOtu += o2Calc.calculateOtuForSegment(ppO2, seconds);
      }

      double fO2At(double depth) => depth <= switchDepth ? 0.5 : 0.21;
      final environment = PlanEngine.environmentFor(plan);
      void travel(double from, double to, int seconds) => breathe(
        environment.pressureAtDepth((from + to) / 2) * fO2At(from),
        seconds,
      );

      var crossings = 0;
      var depth = 45.0;
      var end = outcome.segmentOutcomes.last.endRuntime;
      for (final stop in outcome.stops) {
        final to = stop.depthMeters;
        final seconds = stop.arrivalRuntimeSeconds - end;
        if (depth > switchDepth && to < switchDepth) {
          crossings++;
          final deep = (seconds * (depth - switchDepth) / (depth - to)).round();
          travel(depth, switchDepth, deep);
          travel(switchDepth, to, seconds - deep);
        } else {
          travel(depth, to, seconds);
        }
        breathe(
          environment.pressureAtDepth(to) * fO2At(to),
          stop.durationSeconds,
        );
        depth = to;
        end = stop.arrivalRuntimeSeconds + stop.durationSeconds;
      }
      travel(depth, 0, outcome.runtimeSeconds - end);

      expect(crossings, 1);
      expect(outcome.cnsEnd, closeTo(expectedCns, 1e-9));
      expect(outcome.otuTotal, closeTo(expectedOtu, 1e-9));
    });
  });

  // Every plan above is in the default water, which a hardcoded environment
  // would satisfy just as well. These pick one that differs from it.
  group('open-circuit computed ascent in the plan water (#4010)', () {
    const idealEngine = PlanEngine(
      config: PlanEngineConfig(gasModel: GasModel.ideal),
    );

    for (final (ascentRate, travelSeconds, ascentCns, ascentOtu) in [
      (9.0, 133, 0.5364472660949917, 1.6108488366438571),
      (1.0, 1200, 4.840125709127745, 14.533974465959611),
    ]) {
      test(
        'a no-stop ascent at $ascentRate m/min is charged the plan water',
        () {
          final plan = _plan(
            depth: 20,
            minutes: 5,
            gas: _ean50,
            tanks: [_tank('ean50', _ean50)],
            ascentRate: ascentRate,
            altitude: 3000,
            waterType: WaterType.fresh,
          );

          final implicit = idealEngine.compute(plan);
          final authored = implicit.segmentOutcomes.last;
          final explicit = idealEngine.compute(
            _authored(plan, [(0, travelSeconds)]),
          );

          expect(implicit.stops, isEmpty);
          expect(implicit.runtimeSeconds - authored.endRuntime, travelSeconds);
          expect(implicit.cnsEnd - authored.cns, closeTo(ascentCns, 1e-9));
          expect(implicit.otuTotal - authored.otu, closeTo(ascentOtu, 1e-9));
          expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
          expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
        },
      );
    }

    test('stops and travel match the same authored ascent', () {
      final plan = _plan(
        depth: 35,
        minutes: 40,
        gas: _ean32,
        tanks: [_tank('back', _ean32)],
        altitude: 3000,
        waterType: WaterType.fresh,
      );

      final implicit = engine.compute(plan);
      expect(implicit.stops.length, greaterThan(1));
      final explicit = engine.compute(
        _authored(plan, _computedAscent(implicit)),
      );

      expect(implicit.runtimeSeconds, explicit.runtimeSeconds);
      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });

    test('each gas is charged the plan water over its own stretch', () {
      final plan = _plan(
        depth: 30,
        minutes: 10,
        gas: _air,
        tanks: [
          _tank('back', _air),
          _tank('deco', _ean50, role: TankRole.deco),
        ],
        altitude: 3000,
        waterType: WaterType.fresh,
      );

      final implicit = engine.compute(plan);
      expect(implicit.stops, isEmpty);
      final ascent = implicit.schedule
          .where((row) => row.kind == PlanScheduleRowKind.ascent)
          .toList();
      expect(ascent, hasLength(2), reason: 'splits at the EAN50 switch depth');

      final explicit = engine.compute(
        _authored(
          _authored(plan, [
            (ascent.first.depthMeters, ascent.first.durationSeconds),
          ]),
          [(0, ascent.last.durationSeconds)],
          gas: _ean50,
          tankId: 'deco',
        ),
      );

      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });
  });

  group('semi-closed computed ascent exposure', () {
    for (final mode in const [domain.PlanMode.scr, domain.PlanMode.pscr]) {
      domain.DivePlan loopPlan({double depth = 40, int minutes = 30}) => _plan(
        depth: depth,
        minutes: minutes,
        gas: _ean32,
        tanks: [_tank('supply', _ean32, role: TankRole.diluent)],
        mode: mode,
      );

      test('$mode stops and travel match the same authored ascent', () {
        final plan = loopPlan();

        final implicit = engine.compute(plan);
        expect(implicit.stops.length, greaterThan(1));
        final explicit = engine.compute(
          _authored(plan, _computedAscent(implicit)),
        );

        expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
        expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
      });

      test('$mode surfaces on the loop, not on its supply gas', () {
        final plan = loopPlan(depth: 18, minutes: 10);

        final implicit = engine.compute(plan);
        expect(implicit.stops, isEmpty);
        final explicit = engine.compute(
          _authored(plan, _computedAscent(implicit)),
        );

        expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
        expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
      });
    }
  });

  group('closed-circuit computed ascent exposure', () {
    domain.DivePlan loopPlan({
      double depth = 45,
      int minutes = 25,
      double? setpointSwitchDepth,
    }) => _plan(
      depth: depth,
      minutes: minutes,
      gas: _diluent,
      tanks: [
        _tank('dil', _diluent, role: TankRole.diluent),
        _tank('o2', _oxygen, role: TankRole.oxygenSupply),
      ],
      mode: domain.PlanMode.ccr,
      setpointSwitchDepth: setpointSwitchDepth,
    );

    test('stops and travel match the same authored ascent', () {
      // A switch depth on the 3 m stop grid, so no authored leg straddles it.
      final plan = loopPlan(setpointSwitchDepth: 9);

      final implicit = engine.compute(plan);
      expect(implicit.stops.length, greaterThan(1));
      final explicit = engine.compute(
        _authored(plan, _computedAscent(implicit)),
      );

      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });

    test('a leg splits at the setpoint switch inside it', () {
      final plan = loopPlan(depth: 20, minutes: 10, setpointSwitchDepth: 10);

      final implicit = engine.compute(plan);
      expect(implicit.stops, isEmpty);
      final seconds =
          implicit.runtimeSeconds - implicit.segmentOutcomes.last.endRuntime;
      final deepSeconds = (seconds / 2).round();
      final explicit = engine.compute(
        _authored(plan, [(10, deepSeconds), (0, seconds - deepSeconds)]),
      );

      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });

    test('a setpoint the shallows cannot hold follows the clamped loop', () {
      // No low-setpoint switch at all, and at the ascent's mean depth of 2 m
      // the 1.3 bar setpoint is more than the alveolar pressure of 1.14 bar.
      final plan = loopPlan(depth: 4, minutes: 10, setpointSwitchDepth: 0);

      final implicit = engine.compute(plan);
      expect(implicit.stops, isEmpty);
      final explicit = engine.compute(
        _authored(plan, _computedAscent(implicit)),
      );

      expect(implicit.cnsEnd, closeTo(explicit.cnsEnd, 1e-9));
      expect(implicit.otuTotal, closeTo(explicit.otuTotal, 1e-9));
    });
  });
}
