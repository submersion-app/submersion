import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _diluent = GasMix(o2: 18, he: 45);
const _diluentTank = DiveTank(
  id: 'dil',
  volume: 3.0,
  startPressure: 200,
  gasMix: _diluent,
  role: TankRole.diluent,
);

DiveTank _bailout({double volume = 11.1, double pressure = 207}) => DiveTank(
  id: 'bo',
  volume: volume,
  startPressure: pressure,
  gasMix: const GasMix(o2: 50),
  role: TankRole.bailout,
);

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.ccr,
  List<DiveTank>? tanks,
  int bottomMinutes = 25,
  Map<int, int> stopMinimums = const {},
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Bailout test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    tanks: tanks ?? [_diluentTank, _bailout()],
    stopMinimums: stopMinimums,
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 60.0,
        tankId: 'dil',
        gasMix: _diluent,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: 60.0,
        durationMinutes: bottomMinutes,
        tankId: 'dil',
        gasMix: _diluent,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const solver = BailoutSolver();

  test('returns null for OC plans and when no bailout tanks are carried', () {
    expect(solver.solve(_plan(mode: domain.PlanMode.oc)), isNull);
    expect(solver.solve(_plan(tanks: const [_diluentTank])), isNull);
  });

  test('SCR plans get a bailout outcome too, not just CCR (issue #3743): the '
      'mode gate widened, and the diluent tank role already honours a loop '
      'plan generically, not CCR alone (TankRoleResolver)', () {
    final outcome = solver.solve(_plan(mode: domain.PlanMode.scr));
    expect(outcome, isNotNull);
    expect(outcome!.worstCase.litersRequired, greaterThan(0));
    expect(outcome.bailoutTankUsages, isNotEmpty);
  });

  test('pSCR plans get a bailout outcome too: every non-OC mode is a loop '
      'with bailout tanks (TankRoleResolver), not CCR and SCR alone', () {
    final outcome = solver.solve(_plan(mode: domain.PlanMode.pscr));
    expect(outcome, isNotNull);
    expect(outcome!.worstCase.litersRequired, greaterThan(0));
  });

  test('the loop rows of an SCR/pSCR bailout read the plan\'s own loop '
      'model, not a CCR setpoint (issue #3743)', () {
    for (final mode in [domain.PlanMode.scr, domain.PlanMode.pscr]) {
      final plan = _plan(mode: mode);
      final bottomRow = solver.solve(plan)!.ccrRows.last;
      final expected =
          breathingFor(
                plan,
                _diluent,
                bottomRow.depthMeters,
                config: const PlanEngineConfig(),
                segment: plan.segments.last,
              )
              .inspiredAt(
                PlanEngine.environmentFor(
                  plan,
                ).pressureAtDepth(bottomRow.depthMeters),
              )
              .pO2;
      expect(bottomRow.ppO2, closeTo(expected, 1e-9), reason: mode.name);
    }
  });

  test('worst case sits at (or near) the end of the bottom phase', () {
    final outcome = solver.solve(_plan())!;
    final lastPoint = outcome.points.last;
    expect(
      outcome.worstCase.runtimeSeconds,
      greaterThanOrEqualTo(lastPoint.runtimeSeconds - 90),
      reason: 'square profile loads monotonically, so latest is worst',
    );
    expect(outcome.worstCase.depthMeters, closeTo(60.0, 0.1));
  });

  test('required liters grow across the bottom phase', () {
    final outcome = solver.solve(_plan())!;
    final bottomPoints = outcome.points
        .where((p) => p.depthMeters > 59.0)
        .toList();
    expect(bottomPoints.length, greaterThan(2));

    // Loading only ever grows on a square profile, so the demand grows with
    // it - but not smoothly. The stop grid is discrete and the ascent rate
    // depends on whether a stop is actually held: the minute a marginal deep
    // stop first appears, every leg above it changes from the working ascent
    // to the slower climb up the grid, and the minute it disappears again
    // they change back. A step like that can shave a few seconds off the
    // total ascent while the tissues are still loading, so allow a sample to
    // give back a little rather than pinning an exactness the model does not
    // promise. The trend is the real claim, and it is asserted below.
    // Whole-minute stop snapping (brought in line with PlanEngine's own
    // policy by a Copilot review) rounds a stop duration up to the next
    // full minute, a slightly bigger single-sample step than the plain
    // unsnapped grid gave, hence the wider tolerance.
    for (var i = 1; i < bottomPoints.length; i++) {
      expect(
        bottomPoints[i].litersRequired,
        greaterThanOrEqualTo(bottomPoints[i - 1].litersRequired * 0.97),
        reason: 'sample $i fell more than one grid step below its predecessor',
      );
    }
    expect(
      bottomPoints.last.litersRequired,
      greaterThan(bottomPoints.first.litersRequired * 2),
    );
  });

  test('sufficiency flips with the carried bailout volume', () {
    final small = solver.solve(
      _plan(tanks: [_diluentTank, _bailout(volume: 3.0, pressure: 100)]),
    )!;
    expect(small.sufficient, isFalse);

    final big = solver.solve(
      _plan(
        tanks: [_diluentTank, _bailout(volume: 24.0, pressure: 232)],
        bottomMinutes: 10,
      ),
    )!;
    expect(big.sufficient, isTrue);
  });

  test('nearest() returns the closest sampled point', () {
    final outcome = solver.solve(_plan())!;
    final target = outcome.points[2].runtimeSeconds.toDouble();
    expect(outcome.nearest(target).runtimeSeconds, target.toInt());
  });

  group('worstCaseRows (#3137)', () {
    test('reads the whole dive: the authored descent/bottom phase (on the '
        'diluent) up to the bailout instant, then the OC ascent down to the '
        'surface', () {
      final outcome = solver.solve(_plan())!;
      expect(outcome.worstCaseRows, isNotEmpty);
      expect(outcome.worstCaseRows.first.kind, PlanScheduleRowKind.descent);
      expect(outcome.worstCaseRows.first.tankId, 'dil');
      expect(outcome.worstCaseRows.last.depthMeters, 0);
      // RT is continuous across the whole table, not restarted at the
      // bailout instant.
      for (var i = 1; i < outcome.worstCaseRows.length; i++) {
        expect(
          outcome.worstCaseRows[i].runtimeSeconds,
          greaterThanOrEqualTo(outcome.worstCaseRows[i - 1].runtimeSeconds),
          reason: 'row $i',
        );
      }
      expect(
        outcome.worstCaseRows.last.runtimeSeconds,
        greaterThanOrEqualTo(outcome.worstCase.ttsSeconds),
      );
    });

    test('the OC tail resolves to the single carried bailout tank; the '
        'authored phase before it stays on the diluent', () {
      final outcome = solver.solve(_plan())!;
      final bailoutStart = outcome.worstCaseRows.indexWhere(
        (r) => r.tankId == 'bo',
      );
      expect(bailoutStart, greaterThan(0));
      for (final row in outcome.worstCaseRows.sublist(0, bailoutStart)) {
        expect(row.tankId, 'dil', reason: 'row at ${row.depthMeters} m');
      }
      for (final row in outcome.worstCaseRows.sublist(bailoutStart)) {
        expect(row.tankId, 'bo', reason: 'row at ${row.depthMeters} m');
        expect(row.gasFO2, closeTo(0.50, 1e-9));
      }
    });

    test('a second, richer bailout gas switches in near its own MOD', () {
      final outcome = solver.solve(
        _plan(
          tanks: [
            _diluentTank,
            _bailout(),
            const DiveTank(
              id: 'deco',
              volume: 11.1,
              startPressure: 207,
              gasMix: GasMix(o2: 100),
              role: TankRole.bailout,
            ),
          ],
        ),
      )!;
      final tankIds = outcome.worstCaseRows.map((r) => r.tankId).toSet();
      expect(
        tankIds,
        containsAll(['bo', 'deco']),
        reason: 'the shallower, richer gas should get used near the surface',
      );
    });

    test('a travel row reads PO2/END at the leg\'s deeper end, same as the '
        'main table', () {
      final rows = solver.solve(_plan())!.worstCaseRows;
      final firstOc = rows.indexWhere((r) => r.tankId == 'bo');
      final travel = rows[firstOc];
      final firstStop = rows[firstOc + 1];
      expect(travel.kind, PlanScheduleRowKind.ascent);
      expect(firstStop.kind, PlanScheduleRowKind.stop);
      expect(travel.gasFO2, closeTo(firstStop.gasFO2, 1e-9));
      // ppO2 / fO2 is the ambient pressure the row was computed at: the
      // travel row leaves 60 m, so it must be deeper than the stop it
      // arrives at (which it displays as its own depth).
      expect(
        travel.ppO2 / travel.gasFO2,
        greaterThan(firstStop.ppO2 / firstStop.gasFO2),
      );
      // The surfacing row leaves the last stop on the last stop's gas.
      final lastStop = rows[rows.length - 2];
      final surfacing = rows.last;
      expect(surfacing.kind, PlanScheduleRowKind.ascent);
      expect(surfacing.ppO2, closeTo(lastStop.ppO2, 1e-9));
    });

    test('the first OC leg splits at gas switches, so a bailout gas whose '
        'whole window sits inside it still gets used (#3225)', () {
      // Deep bottom, modest bottom time: the worst case's first real OC
      // stop lands well shallower than the mid gas's own MOD (78.9 m), so
      // its window -- between that and the shallow gas's MOD (54.0 m) --
      // sits entirely inside the single long bailout-point-to-first-stop
      // leg, same shape as the main table's own #3225 regression.
      final deepPlan = domain.DivePlan(
        id: 'deep-plan',
        name: 'Deep bailout test',
        mode: domain.PlanMode.ccr,
        gfLow: 50,
        gfHigh: 80,
        tanks: [
          _diluentTank,
          const DiveTank(
            id: 'bo-bottom',
            volume: 11.1,
            startPressure: 207,
            gasMix: GasMix(o2: 10, he: 70), // MOD(1.6) = 150 m.
            role: TankRole.bailout,
          ),
          const DiveTank(
            id: 'bo-mid',
            volume: 11.1,
            startPressure: 207,
            gasMix: GasMix(o2: 18, he: 45), // MOD(1.6) = 78.9 m.
            role: TankRole.bailout,
          ),
          const DiveTank(
            id: 'bo-shallow',
            volume: 11.1,
            startPressure: 207,
            gasMix: GasMix(o2: 25, he: 50), // MOD(1.6) = 54.0 m.
            role: TankRole.bailout,
          ),
        ],
        segments: [
          PlanSegment.travel(
            id: 'deep-seg-1',
            fromDepth: 0,
            targetDepth: 100.0,
            tankId: 'dil',
            gasMix: _diluent,
            order: 0,
            ratePerMinute: 18.0,
          ),
          PlanSegment.hold(
            id: 'deep-seg-2',
            depth: 100.0,
            durationMinutes: 8,
            tankId: 'dil',
            gasMix: _diluent,
            order: 1,
          ),
        ],
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      );
      final outcome = solver.solve(deepPlan)!;

      final firstStopIndex = outcome.worstCaseRows.indexWhere(
        (r) => r.kind == PlanScheduleRowKind.stop,
      );
      expect(
        outcome.worstCaseRows[firstStopIndex].depthMeters,
        lessThan(78.9),
        reason:
            'precondition: the mid gas\'s window must sit inside the '
            'first OC leg for this test to exercise anything',
      );

      final usage = outcome.bailoutTankUsages.firstWhere(
        (u) => u.tankId == 'bo-mid',
      );
      expect(usage.litersUsed, greaterThan(0));
    });

    test('the plan\'s own o2Narcotic override reaches the bailout schedule, '
        'not just the global setting (a diver reported this never changed '
        'the bailout table, only the main one)', () {
      const trimixBailout = DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 207,
        gasMix: GasMix(o2: 21, he: 35),
        role: TankRole.bailout,
      );
      // Same solver (global config, default o2Narcotic: true) for both --
      // only the plan's own override differs: unset (falls back to the
      // global true) vs. explicitly false.
      const solver = BailoutSolver();
      final baseline = _plan(tanks: [_diluentTank, trimixBailout]);
      final overridden = baseline.copyWith(o2Narcotic: false);

      final baselineRow = solver
          .solve(baseline)!
          .worstCaseRows
          .firstWhere((r) => r.tankId == 'bo');
      final overriddenRow = solver
          .solve(overridden)!
          .worstCaseRows
          .firstWhere((r) => r.tankId == 'bo');
      expect(
        overriddenRow.endMeters,
        isNot(closeTo(baselineRow.endMeters, 0.5)),
      );
    });

    test("a segment's mid-plan OC bailout override is replayed open circuit, "
        "not loaded as if the loop never left, same as PlanEngine.compute's "
        'own authored-leg replay (a Copilot review caught this: the bottom-'
        'phase tissue replay always built ClosedCircuit, regardless of the '
        "segment's own diveModeOverride)", () {
      // A lean diluent: breathed open circuit at 60 m its own ppO2 is
      // only ~0.7 bar, far under the plan's 1.3 bar CCR setpoint -- a gap
      // wide enough that the two replays cannot land on the same tissue
      // loading by coincidence (an 18/45-style diluent's OC ppO2 sits
      // close enough to 1.3 bar at 60 m that an earlier version of this
      // test could not tell a correct replay from a broken one).
      const leanDiluent = GasMix(o2: 10, he: 50);
      const leanDiluentTank = DiveTank(
        id: 'dil-lean',
        volume: 3.0,
        startPressure: 200,
        gasMix: leanDiluent,
        role: TankRole.diluent,
      );
      final tanks = [leanDiluentTank, _bailout()];
      PlanSegment ocLeg(domain.PlanMode? override) => PlanSegment.hold(
        id: 'seg-oc',
        depth: 60.0,
        durationMinutes: 40,
        tankId: 'dil-lean',
        gasMix: leanDiluent,
        diveModeOverride: override,
        order: 1,
      );
      domain.DivePlan planWith(domain.PlanMode? override) => domain.DivePlan(
        id: 'plan-mid-bailout',
        name: 'Mid-plan bailout',
        mode: domain.PlanMode.ccr,
        gfLow: 50,
        gfHigh: 80,
        tanks: tanks,
        segments: [
          PlanSegment.travel(
            id: 'seg-1',
            fromDepth: 0,
            targetDepth: 60.0,
            tankId: 'dil-lean',
            gasMix: leanDiluent,
            order: 0,
            ratePerMinute: 18.0,
          ),
          ocLeg(override),
        ],
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      );

      final asLoop = solver.solve(planWith(null))!;
      final asOc = solver.solve(planWith(domain.PlanMode.oc))!;

      // Replaying the same leg open circuit instead of on the loop's
      // constant-ppO2 setpoint changes the inert gas actually loaded,
      // so the two must disagree -- if they matched, the override was
      // never read.
      expect(
        asOc.worstCase.litersRequired,
        isNot(closeTo(asLoop.worstCase.litersRequired, 0.5)),
      );
    });

    test("the bailout schedule honours the plan's own configured stop "
        'minimums, same as the main table (a Copilot review caught this: '
        'the bailout policy omitted them entirely)', () {
      final withMinimum = solver.solve(_plan(stopMinimums: const {3: 600}))!;
      final stopAt3m = withMinimum.worstCaseRows.firstWhere(
        (r) => r.kind == PlanScheduleRowKind.stop && r.depthMeters == 3,
      );
      expect(stopAt3m.durationSeconds, greaterThanOrEqualTo(600));
    });

    test('END is floored at 0 m on every row, same as the main table', () {
      final outcome = solver.solve(_plan())!;
      final rows = outcome.worstCaseRows;
      // The surfacing row (0 m) on any mix, and the 18/45 diluent rows at
      // shallow depth, would otherwise read negative from GasMix.end().
      expect(rows.last.depthMeters, 0);
      expect(rows.last.endMeters, 0.0);
      for (final row in rows) {
        expect(
          row.endMeters,
          greaterThanOrEqualTo(0.0),
          reason: 'row at ${row.depthMeters} m (${row.kind})',
        );
      }
    });

    test('only the first travel leg prints before a stop; later stops '
        'fold the travel time in, same as the main table (#3138)', () {
      final outcome = solver.solve(_plan())!;
      final rows = outcome.worstCaseRows;
      final stopIndexes = [
        for (var i = 0; i < rows.length; i++)
          if (rows[i].kind == PlanScheduleRowKind.stop) i,
      ];
      expect(stopIndexes.length, greaterThan(1));
      for (final i in stopIndexes.skip(1)) {
        expect(rows[i - 1].kind, PlanScheduleRowKind.stop);
      }
    });
  });

  group('bailoutTankUsages', () {
    test('one row per bailout tank, summing to the worst case\'s required '
        'liters', () {
      final outcome = solver.solve(_plan())!;
      expect(outcome.bailoutTankUsages, hasLength(1));
      final usage = outcome.bailoutTankUsages.single;
      expect(usage.tankId, 'bo');
      expect(usage.litersUsed, closeTo(outcome.worstCase.litersRequired, 0.5));
      expect(usage.totalLiters, isNotNull);
      expect(usage.remainingPressure, isNotNull);
    });

    test('usage splits across tanks when more than one bailout gas is '
        'actually used', () {
      final outcome = solver.solve(
        _plan(
          tanks: [
            _diluentTank,
            _bailout(),
            const DiveTank(
              id: 'deco',
              volume: 11.1,
              startPressure: 207,
              gasMix: GasMix(o2: 100),
              role: TankRole.bailout,
            ),
          ],
        ),
      )!;
      final byId = {for (final u in outcome.bailoutTankUsages) u.tankId: u};
      expect(byId.keys, containsAll(['bo', 'deco']));
      expect(byId['bo']!.litersUsed, greaterThan(0));
      expect(byId['deco']!.litersUsed, greaterThan(0));
      final total = byId.values.fold<double>(0, (sum, u) => sum + u.litersUsed);
      expect(total, closeTo(outcome.worstCase.litersRequired, 0.5));
    });

    test('lists cylinders in the order the worst-case table breathes them, '
        'not the order they were added', () {
      // Oxygen authored before the 50 % bailout: the OC tail still starts
      // on the 50 % at depth and only reaches oxygen near the surface, so
      // the list reads 50 % first, oxygen second.
      final outcome = solver.solve(
        _plan(
          tanks: [
            _diluentTank,
            const DiveTank(
              id: 'deco',
              volume: 11.1,
              startPressure: 207,
              gasMix: GasMix(o2: 100),
              role: TankRole.bailout,
            ),
            _bailout(),
          ],
        ),
      )!;
      expect(outcome.bailoutTankUsages.map((u) => u.tankId), ['bo', 'deco']);
    });

    test(
      'flags a cylinder whose own usage exceeds its own capacity (#3190)',
      () {
        final outcome = solver.solve(
          _plan(tanks: [_diluentTank, _bailout(volume: 3.0, pressure: 100)]),
        )!;
        final usage = outcome.bailoutTankUsages.single;
        expect(usage.litersUsed, greaterThan(usage.totalLiters!));
        expect(usage.reserveViolation, isTrue);
        // The shortfall, priced as a negative pressure, not floored to 0 as
        // if the cylinder had exactly covered it.
        expect(usage.remainingPressure, lessThan(0));
        expect(usage.remainingLiters, lessThan(0));
        expect(usage.percentUsed, greaterThan(100));
      },
    );
  });

  group('hypercapnia phase (issue #3743)', () {
    test('enabling the phase increases the worst-case demand over the '
        'stressed-only baseline', () {
      final baseline = solver.solve(_plan())!;
      final withHypercapnia = const BailoutSolver(
        config: PlanEngineConfig(
          hypercapniaEnabled: true,
          hypercapniaFactor: 4.0,
          hypercapniaMinutes: 5,
        ),
      ).solve(_plan())!;
      expect(
        withHypercapnia.worstCase.litersRequired,
        greaterThan(baseline.worstCase.litersRequired),
      );
    });

    test('a window at least as long as the whole ascent matches charging the '
        'entire ascent at that rate - proves the time-split arithmetic '
        'degenerates correctly rather than double-counting or dropping a '
        'leg when the boundary never actually falls inside the ascent', () {
      const factor = 6.0;
      final allHypercapnia = const BailoutSolver(
        config: PlanEngineConfig(
          sacStressedFactor: 2.5,
          hypercapniaEnabled: true,
          hypercapniaFactor: factor,
          hypercapniaMinutes: 999,
        ),
      ).solve(_plan())!;
      final allStressedAtThatRate = const BailoutSolver(
        config: PlanEngineConfig(sacStressedFactor: factor),
      ).solve(_plan())!;

      expect(
        allHypercapnia.worstCase.litersRequired,
        closeTo(allStressedAtThatRate.worstCase.litersRequired, 0.01),
      );
      // Per-tank totals must also agree, not just the headline total - a
      // bug in the leg-by-leg split could cancel out in the sum while
      // still misattributing liters between tanks.
      final hypUsage = {
        for (final u in allHypercapnia.bailoutTankUsages)
          u.tankId: u.litersUsed,
      };
      final stressedUsage = {
        for (final u in allStressedAtThatRate.bailoutTankUsages)
          u.tankId: u.litersUsed,
      };
      expect(hypUsage.keys, stressedUsage.keys);
      for (final id in hypUsage.keys) {
        expect(hypUsage[id], closeTo(stressedUsage[id]!, 0.01));
      }
    });

    test('the boundary splits correctly even when it falls inside a leg that '
        'also carries a gas switch: per-tank usage still sums to the '
        "worst case's own total", () {
      final outcome =
          const BailoutSolver(
            config: PlanEngineConfig(
              hypercapniaEnabled: true,
              hypercapniaFactor: 4.0,
              hypercapniaMinutes: 1,
            ),
          ).solve(
            _plan(
              tanks: [
                _diluentTank,
                _bailout(),
                const DiveTank(
                  id: 'deco',
                  volume: 11.1,
                  startPressure: 207,
                  gasMix: GasMix(o2: 100),
                  role: TankRole.bailout,
                ),
              ],
            ),
          )!;
      final total = outcome.bailoutTankUsages.fold<double>(
        0,
        (sum, u) => sum + u.litersUsed,
      );
      expect(total, closeTo(outcome.worstCase.litersRequired, 0.5));
    });

    test('a hypercapnia rate below the stressed rate never shrinks the '
        'bailout requirement: the phase is layered over stressed SAC', () {
      final baseline = solver.solve(_plan())!;
      final lowFactor = const BailoutSolver(
        config: PlanEngineConfig(
          hypercapniaEnabled: true,
          hypercapniaFactor: 1.0,
          hypercapniaMinutes: 5,
        ),
      ).solve(_plan())!;
      expect(
        lowFactor.worstCase.litersRequired,
        closeTo(baseline.worstCase.litersRequired, 0.01),
      );
    });

    test('each side of the boundary is charged at its own mean depth on a '
        'travel leg, not the whole leg midpoint', () {
      const environment = DiveEnvironment.standard;
      // 30 m to 0 m over 60 s, boundary at 30 s: the hypercapnia half runs
      // 30 m to 15 m (mean 22.5 m), the stressed half 15 m to 0 m (7.5 m).
      final liters = bailoutSpanLiters(
        startSecondsSinceBailout: 0,
        durationSeconds: 60,
        fromDepth: 30,
        toDepth: 0,
        hypercapniaAmv: 100,
        stressedAmv: 40,
        hypercapniaSeconds: 30,
        environment: environment,
      );
      expect(
        liters,
        closeTo(
          100 * 0.5 * environment.pressureAtDepth(22.5) +
              40 * 0.5 * environment.pressureAtDepth(7.5),
          1e-9,
        ),
      );
    });

    test('a span entirely past the boundary is charged at its mean depth, '
        'as before the phase existed', () {
      const environment = DiveEnvironment.standard;
      final liters = bailoutSpanLiters(
        startSecondsSinceBailout: 600,
        durationSeconds: 120,
        fromDepth: 21,
        toDepth: 9,
        hypercapniaAmv: 100,
        stressedAmv: 40,
        hypercapniaSeconds: 300,
        environment: environment,
      );
      expect(liters, closeTo(40 * 2 * environment.pressureAtDepth(15), 1e-9));
    });
  });
}
