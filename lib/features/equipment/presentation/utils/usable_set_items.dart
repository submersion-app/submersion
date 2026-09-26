import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The members of a set a diver can still put on a dive: those in
/// [visibleIds] (owned or shared). A member whose share was removed stays
/// in the set, shown as "No longer shared", but is not applied (issue
/// #2046). Set order is kept.
List<EquipmentItem> usableSetItems(
  Iterable<EquipmentItem> items,
  Set<String> visibleIds,
) => [
  for (final item in items)
    if (visibleIds.contains(item.id)) item,
];
