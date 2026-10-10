import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

/// Builds the swim path as a bright 3D ribbon threading the seascape, plus
/// entry/exit "pins" dropped from the water surface to the path ends.
class SpatialPathBuilder {
  /// Scene units to either side of the path. At 0.08 the track read as a
  /// band rather than a line next to the isobaths (issue #3215).
  static const double ribbonHalfWidth = majorContourHalfWidth;
  static const Color _shallowPath = Color(0xFFFDE047); // yellow
  static const Color _deepPath = Color(0xFFF97316); // orange
  static const Color _entryColor = Color(0xFF22C55E); // green
  static const Color _exitColor = Color(0xFFEF4444); // red

  /// The path ribbon: a thin horizontal-perpendicular extrusion following
  /// the route, colored by depth so it reads against the terrain.
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
    final xs = [for (final p in pts) proj.xOf(p.east)];
    final ys = [for (final p in pts) proj.yOf(p.depth)];
    final zs = [for (final p in pts) proj.zOf(p.north)];

    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    // Side vector: perpendicular in xz, rotated the way the map frame
    // turns: scene Z runs SOUTH (see SpatialProjection), so the sense is
    // (tz, -tx). A zero-length segment (a stationary stop) has no tangent,
    // so it keeps the previous side vector instead of pinching the ribbon
    // to a point; before the first real segment it faces the first one.
    var px = 0.0, pz = -1.0;
    for (var j = 0; j < n - 1; j++) {
      final tx = xs[j + 1] - xs[j];
      final tz = zs[j + 1] - zs[j];
      final len = math.sqrt(tx * tx + tz * tz);
      if (len > 1e-9) {
        px = tz / len;
        pz = -tx / len;
        break;
      }
    }
    for (var i = 0; i < n; i++) {
      // Horizontal tangent (forward difference, last uses previous).
      final j = i < n - 1 ? i : i - 1;
      final tx = xs[j + 1] - xs[j];
      final tz = zs[j + 1] - zs[j];
      final len = math.sqrt(tx * tx + tz * tz);
      if (len > 1e-9) {
        px = tz / len;
        pz = -tx / len;
      }
      final t = proj.maxDepth <= 0
          ? 0.0
          : (pts[i].depth / proj.maxDepth).clamp(0.0, 1.0);
      final color = Color.lerp(_shallowPath, _deepPath, t)!;
      final vi = i * 6;
      positions[vi] = xs[i] - px * ribbonHalfWidth;
      positions[vi + 1] = ys[i];
      positions[vi + 2] = zs[i] - pz * ribbonHalfWidth;
      positions[vi + 3] = xs[i] + px * ribbonHalfWidth;
      positions[vi + 4] = ys[i];
      positions[vi + 5] = zs[i] + pz * ribbonHalfWidth;
      for (var s = 0; s < 2; s++) {
        colors[vi + s * 3] = color.r;
        colors[vi + s * 3 + 1] = color.g;
        colors[vi + s * 3 + 2] = color.b;
      }
    }
    return MeshData(
      positions: positions,
      indices: _stripIndices(n),
      colors: colors,
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
