import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Builds the core dive object: the depth-time curve extruded laterally
/// into a triangle-strip ribbon, plus the translucent curtain that falls
/// from the ribbon to the max-depth plane (the 3D analogue of the 2D
/// chart's area fill).
class RibbonBuilder {
  static const Color _curtainColor = Color(0xFF0077B6);
  static const double _curtainOpacity = 0.15;

  static MeshData build({
    required List<double> times,
    required List<double> depths,
    required Float32List sampleColors,
    required SceneBounds bounds,
    double zCenter = 0,
    double opacity = 1.0,
  }) {
    final n = times.length;
    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    for (var i = 0; i < n; i++) {
      final x = bounds.xOf(times[i]);
      final y = bounds.yOf(depths[i]);
      final p = i * 6;
      positions[p] = x;
      positions[p + 1] = y;
      positions[p + 2] = zCenter - SceneBounds.zHalfWidth;
      positions[p + 3] = x;
      positions[p + 4] = y;
      positions[p + 5] = zCenter + SceneBounds.zHalfWidth;
      final c = i * 3;
      for (var k = 0; k < 3; k++) {
        colors[p + k] = sampleColors[c + k];
        colors[p + 3 + k] = sampleColors[c + k];
      }
    }
    return MeshData(
      positions: positions,
      indices: _stripIndices(n),
      colors: colors,
      opacity: opacity,
    );
  }

  static MeshData curtain({
    required List<double> times,
    required List<double> depths,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    const floorY = -SceneBounds.ySpan;
    for (var i = 0; i < n; i++) {
      final x = bounds.xOf(times[i]);
      final p = i * 6;
      positions[p] = x;
      positions[p + 1] = bounds.yOf(depths[i]);
      positions[p + 2] = 0;
      positions[p + 3] = x;
      positions[p + 4] = floorY;
      positions[p + 5] = 0;
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = _curtainColor.r;
        colors[p + k * 3 + 1] = _curtainColor.g;
        colors[p + k * 3 + 2] = _curtainColor.b;
      }
    }
    return MeshData(
      positions: positions,
      indices: _stripIndices(n),
      colors: colors,
      opacity: _curtainOpacity,
    );
  }

  /// Indices for a strip of n vertex pairs: two triangles per segment.
  static Uint32List _stripIndices(int pairCount) {
    if (pairCount < 2) return Uint32List(0);
    final indices = Uint32List((pairCount - 1) * 6);
    var j = 0;
    for (var i = 0; i < pairCount - 1; i++) {
      final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
      indices[j++] = a;
      indices[j++] = b;
      indices[j++] = c;
      indices[j++] = b;
      indices[j++] = d;
      indices[j++] = c;
    }
    return indices;
  }
}
