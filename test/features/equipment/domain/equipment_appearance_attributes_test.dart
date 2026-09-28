import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';

void main() {
  const excluded = {
    EquipmentType.o2Cell,
    EquipmentType.battery,
    EquipmentType.other,
  };

  test('every type but cells, batteries and other has a colour', () {
    for (final type in EquipmentType.values) {
      final keys = EquipmentAttributeCatalog.attributesFor(
        type,
      ).map((d) => d.key);
      expect(
        keys.contains(EquipmentAttrKeys.color),
        !excluded.contains(type),
        reason: type.name,
      );
    }
  });

  test('the colour is its own kind in its own group', () {
    final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.color)!;
    expect(def.kind, AttributeKind.color);
    expect(def.group, AttributeGroup.appearance);
    expect(def.choiceKeys, isEmpty);
  });

  test('the figure reads the same key', () {
    expect(kFigureColorAttribute, EquipmentAttrKeys.color);
  });
}
