import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';

/// A repetitive dive starts with the oxygen exposure the earlier dives left
/// behind (issue #3565): CNS decayed over the surface interval, OTU carried
/// for the day. The engine adds it to the dive's own exposure, and every
/// alternative to the live plan (contingencies, the range table) starts
/// from the same place.

const _ean32 = GasMix(o2: 32);

domain.DivePlan _plan({double startCns = 0, double startOtu = 0}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Start exposure',
    gfLow: 40,
    gfHigh: 80,
    startCns: startCns,
    startOtu: startOtu,
    tanks: const [
      DiveTank(id: 'back', volume: 12, startPressure: 232, gasMix: _ean32),
    ],
    segments: [
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 30,
        tankId: 'back',
        gasMix: _ean32,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'bottom',
        depth: 30,
        durationMinutes: 25,
        tankId: 'back',
        gasMix: _ean32,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 10, 27),
    updatedAt: DateTime(2026, 10, 27),
  );
}

bool _hasCnsIssue(PlanOutcome outcome) => outcome.issues.any(
  (i) =>
      i.type == PlanIssueType.cnsWarning || i.type == PlanIssueType.cnsCritical,
);

void main() {
  const engine = PlanEngine();

  group('engine start exposure', () {
    test('a warning names when carried exposure reached its limit', () {
      int? onsetOf(domain.DivePlan plan, PlanIssueType type) => engine
          .compute(plan)
          .issues
          .firstWhere((issue) => issue.type == type)
          .atRuntime;

      // Over the limit from the start: there is no moment to point at later.
      expect(onsetOf(_plan(startCns: 120), PlanIssueType.cnsCritical), 0);
      expect(onsetOf(_plan(startOtu: 1000), PlanIssueType.otuHigh), 0);

      // Half the dive's own CNS short of the limit: reached part way through.
      final own = engine.compute(_plan());
      final limit = engine.config.cnsWarningThreshold.toDouble();
      final onset = onsetOf(
        _plan(startCns: limit - own.cnsEnd / 2),
        PlanIssueType.cnsWarning,
      )!;
      expect(onset, greaterThan(0));
      expect(onset, lessThan(own.runtimeSeconds));
    });

    test('a fresh plan starts at zero, as before', () {
      final plan = _plan();
      expect(plan.startCns, 0);
      expect(plan.startOtu, 0);
    });

    test('start CNS and OTU add to the dive\'s own exposure', () {
      final fresh = engine.compute(_plan());
      final repetitive = engine.compute(_plan(startCns: 30, startOtu: 120));

      expect(repetitive.cnsEnd, closeTo(fresh.cnsEnd + 30, 1e-9));
      expect(repetitive.otuTotal, closeTo(fresh.otuTotal + 120, 1e-9));
    });

    test('per-segment CNS runs on from the start exposure', () {
      final fresh = engine.compute(_plan());
      final repetitive = engine.compute(_plan(startCns: 30));

      expect(
        repetitive.segmentOutcomes.first.cns,
        closeTo(fresh.segmentOutcomes.first.cns + 30, 1e-9),
      );
    });

    test('carried CNS can push the dive over the CNS warning', () {
      final fresh = engine.compute(_plan());
      expect(_hasCnsIssue(fresh), isFalse);

      final repetitive = engine.compute(_plan(startCns: 95));
      expect(_hasCnsIssue(repetitive), isTrue);
    });

    test('contingency and range variants start from the same exposure', () {
      final plan = _plan(startCns: 30);
      final live = engine.compute(plan);
      final deviations = const ContingencyService().deviations(plan);
      final range = const RangeTableService().compute(plan);

      for (final deviation in deviations) {
        expect(deviation.outcome.cnsEnd, greaterThan(live.cnsEnd));
      }
      final cells = range.cells.expand((row) => row).nonNulls.toList();
      expect(cells, isNotEmpty);
      for (final cell in cells) {
        expect(cell.outcome.cnsEnd, greaterThan(30));
      }
    });
  });

  group('editing state to plan', () {
    DivePlanState state({
      double? initialCns,
      double? initialOtu,
      Duration? surfaceInterval,
    }) => DivePlanState(
      id: 'plan-1',
      name: 'Start exposure',
      initialCns: initialCns,
      initialOtu: initialOtu,
      surfaceInterval: surfaceInterval,
      segments: const [],
      tanks: const [],
      createdAt: DateTime(2026, 10, 27),
      updatedAt: DateTime(2026, 10, 27),
    );

    test('no carried exposure maps to a zero start', () {
      final plan = divePlanFromState(state());
      expect(plan.startCns, 0);
      expect(plan.startOtu, 0);
    });

    test('carried CNS decays over the surface interval', () {
      final plan = divePlanFromState(
        state(initialCns: 40, surfaceInterval: const Duration(minutes: 90)),
      );
      expect(plan.startCns, closeTo(20, 1e-9));
      expect(
        plan.startCns,
        closeTo(CnsTable.cnsAfterSurfaceInterval(40, 90), 1e-9),
      );
    });

    test('carried CNS with no surface interval is not decayed', () {
      final plan = divePlanFromState(state(initialCns: 40));
      expect(plan.startCns, 40);
    });

    test('carried OTU passes through unchanged', () {
      final plan = divePlanFromState(
        state(initialOtu: 150, surfaceInterval: const Duration(hours: 2)),
      );
      expect(plan.startOtu, 150);
    });
  });
}
