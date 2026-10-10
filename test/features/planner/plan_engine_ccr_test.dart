import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _diluent = GasMix(o2: 18, he: 45);
const _diluentTank = DiveTank(
  id: 'dil',
  volume: 3.0,
  startPressure: 200,
  gasMix: _diluent,
  role: TankRole.diluent,
);
const _o2Tank = DiveTank(
  id: 'o2',
  volume: 3.0,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
);
const _bailoutTank = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 207,
  gasMix: GasMix(o2: 50),
  role: TankRole.bailout,
);

List<PlanSegment> _segments({
  double depth = 60.0,
  int minutes = 25,
  GasMix gasMix = _diluent,
}) => [
  PlanSegment.travel(
    id: 'seg-1',
    fromDepth: 0,
    targetDepth: depth,
    tankId: 'dil',
    gasMix: gasMix,
    order: 0,
    ratePerMinute: 18.0,
  ),
  PlanSegment.hold(
    id: 'seg-2',
    depth: depth,
    durationMinutes: minutes,
    tankId: 'dil',
    gasMix: gasMix,
    order: 1,
  ),
];

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.ccr,
  List<DiveTank> tanks = const [_diluentTank, _o2Tank, _bailoutTank],
  List<PlanSegment>? segments,
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'CCR test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    tanks: tanks,
    segments: segments ?? _segments(),
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const engine = PlanEngine();

  group('PlanEngine CCR', () {
    test('loop deco is shorter than OC deco on the diluent alone', () {
      final ccr = engine.compute(_plan());
      // The honest OC baseline carries ONLY the diluent: giving the OC plan
      // the O2/EAN50 cylinders would hand it deco gases the loop's low
      // shallow setpoint (0.7 bar) cannot match.
      final ocDiluentOnly = engine.compute(
        _plan(mode: domain.PlanMode.oc, tanks: const [_diluentTank]),
      );

      expect(ccr.stops, isNotEmpty);
      expect(
        ccr.totalDecoSeconds,
        lessThan(ocDiluentOnly.totalDecoSeconds),
        reason: 'constant-ppO2 loop off-gasses faster than OC diluent',
      );
    });

    test('O2 consumption is metabolic rate times runtime', () {
      final outcome = engine.compute(_plan());
      final o2 = outcome.tankUsages.firstWhere((u) => u.tankId == 'o2');
      expect(o2.litersUsed, closeTo(1.0 * outcome.runtimeSeconds / 60.0, 1.0));
    });

    test('diluent charged for the descent loop fill; bailout untouched', () {
      final outcome = engine.compute(_plan());
      final diluent = outcome.tankUsages.firstWhere((u) => u.tankId == 'dil');
      // 6 L loop x 6 bar depth-pressure delta at 60 m standard.
      expect(diluent.litersUsed, closeTo(36.0, 0.5));
      final bailout = outcome.tankUsages.firstWhere((u) => u.tankId == 'bo');
      expect(bailout.litersUsed, 0.0);
      expect(bailout.reserveViolation, isFalse);
    });

    test('CCR ppO2 and CNS run on the setpoint, not the diluent', () {
      final outcome = engine.compute(_plan());
      // At 1.3 bar setpoint no ppO2 issue should fire even at 60 m, where
      // OC on the diluent would be far below any limit anyway; the real
      // check: max segment ppO2 equals the high setpoint.
      final bottom = outcome.segmentOutcomes.last;
      expect(bottom.maxPpO2, closeTo(1.3, 1e-9));
      expect(
        outcome.issues.map((i) => i.type),
        isNot(contains(PlanIssueType.ppO2Critical)),
      );
    });

    test('a lean diluent within Dil MOD raises no issue', () {
      final outcome = engine.compute(_plan());
      // _diluent is 18% O2: ~1.27 bar at 60 m, under the 1.6 bar default.
      expect(
        outcome.issues.map((i) => i.type),
        isNot(contains(PlanIssueType.diluentModExceeded)),
      );
    });

    test('a diluent that would exceed Dil MOD at depth raises an issue', () {
      const richDiluent = GasMix(o2: 30, he: 25);
      final outcome = engine.compute(
        _plan(segments: _segments(gasMix: richDiluent)),
      );
      // 30% O2 at 60 m on the plan's default salt water (1025 kg/m3, not
      // the flat 1 bar/10 m assumption) is ~7.029 bar ambient, so ~2.109
      // bar, over the 1.6 bar default Dil MOD.
      final issue = outcome.issues.firstWhere(
        (i) => i.type == PlanIssueType.diluentModExceeded,
      );
      expect(issue.value, closeTo(2.109, 0.001));
      expect(issue.threshold, closeTo(1.6, 1e-9));
    });

    test('an OC plan never raises diluentModExceeded', () {
      const richDiluent = GasMix(o2: 30, he: 25);
      final outcome = engine.compute(
        _plan(
          mode: domain.PlanMode.oc,
          tanks: const [_diluentTank],
          segments: _segments(gasMix: richDiluent),
        ),
      );
      expect(
        outcome.issues.map((i) => i.type),
        isNot(contains(PlanIssueType.diluentModExceeded)),
      );
    });

    test(
      'noBailoutCarried fires without a bailout tank and clears with one',
      () {
        final without = engine.compute(
          _plan(tanks: const [_diluentTank, _o2Tank]),
        );
        expect(
          without.issues.map((i) => i.type),
          contains(PlanIssueType.noBailoutCarried),
        );
        // OC-specific "no deco gas" alert must NOT fire for CCR.
        expect(
          without.issues.map((i) => i.type),
          isNot(contains(PlanIssueType.ndlExceededNoDecoGas)),
        );

        final withBailout = engine.compute(_plan());
        expect(
          withBailout.issues.map((i) => i.type),
          isNot(contains(PlanIssueType.noBailoutCarried)),
        );
      },
    );

    test(
      'the gas column never attributes the loop to a bailout tank (#3131)',
      () {
        // A dense OC bailout staging, as a technical diver carries for a
        // deep dive, spans a wide O2 range in fine steps. The loop's
        // continuously shifting inert fraction can coincidentally fall
        // within the matching tolerance of one of these at almost any stop,
        // even though the diver never leaves the loop.
        final bailoutTanks = [
          for (var o2 = 10; o2 <= 95; o2++)
            DiveTank(
              id: 'bo-$o2',
              volume: 11.1,
              startPressure: 207,
              gasMix: GasMix(o2: o2.toDouble()),
              role: TankRole.bailout,
            ),
        ];
        const airDiluent = DiveTank(
          id: 'dil',
          volume: 3.0,
          startPressure: 200,
          gasMix: GasMix(o2: 21),
          role: TankRole.diluent,
        );
        final outcome = engine.compute(
          _plan(
            tanks: [airDiluent, _o2Tank, ...bailoutTanks],
            segments: _segments(gasMix: const GasMix(o2: 21)),
          ),
        );

        final bailoutIds = bailoutTanks.map((t) => t.id).toSet();
        for (final row in outcome.schedule) {
          expect(
            bailoutIds.contains(row.tankId),
            isFalse,
            reason:
                'row at ${row.depthMeters} m resolved to a bailout tank '
                '(${row.tankId}) while the diver is on the loop',
          );
        }
      },
    );

    test('the computed ascent never claims a gas switch on a single-diluent '
        'dive (#3131)', () {
      // CcrLoopAscentGas expresses the loop's constant-ppO2 composition as
      // a continuously drifting fraction (O2% rises as ambient pressure
      // falls on ascent). Comparing consecutive stops' raw fractions, as
      // the OC switch-detection formula does, flags nearly every stop as
      // a "switch" to a different fabricated gas even though the diver
      // never leaves the loop or its one diluent.
      final outcome = engine.compute(_plan());

      expect(outcome.schedule, isNotEmpty);
      final switchRows = outcome.schedule.where((r) => r.gasSwitch);
      expect(
        switchRows.length,
        1,
        reason:
            'only the first line (establishing the diluent) should show '
            'a gas; got switches at depths '
            '${switchRows.map((r) => r.depthMeters).toList()}',
      );
      expect(outcome.schedule.first.gasSwitch, isTrue);
    });

    test('the Gas column shows the real diluent on every computed-ascent '
        'line, never an interpolated mix (#3131)', () {
      // CcrLoopAscentGas's own gasForDepth() is normalized against
      // alveolar pressure for the deco engine's bookkeeping and drifts
      // continuously with depth -- using it for display fabricated a
      // different invented gas on nearly every line (a diver saw this
      // directly: a single Tx 10/70 diluent shown as Tx 12/68, Tx 24/59,
      // ... Tx 87/10 on the way up). The diluent itself never changes
      // mid-ascent, so every row's stored gasFO2/gasFHe must equal it
      // exactly.
      final outcome = engine.compute(_plan());
      for (final row in outcome.schedule) {
        expect(row.gasFO2, closeTo(_diluent.o2 / 100.0, 1e-9));
        expect(row.gasFHe, closeTo(_diluent.he / 100.0, 1e-9));
      }
    });

    test('PO2 column shows the loop setpoint, not the diluent\'s own ambient '
        'ppO2', () {
      // _diluent is 18% O2, so at 60 m (salt water default) its own
      // ambient ppO2 would be well above the 1.3 bar high setpoint --
      // showing that number instead of the setpoint would be an obvious,
      // immediately-noticeable wrong reading for a CCR diver.
      final outcome = engine.compute(_plan());
      final bottomRow = outcome.schedule.firstWhere(
        (r) => r.kind == PlanScheduleRowKind.level,
      );
      expect(bottomRow.ppO2, closeTo(1.3, 1e-9));

      // The computed ascent's PO2 must also read the setpoint EXACTLY
      // throughout (high above the 10 m switch depth, low below it), never
      // a value that drifts with depth. PO2 is asked directly of the loop
      // model (ClosedCircuit.inspiredAt) rather than back-derived by
      // multiplying the stored ambient-normalized gas fraction by ambient
      // pressure again, which previously overstated it by a margin that
      // grew at shallow depth (a diver saw this directly: 1.30 at depth,
      // drifting up to 1.35 near the surface, on a single 1.3 bar
      // setpoint).
      for (final row in outcome.schedule) {
        if (row.depthMeters <= 0) continue;
        final expectedSetpoint = row.depthMeters > 10.0 ? 1.3 : 0.7;
        expect(
          row.ppO2,
          closeTo(expectedSetpoint, 1e-9),
          reason: 'row at ${row.depthMeters} m should read the setpoint',
        );
      }
    });

    test('END column matches GasMix.end() on the row\'s own gas and depth '
        '(depth-matched rows only)', () {
      final outcome = engine.compute(_plan());
      // A computed travel row (kind == ascent) samples its fraction at the
      // leg's deeper end but is displayed at the shallower arrival depth,
      // so its END is not directly recomputable from the displayed depth
      // alone. Every other kind -- descent, level, and stop -- is always
      // depth-matched (authored legs never split; computed stops sample
      // exactly their own depth), so this checks those.
      final depthMatched = outcome.schedule.where(
        (r) => r.kind != PlanScheduleRowKind.ascent,
      );
      expect(depthMatched, isNotEmpty);
      for (final row in depthMatched) {
        final expected = GasMix(
          o2: row.gasFO2 * 100,
          he: row.gasFHe * 100,
        ).end(row.depthMeters, o2Narcotic: true);
        expect(
          row.endMeters,
          closeTo(expected, 1e-9),
          reason: 'row at ${row.depthMeters} m (${row.kind})',
        );
      }
    });
  });
}
