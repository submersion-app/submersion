import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Which gear each equipment report covers. One place, so the reports and
/// their tests cannot drift apart. A null [diverId] is a library with no
/// active diver, where everything counts, and an ownerless item belongs to
/// whoever is looking at it, the rule `canDeleteEquipment` follows.
bool isOwnedByDiver(EquipmentItem item, String? diverId) =>
    diverId == null || item.diverId == null || item.diverId == diverId;

/// The inventory: gear the diver holds today. Shared gear belongs on its
/// owner's inventory.
bool isOwnedNow(EquipmentItem item, String? diverId) =>
    isOwnedByDiver(item, diverId) && isServiceable(item);

/// The service report's "All gear". The caller has already narrowed the list
/// to what the diver can see, so shared gear stays: the diver dives it.
bool isServiceable(EquipmentItem item) =>
    item.isFitted && item.status != EquipmentStatus.lost;

/// Cost of ownership: sold and retired gear still cost that money, and
/// wishlist gear never did.
bool isEverOwned(EquipmentItem item, String? diverId) =>
    isOwnedByDiver(item, diverId) && !item.isWanted;

/// Idle gear: a spare is meant to sit on the shelf, and a part follows its
/// parent.
bool isIdleCandidate(EquipmentItem item, String? diverId) =>
    isOwnedNow(item, diverId) &&
    item.status != EquipmentStatus.spare &&
    item.parentEquipmentId == null;

/// One printed row: an item and how deeply it sits under its parent.
typedef ReportRow = ({EquipmentItem item, int depth});

/// [items] with each part following its parent, in the given order. A part
/// whose parent is not in [items] is a top-level row, and so is the first
/// item met in a parent loop, so every item prints exactly once.
List<ReportRow> arrangeAsTree(List<EquipmentItem> items) {
  final ids = {for (final item in items) item.id};
  final children = <String, List<EquipmentItem>>{};
  for (final item in items) {
    final parent = item.parentEquipmentId;
    if (parent != null && ids.contains(parent)) {
      (children[parent] ??= []).add(item);
    }
  }
  final seen = <String>{};
  final rows = <ReportRow>[];
  void visit(EquipmentItem item, int depth) {
    if (!seen.add(item.id)) return;
    rows.add((item: item, depth: depth));
    for (final child in children[item.id] ?? const <EquipmentItem>[]) {
      visit(child, depth + 1);
    }
  }

  for (final item in items) {
    final parent = item.parentEquipmentId;
    if (parent == null || !ids.contains(parent)) visit(item, 0);
  }
  // Only a parent loop is left: no member of one is reachable from a root.
  for (final item in items) {
    visit(item, 0);
  }
  return rows;
}

/// [rootId] and everything installed in it, at any depth.
Set<String> withInstalledParts(String rootId, List<EquipmentItem> all) {
  final found = <String>{rootId};
  final pending = [rootId];
  while (pending.isNotEmpty) {
    final parent = pending.removeLast();
    for (final item in all) {
      if (item.parentEquipmentId == parent && found.add(item.id)) {
        pending.add(item.id);
      }
    }
  }
  return found;
}
