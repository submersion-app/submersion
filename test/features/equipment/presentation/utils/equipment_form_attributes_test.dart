import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_form_attributes.dart';

EquipmentAttribute _curated(String key, {String? text, double? num}) =>
    EquipmentAttribute.curated(
      equipmentId: 'eq',
      key: key,
      valueText: text,
      valueNum: num,
    );

EquipmentAttribute _custom(String id, String key, String? text, int order) =>
    EquipmentAttribute(
      id: id,
      equipmentId: 'eq',
      key: key,
      isCustom: true,
      valueText: text,
      sortOrder: order,
    );

void main() {
  group('equipmentAttributesToSave', () {
    test('keeps curated values in catalog order, dropping empty ones', () {
      final saved = equipmentAttributesToSave(
        type: EquipmentType.regulator,
        values: {
          EquipmentAttrKeys.sku: _curated(EquipmentAttrKeys.sku, text: 'A1'),
          EquipmentAttrKeys.buoyancyKg: _curated(
            EquipmentAttrKeys.buoyancyKg,
            num: 1.5,
          ),
          EquipmentAttrKeys.retailer: _curated(
            EquipmentAttrKeys.retailer,
            text: '  ',
          ),
        },
        customFields: const [],
      );

      // Universal (buoyancy) comes before the purchase record (sku).
      expect(saved.map((a) => a.key), [
        EquipmentAttrKeys.buoyancyKg,
        EquipmentAttrKeys.sku,
      ]);
    });

    test('drops values outside the selected type\'s catalog', () {
      // A volume belongs to tanks; a regulator saved with one drops it.
      final saved = equipmentAttributesToSave(
        type: EquipmentType.regulator,
        values: {
          EquipmentAttrKeys.volumeL: _curated(
            EquipmentAttrKeys.volumeL,
            num: 12,
          ),
        },
        customFields: const [],
      );

      expect(saved, isEmpty);
    });

    test('de-dupes custom fields by trimmed key and re-packs sort order', () {
      final saved = equipmentAttributesToSave(
        type: EquipmentType.regulator,
        values: const {},
        customFields: [
          _custom('c1', ' Colour ', 'red', 5),
          _custom('c2', '', 'orphan', 6),
          _custom('c3', 'Colour', 'blue', 7),
          _custom('c4', 'Notes', null, 8),
          _custom('c5', 'Hose', 'long', 9),
        ],
      );

      expect(saved.map((a) => (a.id, a.key, a.valueText, a.sortOrder)), [
        ('c1', 'Colour', 'red', 0),
        ('c5', 'Hose', 'long', 1),
      ]);
    });
  });
}
