import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

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
      indices: stripIndices(n),
      colors: colors,
      opacity: opacity,
    );
  }

  static MeshData curtain({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    final floorY = bounds.sceneMinY;
    for (var i = 0; i < n; i++) {
      final x = bounds.xOf(times[i]);
      final p = i * 6;
      positions[p] = x;
      positions[p + 1] = bounds.yOf(depths[i]);
      positions[p + 2] = zs[i];
      positions[p + 3] = x;
      positions[p + 4] = floorY;
      positions[p + 5] = zs[i];
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = _curtainColor.r;
        colors[p + k * 3 + 1] = _curtainColor.g;
        colors[p + k * 3 + 2] = _curtainColor.b;
      }
    }
    return MeshData(
      positions: positions,
      indices: stripIndices(n),
      colors: colors,
      opacity: _curtainOpacity,
    );
  }
}
