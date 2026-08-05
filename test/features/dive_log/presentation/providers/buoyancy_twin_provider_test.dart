import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

import '../../../../helpers/test_database.dart';

// Regression test for the lean-hydration gap: the twin must see the dive's
// TYPED dive_weights rows and its linked exposure suit, not just the legacy
// scalar weight. Exercises the real provider + database, not a hand-built Dive.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  ProviderContainer container() => ProviderContainer(
    overrides: [
      weightCalibrationProvider.overrideWith(
        (ref) async => WeightPredictionEngine.fit(
          observations: const [],
          gearById: (_) => null,
          bodyWeightKg: 75,
        ),
      ),
      latestDiverWeightProvider.overrideWith((ref) async => null),
    ],
  );

  test(
    'counts typed dive_weights rows and detects the exposure suit',
    () async {
      final suit = await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: '',
          name: '5mm Wetsuit',
          type: EquipmentType.wetsuit,
        ),
      );
      final dive = await DiveRepository().createDive(
        Dive(
          id: '',
          diveNumber: 1,
          dateTime: DateTime(2026, 1, 1),
          equipment: [suit],
          tanks: const [
            DiveTank(
              id: 't1',
              volume: 11,
              workingPressure: 207,
              startPressure: 200,
              endPressure: 50,
              material: TankMaterial.aluminum,
              presetName: 'al80',
            ),
          ],
          weights: const [
            DiveWeight(
              id: 'w1',
              diveId: '',
              weightType: WeightType.belt,
              amountKg: 4.0,
            ),
            DiveWeight(
              id: 'w2',
              diveId: '',
              weightType: WeightType.trimWeights,
              amountKg: 2.0,
            ),
          ],
          waterType: WaterType.salt,
        ),
      );

      final c = container();
      addTearDown(c.dispose);

      final outcome = await c.read(buoyancyTwinProvider(dive.id).future);
      expect(outcome, isNotNull);

      // Typed weights (4 + 2) are counted, not the (absent) legacy scalar.
      expect(outcome!.result.input.leadKg, closeTo(6.0, 1e-9));
      // Only the belt is ditchable; trim weights are fixed.
      expect(outcome.result.input.droppableLeadKg, closeTo(4.0, 1e-9));
      // The linked wetsuit is detected, so suit compression is modeled.
      expect(outcome.result.input.suit.kind, TwinSuitKind.wetsuit);
      // The lead term appears in the diagnosis breakdown.
      final lead = outcome.outputs.verdict.terms.firstWhere(
        (t) => t.label == 'lead',
      );
      expect(lead.kg, closeTo(-6.0, 1e-9));
    },
  );
}
