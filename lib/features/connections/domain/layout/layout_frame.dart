import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

/// One immutable snapshot of a layout. The painter reads frames and never
/// touches layout state.
class LayoutFrame {
  const LayoutFrame({
    required this.positions,
    required this.bounds,
    required this.settled,
    this.appear = const {},
  });

  static const empty = LayoutFrame(
    positions: {},
    bounds: GraphBounds.zero,
    settled: true,
  );

  factory LayoutFrame.fromPositions(
    Map<NodeRef, GraphPoint> positions, {
    required bool settled,
    Map<NodeRef, double> appear = const {},
  }) {
    return LayoutFrame(
      positions: Map.unmodifiable(positions),
      bounds: GraphBounds.of(positions.values),
      settled: settled,
      appear: Map.unmodifiable(appear),
    );
  }

  final Map<NodeRef, GraphPoint> positions;
  final GraphBounds bounds;
  final bool settled;

  /// 0 to 1 per node while it grows in during a refocus; absent means 1.
  final Map<NodeRef, double> appear;

  double appearOf(NodeRef ref) => appear[ref] ?? 1;
}
