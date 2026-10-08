import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';

void main() {
  test('arithmetic and distance', () {
    const a = GraphPoint(1, 2);
    const b = GraphPoint(4, 6);
    expect(a + b, const GraphPoint(5, 8));
    expect(b - a, const GraphPoint(3, 4));
    expect(a.distanceTo(b), 5);
    expect(a.scaled(2), const GraphPoint(2, 4));
    expect(const GraphPoint(double.nan, 0).isFinite, isFalse);
  });

  test('bounds of points, inflate and translate', () {
    final b = GraphBounds.of(const [GraphPoint(-1, 2), GraphPoint(3, -4)]);
    expect(b.left, -1);
    expect(b.top, -4);
    expect(b.right, 3);
    expect(b.bottom, 2);
    expect(b.width, 4);
    expect(b.height, 6);
    expect(b.center, const GraphPoint(1, -1));
    expect(b.inflate(1).width, 6);
    expect(b.translate(10, 0).left, 9);
    expect(GraphBounds.of(const []), GraphBounds.zero);
    expect(GraphBounds.zero.isEmpty, isTrue);
  });
}
