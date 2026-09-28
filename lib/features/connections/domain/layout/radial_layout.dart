import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_edge.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// Hub-and-spokes placement for ego mode.
///
/// The focus sits at the origin. Nodes are placed by hop: hop 1 (and nodes
/// without a hop) on the inner rings, each farther hop outside all of the
/// nearer ones. Within a hop, kinds (in [ConnectionKind] order) keep
/// contiguous arcs sized by count, sorted by spoke weight within the arc,
/// and spill to outer rings when an arc cannot hold them at
/// [minArcSpacing].
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
    // Hop 2 and 3 nodes reach the focus only through chords, so every node
    // gets a weight (zero without a spoke) for the in-arc ordering.
    for (final n in nodes) {
      if (n.ref != focus) weightTo.putIfAbsent(n.ref, () => 0);
    }
    final neighbours = nodes.where((n) => n.ref != focus).toList();
    final positions = <NodeRef, GraphPoint>{focus: GraphPoint.zero};
    if (neighbours.isEmpty) {
      return LayoutFrame.fromPositions(positions, settled: true);
    }

    final hops = <int, List<ConnectionNode>>{};
    for (final n in neighbours) {
      hops.putIfAbsent(n.hop ?? 1, () => []).add(n);
    }
    var ringBase = 0;
    for (final h in hops.keys.toList()..sort()) {
      final members = hops[h]!;
      final byKind = <ConnectionKind, List<ConnectionNode>>{};
      for (final n in members) {
        byKind.putIfAbsent(n.ref.kind, () => []).add(n);
      }
      final kinds = byKind.keys.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      var arcStart = 0.0;
      var ringsUsed = 1;
      for (final k in kinds) {
        final group = byKind[k]!
          ..sort((a, b) {
            final byWeight = weightTo[b.ref]!.compareTo(weightTo[a.ref]!);
            return byWeight != 0 ? byWeight : a.label.compareTo(b.label);
          });
        final arc = 2 * math.pi * group.length / members.length;
        var placed = 0;
        var ring = 0;
        while (placed < group.length) {
          final radius = firstRing + (ringBase + ring) * ringGap;
          final capacity = math.max(1, (arc * radius / minArcSpacing).floor());
          final count = math.min(capacity, group.length - placed);
          for (var i = 0; i < count; i++) {
            final t = count == 1 ? 0.5 : (i + 0.5) / count;
            final angle = arcStart + arc * t;
            positions[group[placed + i].ref] = GraphPoint(
              radius * math.cos(angle),
              radius * math.sin(angle),
            );
          }
          placed += count;
          ring++;
        }
        ringsUsed = math.max(ringsUsed, ring);
        arcStart += arc;
      }
      ringBase += ringsUsed;
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
