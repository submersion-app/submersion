import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';

/// How many items a capped type group shows above its show-more row (#3993).
const equipmentGroupVisibleItems = 3;

/// The smallest group that is capped, so a cap never hides just one item: a
/// group of 4 shows all 4, a group of 5 shows 3 and offers the other 2.
const _collapseThreshold = 5;

/// The items of [group] that sit behind its show-more row, in display order.
///
/// Empty for a group too small to cap, and for ungrouped gear ([group]'s type
/// null), which has no heading to sit under and is not what #3993 is about.
List<EquipmentItem> cappedGroupTail(EquipmentGroup group) {
  if (group.type == null || group.items.length < _collapseThreshold) {
    return const [];
  }
  return group.items.sublist(equipmentGroupVisibleItems);
}
