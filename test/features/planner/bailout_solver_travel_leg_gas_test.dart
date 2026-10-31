import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix();
const _ean50 = GasMix(o2: 50);

/// A CCR plan with air and EAN50 bailout cylinders. By default it owes no
/// stops, so its bailout is one leg to the surface that still crosses the
/// switch to the richer gas.
domain.DivePlan _plan({
  double depth = 30,
  int minutes = 3,
  double? richSwitchDepth,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'no-stop bailout',
  mode: domain.PlanMode.ccr,
  gfLow: 50,
  gfHigh: 80,
  problemSolvingMinutes: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  hypercapniaExplicitlyOff: true,
  tanks: [
    const DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    const DiveTank(
      id: 'back',
      volume: 11,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.bailout,
    ),
    DiveTank(
      id: 'rich',
      volume: 7,
      startPressure: 200,
      gasMix: _ean50,
      role: TankRole.bailout,
      decoSwitchDepth: richSwitchDepth,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

void main() {
  const solver = BailoutSolver();

  test('a no-stop bailout splits its surface leg at the gas switch', () {
    final outcome = solver.solve(_plan())!;
    expect(outcome.worstCase.schedule.stops, isEmpty);

    final ascent = outcome.worstCaseRows
        .skip(outcome.ccrRows.length)
        .where((row) => row.kind == PlanScheduleRowKind.ascent)
        .toList();

    expect(ascent.map((row) => row.tankId), ['back', 'rich']);
    expect(ascent.last.depthMeters, 0);
    expect(ascent.last.endMeters, 0, reason: 'floored at the surface');
  });

  test('each bailout cylinder pays for its own stretch of that leg', () {
    final outcome = solver.solve(_plan())!;
    double used(String id) => outcome.bailoutTankUsages
        .singleWhere((usage) => usage.tankId == id)
        .litersUsed;

    expect(used('rich'), greaterThan(0));
    expect(
      used('back') + used('rich'),
      closeTo(outcome.worstCase.litersRequired, 1.0),
    );
  });

  /// Checks the rich cylinder against bar-minutes read off the printed table,
  /// for a rich gas joining at [switchDepth]: a leg is breathed on the gas
  /// eligible where it starts, so the diver reaches a switch on the old gas.
  void expectRichLiters(double switchDepth, {required int crossings}) {
    final plan = _plan(depth: 45, minutes: 25, richSwitchDepth: switchDepth);
    final outcome = solver.solve(plan)!;
    final worst = outcome.worstCase;
    final environment = PlanEngine.environmentFor(plan);

    var back = 0.0;
    var rich = 0.0;
    var crossed = 0;
    void spend(bool onRich, int seconds, double from, double to) {
      final barMinutes =
          (seconds / 60) * environment.pressureAtDepth((from + to) / 2);
      if (onRich) {
        rich += barMinutes;
      } else {
        back += barMinutes;
      }
    }

    var depth = worst.depthMeters;
    var stops = worst.schedule.stops;
    for (final row in outcome.worstCaseRows.skip(outcome.ccrRows.length)) {
      final onRich = row.tankId == 'rich';
      if (row.kind == PlanScheduleRowKind.ascent) {
        spend(onRich, row.durationSeconds, depth, row.depthMeters);
      } else {
        // A stop's row folds in the travel to it.
        final hold = stops.first.durationSeconds;
        stops = stops.sublist(1);
        final travel = row.durationSeconds - hold;
        if (depth > switchDepth && row.depthMeters < switchDepth) {
          crossed++;
          final deepSeconds =
              (travel * (depth - switchDepth) / (depth - row.depthMeters))
                  .round();
          spend(false, deepSeconds, depth, switchDepth);
          spend(true, travel - deepSeconds, switchDepth, row.depthMeters);
        } else {
          spend(depth <= switchDepth, travel, depth, row.depthMeters);
        }
        spend(onRich, hold, row.depthMeters, row.depthMeters);
      }
      depth = row.depthMeters;
    }

    expect(worst.schedule.stops.first.depthMeters, greaterThan(switchDepth));
    expect(crossed, crossings);
    final amv = worst.litersRequired / (back + rich);
    expect(
      outcome.bailoutTankUsages
          .singleWhere((usage) => usage.tankId == 'rich')
          .litersUsed,
      closeTo(amv * rich, 0.5),
    );
  }

  test('a switch set between two stops divides the leg between them', () {
    expectRichLiters(10, crossings: 1);
  });

  test('a leg into a switch stop is still on the gas it left', () {
    expectRichLiters(9, crossings: 0);
  });
}
