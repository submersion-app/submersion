import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('the identifier key keeps its stored name', () {
    // Renaming the stored key would rewrite rows on every sync peer.
    expect(EquipmentAttrKeys.identifier, 'tank_identifier');
  });

  test('identifier reads the curated attribute on any type', () {
    final pouch = EquipmentItem(
      id: 'p1',
      name: 'Pouches',
      type: EquipmentType.weights,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'p1',
          key: EquipmentAttrKeys.identifier,
          valueText: 'P2',
        ),
      ],
    );
    expect(pouch.identifier, 'P2');
  });

  test('identifier is null when unset, and ignores a custom field', () {
    const bare = EquipmentItem(
      id: 'p1',
      name: 'Pouches',
      type: EquipmentType.weights,
    );
    expect(bare.identifier, isNull);

    const custom = EquipmentItem(
      id: 'p1',
      name: 'Pouches',
      type: EquipmentType.weights,
      attributes: [
        EquipmentAttribute(
          id: 'a1',
          equipmentId: 'p1',
          key: 'tank_identifier',
          isCustom: true,
          valueText: 'mine',
        ),
      ],
    );
    expect(custom.identifier, isNull);
  });
}
