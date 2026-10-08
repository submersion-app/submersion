import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

/// The status worth offering after an item moves to a place of [kind], or
/// null when the offer would change nothing useful. [kind] is null for a
/// move to "No location". The diver confirms every offer; nothing here
/// changes a status by itself.
EquipmentStatus? offeredStatusAfterMove(
  EquipmentLocationKind? kind,
  EquipmentStatus current,
) {
  // Gear that has left the diver's hands, or is not theirs yet (a wishlist
  // item, #2025), is never offered a status by being moved.
  const terminal = {
    EquipmentStatus.retired,
    EquipmentStatus.sold,
    EquipmentStatus.wanted,
  };
  switch (kind) {
    case EquipmentLocationKind.serviceShop:
      if (current == EquipmentStatus.inService || terminal.contains(current)) {
        return null;
      }
      return EquipmentStatus.inService;
    case EquipmentLocationKind.person:
      if (current == EquipmentStatus.loaned || terminal.contains(current)) {
        return null;
      }
      return EquipmentStatus.loaned;
    case EquipmentLocationKind.storage:
      // Back home: only gear that was away comes back to Active. A spare or
      // a needs-service item stored on the shelf keeps its status.
      const away = {
        EquipmentStatus.inService,
        EquipmentStatus.loaned,
        EquipmentStatus.lost,
      };
      return away.contains(current) ? EquipmentStatus.active : null;
    case EquipmentLocationKind.other:
    case null:
      return null;
  }
}
