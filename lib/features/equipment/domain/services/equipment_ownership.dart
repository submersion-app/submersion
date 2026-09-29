import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Who may do what to an item shared between diver profiles (issue #2046).
/// The repository, the item page, the sharing row and the list's bulk
/// actions all ask here, so the rule lives in one place.

/// Delete is owner-only. An ownerless item (no owner to defer to) and a
/// library with no active diver delete as they did before sharing existed.
bool canDeleteEquipment(EquipmentItem item, String? activeDiverId) =>
    activeDiverId == null ||
    item.diverId == null ||
    item.diverId == activeDiverId;

/// Managing an item's shares takes a real owner: an ownerless item has no
/// one to manage them, and an unknown active diver cannot claim it.
bool canShareEquipment(EquipmentItem item, String? activeDiverId) =>
    activeDiverId != null && item.diverId == activeDiverId;

/// Whether applying a set gives [diverId]'s dive a member owned by
/// [ownerId]: every member except one another profile owns and has not
/// shared with [diverId] (issue #2046). An ownerless member, or a library
/// with no active diver, applies as it did before sharing existed. The
/// set-application query and the planner's in-memory filter both ask here.
bool isSetMemberUsableBy({
  required String? ownerId,
  required String? diverId,
  required bool sharedWithDiver,
}) =>
    diverId == null || ownerId == null || ownerId == diverId || sharedWithDiver;
