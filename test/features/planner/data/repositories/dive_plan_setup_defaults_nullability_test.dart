import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../../helpers/test_database.dart';

/// Every Setup-accordion field made nullable for issue #3552 (Deco/Rates,
/// Gas, Contingency) round-trips through the repository as a genuine SQL
/// NULL, not a silently-reapplied default - the behaviour the whole feature
/// depends on.
void main() {
  late DivePlanRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DivePlanRepository();
  });

  tearDown(tearDownTestDatabase);

  test('an unset plan persists every Setup field as null', () async {
    final t = DateTime(2026, 1, 1);
    final plan = DivePlan(
      id: 'p1',
      name: 'Unset',
      createdAt: t,
      updatedAt: t,
      gfLow: 30,
      gfHigh: 70,
      // Every field in scope left at its nullable default.
    );
    await repo.savePlan(plan);
    final read = await repo.getPlan('p1');

    expect(read, isNotNull);
    expect(read!.descentRate, isNull);
    expect(read.ascentRate, isNull);
    expect(read.intermediateAscentRate, isNull);
    expect(read.shallowAscentRate, isNull);
    expect(read.finalAscentRate, isNull);
    expect(read.lastStopDepth, isNull);
    expect(read.gasSwitchStopSeconds, isNull);
    expect(read.sacBottom, isNull);
    expect(read.sacDeco, isNull);
    expect(read.sacStressed, isNull);
    expect(read.sacFactor, isNull);
    expect(read.problemSolvingMinutes, isNull);
    expect(read.bestMixEndMeters, isNull);
    expect(read.deviationDepthDelta, isNull);
    expect(read.deviationTimeMinutes, isNull);
  });

  test('a plan with every Setup field overridden round-trips the concrete '
      'values unchanged', () async {
    final t = DateTime(2026, 1, 1);
    final plan = DivePlan(
      id: 'p2',
      name: 'Overridden',
      createdAt: t,
      updatedAt: t,
      gfLow: 30,
      gfHigh: 70,
      descentRate: 20.0,
      ascentRate: 10.0,
      intermediateAscentRate: 7.0,
      shallowAscentRate: 4.0,
      finalAscentRate: 2.0,
      lastStopDepth: 6.0,
      gasSwitchStopSeconds: 30,
      sacBottom: 18.0,
      sacDeco: 16.0,
      sacStressed: 45.0,
      sacFactor: 2.5,
      problemSolvingMinutes: 3,
      bestMixEndMeters: 33.0,
      deviationDepthDelta: 6.0,
      deviationTimeMinutes: 7,
    );
    await repo.savePlan(plan);
    final read = await repo.getPlan('p2');

    expect(read, isNotNull);
    expect(read!.descentRate, 20.0);
    expect(read.ascentRate, 10.0);
    expect(read.intermediateAscentRate, 7.0);
    expect(read.shallowAscentRate, 4.0);
    expect(read.finalAscentRate, 2.0);
    expect(read.lastStopDepth, 6.0);
    expect(read.gasSwitchStopSeconds, 30);
    expect(read.sacBottom, 18.0);
    expect(read.sacDeco, 16.0);
    expect(read.sacStressed, 45.0);
    expect(read.sacFactor, 2.5);
    expect(read.problemSolvingMinutes, 3);
    expect(read.bestMixEndMeters, 33.0);
    expect(read.deviationDepthDelta, 6.0);
    expect(read.deviationTimeMinutes, 7);
  });

  test(
    'clearing an override back to null persists as null, not the old value',
    () async {
      final t = DateTime(2026, 1, 1);
      final plan = DivePlan(
        id: 'p3',
        name: 'Cleared',
        createdAt: t,
        updatedAt: t,
        gfLow: 30,
        gfHigh: 70,
        descentRate: 20.0,
        sacBottom: 18.0,
        deviationDepthDelta: 6.0,
      );
      await repo.savePlan(plan);
      final saved = await repo.getPlan('p3');

      await repo.savePlan(
        saved!.copyWith(
          clearDescentRate: true,
          clearSacBottom: true,
          clearDeviationDepthDelta: true,
        ),
      );
      final read = await repo.getPlan('p3');

      expect(read!.descentRate, isNull);
      expect(read.sacBottom, isNull);
      expect(read.deviationDepthDelta, isNull);
    },
  );
}
