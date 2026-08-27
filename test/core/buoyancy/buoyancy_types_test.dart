// Deliberately non-const: two identical const expressions canonicalize to a
// single instance, so == short-circuits on identity and the Equatable props
// under test are never evaluated.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/ridge_regression.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';

/// Value-equality and branch coverage for the buoyancy value types.
void main() {
  group('value equality', () {
    // Note: both operands must be RUNTIME instances. Two identical const
    // expressions canonicalize to one object and == short-circuits on
    // identity without ever evaluating props.
    ObservedTank tank() => ObservedTank(
      volumeL: 11.1,
      workingPressureBar: 207,
      material: TankMaterial.aluminum,
      presetName: 'al80',
    );

    test('ObservedTank compares by value', () {
      expect(tank(), tank());
      expect(tank(), isNot(const ObservedTank(volumeL: 12.0)));
    });

    test('ObservedTank and WeightObservation compare by value', () {
      final a = WeightObservation(
        diveId: 'd1',
        diveDateTime: DateTime(2026, 1, 1),
        waterType: WaterType.salt,
        carriedKg: 8.0,
        placement: const {'integrated': 8.0},
        equipmentIds: const ['suit'],
        tanks: [tank()],
        feedback: 'correct',
        feedbackKg: 1.0,
      );
      final b = WeightObservation(
        diveId: 'd1',
        diveDateTime: DateTime(2026, 1, 1),
        waterType: WaterType.salt,
        carriedKg: 8.0,
        placement: const {'integrated': 8.0},
        equipmentIds: const ['suit'],
        tanks: [tank()],
        feedback: 'correct',
        feedbackKg: 1.0,
      );
      expect(a, b);
      expect(
        a,
        isNot(
          WeightObservation(
            diveId: 'd2',
            diveDateTime: DateTime(2026, 1, 1),
            carriedKg: 8.0,
          ),
        ),
      );
    });

    test('GearFeature, TankSpec, RigSpec, and prediction types compare by '
        'value', () {
      GearFeature feature() => GearFeature(
        id: 'suit',
        label: 'Suit',
        priorKg: 5.0,
        priorStrength: 2.0,
        dryMassKg: 2.0,
      );
      expect(feature(), feature());

      TankSpec spec() => TankSpec(presetName: 'al80', volumeL: 11.1);
      expect(spec(), spec());

      RigSpec rig() =>
          RigSpec(gear: [feature()], tanks: [spec()], bodyWeightKg: 80);
      expect(rig(), rig());

      PredictionTerm term() =>
          PredictionTerm(label: 'Suit', kg: 5.0, source: TermSource.measured);
      expect(term(), term());

      WeightPrediction prediction() => WeightPrediction(
        totalKg: 8.0,
        terms: [term()],
        confidence: PredictionConfidence.high,
        supportingDives: 10,
      );
      expect(prediction(), prediction());
    });
  });

  group('physics fallback branches', () {
    test('carbon fiber uses its per-liter fallback', () {
      final term = BuoyancyPhysics.tankTermKg(
        volumeL: 10.0,
        material: TankMaterial.carbonFiber,
      );
      // 10*0.30 - 10*50*0.001225 = 3.0 - 0.6125
      expect(term, closeTo(2.3875, 0.001));
    });

    test('catalog preset resolves its own volume when none is given', () {
      final withVolume = BuoyancyPhysics.tankTermKg(
        presetName: 'al80',
        volumeL: 11.1,
      );
      final withoutVolume = BuoyancyPhysics.tankTermKg(presetName: 'al80');
      expect(withoutVolume, closeTo(withVolume, 0.001));
    });

    test('unknown preset name falls through to the material estimate', () {
      final term = BuoyancyPhysics.tankTermKg(
        presetName: 'mystery-tank',
        volumeL: 12.0,
        material: TankMaterial.steel,
      );
      expect(term, closeTo(-2.175, 0.001));
    });
  });

  group('ridge regression edge branches', () {
    test('partial pivoting swaps rows when a later row has the larger '
        'pivot', () {
      // Single observation [0.001, 1.0] makes A[1][0] >> A[0][0].
      final b = RidgeRegression.solve(
        x: const [
          [0.001, 1.0],
        ],
        y: const [1.0],
        weights: const [1.0],
        prior: const [0.0, 0.0],
        lambda: const [1e-9, 1e-9],
      );
      final reproduced = 0.001 * b[0] + 1.0 * b[1];
      expect(reproduced, closeTo(1.0, 1e-3));
    });

    test('zero lambda on an empty system trips the singular guard', () {
      expect(
        () => RidgeRegression.solve(
          x: const [],
          y: const [],
          weights: const [],
          prior: const [0.0, 0.0],
          lambda: const [0.0, 0.0],
        ),
        throwsStateError,
      );
    });
  });
}
