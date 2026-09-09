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

/// Turns a flat link list into set buckets and parent-child nesting, the
/// shape both dive pages and the PDF render (issue #1487). Pure and
/// cycle-safe: a row whose parent is absent, or part of a loop, is shown
/// as a top-level row rather than dropped.
abstract final class GearTree {
  static List<GearBucket> build(List<GearLink> links) {
    final present = {for (final l in links) l.item.id};
    final childrenOf = <String, List<GearLink>>{};
    final roots = <GearLink>[];
    for (final l in links) {
      final parent = l.viaEquipmentId;
      if (parent != null && present.contains(parent) && parent != l.item.id) {
        childrenOf.putIfAbsent(parent, () => []).add(l);
      } else {
        roots.add(l);
      }
    }
    // Every row reachable from a root is nested; anything left over sits
    // in a loop with no root and is promoted so it is never invisible.
    final placed = <String>{};
    GearNode node(GearLink l) {
      placed.add(l.item.id);
      return GearNode(
        link: l,
        children: [
          for (final c in childrenOf[l.item.id] ?? const <GearLink>[])
            if (!placed.contains(c.item.id)) node(c),
        ],
      );
    }

    final rootNodes = [for (final r in roots) node(r)];
    for (final l in links) {
      if (!placed.contains(l.item.id)) rootNodes.add(node(l));
    }

    final buckets = <String?, List<GearNode>>{};
    for (final n in rootNodes) {
      buckets.putIfAbsent(n.link.viaSetId, () => []).add(n);
    }
    final loose = buckets.remove(null);
    return [
      for (final e in buckets.entries) GearBucket(setId: e.key, roots: e.value),
      if (loose != null) GearBucket(setId: null, roots: loose),
    ];
  }

  /// Ids that have at least one child row: an assembly's own attributes
  /// must not count toward buoyancy when its parts are on the dive.
  static Set<String> rolledUpIds(Iterable<GearProvenance> rows) => {
    for (final r in rows)
      if (r.viaEquipmentId != null) r.viaEquipmentId!,
  };

  /// Items with no child row on this dive, in link order.
  static List<EquipmentItem> leafItems(List<GearLink> links) {
    final parents = {
      for (final l in links)
        if (l.viaEquipmentId != null) l.viaEquipmentId!,
    };
    return [
      for (final l in links)
        if (!parents.contains(l.item.id)) l.item,
    ];
  }
}
