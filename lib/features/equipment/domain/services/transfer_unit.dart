/// Transfer units for equipment ownership changes (issue #2852).
///
/// A transfer never moves a lone installed part or a lone assembly
/// component: it moves the item's unit, every item of the same owner
/// connected to it through the installed-on link
/// (`equipment.parent_equipment_id`) or the assembly link
/// (`equipment_components`), in either direction. An item another profile
/// owns is a boundary: it is not moved and nothing is reached through it.
library;

/// The links and owners a unit is computed over.
class TransferUnitGraph {
  const TransferUnitGraph({
    required this.ownerOf,
    required this.hostOf,
    required this.componentEdges,
  });

  /// Owner by equipment id. An id missing here is unknown and never moves.
  final Map<String, String?> ownerOf;

  /// Host by installed item id (`parent_equipment_id`).
  final Map<String, String> hostOf;

  /// Assembly edges (`equipment_components`).
  final List<({String parent, String component})> componentEdges;
}

/// The disjoint units [picked] expands to for [ownerId], ordered by first
/// appearance in [picked]. Picked items [ownerId] does not own are in no
/// unit; the caller counts them as skipped.
List<Set<String>> transferUnits(
  TransferUnitGraph graph,
  Iterable<String> picked, {
  required String ownerId,
}) {
  final neighbours = <String, Set<String>>{};
  void link(String a, String b) {
    (neighbours[a] ??= {}).add(b);
    (neighbours[b] ??= {}).add(a);
  }

  graph.hostOf.forEach(link);
  for (final e in graph.componentEdges) {
    link(e.parent, e.component);
  }

  bool owned(String id) => graph.ownerOf[id] == ownerId;

  final units = <Set<String>>[];
  final seen = <String>{};
  for (final start in picked) {
    if (!owned(start) || seen.contains(start)) continue;
    final unit = <String>{};
    final queue = [start];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!owned(id) || !unit.add(id)) continue;
      queue.addAll(neighbours[id] ?? const <String>{});
    }
    seen.addAll(unit);
    units.add(unit);
  }
  return units;
}
