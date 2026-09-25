import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

void main() {
  test('toScreen and toGraph invert each other', () {
    final v = GraphViewport(scale: 2, offset: const Offset(10, 20));
    expect(v.toScreen(const GraphPoint(5, 5)), const Offset(20, 30));
    final back = v.toGraph(const Offset(20, 30));
    expect(back.x, closeTo(5, 1e-9));
    expect(back.y, closeTo(5, 1e-9));
  });

  test('fitted centres the bounds and clamps the scale', () {
    const bounds = GraphBounds(-100, -50, 100, 50);
    final v = const GraphViewport().fitted(
      bounds,
      const Size(400, 400),
      padding: 0,
    );
    expect(v.scale, closeTo(2, 1e-9));
    expect(v.toScreen(bounds.center), const Offset(200, 200));
    final huge = const GraphViewport().fitted(
      const GraphBounds(0, 0, 1, 1),
      const Size(400, 400),
    );
    expect(huge.scale, GraphViewport.maxScale);
    final empty = const GraphViewport().fitted(
      GraphBounds.zero,
      const Size(400, 400),
    );
    expect(empty.scale, 1);
    expect(empty.toScreen(GraphPoint.zero), const Offset(200, 200));
  });

  test('zoomedAt keeps the focal point fixed', () {
    final v = GraphViewport(scale: 1, offset: const Offset(50, 50));
    const focal = Offset(120, 80);
    final under = v.toGraph(focal);
    final z = v.zoomedAt(1.5, focal);
    expect(z.scale, closeTo(1.5, 1e-9));
    final after = z.toScreen(under);
    expect(after.dx, closeTo(focal.dx, 1e-6));
    expect(after.dy, closeTo(focal.dy, 1e-6));
  });

  test('clampedTo keeps part of the graph on screen', () {
    const bounds = GraphBounds(0, 0, 100, 100);
    final gone = GraphViewport(scale: 1, offset: const Offset(-5000, -5000));
    final v = gone.clampedTo(bounds, const Size(400, 400));
    final right = v.toScreen(const GraphPoint(100, 100));
    expect(right.dx, greaterThanOrEqualTo(48));
    expect(right.dy, greaterThanOrEqualTo(48));
  });
}
