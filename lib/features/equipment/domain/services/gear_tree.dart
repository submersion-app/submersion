import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// One rendered row and the rows nested under it.
class GearNode {
  final GearLink link;
  final List<GearNode> children;
  const GearNode({required this.link, this.children = const []});
}

/// The rows that came from one set (or none), with their top-level roots.
class GearBucket {
  final String? setId;
  final List<GearNode> roots;
  const GearBucket({required this.setId, required this.roots});
}

/// Where each row landed once every row was placed exactly once: the
/// top-level ids in order, and each id's children in row order.
typedef _Placement = ({List<String> roots, Map<String, List<String>> children});

/// Turns a flat link list into set buckets and parent-child nesting, the
/// shape both dive pages and the PDF render (issue #1487). Pure and
/// cycle-safe: a row whose parent is absent, or part of a loop, is shown
/// as a top-level row rather than dropped, and the two buoyancy helpers
/// read the same placement so a loop never rolls up every row at once.
abstract final class GearTree {
  static List<GearBucket> build(List<GearLink> links) {
    final byId = {for (final l in links) l.item.id: l};
    final placement = _place([
      for (final l in links) (id: l.item.id, parent: l.viaEquipmentId),
    ]);
    GearNode node(String id) => GearNode(
      link: byId[id]!,
      children: [for (final c in placement.children[id]!) node(c)],
    );

    final buckets = <String?, List<GearNode>>{};
    for (final id in placement.roots) {
      buckets.putIfAbsent(byId[id]!.viaSetId, () => []).add(node(id));
    }
    final loose = buckets.remove(null);
    return [
      for (final e in buckets.entries) GearBucket(setId: e.key, roots: e.value),
      if (loose != null) GearBucket(setId: null, roots: loose),
    ];
  }

  /// Ids that have at least one child row once placed: an assembly's own
  /// attributes must not count toward buoyancy when its parts are on the
  /// dive. In a corrupt loop one row is promoted to a root and the other
  /// nests under it, so at least one row always stays counted.
  static Set<String> rolledUpIds(Iterable<GearProvenance> rows) {
    final placement = _place([
      for (final r in rows) (id: r.equipmentId, parent: r.viaEquipmentId),
    ]);
    return {
      for (final e in placement.children.entries)
        if (e.value.isNotEmpty) e.key,
    };
  }

  /// Ids nested under a parent once placed: the rows a chip list folds into
  /// their assembly's count. An orphan whose parent is absent, or the
  /// promoted row of a loop, is a top-level row and not one of these.
  static Set<String> partIds(Iterable<GearProvenance> rows) {
    final roots = _place([
      for (final r in rows) (id: r.equipmentId, parent: r.viaEquipmentId),
    ]).roots.toSet();
    return {
      for (final r in rows)
        if (!roots.contains(r.equipmentId)) r.equipmentId,
    };
  }

  /// Parts under each assembly id once placed, for chip labels.
  static Map<String, int> partCounts(Iterable<GearProvenance> rows) {
    final placement = _place([
      for (final r in rows) (id: r.equipmentId, parent: r.viaEquipmentId),
    ]);
    return {
      for (final e in placement.children.entries)
        if (e.value.isNotEmpty) e.key: e.value.length,
    };
  }

  /// How many rows render as top-level once placed. Reads the placement
  /// rather than `isTopLevel` so an orphan (parent not on the dive) or a
  /// promoted loop row counts, matching what the renderer shows.
  static int topLevelCount(Iterable<GearProvenance> rows) => _place([
    for (final r in rows) (id: r.equipmentId, parent: r.viaEquipmentId),
  ]).roots.length;

  /// Items with no child row on this dive once placed, in link order.
  static List<EquipmentItem> leafItems(List<GearLink> links) {
    final placement = _place([
      for (final l in links) (id: l.item.id, parent: l.viaEquipmentId),
    ]);
    return [
      for (final l in links)
        if (placement.children[l.item.id]!.isEmpty) l.item,
    ];
  }

  /// Places every id exactly once. A row nests under its parent when the
  /// parent is present and not itself; every row reachable from a root is
  /// nested; anything left over sits in a loop with no root and is promoted
  /// so it is never invisible. Rows keep their input order throughout.
  static _Placement _place(List<({String id, String? parent})> rows) {
    final present = {for (final r in rows) r.id};
    final childrenOf = <String, List<String>>{};
    final roots = <String>[];
    for (final r in rows) {
      final parent = r.parent;
      if (parent != null && present.contains(parent) && parent != r.id) {
        childrenOf.putIfAbsent(parent, () => []).add(r.id);
      } else {
        roots.add(r.id);
      }
    }
    final placed = <String>{};
    final children = <String, List<String>>{};
    void place(String id) {
      final kids = <String>[];
      for (final c in childrenOf[id] ?? const <String>[]) {
        if (placed.add(c)) {
          kids.add(c);
          place(c);
        }
      }
      children[id] = kids;
    }

    final allRoots = <String>[];
    for (final id in roots) {
      if (placed.add(id)) {
        allRoots.add(id);
        place(id);
      }
    }
    for (final r in rows) {
      if (placed.add(r.id)) {
        allRoots.add(r.id);
        place(r.id);
      }
    }
    return (roots: allRoots, children: children);
  }
}
