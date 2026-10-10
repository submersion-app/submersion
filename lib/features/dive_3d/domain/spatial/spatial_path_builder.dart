import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

/// Builds the swim path as a bright 3D line threading the seascape, plus
/// entry/exit "pins" dropped from the water surface to the path ends.
class SpatialPathBuilder {
  /// Half-width of the track on the canvas, in logical pixels (see
  /// [MeshData.strokeHalfWidthPx]). A width in scene units grew with the
  /// terrain when zooming in and read as a band, not a line (issue #3215).
  static const double strokeHalfWidthPx = 1.5;
  static const Color _shallowPath = Color(0xFFFDE047); // yellow
  static const Color _deepPath = Color(0xFFF97316); // orange
  static const Color _entryColor = Color(0xFF22C55E); // green
  static const Color _exitColor = Color(0xFFEF4444); // red

  /// The path stroke: a strip of vertex pairs on the route, colored by
  /// depth so it reads against the terrain. The renderer gives it its
  /// width on the canvas.
  static MeshData buildRibbon(ReckonedPath path, SpatialProjection proj) {
    final pts = path.points;
    final n = pts.length;
    if (n < 2) {
      return MeshData(
        positions: Float32List(0),
        indices: Uint32List(0),
        colors: Float32List(0),
      );
    }
    // Two pairs on every interior point, one per leg meeting there (see
    // MeshData.strokeHalfWidthPx).
    final pairCount = 2 * n - 2;
    final positions = Float32List(pairCount * 6);
    final colors = Float32List(pairCount * 6);
    var pair = 0;
    for (var i = 0; i < n; i++) {
      final p = pts[i];
      final x = proj.xOf(p.east);
      final y = proj.yOf(p.depth);
      final z = proj.zOf(p.north);
      final t = proj.maxDepth <= 0
          ? 0.0
          : (p.depth / proj.maxDepth).clamp(0.0, 1.0);
      final color = Color.lerp(_shallowPath, _deepPath, t)!;
      final copies = i == 0 || i == n - 1 ? 1 : 2;
      for (var c = 0; c < copies; c++, pair++) {
        for (var s = 0; s < 2; s++) {
          final vi = pair * 6 + s * 3;
          positions[vi] = x;
          positions[vi + 1] = y;
          positions[vi + 2] = z;
          colors[vi] = color.r;
          colors[vi + 1] = color.g;
          colors[vi + 2] = color.b;
        }
      }
    }
    return MeshData(
      positions: positions,
      indices: _stripIndices(pairCount),
      colors: colors,
      strokeHalfWidthPx: strokeHalfWidthPx,
    );
  }

  /// A thin vertical pin from the water surface (Y=0) down to [point].
  static MeshData buildPin(
    ReckonedPoint point,
    SpatialProjection proj, {
    required bool isEntry,
  }) {
    final x = proj.xOf(point.east);
    final z = proj.zOf(point.north);
    final yBottom = proj.yOf(point.depth);
    const w = 0.05;
    final color = isEntry ? _entryColor : _exitColor;
    final positions = Float32List.fromList([
      x - w,
      0,
      z,
      x + w,
      0,
      z,
      x - w,
      yBottom,
      z,
      x + w,
      yBottom,
      z,
    ]);
    final colors = Float32List(4 * 3);
    for (var i = 0; i < 4; i++) {
      colors[i * 3] = color.r;
      colors[i * 3 + 1] = color.g;
      colors[i * 3 + 2] = color.b;
    }
    return MeshData(
      positions: positions,
      indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
      colors: colors,
    );
  }

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
