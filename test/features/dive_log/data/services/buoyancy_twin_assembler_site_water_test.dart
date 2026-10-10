import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// A dive with no water type of its own is modelled in its site's water, as
/// `Dive.effectiveWaterType` reads it everywhere else (issue #3196).
void main() {
  final model = WeightPredictionEngine.fit(
    observations: const [],
    gearById: (_) => null,
    bodyWeightKg: 75,
  );

  Dive dive({WaterType? own, WaterType? site}) => Dive(
    id: 'd1',
    dateTime: DateTime(2024, 1, 1),
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 11.0,
        workingPressure: 207,
        startPressure: 200,
        endPressure: 50,
        gasMix: GasMix(o2: 21),
      ),
    ],
    gear: looseGear(const []),
    waterType: own,
    site: DiveSite(id: 's1', name: 'Quarry', waterType: site),
  );

  double density(Dive d) => BuoyancyTwinAssembler.assemble(
    dive: d,
    tankPressures: const {},
    model: model,
    bodyWeightKg: 75,
  )!.environment.waterDensityKgM3;

  test('uses the site water type when the dive has none', () {
    expect(
      density(dive(site: WaterType.fresh)),
      DiveEnvironment.freshWaterDensity,
    );
  });

  test('the dive own water type wins over the site one', () {
    expect(
      density(dive(own: WaterType.salt, site: WaterType.fresh)),
      DiveEnvironment.saltWaterDensity,
    );
  });
}
