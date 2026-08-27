import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  // The buoyancy twin, evaluated at the neutral-at-safety-stop convention the
  // static weight engine assumes, must reproduce that engine's prediction.
  // Any drift between the two engines fails here.
  test('twin at the weighting convention agrees with the static engine', () {
    const suit = GearFeature(
      id: 'suit',
      label: 'Wetsuit',
      priorKg: 3.0,
      priorStrength: 2.0,
      dryMassKg: 2.5,
    );

    // Pure-prior model (no history): predictions come entirely from priors.
    final model = WeightPredictionEngine.fit(
      observations: const [],
      gearById: (_) => null,
      bodyWeightKg: 75,
    );

    const rig = RigSpec(
      gear: [suit],
      tanks: [
        TankSpec(
          presetName: 'al80',
          volumeL: 11.0,
          workingPressureBar: 207,
          material: TankMaterial.aluminum,
        ),
      ],
      waterType: WaterType.salt,
      bodyWeightKg: 75,
    );

    final prediction = model.predict(rig);
    final lead = prediction.totalKg;

    final personal = prediction.terms.firstWhere((t) => t.label == 'personal');
    final water = prediction.terms.firstWhere((t) => t.label == 'water');
    final suitTerm = prediction.terms.firstWhere((t) => t.label == 'Wetsuit');

    final saltEnv = DiveEnvironment.forConditions(waterType: WaterType.salt);
    final input = TwinInput(
      // Single sample at the 5 m safety stop, tank at the reserve pressure.
      profile: const [TwinProfileSample(timestamp: 0, depthM: 5.0)],
      tanks: const [
        TwinTankInput(
          id: 't1',
          label: 'al80',
          presetName: 'al80',
          volumeL: 11.0,
          workingPressureBar: 207,
          material: TankMaterial.aluminum,
          o2Percent: 21,
          startPressureBar: 50,
          endPressureBar: 50,
        ),
      ],
      suit: TwinSuitInput(
        kind: TwinSuitKind.wetsuit,
        anchorKg: suitTerm.kg,
        source: suitTerm.source,
      ),
      staticTerms: [
        TwinStaticTerm(
          label: 'personal',
          kg: personal.kg,
          source: personal.source,
        ),
        TwinStaticTerm(label: 'water', kg: water.kg, source: water.source),
      ],
      leadKg: lead,
      droppableLeadKg: lead,
      environment: saltEnv,
    );

    final result = runBuoyancyTwin(input);
    // Residual is the gas-density delta (air 0.001225 vs 21/79 ~0.001220 at
    // 11 L x 50 bar ~= 0.003 kg); comfortably under the tolerance.
    expect(result.samples.single.netKg, closeTo(0.0, 0.05));
  });
}
