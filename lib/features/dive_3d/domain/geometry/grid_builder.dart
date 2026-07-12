import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Faint horizontal reference lines at round depth intervals in the
/// diver's display unit (step is passed in meters, pre-converted by the
/// caller). Rendered as thin quads so both renderers reuse the triangle
/// pipeline. Text labels are deliberately deferred (plan deviation 5);
/// the readout panel carries the numeric context.
class GridBuilder {
  static const Color _color = Color(0xFF6B7280);
  static const double _opacity = 0.25;
  static const double _halfThickness = 0.015;

  static MeshData? build({
    required SceneBounds bounds,
    required double stepMeters,
  }) {
    if (stepMeters <= 0 || bounds.maxDepthMeters < stepMeters) return null;
    final steps = <double>[];
    for (var d = stepMeters; d <= bounds.maxDepthMeters; d += stepMeters) {
      steps.add(d);
    }
    final positions = Float32List(steps.length * 12);
    final colors = Float32List(steps.length * 12);
    final indices = Uint32List(steps.length * 6);
    const z = SceneBounds.zSlabHalfWidth;
    for (var i = 0; i < steps.length; i++) {
      final y = bounds.yOf(steps[i]);
      final p = i * 12;
      final corners = [
        [0.0, y - _halfThickness, z],
        [0.0, y + _halfThickness, z],
        [SceneBounds.xSpan, y - _halfThickness, z],
        [SceneBounds.xSpan, y + _halfThickness, z],
      ];
      for (var v = 0; v < 4; v++) {
        positions[p + v * 3] = corners[v][0];
        positions[p + v * 3 + 1] = corners[v][1];
        positions[p + v * 3 + 2] = corners[v][2];
        colors[p + v * 3] = _color.r;
        colors[p + v * 3 + 1] = _color.g;
        colors[p + v * 3 + 2] = _color.b;
      }
      final base = i * 4;
      final q = i * 6;
      indices[q] = base;
      indices[q + 1] = base + 1;
      indices[q + 2] = base + 2;
      indices[q + 3] = base + 1;
      indices[q + 4] = base + 3;
      indices[q + 5] = base + 2;
    }
    return MeshData(
      positions: positions,
      indices: indices,
      colors: colors,
      opacity: _opacity,
    );
  }
}
