import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';

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
/// A member on the wishlist (#2025) is never applied either. The same rule
/// as `EquipmentRepository.usableSetMemberIds`, for callers that already
/// hold the visible list.
List<EquipmentItem> setItemsUsableBy(
  Iterable<EquipmentItem> items, {
  required String? diverId,
  required Set<String> visibleIds,
}) => [
  for (final item in items)
    if (!item.isWanted &&
        isSetMemberUsableBy(
          ownerId: item.diverId,
          diverId: diverId,
          sharedWithDiver: visibleIds.contains(item.id),
        ))
      item,
];
