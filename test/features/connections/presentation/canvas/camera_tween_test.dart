import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/presentation/canvas/camera_tween.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

void main() {
  const size = Size(400, 300);
  const from = GraphViewport(scale: 0.5, offset: Offset(10, 20));
  const to = GraphViewport(scale: 2, offset: Offset(-300, -100));

  test('the endpoints are the two viewports', () {
    final tween = CameraTween(from, to, size);
    expect(tween.at(0).scale, closeTo(0.5, 1e-9));
    expect(tween.at(0).offset.dx, closeTo(10, 1e-6));
    expect(tween.at(1).scale, closeTo(2, 1e-9));
    expect(tween.at(1).offset.dy, closeTo(-100, 1e-6));
  });

  test('scale blends in log space', () {
    expect(
      CameraTween(from, to, size).at(0.5).scale,
      closeTo(math.sqrt(1), 1e-9),
    );
  });

  test('the centre point travels linearly', () {
    final tween = CameraTween(from, to, size);
    const centre = Offset(200, 150);
    final a = from.toGraph(centre);
    final b = to.toGraph(centre);
    final mid = tween.at(0.5).toGraph(centre);
    expect(mid.x, closeTo((a.x + b.x) / 2, 1e-6));
    expect(mid.y, closeTo((a.y + b.y) / 2, 1e-6));
  });
}
