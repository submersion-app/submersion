import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';

void main() {
  EquipmentItem weights(
    String id, {
    double? dryWeightKg,
    double? buoyancyKg,
    String? style,
    EquipmentType type = EquipmentType.weights,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: type,
    attributes: [
      if (dryWeightKg != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.dryWeightKg,
          valueNum: dryWeightKg,
        ),
      if (buoyancyKg != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.buoyancyKg,
          valueNum: buoyancyKg,
        ),
      if (style != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.weightStyle,
          valueText: style,
        ),
    ],
  );

  group('ballastKg', () {
    test('prefers dry weight over buoyancy', () {
      expect(EquipmentLead.ballastKg(dryWeightKg: 3.6, buoyancyKg: -3.2), 3.6);
    });

    test('falls back to negated buoyancy when dry weight is absent', () {
      expect(EquipmentLead.ballastKg(dryWeightKg: null, buoyancyKg: -3.2), 3.2);
    });

    test('ignores a positive buoyancy: lead never floats', () {
      expect(EquipmentLead.ballastKg(dryWeightKg: null, buoyancyKg: 3.2), 0.0);
    });

    test('ignores a non-positive dry weight and falls through', () {
      expect(EquipmentLead.ballastKg(dryWeightKg: 0, buoyancyKg: -2.0), 2.0);
      expect(EquipmentLead.ballastKg(dryWeightKg: -1, buoyancyKg: -2.0), 2.0);
    });

    test('treats non-finite user numbers as absent', () {
      // Numeric attributes parse with double.tryParse, which accepts 1e309.
      expect(
        EquipmentLead.ballastKg(dryWeightKg: double.infinity, buoyancyKg: -2.0),
        2.0,
      );
      expect(
        EquipmentLead.ballastKg(dryWeightKg: null, buoyancyKg: double.nan),
        0.0,
      );
    });

    test('is zero when the item declares nothing', () {
      expect(EquipmentLead.ballastKg(dryWeightKg: null, buoyancyKg: null), 0.0);
    });
  });

  group('kgFor / totalKg', () {
    test('counts only weights-type gear', () {
      final bcd = weights(
        'bpw',
        dryWeightKg: 3.2,
        buoyancyKg: -3.2,
        type: EquipmentType.bcd,
      );
      expect(EquipmentLead.kgFor(bcd), 0.0);
      expect(EquipmentLead.totalKg([bcd]), 0.0);
    });

    test('sums declared ballast across weights gear', () {
      expect(
        EquipmentLead.totalKg([
          weights('dump', dryWeightKg: 3.63),
          weights('sta', buoyancyKg: -4.17),
          weights('unspecified'),
        ]),
        closeTo(7.8, 0.001),
      );
    });

    test('a weights item with no numbers contributes nothing', () {
      expect(EquipmentLead.totalKg([weights('belt')]), 0.0);
    });
  });

  group('placement', () {
    test('maps catalog styles onto weight types', () {
      expect(EquipmentLead.placementFor('belt'), WeightType.belt);
      expect(EquipmentLead.placementFor('integrated'), WeightType.integrated);
      expect(EquipmentLead.placementFor('trim'), WeightType.trimWeights);
      expect(EquipmentLead.placementFor('ankle'), WeightType.ankleWeights);
    });

    test('unset and future catalog values resolve to null', () {
      expect(EquipmentLead.placementFor(null), isNull);
      expect(EquipmentLead.placementFor('harness_pocket'), isNull);
    });

    test('only belt and integrated ballast counts as droppable', () {
      final rig = [
        weights('dump', dryWeightKg: 3.63, style: 'belt'),
        weights('pocket', dryWeightKg: 2.0, style: 'integrated'),
        weights('trim', dryWeightKg: 1.0, style: 'trim'),
      ];
      expect(EquipmentLead.droppableKg(rig), closeTo(5.63, 0.001));
    });

    test('unstyled ballast counts as fixed, not droppable', () {
      // Understating what the diver can ditch is the safe error; the twin's
      // min-ditchable warning would otherwise go quiet on a guess.
      expect(
        EquipmentLead.droppableKg([weights('sta', dryWeightKg: 4.0)]),
        0.0,
      );
    });

    test('placementKg groups by weight type and omits unplaced ballast', () {
      final rig = [
        weights('a', dryWeightKg: 2.0, style: 'belt'),
        weights('b', dryWeightKg: 1.5, style: 'belt'),
        weights('c', dryWeightKg: 4.0),
      ];
      expect(EquipmentLead.placementKg(rig), {'belt': 3.5});
    });
  });
}
