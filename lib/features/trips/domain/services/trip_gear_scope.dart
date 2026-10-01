import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The items of [items] that go on a trip whose gear ids are [onTrip]
/// (packed, or on a slot of its cylinder board), in their given order. An
/// item goes when it is listed, or when it is installed, at any depth, in
/// an item that is: a packed reg set takes its first stage along (issue
/// #2727). The walk up the parents stays within [items], so a part of a
/// retired assembly goes only when it is listed itself.
List<EquipmentItem> gearOnTrip(List<EquipmentItem> items, Set<String> onTrip) {
  if (onTrip.isEmpty) return const [];
  final byId = {for (final item in items) item.id: item};
  bool goes(EquipmentItem item) {
    final seen = <String>{};
    for (
      EquipmentItem? at = item;
      at != null && seen.add(at.id);
      at = at.parentEquipmentId == null ? null : byId[at.parentEquipmentId]
    ) {
      if (onTrip.contains(at.id)) return true;
    }
    return false;
  }

  return [
    for (final item in items)
      if (goes(item)) item,
  ];
}
