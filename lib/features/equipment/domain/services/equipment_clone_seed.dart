import 'package:uuid/uuid.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Curated attributes that place one physical item, so a clone starts
/// without them: two O2 cells must not claim one slot, and a clone counts
/// its parent's dives from its own creation, not the original's install.
const _perItemAttrKeys = {
  EquipmentAttrKeys.cellSlot,
  EquipmentAttrKeys.installedDate,
};

/// The item the Clone form starts from (issue #3184): [source] with no id,
/// owner or creation time (the save assigns them), the name from [copyName],
/// no serial number, none of the frozen legacy service fields, and without
/// the per-item attributes above. Everything else on the form is kept.
///
/// Every attribute leaves the source's rows behind: saveAttributes upserts a
/// custom field by its id, so a kept id would move the original's field onto
/// the clone. Custom fields get a fresh id, as the form's "Add field" gives
/// one; curated ids are derived from the item on save.
EquipmentItem cloneFormSeed(
  EquipmentItem source, {
  required String Function(String name) copyName,
}) {
  const uuid = Uuid();
  return EquipmentItem(
    id: '',
    name: copyName(source.name),
    type: source.type,
    brand: source.brand,
    model: source.model,
    status: source.status,
    purchaseDate: source.purchaseDate,
    purchasePrice: source.purchasePrice,
    purchaseCurrency: source.purchaseCurrency,
    notes: source.notes,
    isActive: source.isActive,
    attributes: [
      for (final a in source.attributes)
        if (a.isCustom || !_perItemAttrKeys.contains(a.key))
          a.copyWith(id: a.isCustom ? uuid.v4() : '', equipmentId: ''),
    ],
    customReminderEnabled: source.customReminderEnabled,
    customReminderDays: source.customReminderDays,
    parentEquipmentId: source.parentEquipmentId,
  );
}
