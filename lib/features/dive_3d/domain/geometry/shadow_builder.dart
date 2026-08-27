import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

typedef ShadowMeshes = ({MeshData walls, MeshData drops});

/// Projects the path onto the three walls of the scene box as thin gray
/// strips (the same thin-quad trick the old grid used, so the painter needs
/// no line primitive), plus sparse vertical drop lines from the path to the
/// floor. Each shadow is a 2D chart: depth vs time on the back wall,
/// metric vs time on the floor, depth vs metric on the left wall.
class ShadowBuilder {
  static const Color _color = Color(0xFF9CA3AF);
  static const double wallOpacity = 0.45;
  static const double dropOpacity = 0.3;
  static const double halfThickness = 0.015;

  /// Offset off each wall toward the box interior so the strip never
  /// z-fights the frame grid drawn behind the scene.
  static const double lift = 0.02;
  static const int dropLineTarget = 24;

  static ShadowMeshes build({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    final xs = [for (final t in times) bounds.xOf(t)];
    final ys = [for (final d in depths) bounds.yOf(d)];
    final zBack = bounds.sceneMinZ + lift;
    final yFloor = bounds.sceneMinY + lift;

    final positions = Float32List(n * 18);
    for (var i = 0; i < n; i++) {
      final x = xs[i], y = ys[i], z = zs[i];
      // Back wall (z fixed): widened in Y.
      _pair(
        positions,
        i * 6,
        x,
        y - halfThickness,
        zBack,
        x,
        y + halfThickness,
        zBack,
      );
      // Floor (y fixed): widened in Z.
      _pair(
        positions,
        n * 6 + i * 6,
        x,
        yFloor,
        z - halfThickness,
        x,
        yFloor,
        z + halfThickness,
      );
      // Left wall (x fixed): widened in Y.
      _pair(
        positions,
        n * 12 + i * 6,
        lift,
        y - halfThickness,
        z,
        lift,
        y + halfThickness,
        z,
      );
    }
    final strip = stripIndices(n);
    final indices = Uint32List(strip.length * 3);
    for (var s = 0; s < 3; s++) {
      for (var i = 0; i < strip.length; i++) {
        indices[s * strip.length + i] = strip[i] + s * n * 2;
      }
    }
    final walls = MeshData(
      positions: positions,
      indices: indices,
      colors: _flat(n * 6),
      opacity: wallOpacity,
    );

    final step = math.max(1, (n / dropLineTarget).round());
    final picks = [for (var i = 0; i < n; i += step) i];
    final dropPositions = Float32List(picks.length * 12);
    final dropIndices = Uint32List(picks.length * 6);
    for (var j = 0; j < picks.length; j++) {
      final i = picks[j];
      final x = xs[i], y = ys[i], z = zs[i];
      final p = j * 12;
      _pair(dropPositions, p, x, y, z - halfThickness, x, y, z + halfThickness);
      _pair(
        dropPositions,
        p + 6,
        x,
        bounds.sceneMinY,
        z - halfThickness,
        x,
        bounds.sceneMinY,
        z + halfThickness,
      );
      final base = j * 4, q = j * 6;
      dropIndices[q] = base;
      dropIndices[q + 1] = base + 1;
      dropIndices[q + 2] = base + 2;
      dropIndices[q + 3] = base + 1;
      dropIndices[q + 4] = base + 3;
      dropIndices[q + 5] = base + 2;
    }
    final drops = MeshData(
      positions: dropPositions,
      indices: dropIndices,
      colors: _flat(picks.length * 4),
      opacity: dropOpacity,
    );
    return (walls: walls, drops: drops);
  }

  static void _pair(
    Float32List out,
    int at,
    double x1,
    double y1,
    double z1,
    double x2,
    double y2,
    double z2,
  ) {
    out[at] = x1;
    out[at + 1] = y1;
    out[at + 2] = z1;
    out[at + 3] = x2;
    out[at + 4] = y2;
    out[at + 5] = z2;
  }

  static Float32List _flat(int vertexCount) {
    final colors = Float32List(vertexCount * 3);
    for (var v = 0; v < vertexCount; v++) {
      colors[v * 3] = _color.r;
      colors[v * 3 + 1] = _color.g;
      colors[v * 3 + 2] = _color.b;
    }
    return colors;
  }
}
