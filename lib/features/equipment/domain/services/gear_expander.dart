import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

/// One item being attached to a dive or plan, and the set it came from.
typedef GearAddition = ({String equipmentId, String? viaSetId});

/// The one place an assembly is turned into gear rows (issue #1487). Pure:
/// it takes ids and the adjacency index and returns the new provenance
/// list, so the edit page, the repository bulk operations, the defaulter
/// and the planner all expand identically and one test file proves it.
///
/// Rules:
/// - An added item is a top-level row carrying the addition's set id.
/// - Each active part of it, in template order, becomes a row whose parent
///   is the item and whose set id is the same, recursively.
/// - A retired or lost part is skipped ([isActive] decides).
/// - An item already present as a top-level row that is now being added
///   beneath an assembly adopts that parent and set. A row that already has
///   a parent is left alone. A top-level row that had no set gains the set.
/// - A visited set makes the walk terminate even on a corrupt loop.
///
/// Installed-in children (equipment.parent_equipment_id) are not parts and
/// are never followed here.
abstract final class GearExpander {
  static List<GearProvenance> expand({
    required List<GearAddition> additions,
    required ComponentsIndex index,
    required List<GearProvenance> existing,
    required bool Function(String equipmentId) isActive,
  }) {
    final rows = <String, GearProvenance>{
      for (final r in existing) r.equipmentId: r,
    };
    final order = [for (final r in existing) r.equipmentId];

    void put(GearProvenance row) {
      if (!rows.containsKey(row.equipmentId)) order.add(row.equipmentId);
      rows[row.equipmentId] = row;
    }

    void addPart(String id, String parentId, String? setId, Set<String> seen) {
      if (!seen.add(id)) return;
      final current = rows[id];
      if (current == null) {
        put(
          GearProvenance(
            equipmentId: id,
            viaEquipmentId: parentId,
            viaSetId: setId,
          ),
        );
      } else if (current.isTopLevel) {
        put(
          current.copyWith(
            viaEquipmentId: parentId,
            viaSetId: setId ?? current.viaSetId,
          ),
        );
      }
      // A row that already has a parent keeps it.
      for (final edge in index.byParent[id] ?? const []) {
        final child = edge.componentEquipmentId;
        if (isActive(child)) addPart(child, id, setId, seen);
      }
    }

    for (final addition in additions) {
      final id = addition.equipmentId;
      final current = rows[id];
      if (current == null) {
        put(GearProvenance(equipmentId: id, viaSetId: addition.viaSetId));
      } else if (current.viaSetId == null && addition.viaSetId != null) {
        put(current.copyWith(viaSetId: addition.viaSetId));
      }
      final seen = <String>{id};
      for (final edge in index.byParent[id] ?? const []) {
        final child = edge.componentEquipmentId;
        if (isActive(child)) addPart(child, id, addition.viaSetId, seen);
      }
    }
    return [for (final id in order) rows[id]!];
  }

  /// [equipmentId] and every row reachable downward from it through
  /// `viaEquipmentId`, cycle-safe.
  static Set<String> subtreeIds(List<GearProvenance> rows, String equipmentId) {
    final children = <String, List<String>>{};
    for (final r in rows) {
      final parent = r.viaEquipmentId;
      if (parent != null) {
        children.putIfAbsent(parent, () => []).add(r.equipmentId);
      }
    }
    final out = <String>{equipmentId};
    final queue = [equipmentId];
    while (queue.isNotEmpty) {
      for (final c in children[queue.removeLast()] ?? const <String>[]) {
        if (out.add(c)) queue.add(c);
      }
    }
    return out;
  }

  static List<GearProvenance> removeSubtree(
    List<GearProvenance> rows,
    String equipmentId,
  ) {
    final gone = subtreeIds(rows, equipmentId);
    return [
      for (final r in rows)
        if (!gone.contains(r.equipmentId)) r,
    ];
  }

  static List<GearProvenance> removeSet(
    List<GearProvenance> rows,
    String setId,
  ) => [
    for (final r in rows)
      if (r.viaSetId != setId) r,
  ];

  /// Drops one leaf row (the per-dive deviation). A row that still has
  /// children on the dive is removed as a subtree instead, so no row is
  /// ever left pointing at a parent that is gone.
  static List<GearProvenance> removePart(
    List<GearProvenance> rows,
    String equipmentId,
  ) {
    final hasChildren = rows.any((r) => r.viaEquipmentId == equipmentId);
    if (hasChildren) return removeSubtree(rows, equipmentId);
    return [
      for (final r in rows)
        if (r.equipmentId != equipmentId) r,
    ];
  }
}
