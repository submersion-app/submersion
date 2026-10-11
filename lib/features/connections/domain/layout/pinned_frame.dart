import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';

/// A static layout with the diver's dragged nodes put where they dropped
/// them. Pins for nodes no longer on the frame are ignored.
abstract final class PinnedFrame {
  static LayoutFrame apply(LayoutFrame base, Map<NodeRef, GraphPoint> pins) {
    if (pins.isEmpty) return base;
    return LayoutFrame.fromPositions(
      {
        ...base.positions,
        for (final MapEntry(:key, :value) in pins.entries)
          if (base.positions.containsKey(key)) key: value,
      },
      settled: base.settled,
      appear: base.appear,
      guides: base.guides,
    );
  }
}
