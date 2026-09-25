import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// Hub-and-spokes placement for ego mode.
///
/// The focus sits at the origin. Neighbours are grouped by kind (in
/// [ConnectionKind] order) into contiguous arcs sized by count, sorted by
/// spoke weight within the arc, and spill to outer rings when an arc cannot
/// hold them at [minArcSpacing]. Nodes not connected to the focus are
/// dropped.
class RadialLayout {
  const RadialLayout._();

  static LayoutFrame compute({
    required NodeRef focus,
    required List<ConnectionNode> nodes,
    required List<ConnectionEdge> edges,
    double firstRing = 170,
    double ringGap = 120,
    double minArcSpacing = 36,
  }) {
    final weightTo = <NodeRef, int>{};
    for (final e in edges) {
      final other = e.otherEnd(focus);
      if (other != null) weightTo[other] = (weightTo[other] ?? 0) + e.weight;
    }
    final neighbours = nodes
        .where((n) => n.ref != focus && weightTo.containsKey(n.ref))
        .toList();
    final positions = <NodeRef, GraphPoint>{focus: GraphPoint.zero};
    if (neighbours.isEmpty) {
      return LayoutFrame.fromPositions(positions, settled: true);
    }

    final groups = <ConnectionKind, List<ConnectionNode>>{};
    for (final n in neighbours) {
      groups.putIfAbsent(n.ref.kind, () => []).add(n);
    }
    final kinds = groups.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final k in kinds) {
      groups[k]!.sort((a, b) {
        final byWeight = weightTo[b.ref]!.compareTo(weightTo[a.ref]!);
        return byWeight != 0 ? byWeight : a.label.compareTo(b.label);
      });
    }

    final total = neighbours.length;
    var arcStart = 0.0;
    for (final k in kinds) {
      final members = groups[k]!;
      final arc = 2 * math.pi * members.length / total;
      var placed = 0;
      var ring = 0;
      while (placed < members.length) {
        final radius = firstRing + ring * ringGap;
        final capacity = math.max(1, (arc * radius / minArcSpacing).floor());
        final count = math.min(capacity, members.length - placed);
        for (var i = 0; i < count; i++) {
          final t = count == 1 ? 0.5 : (i + 0.5) / count;
          final angle = arcStart + arc * t;
          positions[members[placed + i].ref] = GraphPoint(
            radius * math.cos(angle),
            radius * math.sin(angle),
          );
        }
        placed += count;
        ring++;
      }
      arcStart += arc;
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
