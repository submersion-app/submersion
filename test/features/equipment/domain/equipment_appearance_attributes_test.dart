import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
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

  test('hasColor agrees with the catalog', () {
    for (final type in EquipmentType.values) {
      expect(
        EquipmentAttributeCatalog.hasColor(type),
        !excluded.contains(type),
        reason: type.name,
      );
    }
  });

  // Issue #2520: a colour that reached a type without one.
  group('keepStrayColorAsCustom', () {
    final colour = EquipmentAttribute.curated(
      equipmentId: 'e1',
      key: EquipmentAttrKeys.color,
      valueText: '#EF4444',
    );
    const note = EquipmentAttribute(
      id: 'c1',
      equipmentId: 'e1',
      key: 'Note',
      isCustom: true,
      valueText: 'spare',
      sortOrder: 3,
    );

    test('a type with a colour keeps it as the item colour', () {
      final attrs = [colour, note];
      expect(keepStrayColorAsCustom(EquipmentType.fins, attrs), attrs);
    });

    test('a battery keeps it as a new custom field after its own', () {
      expect(keepStrayColorAsCustom(EquipmentType.battery, [colour, note]), [
        note,
        const EquipmentAttribute(
          id: '',
          equipmentId: 'e1',
          key: EquipmentAttrKeys.color,
          isCustom: true,
          valueText: '#EF4444',
          sortOrder: 4,
        ),
      ]);
    });

    test('the diver\'s own "color" field wins over the stray colour', () {
      const own = EquipmentAttribute(
        id: 'c2',
        equipmentId: 'e1',
        key: EquipmentAttrKeys.color,
        isCustom: true,
        valueText: 'Red',
      );
      expect(keepStrayColorAsCustom(EquipmentType.other, [colour, own]), [own]);
    });
  });
}
