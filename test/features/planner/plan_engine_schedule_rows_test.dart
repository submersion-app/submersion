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

    test('alternates a travel leg and a stop for every computed stop', () {
      final tail = rows.sublist(2);
      // ..., travel, stop, travel, stop, ..., travel-to-surface.
      expect(tail.last.kind, PlanScheduleRowKind.ascent);
      expect(tail.last.depthMeters, 0);
      final stopsInTable = tail.where(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      expect(stopsInTable.length, outcome.stops.length);
      for (var i = 0; i < tail.length - 1; i++) {
        final expected = i.isEven
            ? PlanScheduleRowKind.ascent
            : PlanScheduleRowKind.stop;
        expect(tail[i].kind, expected, reason: 'tail row $i');
      }
    });

    test('each line begins where the previous one ended', () {
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i].startRuntimeSeconds,
          rows[i - 1].runtimeSeconds,
          reason: 'row $i',
        );
      }
    });

    test('a travel leg arrives at the depth of the stop after it', () {
      for (var i = 2; i < rows.length - 1; i++) {
        if (rows[i].kind == PlanScheduleRowKind.ascent) {
          expect(rows[i].depthMeters, rows[i + 1].depthMeters);
        }
      }
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
      // Air off the boat, EAN50 once: the switch sits on a stop line, not on
      // the leg that reaches it - the diver changes regulators at the stop.
      expect(switches.length, 2);
      expect(switches[1].kind, PlanScheduleRowKind.stop);
      expect(switches[1].gasFO2, closeTo(0.50, 1e-9));
      expect(switches[1].depthMeters, lessThanOrEqualTo(21));
      // The leg that carried the diver there was still on air.
      final legBefore = rows[rows.indexOf(switches[1]) - 1];
      expect(legBefore.kind, PlanScheduleRowKind.ascent);
      expect(legBefore.gasFO2, closeTo(0.21, 1e-9));
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
