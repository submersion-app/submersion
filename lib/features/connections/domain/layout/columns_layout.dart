import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// One column per kind, left to right in kind order, busiest at the top.
/// A column longer than [maxPerColumn] wraps into sub-columns. In Around
/// mode the focus's kind comes first and the focus tops its column.
abstract final class ColumnsLayout {
  static const int maxPerColumn = 25;
  static const double columnGap = 240;
  static const double subColumnGap = 160;
  static const double rowGap = 56;

  static LayoutFrame compute({
    required List<ConnectionNode> nodes,
    NodeRef? focus,
    double spacing = 1,
  }) {
    final byKind = <ConnectionKind, List<ConnectionNode>>{};
    for (final n in nodes) {
      byKind.putIfAbsent(n.ref.kind, () => []).add(n);
    }
    final focusKind = focus != null && nodes.any((n) => n.ref == focus)
        ? focus.kind
        : null;
    final kinds = [
      ?focusKind,
      ...(byKind.keys.where((k) => k != focusKind).toList()
        ..sort((a, b) => a.index.compareTo(b.index))),
    ];
    final positions = <NodeRef, GraphPoint>{};
    var x = 0.0;
    for (final kind in kinds) {
      final sorted = [...byKind[kind]!]..sort(compareDivesLabel);
      // The focus tops its own column whatever its dive count.
      final members = kind == focusKind
          ? [
              ...sorted.where((n) => n.ref == focus),
              ...sorted.where((n) => n.ref != focus),
            ]
          : sorted;
      for (var i = 0; i < members.length; i++) {
        positions[members[i].ref] = GraphPoint(
          x + (i ~/ maxPerColumn) * subColumnGap * spacing,
          (i % maxPerColumn) * rowGap * spacing,
        );
      }
      final subColumns = (members.length + maxPerColumn - 1) ~/ maxPerColumn;
      x += ((subColumns - 1) * subColumnGap + columnGap) * spacing;
    }
    return LayoutFrame.fromPositions(positions, settled: true);
  }
}
