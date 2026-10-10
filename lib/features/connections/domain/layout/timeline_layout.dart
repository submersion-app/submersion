import 'dart:math' as math;

import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/layout/node_order.dart';

/// Nodes left to right by the year of their first dive in scope, one lane
/// per kind top to bottom, busiest first within a year. Every year from the
/// first to the last keeps a band, so distance reads as time. A node with
/// no date joins the earliest band.
abstract final class TimelineLayout {
  static const double yearWidth = 170;
  static const double rowGap = 52;
  static const double laneGap = 70;

  /// How far the year labels sit above the first lane, and the lane labels
  /// left of the first year.
  static const double guideOffset = 70;

  static LayoutFrame compute({
    required List<ConnectionNode> nodes,
    double spacing = 1,
  }) {
    if (nodes.isEmpty) return LayoutFrame.empty;
    final years = [
      for (final n in nodes)
        if (n.firstDiveAt case final at?) at.year,
    ];
    final first = years.isEmpty ? null : years.reduce(math.min);
    final last = years.isEmpty ? null : years.reduce(math.max);
    final origin = first ?? 0;
    final cells = <ConnectionKind, Map<int, List<ConnectionNode>>>{};
    for (final n in nodes) {
      final year = n.firstDiveAt?.year ?? origin;
      cells
          .putIfAbsent(n.ref.kind, () => {})
          .putIfAbsent(year, () => [])
          .add(n);
    }
    final kinds = cells.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final positions = <NodeRef, GraphPoint>{};
    final guides = <LayoutGuide>[];
    var laneTop = 0.0;
    for (final kind in kinds) {
      var tallest = 0;
      for (final MapEntry(key: year, value: cell) in cells[kind]!.entries) {
        final members = [...cell]..sort(compareDivesLabel);
        for (var i = 0; i < members.length; i++) {
          positions[members[i].ref] = GraphPoint(
            (year - origin) * yearWidth * spacing,
            laneTop + i * rowGap * spacing,
          );
        }
        tallest = math.max(tallest, members.length);
      }
      guides.add(LaneGuide(kind, GraphPoint(-guideOffset * spacing, laneTop)));
      laneTop += (tallest * rowGap + laneGap) * spacing;
    }
    if (first != null && last != null) {
      for (var y = first; y <= last; y++) {
        guides.add(
          YearGuide(
            y,
            GraphPoint(
              (y - origin) * yearWidth * spacing,
              -guideOffset * spacing,
            ),
          ),
        );
      }
    }
    return LayoutFrame.fromPositions(positions, settled: true, guides: guides);
  }
}
