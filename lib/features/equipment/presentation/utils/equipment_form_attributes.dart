import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// The attributes the equipment edit form writes on save.
///
/// Only attributes in [type]'s catalog are kept: switching type drops
/// out-of-catalog values at save time (form = source of truth). Then come
/// the non-empty custom fields, de-duped by trimmed key: the schema enforces
/// UNIQUE(equipment_id, attr_key, is_custom), so two custom fields sharing a
/// label would fail the insert. First occurrence wins; sort order is
/// re-packed to the surviving order.
List<EquipmentAttribute> equipmentAttributesToSave({
  required EquipmentType type,
  required Map<String, EquipmentAttribute> values,
  required List<EquipmentAttribute> customFields,
}) {
  final customAttributes = <EquipmentAttribute>[];
  final seenCustomKeys = <String>{};
  for (final field in customFields) {
    final key = field.key.trim();
    if (key.isEmpty || !field.hasValue) continue;
    if (!seenCustomKeys.add(key)) continue;
    customAttributes.add(
      field.copyWith(key: key, sortOrder: customAttributes.length),
    );
  }
  return [
    for (final def in EquipmentAttributeCatalog.attributesFor(type))
      if (values[def.key] case final attr? when attr.hasValue) attr,
    ...customAttributes,
  ];
}
