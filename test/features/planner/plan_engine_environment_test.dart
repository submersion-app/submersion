import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

domain.DivePlan _plan({double? altitude, WaterType? waterType}) =>
    domain.DivePlan(
      id: 'plan-1',
      name: 'Environment',
      gfLow: 40,
      gfHigh: 80,
      altitude: altitude,
      waterType: waterType,
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 25),
    );

void main() {
  test('an unset or zero altitude keeps the legacy 1.0 bar surface', () {
    for (final altitude in [null, 0.0, -10.0]) {
      expect(
        PlanEngine.environmentFor(_plan(altitude: altitude)),
        DiveEnvironment.forConditions(
          altitudeMeters: null,
          waterType: WaterType.salt,
        ),
        reason: '$altitude',
      );
    }
  });

  test('a positive altitude lowers the surface pressure', () {
    final environment = PlanEngine.environmentFor(_plan(altitude: 1500));
    expect(environment.surfacePressureBar, lessThan(1.0));
  });

  test('an unset water type is salt; a set one is honoured', () {
    expect(
      PlanEngine.environmentFor(_plan()).waterDensityKgM3,
      DiveEnvironment.saltWaterDensity,
    );
    expect(
      PlanEngine.environmentFor(
        _plan(waterType: WaterType.fresh),
      ).waterDensityKgM3,
      DiveEnvironment.freshWaterDensity,
    );
  });
}
