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

/// An item's catalog attribute values by key: choice keys and its colour.
/// Custom attributes are dropped; the figure reads only catalog keys.
Map<String, String?> figureAttributesOf(EquipmentItem item) => {
  for (final a in item.attributes)
    if (!a.isCustom) a.key: a.valueText,
};
