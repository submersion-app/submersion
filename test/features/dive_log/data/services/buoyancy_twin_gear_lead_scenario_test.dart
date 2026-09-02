import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// End-to-end reconstruction of the rig from issue #1103: a cold-water
/// backplate-and-wing diver whose entire ~30 lb of ballast is built into
/// weighted gear, with the dive's Weights section left empty.
///
/// Before the fix the twin saw zero lead and reported the diver 17.3 lb
/// buoyant at the final stop -- the exact figure in the bug report -- while
/// they were in fact holding a 6 ft stop on an empty wing.
void main() {
  const kgPerLb = 0.45359237;
  double lb(double kg) => kg / kgPerLb;

  EquipmentItem item(
    String id,
    String name,
    EquipmentType type, {
    double? buoyancyLb,
    double? dryWeightLb,
  }) => EquipmentItem(
    id: id,
    name: name,
    type: type,
    attributes: [
      if (buoyancyLb != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.buoyancyKg,
          valueNum: buoyancyLb * kgPerLb,
        ),
      if (dryWeightLb != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.dryWeightKg,
          valueNum: dryWeightLb * kgPerLb,
        ),
    ],
  );

  // Ballast totals -29.9 lb, of which -17.2 lb sits in weights-type gear.
  final rig = [
    item('c1', 'Shearwater Petrel 3', EquipmentType.computer),
    item(
      'bpw',
      'Weighted BPW',
      EquipmentType.bcd,
      buoyancyLb: -7.0,
      dryWeightLb: 7.0,
    ),
    item(
      'dump',
      'Dump Weights',
      EquipmentType.weights,
      buoyancyLb: -8.0,
      dryWeightLb: 8.0,
    ),
    item(
      'sta',
      'Weighted STA',
      EquipmentType.weights,
      buoyancyLb: -9.2,
      dryWeightLb: 9.2,
    ),
    item('suit', 'Santi E.Motion+', EquipmentType.drysuit),
    item(
      'harness',
      'Halcyon Vector Pro - weighted',
      EquipmentType.other,
      buoyancyLb: -5.7,
      dryWeightLb: 5.7,
    ),
  ];

  /// 55 min: descent to 20 m, bottom, ascent, then a long shallow stop.
  List<DiveProfilePoint> profile() {
    final points = <DiveProfilePoint>[];
    for (var t = 0; t <= 55 * 60; t += 20) {
      final minutes = t / 60.0;
      final double depth;
      if (minutes < 3) {
        depth = minutes / 3 * 20;
      } else if (minutes < 45) {
        depth = 20.0;
      } else if (minutes < 50) {
        depth = 20 - (minutes - 45) / 5 * 17.9;
      } else {
        depth = 2.1;
      }
      points.add(DiveProfilePoint(timestamp: t, depth: depth));
    }
    return points;
  }

  Dive dive() => Dive(
    id: 'd1',
    dateTime: DateTime(2026, 8, 1),
    waterType: WaterType.salt,
    equipment: rig,
    profile: profile(),
    tanks: [
      // AL80 run from 3000 psi down to the reported 642 psi.
      const DiveTank(
        id: 'tk1',
        volume: 11.1,
        workingPressure: 207,
        startPressure: 3000 * 0.0689476,
        endPressure: 642 * 0.0689476,
        material: TankMaterial.aluminum,
        presetName: 'al80',
        gasMix: GasMix(o2: 21),
      ),
    ],
  );

  test('gear-carried ballast makes the final stop come out near neutral', () {
    final model = WeightPredictionEngine.fit(
      observations: const [],
      gearById: (_) => null,
      bodyWeightKg: 75,
    );
    final input = BuoyancyTwinAssembler.assemble(
      dive: dive(),
      tankPressures: const {},
      model: model,
      bodyWeightKg: 75,
    )!;
    final outputs = TwinAnalyzer.analyze(runBuoyancyTwin(input));

    // The 17.2 lb of weighted gear is now lead, not nothing.
    expect(lb(input.leadKg), closeTo(17.2, 0.05));

    // Slightly heavy on a full tank, essentially neutral at the final stop:
    // the dive the reporter described, against 17.3 lb buoyant before.
    expect(lb(outputs.beginNetKg), lessThan(0.0));
    expect(lb(outputs.endNetKg).abs(), lessThan(1.0));
    expect(lb(outputs.verdict.netKg).abs(), lessThan(1.0));

    // A rig this close to neutral does demand real lift and real ditchable
    // weight; both read 0.0 while the lead was invisible.
    expect(outputs.peakLiftDemandKg, greaterThan(0.0));
    expect(outputs.minDitchableKg, greaterThan(0.0));
  });
}
