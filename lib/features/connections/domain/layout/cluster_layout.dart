import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/insights/label_propagation.dart';
import 'package:submersion/features/connections/domain/layout/force_layout.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/island_packer.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// The groups the Groups highlight colours, each laid out on its own and
/// packed side by side, biggest first, with ungrouped nodes in a grid
/// below. Every simulation runs to rest here, so the frame is static.
abstract final class ClusterLayout {
  static const double islandGap = 60;
  static const double singleGap = 90;

  static LayoutFrame compute({
    required ConnectionGraph graph,
    double spacing = 1,
  }) {
    final groups = LabelPropagation.communities(graph);
    final members = <int, List<NodeRef>>{};
    final loose = <ConnectionNode>[];
    for (final n in graph.nodes) {
      final g = groups.groupOf[n.ref];
      if (g == null) {
        loose.add(n);
      } else {
        members.putIfAbsent(g, () => []).add(n.ref);
      }
    }
    final frames = <LayoutFrame>[];
    for (var g = 0; g < groups.count; g++) {
      final refs = members[g] ?? const <NodeRef>[];
      final inGroup = refs.toSet();
      final layout = ForceLayout(
        nodes: refs,
        edges: [
          for (final e in graph.edges)
            if (inGroup.contains(e.source) && inGroup.contains(e.target)) e,
        ],
        spacing: spacing,
      );
      // ForceLayout caps its own iterations, so this always ends.
      while (!layout.settled) {
        layout.advance(50);
      }
      frames.add(layout.frame);
    }
    final offsets = IslandPacker.pack(frames, gap: islandGap * spacing);
    final positions = <NodeRef, GraphPoint>{
      for (var i = 0; i < frames.length; i++)
        for (final MapEntry(:key, :value) in frames[i].positions.entries)
          key: value + offsets[i],
    };
    if (loose.isNotEmpty) {
      final ordered = [...loose]..sort(compareDivesLabel);
      final gap = singleGap * spacing;
      final packed = GraphBounds.of(positions.values);
      final cols = math.max(1, (math.sqrt(ordered.length) * 1.6).ceil());
      final x0 = positions.isEmpty ? 0.0 : packed.left;
      final y0 = positions.isEmpty ? 0.0 : packed.bottom + gap;
      for (var i = 0; i < ordered.length; i++) {
        positions[ordered[i].ref] = GraphPoint(
          x0 + (i % cols) * gap,
          y0 + (i ~/ cols) * gap,
        );
      }
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
