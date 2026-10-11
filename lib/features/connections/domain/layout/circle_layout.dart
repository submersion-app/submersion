import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// Every node evenly on one ring, kinds in contiguous arcs, starting at the
/// top and running clockwise. A focus (Around mode) sits in the middle.
abstract final class CircleLayout {
  /// Arc length per node at spacing 1: two of the largest discs (26 px
  /// radius) side by side with a little air.
  static const double slot = 64;
  static const double minRadius = 160;

  static LayoutFrame compute({
    required List<ConnectionNode> nodes,
    NodeRef? focus,
    double spacing = 1,
  }) {
    final centre = focus != null && nodes.any((n) => n.ref == focus)
        ? focus
        : null;
    final ring = [
      for (final n in nodes)
        if (n.ref != centre) n,
    ]..sort(compareKindDivesLabel);
    final positions = <NodeRef, GraphPoint>{?centre: GraphPoint.zero};
    if (ring.isNotEmpty) {
      // Spacing scales the ring, but a tight setting never shrinks it below
      // one slot per node, where the largest discs would overlap.
      final radius = math.max(
        minRadius * spacing,
        ring.length * slot * math.max(1.0, spacing) / (2 * math.pi),
      );
      for (var i = 0; i < ring.length; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * i / ring.length;
        positions[ring[i].ref] = GraphPoint(
          radius * math.cos(angle),
          radius * math.sin(angle),
        );
      }
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
