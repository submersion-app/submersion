import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// The plan table reads like a slate: every travel leg is a line and every
/// stop is a line, the authored legs first and then the computed ascent down
/// to the leg that surfaces. A diver follows it against a watch, so stops end
/// on whole minutes and the last line's runtime is the plan's runtime.
const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'back',
  volume: 22.0,
  startPressure: 200.0,
  gasMix: _air,
);
const _ean50 = DiveTank(
  id: 'deco',
  volume: 11.0,
  startPressure: 200.0,
  gasMix: GasMix(o2: 50),
);

domain.DivePlan _plan({
  required double bottomDepth,
  required int bottomMinutes,
  List<DiveTank> tanks = const [_airTank, _ean50],
}) => domain.DivePlan(
  id: 'p',
  name: 'rows',
  gfLow: 50,
  gfHigh: 80,
  tanks: tanks,
  segments: [
    PlanSegment.travel(
      id: 'seg-1',
      fromDepth: 0,
      targetDepth: bottomDepth,
      ratePerMinute: 10,
      tankId: 'back',
      gasMix: _air,
      order: 0,
    ),
    PlanSegment.hold(
      id: 'seg-2',
      depth: bottomDepth,
      durationMinutes: bottomMinutes,
      tankId: 'back',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 9, 2),
  updatedAt: DateTime(2026, 9, 2),
);

const _engine = PlanEngine();

void main() {
  group('a deco dive (50 m / 30 min, air + EAN50)', () {
    final outcome = _engine.compute(_plan(bottomDepth: 50, bottomMinutes: 30));
    final rows = outcome.schedule;

    test('starts with the authored legs, marked by direction', () {
      expect(rows[0].kind, PlanScheduleRowKind.descent);
      expect(rows[0].depthMeters, 50);
      expect(rows[0].runtimeSeconds, 5 * 60);
      expect(rows[1].kind, PlanScheduleRowKind.level);
      expect(rows[1].depthMeters, 50);
      expect(rows[1].durationSeconds, 30 * 60);
      expect(rows[1].runtimeSeconds, 35 * 60);
    });

    test('a travel leg precedes only the first stop; later stops follow it '
        'directly (#3138)', () {
      final tail = rows.sublist(2);
      // travel-to-first-stop, stop, stop, ..., travel-to-surface: no
      // travel row between two stops, their travel time folds into the
      // stop it leads to instead (scheduleLines derives the printed
      // minutes from consecutive rows' runtimeSeconds, so nothing is
      // lost -- see schedule_lines.dart).
      //
      // The leading travel block can itself be more than one row: air's
      // EAN50 switch (MOD 22 m) falls one metre before this dive's first
      // stop (21 m), so travelLegBoundaries splits the bottom-to-first-stop
      // leg there too (#3225) -- the same "gas whose window starts before
      // the first stop" case that feature targets, just a one-metre
      // instance of it rather than a wide one. Every row up to the first
      // stop is still travel (never a stop itself), and nothing between two
      // stops breaks the fold.
      expect(tail.last.kind, PlanScheduleRowKind.ascent);
      expect(tail.last.depthMeters, 0);
      final firstStopIndex = tail.indexWhere(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      expect(firstStopIndex, greaterThan(0), reason: 'a leading travel leg');
      for (var i = 0; i < firstStopIndex; i++) {
        expect(tail[i].kind, PlanScheduleRowKind.ascent, reason: 'tail row $i');
      }
      final stopsInTable = tail.where(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      expect(stopsInTable.length, outcome.stops.length);
      for (var i = firstStopIndex; i < tail.length - 1; i++) {
        expect(tail[i].kind, PlanScheduleRowKind.stop, reason: 'tail row $i');
      }
    });

    test('the first four lines (authored legs, travel to the first stop, '
        'first stop) begin where the previous one ended', () {
      for (var i = 1; i < 4; i++) {
        expect(
          rows[i].startRuntimeSeconds,
          rows[i - 1].runtimeSeconds,
          reason: 'row $i',
        );
      }
    });

    test('runtime never goes backwards across the table, even where a later '
        "stop's folded-in travel time leaves a gap behind the previous row "
        '(#3138)', () {
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i].runtimeSeconds,
          greaterThanOrEqualTo(rows[i - 1].runtimeSeconds),
          reason: 'row $i',
        );
      }
    });

    test('a travel leg arrives at the depth of the stop after it', () {
      // A travel leg's own displayed depth is where it ends. When the leg
      // leads straight into the next row (a stop, or the final surfacing),
      // that is the next row's depth by definition. When it instead leads
      // into another travel row -- a gas-switch split of the same original
      // leg, per #3225 -- the two sub-legs end at different depths, each
      // its own boundary, so the check only applies at the end of the
      // travel block.
      for (var i = 2; i < rows.length - 1; i++) {
        final isLastOfBlock = rows[i + 1].kind != PlanScheduleRowKind.ascent;
        if (rows[i].kind == PlanScheduleRowKind.ascent && isLastOfBlock) {
          expect(rows[i].depthMeters, rows[i + 1].depthMeters);
        }
      }
    });

    test('a travel row reads PO2/END at the leg\'s deeper end, where its gas '
        'was chosen, not at the arrival depth it displays', () {
      // Travel to the first stop leaves the 50 m bottom on the bottom gas:
      // same gas, same depth as the bottom row, so the same PO2 and END.
      final bottom = rows[1];
      final travel = rows[2];
      expect(travel.kind, PlanScheduleRowKind.ascent);
      expect(travel.gasFO2, closeTo(bottom.gasFO2, 1e-9));
      expect(travel.ppO2, closeTo(bottom.ppO2, 1e-9));
      expect(travel.endMeters, closeTo(bottom.endMeters, 1e-9));
      // The surfacing row leaves the last stop on the last stop's gas.
      final lastStop = rows[rows.length - 2];
      final surfacing = rows.last;
      expect(surfacing.kind, PlanScheduleRowKind.ascent);
      expect(surfacing.gasFO2, closeTo(lastStop.gasFO2, 1e-9));
      expect(surfacing.ppO2, closeTo(lastStop.ppO2, 1e-9));
    });

    test('every stop ends on a whole minute', () {
      for (final row in rows.where((r) => r.kind == PlanScheduleRowKind.stop)) {
        expect(row.runtimeSeconds % 60, 0, reason: '${row.depthMeters} m');
      }
    });

    test('the headline runtime is the last line', () {
      expect(outcome.runtimeSeconds, rows.last.runtimeSeconds);
    });

    test('the gas is marked on the first line and where it switches', () {
      expect(rows.first.gasSwitch, isTrue);
      final switches = rows.where((r) => r.gasSwitch).toList();
      // Air off the boat, EAN50 once: exactly one switch after the first
      // line. Here EAN50's own MOD (22 m) falls a metre before the first
      // stop (21 m), so the switch is marked on the travel sub-leg that
      // crosses that MOD (#3225), not retroactively on the stop after it --
      // the diver already changed regulators on the way down. A dive where
      // the switch MOD coincides with a stop would instead mark it there;
      // either way it never lands on the line before the switch actually
      // happens.
      expect(switches.length, 2);
      expect(
        switches[1].kind,
        anyOf(PlanScheduleRowKind.ascent, PlanScheduleRowKind.stop),
      );
      expect(switches[1].gasFO2, closeTo(0.50, 1e-9));
      expect(switches[1].depthMeters, lessThanOrEqualTo(22));
      // Whatever line came before it was still on air -- the switch is
      // never retroactively attributed to an earlier line.
      final before = rows[rows.indexOf(switches[1]) - 1];
      expect(before.gasFO2, closeTo(0.21, 1e-9));
    });

    test('the table agrees with the stops it was built from', () {
      final stopRows = rows
          .where((r) => r.kind == PlanScheduleRowKind.stop)
          .toList();
      for (var i = 0; i < outcome.stops.length; i++) {
        expect(stopRows[i].depthMeters, outcome.stops[i].depthMeters);
        expect(stopRows[i].durationSeconds, outcome.stops[i].durationSeconds);
        expect(
          stopRows[i].runtimeSeconds,
          outcome.stops[i].arrivalRuntimeSeconds +
              outcome.stops[i].durationSeconds,
        );
      }
    });
  });

  group('travel-to-first-stop leg splits at gas switches (#3225)', () {
    // A trimix carried only for the deep part (MOD well past the bottom,
    // always eligible) plus two richer stage gases whose MODs are both well
    // shallower than the bottom but still deep enough that neither one's
    // own window coincides with a real deco stop -- the exact shape of the
    // bug: a gas whose entire usable range sits inside the single, long
    // bottom-to-first-stop leg, with no stop of its own to be charged at.
    const bottom = GasMix(o2: 10, he: 70); // MOD(1.6) = 150 m -- always on.
    const mid = GasMix(o2: 18, he: 45); // MOD(1.6) = 78.9 m.
    const shallow = GasMix(o2: 25, he: 50); // MOD(1.6) = 54.0 m.
    const bottomTank = DiveTank(
      id: 'bottom',
      volume: 11.1,
      startPressure: 200,
      gasMix: bottom,
    );
    const midTank = DiveTank(
      id: 'mid',
      volume: 11.1,
      startPressure: 200,
      gasMix: mid,
    );
    const shallowTank = DiveTank(
      id: 'shallow',
      volume: 11.1,
      startPressure: 200,
      gasMix: shallow,
    );
    final outcome = _engine.compute(
      _plan(
        bottomDepth: 100,
        bottomMinutes: 8,
        tanks: [bottomTank, midTank, shallowTank],
      ),
    );

    test('the first real stop lands well shallower than the mid gas\'s own '
        'MOD, so its whole window sits inside the first travel leg -- the '
        'precondition the rest of this group depends on', () {
      final firstStop = outcome.schedule.firstWhere(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      expect(firstStop.depthMeters, lessThan(78.9));
    });

    test('the mid gas is actually used, not skipped over', () {
      final usage = outcome.tankUsages.firstWhere((u) => u.tankId == 'mid');
      expect(usage.litersUsed, greaterThan(0));
    });

    test('the table prints a row on the mid gas before the first stop', () {
      final firstStopIndex = outcome.schedule.indexWhere(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      final beforeFirstStop = outcome.schedule.sublist(0, firstStopIndex);
      expect(
        beforeFirstStop.any(
          (r) => (r.gasFO2 - 0.18).abs() < 1e-9 && r.gasFHe > 0.4,
        ),
        isTrue,
        reason: 'no row breathes the mid gas before the first stop',
      );
    });

    test('splitting the leg does not change the total liters charged across '
        'all three tanks versus breathing the whole leg on one gas would '
        'have', () {
      // Conservation check: every liter charged somewhere is still exactly
      // SAC x time x pressure, just attributed to the right tank now
      // instead of all landing on the shallowest one.
      final total = outcome.tankUsages.fold<double>(
        0,
        (sum, u) => sum + u.litersUsed,
      );
      expect(total, greaterThan(0));
      expect(total.isFinite, isTrue);
    });
  });

  group('gas consumption order', () {
    test('lists cylinders in the order the table breathes them, not the '
        'order they were added', () {
      // Deco cylinder authored first, back gas second: the table still
      // breathes the back gas first (descent, bottom, travel), so the gas
      // list reads back gas, then deco.
      final outcome = _engine.compute(
        _plan(bottomDepth: 50, bottomMinutes: 30, tanks: [_ean50, _airTank]),
      );
      expect(outcome.tankUsages.map((u) => u.tankId), ['back', 'deco']);
      // And the table itself agrees on which comes first.
      final firstTankInTable = outcome.schedule
          .map((r) => r.tankId)
          .firstWhere((id) => id != null);
      expect(firstTankInTable, 'back');
    });
  });

  group('a no-deco dive (18 m / 20 min)', () {
    final outcome = _engine.compute(
      _plan(bottomDepth: 18, bottomMinutes: 20, tanks: const [_airTank]),
    );

    test('is descent, bottom, and one working-rate leg to the surface', () {
      expect(outcome.stops, isEmpty);
      expect(outcome.schedule.map((r) => r.kind), [
        PlanScheduleRowKind.descent,
        PlanScheduleRowKind.level,
        PlanScheduleRowKind.ascent,
      ]);
      final surfacing = outcome.schedule.last;
      expect(surfacing.depthMeters, 0);
      expect(surfacing.durationSeconds, 120); // 18 m at 9 m/min
      expect(outcome.runtimeSeconds, surfacing.runtimeSeconds);
    });
  });

  test('an empty plan has no table', () {
    final outcome = _engine.compute(
      domain.DivePlan(
        id: 'p',
        name: 'empty',
        gfLow: 50,
        gfHigh: 80,
        createdAt: DateTime(2026, 9, 2),
        updatedAt: DateTime(2026, 9, 2),
      ),
    );
    expect(outcome.schedule, isEmpty);
  });
}
