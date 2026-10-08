import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';

/// Whether the item page offers "Transfer to..." (issue #2852): the owner
/// only, with two or more profiles. False while the active profile is
/// loading, reloading or failed: a reload still carries the previous
/// profile's id, so during a profile switch it would offer the previous
/// owner's action (as `canDestroySharedItemOnceKnown` guards for trips and
/// sites, issue #2682).
bool canTransferEquipmentOnceKnown(
  AsyncValue<String?> activeDiver,
  EquipmentItem item, {
  required bool multipleDivers,
}) {
  if (!multipleDivers) return false;
  if (activeDiver.isLoading || activeDiver.hasError || !activeDiver.hasValue) {
    return false;
  }
  return canShareEquipment(item, activeDiver.value);
}
