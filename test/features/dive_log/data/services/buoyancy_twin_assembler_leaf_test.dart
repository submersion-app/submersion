import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// An assembly whose parts are on the dive declares nothing itself: the
/// parts carry the mass and lift (issue #1487), so a BCD assembly with its
/// wing attached is counted once, not twice.
void main() {
  EquipmentItem withMass(String id, EquipmentType type, double kg) =>
      EquipmentItem(
        id: id,
        name: id,
        type: type,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: id,
            key: EquipmentAttrKeys.dryWeightKg,
            valueNum: kg,
          ),
        ],
      );
  final model = WeightPredictionEngine.fit(
    observations: const [],
    gearById: (_) => null,
  );

  test('a rolled-up assembly contributes no term and no mass of its own', () {
    final bcd = withMass('bcd', EquipmentType.bcd, 3.0);
    final wing = withMass('wing', EquipmentType.wing, 2.0);
    RigTerms compose(Set<String> rolledUpIds) =>
        BuoyancyTwinAssembler.composeRigTerms(
          items: [bcd, wing],
          tanks: const [],
          model: model,
          waterType: WaterType.salt,
          bodyWeightKg: 80,
          rolledUpIds: rolledUpIds,
        );

    final flat = compose(const {});
    final rolled = compose(const {'bcd'});

    expect(flat.staticTerms.length - rolled.staticTerms.length, 1);
    expect(flat.totalMassKg - rolled.totalMassKg, closeTo(3.0, 1e-9));
  });
}
