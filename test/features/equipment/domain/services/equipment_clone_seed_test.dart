import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_clone_seed.dart';

/// The form a clone starts from (issue #3184).
void main() {
  final source = EquipmentItem(
    id: 'src',
    diverId: 'owner',
    name: 'Cell A',
    type: EquipmentType.o2Cell,
    brand: 'Vandagraph',
    model: 'R22D',
    serialNumber: 'SN-1',
    purchaseDate: DateTime(2026, 3, 1),
    purchasePrice: 120,
    purchaseCurrency: 'EUR',
    lastServiceDate: DateTime(2026, 4, 1),
    serviceIntervalDays: 365,
    notes: 'spare',
    attributes: const [
      EquipmentAttribute(
        id: 'src|cell_slot',
        equipmentId: 'src',
        key: EquipmentAttrKeys.cellSlot,
        valueNum: 2,
      ),
      EquipmentAttribute(
        id: 'src|installed_date',
        equipmentId: 'src',
        key: EquipmentAttrKeys.installedDate,
        valueNum: 1,
      ),
      EquipmentAttribute(
        id: 'src|size',
        equipmentId: 'src',
        key: EquipmentAttrKeys.size,
        valueText: 'M',
      ),
      EquipmentAttribute(
        id: 'custom-1',
        equipmentId: 'src',
        key: 'Batch',
        valueText: 'B7',
        isCustom: true,
        sortOrder: 0,
      ),
      // A custom field that happens to share a curated key is the diver's
      // own data, not the per-item attribute, so it is kept.
      EquipmentAttribute(
        id: 'custom-2',
        equipmentId: 'src',
        key: EquipmentAttrKeys.cellSlot,
        valueText: 'kept',
        isCustom: true,
        sortOrder: 1,
      ),
    ],
    customReminderEnabled: true,
    customReminderDays: const [7],
    parentEquipmentId: 'rebreather',
    createdAt: DateTime(2026, 3, 1),
  );

  final seed = cloneFormSeed(source, copyName: (n) => '$n (copy)');

  test('names the clone with the copy pattern', () {
    expect(seed.name, 'Cell A (copy)');
  });

  test('starts with no id, owner, serial, creation or legacy service', () {
    expect(seed.id, '');
    expect(seed.diverId, isNull);
    expect(seed.serialNumber, isNull);
    expect(seed.createdAt, isNull);
    expect(seed.lastServiceDate, isNull);
    expect(seed.serviceIntervalDays, isNull);
  });

  test('drops the cell slot and install date, keeps every other attribute', () {
    expect(
      [for (final a in seed.attributes) (a.key, a.isCustom, a.value)],
      [
        (EquipmentAttrKeys.size, false, 'M'),
        ('Batch', true, 'B7'),
        (EquipmentAttrKeys.cellSlot, true, 'kept'),
      ],
    );
  });

  test('no attribute keeps a row of the source', () {
    // saveAttributes upserts a custom field by its id: a source id here would
    // move the original's custom field onto the clone instead of copying it.
    final sourceIds = {for (final a in source.attributes) a.id};
    for (final a in seed.attributes) {
      expect(a.equipmentId, '', reason: a.key);
      expect(sourceIds, isNot(contains(a.id)), reason: a.key);
    }
    final custom = [
      for (final a in seed.attributes)
        if (a.isCustom) a.id,
    ];
    expect(custom, everyElement(isNotEmpty));
    expect(custom.toSet(), hasLength(custom.length));
  });

  test('copies the rest of the form as-is', () {
    expect(seed.type, source.type);
    expect(seed.brand, source.brand);
    expect(seed.model, source.model);
    expect(seed.status, source.status);
    expect(seed.isActive, source.isActive);
    expect(seed.purchaseDate, source.purchaseDate);
    expect(seed.purchasePrice, source.purchasePrice);
    expect(seed.purchaseCurrency, source.purchaseCurrency);
    expect(seed.notes, source.notes);
    expect(seed.customReminderEnabled, isTrue);
    expect(seed.customReminderDays, [7]);
    expect(seed.parentEquipmentId, 'rebreather');
  });
}

extension on EquipmentAttribute {
  Object? get value => valueText ?? valueNum;
}
