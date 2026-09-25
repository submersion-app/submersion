import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// One immutable snapshot of a layout. The painter reads frames and never
/// touches layout state.
class LayoutFrame {
  const LayoutFrame({
    required this.positions,
    required this.bounds,
    required this.settled,
  });

  static const empty = LayoutFrame(
    positions: {},
    bounds: GraphBounds.zero,
    settled: true,
  );

  factory LayoutFrame.fromPositions(
    Map<NodeRef, GraphPoint> positions, {
    required bool settled,
  }) {
    return LayoutFrame(
      positions: Map.unmodifiable(positions),
      bounds: GraphBounds.of(positions.values),
      settled: settled,
    );
  }

  final Map<NodeRef, GraphPoint> positions;
  final GraphBounds bounds;
  final bool settled;
}
