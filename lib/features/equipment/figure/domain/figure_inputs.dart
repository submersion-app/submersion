import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';

/// Turns equipment entities into composer inputs, in the same order.
///
/// A child is an item with a parent link or one that is a part of an
/// assembly in [components]. Custom attributes are dropped: the figure reads
/// only catalog keys.
List<FigureItemInput> figureInputsFromItems(
  List<EquipmentItem> items, {
  ComponentsIndex components = ComponentsIndex.empty,
}) {
  return [
    for (final item in items)
      FigureItemInput(
        id: item.id,
        type: item.type,
        name: item.name,
        attributes: figureAttributesOf(item),
        isChild:
            item.parentEquipmentId != null ||
            components.parentIdsOf(item.id).isNotEmpty,
      ),
  ];
}

/// An item's catalog attribute values by key: choice keys, its colour, and
/// flags as `'true'` or `'false'` (a flag stores 1 or 0 in `valueNum`, so a
/// vest's hood switch would otherwise reach the figure as null).
/// Custom attributes are dropped; the figure reads only catalog keys.
Map<String, String?> figureAttributesOf(EquipmentItem item) => {
  for (final a in item.attributes)
    if (!a.isCustom)
      a.key: EquipmentAttributeCatalog.defFor(a.key)?.kind == AttributeKind.flag
          ? (a.valueNum == 1).toString()
          : a.valueText,
};
