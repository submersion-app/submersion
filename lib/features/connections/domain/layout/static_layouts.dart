import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/circle_layout.dart';
import 'package:submersion/features/connections/domain/layout/columns_layout.dart';
import 'package:submersion/features/connections/domain/layout/connections_layout.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/radial_layout.dart';
import 'package:submersion/features/connections/domain/layout/timeline_layout.dart';

/// Every layout computed in one pass. [ConnectionsLayout.web] and
/// [ConnectionsLayout.clusters] are live simulations and have no entry here.
abstract final class StaticLayouts {
  static LayoutFrame compute(
    ConnectionsLayout layout, {
    required ConnectionGraph graph,
    NodeRef? focus,
    double spacing = 1,
  }) => switch (layout) {
    // Radial needs a centre; without one it is a ring.
    ConnectionsLayout.radial when focus != null => RadialLayout.compute(
      focus: focus,
      nodes: graph.nodes,
      edges: graph.edges,
      spacing: spacing,
    ),
    ConnectionsLayout.radial || ConnectionsLayout.circle =>
      CircleLayout.compute(nodes: graph.nodes, focus: focus, spacing: spacing),
    ConnectionsLayout.columns => ColumnsLayout.compute(
      nodes: graph.nodes,
      focus: focus,
      spacing: spacing,
    ),
    ConnectionsLayout.timeline => TimelineLayout.compute(
      nodes: graph.nodes,
      spacing: spacing,
    ),
    ConnectionsLayout.web || ConnectionsLayout.clusters =>
      throw ArgumentError.value(layout, 'layout', 'a live layout'),
  };
}
