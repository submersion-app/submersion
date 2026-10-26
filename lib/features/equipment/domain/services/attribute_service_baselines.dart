import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// The catalog date attributes that record a service, keyed by attribute
/// key, valued by the service kind whose clock counts from them (issue
/// #3662). The v317 backfill mirrors this mapping in SQL.
const Map<String, String> kAttributeServiceKinds = {
  EquipmentAttrKeys.lastVisualInspection: 'vip',
  EquipmentAttrKeys.lastHydroTest: 'hydro',
};

/// The clock baselines a save of [current] sets, keyed by service kind id:
/// each [kAttributeServiceKinds] date present in [current] and absent from
/// or different in [previous] (the item's attributes before the save).
///
/// A date left unchanged or cleared sets nothing, so re-saving an item
/// never undoes a baseline the diver moved since from the clock's dialog.
Map<String, DateTime> attributeServiceBaselines({
  required Iterable<EquipmentAttribute> current,
  Iterable<EquipmentAttribute> previous = const [],
}) {
  double? dateOf(Iterable<EquipmentAttribute> attributes, String key) =>
      attributes
          .where((a) => !a.isCustom && a.key == key)
          .firstOrNull
          ?.valueNum;

  return {
    for (final MapEntry(key: attrKey, value: kindId)
        in kAttributeServiceKinds.entries)
      if (dateOf(current, attrKey) case final ms?
          when ms != dateOf(previous, attrKey))
        kindId: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
  };
}
