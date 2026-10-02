import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/connections/domain/layout/graph_point.dart';
import 'package:submersion/features/connections/presentation/canvas/graph_viewport.dart';

/// Interpolates the camera between two viewports: scale in log space, so a
/// zoom in and a zoom out feel equally paced, and the graph point under the
/// screen centre moves in a straight line, so the camera travels rather than
/// swinging about a corner.
class CameraTween {
  CameraTween(this.from, this.to, this.size)
    : _centre = Offset(size.width / 2, size.height / 2);

  final GraphViewport from;
  final GraphViewport to;
  final Size size;
  final Offset _centre;

  GraphViewport at(double t) {
    final scale = math.exp(
      math.log(from.scale) + (math.log(to.scale) - math.log(from.scale)) * t,
    );
    final a = from.toGraph(_centre);
    final b = to.toGraph(_centre);
    final c = GraphPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
    return GraphViewport(
      scale: scale,
      offset: Offset(_centre.dx - c.x * scale, _centre.dy - c.y * scale),
    );
  }
}
