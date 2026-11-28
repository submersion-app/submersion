import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The items in [items] that the buddy [buddyId] or the dive centre
/// [centerId] sold the diver (issue #5140): newest purchase first, undated
/// ones last by name. A wishlist item is left out, since nothing has been
/// bought yet. Empty when neither is named.
List<EquipmentItem> gearBoughtFrom(
  List<EquipmentItem> items, {
  String? buddyId,
  String? centerId,
}) {
  if (buddyId == null && centerId == null) return const [];
  final bought = [
    for (final item in items)
      if (item.status != EquipmentStatus.wanted &&
          ((buddyId != null && item.sellerBuddyId == buddyId) ||
              (centerId != null && item.sellerDiveCenterId == centerId)))
        item,
  ];
  bought.sort((a, b) {
    final da = a.purchaseDate;
    final db = b.purchaseDate;
    if (da != null && db != null && da != db) return db.compareTo(da);
    if (da == null && db != null) return 1;
    if (da != null && db == null) return -1;
    return compareTextForSort(a.name, b.name);
  });
  return bought;
}
