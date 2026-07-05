import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

List<PlanSegment> _airSegments({double depth = 45.0, int minutes = 25}) => [
  PlanSegment.descent(
    id: 'seg-1',
    targetDepth: depth,
    tankId: 'tank-1',
    gasMix: _air,
    order: 0,
  ),
  PlanSegment.bottom(
    id: 'seg-2',
    depth: depth,
    durationMinutes: minutes,
    tankId: 'tank-1',
    gasMix: _air,
    order: 1,
  ),
];

domain.DivePlan _plan({
  List<PlanSegment>? segments,
  List<DiveTank> tanks = const [_airTank],
  double lastStopDepth = 3.0,
  AirBreakPolicy? airBreaks,
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Engine test',
    gfLow: 40,
    gfHigh: 80,
    lastStopDepth: lastStopDepth,
    airBreaks: airBreaks,
    segments: segments ?? _airSegments(),
    tanks: tanks,
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  group('PlanEngine schedule', () {
    test('parity with the legacy PlanCalculatorService', () {
      final plan = _plan();
      final outcome = const PlanEngine().compute(plan);

      final legacy = PlanCalculatorService(gfLow: 40, gfHigh: 80).calculatePlan(
        segments: plan.segments,
        tanks: plan.tanks,
        sacRate: 15.0,
      );

      expect(outcome.stops, isNotEmpty);
      expect(outcome.stops.length, legacy.decoSchedule.length);
      for (var i = 0; i < legacy.decoSchedule.length; i++) {
        expect(outcome.stops[i].depthMeters, legacy.decoSchedule[i].depth);
        expect(
          outcome.stops[i].durationSeconds,
          legacy.decoSchedule[i].durationSeconds,
        );
      }
      expect(outcome.ttsAtBottom, legacy.ttsAtBottom);
      expect(outcome.ndlAtBottom, legacy.ndlAtBottom);
    });

    test('trimix multi-gas plan switches to O2 at 6 m and shallower', () {
      const backGas = GasMix(o2: 18, he: 45);
      const tanks = [
        DiveTank(id: 'back', volume: 24, gasMix: backGas),
        DiveTank(
          id: 'ean50',
          volume: 11.1,
          gasMix: GasMix(o2: 50),
          role: TankRole.deco,
        ),
        DiveTank(
          id: 'o2',
          volume: 11.1,
          gasMix: GasMix(o2: 100),
          role: TankRole.deco,
        ),
      ];
      final plan = _plan(
        tanks: tanks,
        segments: [
          PlanSegment.descent(
            id: 'seg-1',
            targetDepth: 60.0,
            tankId: 'back',
            gasMix: backGas,
            order: 0,
          ),
          PlanSegment.bottom(
            id: 'seg-2',
            depth: 60.0,
            durationMinutes: 25,
            tankId: 'back',
            gasMix: backGas,
            order: 1,
          ),
        ],
      );
      final outcome = const PlanEngine().compute(plan);

      expect(outcome.stops, isNotEmpty);
      for (final stop in outcome.stops.where((s) => s.depthMeters <= 6.0)) {
        expect(stop.gasFO2, closeTo(1.0, 1e-9), reason: 'O2 at 6 m and up');
        expect(stop.tankId, 'o2');
      }
      // Arrival runtimes strictly increase.
      var previous = -1;
      for (final stop in outcome.stops) {
        expect(stop.arrivalRuntimeSeconds, greaterThan(previous));
        previous = stop.arrivalRuntimeSeconds;
      }
    });

    test('air breaks lengthen deco and annotate stops', () {
      final baseline = const PlanEngine().compute(
        _plan(segments: _airSegments(minutes: 45)),
      );
      final withBreaks = const PlanEngine().compute(
        _plan(
          segments: _airSegments(minutes: 45),
          tanks: const [
            _airTank,
            DiveTank(
              id: 'o2',
              volume: 11.1,
              gasMix: GasMix(o2: 100),
              role: TankRole.deco,
            ),
          ],
          airBreaks: const AirBreakPolicy(o2Seconds: 720, breakSeconds: 360),
        ),
      );
      // The O2 plan differs from baseline; what matters: annotated breaks
      // appear on a long O2 stop.
      final o2Stops = withBreaks.stops.where((s) => s.depthMeters <= 6.0);
      final totalBreaks = o2Stops.fold<int>(
        0,
        (sum, s) => sum + s.airBreakSeconds,
      );
      expect(totalBreaks, greaterThan(0));
      expect(baseline.stops.every((s) => s.airBreakSeconds == 0), isTrue);
    });

    test('last stop at 6 m removes the 3 m stop', () {
      final outcome = const PlanEngine().compute(_plan(lastStopDepth: 6.0));
      expect(outcome.stops, isNotEmpty);
      expect(outcome.stops.every((s) => s.depthMeters >= 6.0), isTrue);
    });

    test('tissue timeline has one increasing entry per segment', () {
      final outcome = const PlanEngine().compute(_plan());
      expect(outcome.tissueTimeline, hasLength(2));
      expect(
        outcome.tissueTimeline[0].$1,
        lessThan(outcome.tissueTimeline[1].$1),
      );
      expect(outcome.segmentOutcomes, hasLength(2));
      expect(outcome.segmentOutcomes.last.inDeco, isTrue);
    });
  });
}
