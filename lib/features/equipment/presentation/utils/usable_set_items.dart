import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The members of a set to apply: those in [visibleIds], the ids a caller
/// got from `EquipmentRepository.usableSetMemberIds`. A member whose share
/// was removed stays in the set, shown as "No longer shared", but is not
/// applied (issue #2046). Set order is kept.
List<EquipmentItem> usableSetItems(
  Iterable<EquipmentItem> items,
  Set<String> visibleIds,
) => [
  for (final item in items)
    if (visibleIds.contains(item.id)) item,
];

/// The set members [diverId] gets when a set is applied, from items already
/// in hand: every member except one another profile owns that is not in
/// [visibleIds] (issue #2046). Ownerless items apply as they always have.
/// The same rule as `EquipmentRepository.usableSetMemberIds`, for callers
/// that already hold the visible list.
List<EquipmentItem> setItemsUsableBy(
  Iterable<EquipmentItem> items, {
  required String? diverId,
  required Set<String> visibleIds,
}) => [
  for (final item in items)
    if (diverId == null ||
        item.diverId == null ||
        item.diverId == diverId ||
        visibleIds.contains(item.id))
      item,
];
