import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

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
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Bailout test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    tanks: tanks ?? [_diluentTank, _bailout()],
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
    for (var i = 1; i < bottomPoints.length; i++) {
      expect(
        bottomPoints[i].litersRequired,
        greaterThanOrEqualTo(bottomPoints[i - 1].litersRequired * 0.98),
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

    test(
      'flags a cylinder whose own usage exceeds its own capacity (#3190)',
      () {
        final outcome = solver.solve(
          _plan(tanks: [_diluentTank, _bailout(volume: 3.0, pressure: 100)]),
        )!;
        final usage = outcome.bailoutTankUsages.single;
        expect(usage.litersUsed, greaterThan(usage.totalLiters!));
        expect(usage.reserveViolation, isTrue);
        // pressureAfterConsuming floors at zero rather than negative.
        expect(usage.remainingPressure, 0.0);
      },
    );
  });
}
