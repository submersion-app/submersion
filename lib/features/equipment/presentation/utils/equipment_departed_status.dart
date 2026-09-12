import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The status to badge on a row for gear that has left the kit, or null for
/// gear still in it.
///
/// Reads an item the way the edit form does (#636): a legacy row that only
/// ever had `isActive` flipped counts as Retired, but Sold, which is also
/// inactive, keeps its own status rather than being folded into Retired.
/// Lost keeps its own status too, including when `isActive` was never
/// flipped: the gear is gone either way.
EquipmentStatus? departedStatusOf(EquipmentItem item) {
  if (item.status == EquipmentStatus.sold) return EquipmentStatus.sold;
  if (item.status == EquipmentStatus.lost) return EquipmentStatus.lost;
  if (item.status == EquipmentStatus.retired || !item.isActive) {
    return EquipmentStatus.retired;
  }
  return null;
}
