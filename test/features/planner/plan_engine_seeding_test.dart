import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/tissue_seed.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

domain.DivePlan _plan() {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Seeding test',
    gfLow: 40,
    gfHigh: 80,
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 40.0,
        tankId: 'tank-1',
        gasMix: _air,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 40.0,
        durationMinutes: 20,
        tankId: 'tank-1',
        gasMix: _air,
        order: 1,
      ),
    ],
    tanks: const [_airTank],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

/// End-of-dive compartments from a heavy prior dive (40 m for 35 min on air).
List<TissueCompartment> _priorDiveCompartments() {
  final algorithm = BuhlmannAlgorithm(gfLow: 0.40, gfHigh: 0.80);
  algorithm.calculateSegment(depthMeters: 40.0, durationSeconds: 35 * 60);
  return algorithm.compartments;
}

void main() {
  group('tissue seeding', () {
    test('null compartments produce no seed', () {
      expect(
        seededTissueState(
          compartments: null,
          surfaceInterval: const Duration(hours: 1),
          gfLow: 0.40,
          gfHigh: 0.80,
        ),
        isNull,
      );
    });

    test('a seeded repetitive plan carries more deco than a fresh one', () {
      const engine = PlanEngine();
      final fresh = engine.compute(_plan());

      final seeded = seededTissueState(
        compartments: _priorDiveCompartments(),
        surfaceInterval: const Duration(hours: 1),
        gfLow: 0.40,
        gfHigh: 0.80,
      );
      final repetitive = engine.compute(_plan(), startState: seeded);

      expect(repetitive.totalDecoSeconds, greaterThan(fresh.totalDecoSeconds));
    });

    test('a long surface interval trends back toward the fresh plan', () {
      const engine = PlanEngine();
      final fresh = engine.compute(_plan());

      final compartments = _priorDiveCompartments();
      final shortInterval = engine.compute(
        _plan(),
        startState: seededTissueState(
          compartments: compartments,
          surfaceInterval: const Duration(hours: 1),
          gfLow: 0.40,
          gfHigh: 0.80,
        ),
      );
      final longInterval = engine.compute(
        _plan(),
        startState: seededTissueState(
          compartments: compartments,
          surfaceInterval: const Duration(hours: 24),
          gfLow: 0.40,
          gfHigh: 0.80,
        ),
      );

      expect(
        longInterval.totalDecoSeconds,
        lessThan(shortInterval.totalDecoSeconds),
      );
      // After a day at the surface the tissues are essentially clean again.
      expect(
        (longInterval.totalDecoSeconds - fresh.totalDecoSeconds).abs(),
        lessThanOrEqualTo(60),
      );
    });
  });
}
