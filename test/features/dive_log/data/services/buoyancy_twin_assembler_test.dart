import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  FittedWeightModel emptyModel() => WeightPredictionEngine.fit(
    observations: const [],
    gearById: (_) => null,
    bodyWeightKg: 75,
  );

  // 5 mm signal lives in the name; gear_feature parses thickness from the name
  // when no thickness attribute is present (thickness is a curated attribute
  // in the equipment-attributes model, not a scalar field).
  const wetsuit = EquipmentItem(
    id: 'suit1',
    name: 'Wetsuit 5mm',
    type: EquipmentType.wetsuit,
  );
  const drysuit = EquipmentItem(
    id: 'dry1',
    name: 'Drysuit',
    type: EquipmentType.drysuit,
  );
  const mask = EquipmentItem(
    id: 'mask1',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  DiveTank tank(String id) => DiveTank(
    id: id,
    volume: 11.0,
    workingPressure: 207,
    startPressure: 200,
    endPressure: 50,
    material: TankMaterial.aluminum,
    presetName: 'al80',
    gasMix: const GasMix(o2: 21),
  );

  Dive diveWith({
    List<DiveTank> tanks = const [],
    List<EquipmentItem> equipment = const [],
    List<DiveWeight> weights = const [],
    double? weightAmount,
    WeightType? weightType,
  }) => Dive(
    id: 'd1',
    dateTime: DateTime(2024, 1, 1),
    tanks: tanks,
    equipment: equipment,
    weights: weights,
    weightAmount: weightAmount,
    weightType: weightType,
    waterType: WaterType.salt,
  );

  group('BuoyancyTwinAssembler.assemble', () {
    test('assembles lead, droppable lead, suit, and static terms', () {
      final input = BuoyancyTwinAssembler.assemble(
        dive: diveWith(
          tanks: [tank('t1'), tank('t2')],
          equipment: [wetsuit],
          weights: const [
            DiveWeight(
              id: 'w1',
              diveId: 'd1',
              weightType: WeightType.belt,
              amountKg: 4.0,
            ),
            DiveWeight(
              id: 'w2',
              diveId: 'd1',
              weightType: WeightType.trimWeights,
              amountKg: 2.0,
            ),
          ],
        ),
        tankPressures: const {},
        model: emptyModel(),
        bodyWeightKg: 75,
      );

      expect(input, isNotNull);
      expect(input!.leadKg, closeTo(6.0, 1e-9));
      expect(input.droppableLeadKg, closeTo(4.0, 1e-9)); // belt only
      expect(input.tanks.length, 2);
      expect(input.tanks.first.pressureSeries, isNull);
      expect(input.suit.kind, TwinSuitKind.wetsuit);
      expect(input.suit.anchorKg, closeTo(5.0, 1e-9)); // 5 mm type prior
      expect(input.staticTerms.any((t) => t.label == 'personal'), isTrue);
      expect(input.staticTerms.any((t) => t.label == 'water'), isTrue);
    });

    test('unnamed tank falls back to the localizable "tank" key', () {
      // A tank with neither a preset nor a user name must not carry a
      // hardcoded English 'Tank' label (which would leak into localized UIs);
      // it uses the 'tank' key that the breakdown widget localizes.
      final input = BuoyancyTwinAssembler.assemble(
        dive: diveWith(
          tanks: const [
            DiveTank(
              id: 't1',
              volume: 11.0,
              workingPressure: 207,
              startPressure: 200,
              endPressure: 50,
              material: TankMaterial.aluminum,
              gasMix: GasMix(o2: 21),
            ),
          ],
          equipment: [wetsuit],
        ),
        tankPressures: const {},
        model: emptyModel(),
        bodyWeightKg: 75,
      );

      expect(input!.tanks.single.label, 'tank');
    });

    test('returns null when there is nothing to model', () {
      final input = BuoyancyTwinAssembler.assemble(
        dive: diveWith(equipment: [mask]),
        tankPressures: const {},
        model: emptyModel(),
        bodyWeightKg: 75,
      );
      expect(input, isNull);
    });

    test('maps a drysuit to the drysuit suit kind', () {
      final input = BuoyancyTwinAssembler.assemble(
        dive: diveWith(tanks: [tank('t1')], equipment: [drysuit]),
        tankPressures: const {},
        model: emptyModel(),
        bodyWeightKg: 75,
      );
      expect(input!.suit.kind, TwinSuitKind.drysuit);
    });

    test('falls back to the legacy scalar weight when no rows exist', () {
      final input = BuoyancyTwinAssembler.assemble(
        dive: diveWith(
          tanks: [tank('t1')],
          equipment: [wetsuit],
          weightAmount: 7.0,
          weightType: WeightType.integrated,
        ),
        tankPressures: const {},
        model: emptyModel(),
        bodyWeightKg: 75,
      );
      expect(input!.leadKg, closeTo(7.0, 1e-9));
      expect(
        input.droppableLeadKg,
        closeTo(7.0, 1e-9),
      ); // integrated is droppable
    });

    test('maps measured tank pressures into a series', () {
      final input = BuoyancyTwinAssembler.assemble(
        dive: diveWith(tanks: [tank('t1')], equipment: [wetsuit]),
        tankPressures: const {
          't1': [
            TankPressurePoint(
              id: 'p1',
              tankId: 't1',
              timestamp: 0,
              pressure: 200,
            ),
            TankPressurePoint(
              id: 'p2',
              tankId: 't1',
              timestamp: 600,
              pressure: 80,
            ),
          ],
        },
        model: emptyModel(),
        bodyWeightKg: 75,
      );
      expect(input!.tanks.first.pressureSeries, isNotNull);
      expect(input.tanks.first.pressureSeries!.length, 2);
    });
  });

  group('BuoyancyTwinAssembler.droppableLeadKg', () {
    test('sums only belt and integrated rows', () {
      final dive = diveWith(
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: 'd1',
            weightType: WeightType.integrated,
            amountKg: 5.0,
          ),
          DiveWeight(
            id: 'w2',
            diveId: 'd1',
            weightType: WeightType.backplate,
            amountKg: 3.0,
          ),
        ],
      );
      expect(BuoyancyTwinAssembler.droppableLeadKg(dive), closeTo(5.0, 1e-9));
    });
  });

  group('BuoyancyTwinAssembler.droppableLeadFromPlacement', () {
    test('counts only belt and integrated placements', () {
      final droppable = BuoyancyTwinAssembler.droppableLeadFromPlacement({
        WeightType.belt.name: 4.0,
        WeightType.integrated.name: 2.0,
        WeightType.backplate.name: 3.0,
        WeightType.trimWeights.name: 1.0,
      });
      expect(droppable, closeTo(6.0, 1e-9)); // belt + integrated only
    });

    test('ignores unrecognized placement keys', () {
      final droppable = BuoyancyTwinAssembler.droppableLeadFromPlacement({
        WeightType.belt.name: 5.0,
        'nonsense': 10.0,
      });
      expect(droppable, closeTo(5.0, 1e-9));
    });
  });
}
