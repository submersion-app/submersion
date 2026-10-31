import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix();
const _ean50 = GasMix(o2: 50);

void main() {
  const sacDeco = 12.0;

  domain.DivePlan noStopPlan() => domain.DivePlan(
    id: 'gas-use',
    name: 'Gas use',
    mode: domain.PlanMode.oc,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    problemSolvingMinutes: 0,
    sacBottom: 20,
    sacDeco: sacDeco,
    tanks: const [
      DiveTank(id: 'back', volume: 12, startPressure: 200, gasMix: _air),
      DiveTank(
        id: 'deco',
        volume: 7,
        startPressure: 200,
        gasMix: _ean50,
        role: TankRole.deco,
      ),
    ],
    segments: [
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 30,
        tankId: 'back',
        gasMix: _air,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'bottom',
        depth: 30,
        durationMinutes: 10,
        tankId: 'back',
        gasMix: _air,
        order: 1,
      ),
    ],
  );

  test('a no-stop ascent bills each cylinder for its own stretch', () {
    final plan = noStopPlan();
    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    expect(outcome.stops, isEmpty);

    final ascent = outcome.schedule
        .where((row) => row.kind == PlanScheduleRowKind.ascent)
        .toList();
    expect(ascent, hasLength(2), reason: 'splits at the EAN50 switch depth');
    expect(ascent.last.tankId, 'deco');

    final switchDepth = ascent.first.depthMeters;
    final pressure = PlanEngine.environmentFor(
      plan,
    ).pressureAtDepth(switchDepth / 2);
    final deco = outcome.tankUsages.singleWhere((t) => t.tankId == 'deco');

    expect(
      deco.litersUsed,
      closeTo(sacDeco * (ascent.last.durationSeconds / 60) * pressure, 1e-9),
    );
  });

  /// Litres on a deco cylinder that joins at [switchDepth], worked out from
  /// the stops: a leg is breathed on the gas eligible where it starts, so the
  /// diver reaches a switch on the old gas and leaves it on the new one.
  void expectDecoLiters(double switchDepth, {required int crossings}) {
    final plan = domain.DivePlan(
      id: 'gas-use',
      name: 'Gas use',
      mode: domain.PlanMode.oc,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      problemSolvingMinutes: 0,
      sacBottom: 20,
      sacDeco: sacDeco,
      tanks: [
        const DiveTank(
          id: 'back',
          volume: 24,
          startPressure: 200,
          gasMix: _air,
        ),
        DiveTank(
          id: 'deco',
          volume: 11,
          startPressure: 200,
          gasMix: _ean50,
          role: TankRole.deco,
          decoSwitchDepth: switchDepth,
        ),
      ],
      segments: [
        PlanSegment.travel(
          id: 'descent',
          fromDepth: 0,
          targetDepth: 45,
          tankId: 'back',
          gasMix: _air,
          order: 0,
          ratePerMinute: 18,
        ),
        PlanSegment.hold(
          id: 'bottom',
          depth: 45,
          durationMinutes: 25,
          tankId: 'back',
          gasMix: _air,
          order: 1,
        ),
      ],
    );

    const engine = PlanEngine();
    final outcome = engine.compute(plan);
    final environment = PlanEngine.environmentFor(plan);
    double liters(int seconds, double from, double to) =>
        sacDeco * (seconds / 60) * environment.pressureAtDepth((from + to) / 2);

    var expected = 0.0;
    var crossed = 0;
    var depth = 45.0;
    var end = outcome.segmentOutcomes.last.endRuntime;
    for (final stop in outcome.stops) {
      expect(stop.airBreakSeconds, 0);
      final seconds = stop.arrivalRuntimeSeconds - end;
      if (depth <= switchDepth) {
        expected += liters(seconds, depth, stop.depthMeters);
      } else if (stop.depthMeters < switchDepth) {
        crossed++;
        final span = depth - stop.depthMeters;
        final deepSeconds = (seconds * (depth - switchDepth) / span).round();
        expected += liters(
          seconds - deepSeconds,
          switchDepth,
          stop.depthMeters,
        );
      }
      if (stop.depthMeters <= switchDepth) {
        expected += liters(
          stop.durationSeconds,
          stop.depthMeters,
          stop.depthMeters,
        );
      }
      depth = stop.depthMeters;
      end = stop.arrivalRuntimeSeconds + stop.durationSeconds;
    }
    expected += liters(outcome.runtimeSeconds - end, depth, 0);

    expect(outcome.stops.first.depthMeters, greaterThan(switchDepth));
    expect(crossed, crossings);
    expect(
      outcome.tankUsages.singleWhere((t) => t.tankId == 'deco').litersUsed,
      closeTo(expected, 1e-9),
    );
  }

  test('a switch set between two stops divides the leg between them', () {
    expectDecoLiters(10, crossings: 1);
  });

  test('a leg into a switch stop is still on the gas it left', () {
    expectDecoLiters(9, crossings: 0);
  });
}
