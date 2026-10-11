import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_guide.dart';
import 'package:submersion/features/connections/domain/layout/layout_morph.dart';
import 'package:submersion/features/connections/domain/layout/pinned_frame.dart';

const _a = NodeRef(ConnectionKind.buddy, 'a');
const _b = NodeRef(ConnectionKind.buddy, 'b');

void main() {
  final guides = [
    const YearGuide(2020, GraphPoint(0, -70)),
    const LaneGuide(ConnectionKind.buddy, GraphPoint(-70, 0)),
  ];
  final base = LayoutFrame.fromPositions(
    {_a: GraphPoint.zero, _b: const GraphPoint(100, 50)},
    settled: true,
    guides: guides,
  );

  test('bounds take in the guide anchors', () {
    expect(base.bounds, const GraphBounds(-70, -70, 100, 50));
  });

  test('a morph carries the target guides', () {
    final from = LayoutFrame.fromPositions({
      _a: GraphPoint.zero,
    }, settled: true);
    expect(LayoutMorph.at(from: from, to: base, t: 0.5).guides, guides);
  });

  test('no pins returns the base frame itself', () {
    expect(identical(PinnedFrame.apply(base, const {}), base), isTrue);
  });

  test('pins move only nodes on the frame and keep the guides', () {
    final pinned = PinnedFrame.apply(base, {
      _a: const GraphPoint(30, 30),
      const NodeRef(ConnectionKind.site, 'gone'): const GraphPoint(1, 1),
    });
    expect(pinned.positions[_a], const GraphPoint(30, 30));
    expect(pinned.positions[_b], const GraphPoint(100, 50));
    expect(pinned.positions.length, 2);
    expect(pinned.guides, guides);
    expect(pinned.settled, isTrue);
  });
}
