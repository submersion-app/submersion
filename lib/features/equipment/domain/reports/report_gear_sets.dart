import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

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

/// [items] as the reports nest them. Gear hangs together two ways: an item can
/// be installed in another (`parentEquipmentId`), or be a part in an assembly's
/// template (`equipment_components`). A report treats both as the same thing,
/// so a part with no installed-in parent takes its assembly as its parent here.
///
/// A template can share a part between assemblies, but a printed list holds it
/// once: under a fitted assembly first, then the first by name. The copies are
/// for arranging a report only, because the exposure and clock wiring reads
/// `parentEquipmentId` as install history and needs the stored rows.
List<EquipmentItem> withAssemblyParents(
  List<EquipmentItem> items,
  ComponentsIndex index,
) {
  final byId = {for (final item in items) item.id: item};
  return [
    for (final item in items)
      switch (item.parentEquipmentId == null
          ? _assemblyOf(item, byId, index)
          : null) {
        final assembly? => item.copyWith(parentEquipmentId: assembly.id),
        null => item,
      },
  ];
}

EquipmentItem? _assemblyOf(
  EquipmentItem part,
  Map<String, EquipmentItem> byId,
  ComponentsIndex index,
) {
  final assemblies = [for (final id in index.parentIdsOf(part.id)) ?byId[id]]
    ..sort((a, b) {
      if (a.isFitted != b.isFitted) return a.isFitted ? -1 : 1;
      final byName = compareTextForSort(a.name, b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  return assemblies.firstOrNull;
}

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

/// [rootId] and everything fitted to it at any depth, installed or as a part
/// of its assembly template. [index] reaches a shared part from every assembly
/// it belongs to, which `parentEquipmentId` alone cannot.
Set<String> withInstalledParts(
  String rootId,
  List<EquipmentItem> all, {
  ComponentsIndex index = ComponentsIndex.empty,
}) {
  final found = <String>{rootId};
  final pending = [rootId];
  while (pending.isNotEmpty) {
    final parent = pending.removeLast();
    for (final item in all) {
      if (item.parentEquipmentId == parent && found.add(item.id)) {
        pending.add(item.id);
      }
    }
    for (final edge in index.byParent[parent] ?? const []) {
      if (found.add(edge.componentEquipmentId)) {
        pending.add(edge.componentEquipmentId);
      }
    }
  }
  return found;
}

/// The gear a service report covers for [rootIds]: each root whatever its
/// status, so a past trip keeps what has been retired since, plus the parts
/// still in service. A retired part has been replaced, and its clock would
/// print as overdue on gear it is no longer part of. Wishlist gear never counts.
List<EquipmentItem> gearWithParts(
  Set<String> rootIds,
  List<EquipmentItem> all,
  ComponentsIndex index,
) {
  final fitted = {
    for (final id in rootIds) ...withInstalledParts(id, all, index: index),
  };
  return [
    for (final item in all)
      if (!item.isWanted &&
          (rootIds.contains(item.id) ||
              (fitted.contains(item.id) && isServiceable(item))))
        item,
  ];
}
