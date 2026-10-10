import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/stroke_strip.dart';

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
    final xyz = Float32List(pts.length * 3);
    for (final (i, p) in pts.indexed) {
      xyz[i * 3] = proj.xOf(p.east);
      xyz[i * 3 + 1] = proj.yOf(p.depth);
      xyz[i * 3 + 2] = proj.zOf(p.north);
    }
    return buildStrokeStrip(
      xyz: xyz,
      strokeHalfWidthPx: strokeHalfWidthPx,
      colorAt: (i) {
        final t = proj.maxDepth <= 0
            ? 0.0
            : (pts[i].depth / proj.maxDepth).clamp(0.0, 1.0);
        final color = Color.lerp(_shallowPath, _deepPath, t)!;
        return (color.r, color.g, color.b);
      },
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
}
