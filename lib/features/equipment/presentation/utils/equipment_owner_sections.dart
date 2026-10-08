import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// One picker section: the active diver's own items ([ownerId] null), or the
/// items another profile shares with it.
typedef OwnerSection = ({String? ownerId, List<EquipmentItem> items});

/// [items] split for a picker (issue #2046): the active diver's own items
/// first, then a section per other owner ordered by [ownerName]. An item with
/// no owner, or any item when there is no active diver, counts as own.
/// Item order inside a section is kept.
List<OwnerSection> sectionsByOwner(
  List<EquipmentItem> items, {
  required String? activeDiverId,
  required String Function(String ownerId) ownerName,
}) {
  final own = <EquipmentItem>[];
  final others = <String, List<EquipmentItem>>{};
  for (final item in items) {
    final owner = item.diverId;
    if (activeDiverId == null || owner == null || owner == activeDiverId) {
      own.add(item);
    } else {
      (others[owner] ??= []).add(item);
    }
  }
  final ownerIds = sortedByText(others.keys.toList(), ownerName);
  return [
    if (own.isNotEmpty) (ownerId: null, items: own),
    for (final id in ownerIds) (ownerId: id, items: others[id]!),
  ];
}

/// Whether a row for [item] shows an owner chip: another profile owns it
/// than [referenceDiverId] (the active diver in lists, the dive's diver on a
/// dive), and more than one profile exists.
bool showsOwnerChip(
  EquipmentItem item,
  String? referenceDiverId, {
  required bool multipleDivers,
}) =>
    multipleDivers &&
    item.diverId != null &&
    referenceDiverId != null &&
    item.diverId != referenceDiverId;
