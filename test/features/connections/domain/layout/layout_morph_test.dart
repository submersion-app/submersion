import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/domain/layout/layout_frame.dart';
import 'package:submersion/features/connections/domain/layout/layout_morph.dart';

NodeRef _b(String id) => NodeRef(ConnectionKind.buddy, id);

void main() {
  final from = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(0, 0),
    _b('gone'): const GraphPoint(50, 50),
  }, settled: true);
  final to = LayoutFrame.fromPositions({
    _b('a'): const GraphPoint(100, 0),
    _b('new'): const GraphPoint(0, 100),
  }, settled: true);

  test('the endpoints', () {
    final start = LayoutMorph.at(
      from: from,
      to: to,
      t: 0,
      origin: GraphPoint.zero,
    );
    expect(start.positions[_b('a')], const GraphPoint(0, 0));
    expect(start.positions[_b('new')], GraphPoint.zero);
    expect(start.appearOf(_b('new')), 0);
    expect(start.positions.containsKey(_b('gone')), isFalse);
    expect(start.settled, isFalse);
    final end = LayoutMorph.at(
      from: from,
      to: to,
      t: 1,
      origin: GraphPoint.zero,
    );
    expect(end.positions, to.positions);
    expect(end.appearOf(_b('new')), 1);
    expect(end.settled, isTrue);
  });

  test('halfway slides and grows', () {
    final mid = LayoutMorph.at(
      from: from,
      to: to,
      t: 0.5,
      origin: GraphPoint.zero,
    );
    expect(mid.positions[_b('a')], const GraphPoint(50, 0));
    expect(mid.positions[_b('new')], const GraphPoint(0, 50));
    expect(mid.appearOf(_b('new')), 0.5);
    expect(mid.appearOf(_b('a')), 1);
  });
}
