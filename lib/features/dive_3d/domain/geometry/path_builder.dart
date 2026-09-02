import 'dart:typed_data';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

/// The dive path as a tube: two crossed triangle strips (one widened in Z,
/// one widened in Y) along (xOf(t), yOf(depth), z). A thin cross reads as
/// a tube from every camera pose without the cost of a real cylinder.
/// Per-vertex colors come from the color metric's palette.
class PathBuilder {
  static MeshData build({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required Float32List sampleColors,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    const h = SceneBounds.zHalfWidth;
    final positions = Float32List(n * 12);
    final colors = Float32List(n * 12);
    for (var i = 0; i < n; i++) {
      final x = bounds.xOf(times[i]);
      final y = bounds.yOf(depths[i]);
      final z = zs[i];
      // Strip A: pair (2i, 2i+1), widened in Z.
      final a = i * 6;
      positions[a] = x;
      positions[a + 1] = y;
      positions[a + 2] = z - h;
      positions[a + 3] = x;
      positions[a + 4] = y;
      positions[a + 5] = z + h;
      // Strip B: pair (2n+2i, 2n+2i+1), widened in Y.
      final b = n * 6 + i * 6;
      positions[b] = x;
      positions[b + 1] = y - h;
      positions[b + 2] = z;
      positions[b + 3] = x;
      positions[b + 4] = y + h;
      positions[b + 5] = z;
      final c = i * 3;
      for (var k = 0; k < 3; k++) {
        colors[a + k] = sampleColors[c + k];
        colors[a + 3 + k] = sampleColors[c + k];
        colors[b + k] = sampleColors[c + k];
        colors[b + 3 + k] = sampleColors[c + k];
      }
    }
    final stripA = stripIndices(n);
    final indices = Uint32List(stripA.length * 2);
    indices.setRange(0, stripA.length, stripA);
    for (var i = 0; i < stripA.length; i++) {
      indices[stripA.length + i] = stripA[i] + n * 2;
    }
    return MeshData(positions: positions, indices: indices, colors: colors);
  }
}
