import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The status to badge on a row for gear that has left the kit, or null for
/// gear still in it.
///
/// Starts from the edit form's reading (#636): a legacy row that only ever
/// had `isActive` flipped counts as Retired, but Sold, which is also
/// inactive, keeps its own status rather than being folded into Retired.
///
/// Deliberately differs from the form for Lost. The form folds an inactive
/// Lost row into Retired; this badge keeps Lost whether the row is active
/// or not, because the gear is gone either way and "Lost" is the more
/// useful prompt to swap it.
EquipmentStatus? departedStatusOf(EquipmentItem item) {
  if (item.status == EquipmentStatus.sold) return EquipmentStatus.sold;
  if (item.status == EquipmentStatus.lost) return EquipmentStatus.lost;
  if (item.status == EquipmentStatus.retired || !item.isActive) {
    return EquipmentStatus.retired;
  }
  return null;
}
