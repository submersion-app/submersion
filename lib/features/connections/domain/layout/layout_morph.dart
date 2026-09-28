import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// Interpolates between two layout frames for the refocus animation.
class LayoutMorph {
  const LayoutMorph._();

  static LayoutFrame at({
    required LayoutFrame from,
    required LayoutFrame to,
    required double t,
    GraphPoint? origin,
  }) {
    final clamped = t.clamp(0.0, 1.0);
    final positions = <NodeRef, GraphPoint>{};
    final appear = <NodeRef, double>{};
    for (final entry in to.positions.entries) {
      final start = from.positions[entry.key];
      final a = start ?? origin ?? entry.value;
      final b = entry.value;
      positions[entry.key] = GraphPoint(
        a.x + (b.x - a.x) * clamped,
        a.y + (b.y - a.y) * clamped,
      );
      if (start == null && clamped < 1) appear[entry.key] = clamped;
    }
    return LayoutFrame.fromPositions(
      positions,
      settled: clamped >= 1,
      appear: appear,
    );
  }
}
