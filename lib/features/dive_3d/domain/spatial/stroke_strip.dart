import 'dart:typed_data';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

/// Two points closer than this, in scene units, are one point: a line
/// whose last point lands back on its first is closed.
const double _closeTolerance = 1e-4;

/// Builds a stroke mesh (see [MeshData.strokeHalfWidthPx]) along [xyz],
/// three scene coordinates per point: one vertex pair at each end and two
/// on every interior point, so the renderer can end the arriving leg and
/// start the leaving one at full width and bevel the corner between them.
/// A closed line (its last point back on its first) gets two pairs on its
/// closing point as well, written at the first point's exact coordinates,
/// so the renderer recognizes the seam and bevels it like any other
/// corner. Fewer than two points give an empty mesh.
///
/// [colorAt] gives a point's rgb (0..1); [sortHeightAt], when given, its
/// depth-sort height (see [MeshData.sortHeights]).
MeshData buildStrokeStrip({
  required List<double> xyz,
  required double strokeHalfWidthPx,
  required (double, double, double) Function(int point) colorAt,
  double Function(int point)? sortHeightAt,
  double opacity = 1.0,
}) {
  final n = xyz.length ~/ 3;
  if (n < 2) {
    return MeshData(
      positions: Float32List(0),
      indices: Uint32List(0),
      colors: Float32List(0),
      opacity: opacity,
    );
  }
  final last = (n - 1) * 3;
  final closed =
      n > 2 &&
      (xyz[0] - xyz[last]).abs() <= _closeTolerance &&
      (xyz[1] - xyz[last + 1]).abs() <= _closeTolerance &&
      (xyz[2] - xyz[last + 2]).abs() <= _closeTolerance;
  final pairCount = closed ? 2 * n - 1 : 2 * n - 2;
  final positions = Float32List(pairCount * 6);
  final colors = Float32List(pairCount * 6);
  final sortHeights = sortHeightAt == null ? null : Float32List(pairCount * 2);
  var pair = 0;
  for (var i = 0; i < n; i++) {
    final src = closed && i == n - 1 ? 0 : i;
    final x = xyz[src * 3], y = xyz[src * 3 + 1], z = xyz[src * 3 + 2];
    final (r, g, b) = colorAt(i);
    final sortHeight = sortHeightAt?.call(i);
    final copies = i == 0 || (i == n - 1 && !closed) ? 1 : 2;
    for (var c = 0; c < copies; c++, pair++) {
      for (var s = 0; s < 2; s++) {
        final vi = pair * 6 + s * 3;
        positions[vi] = x;
        positions[vi + 1] = y;
        positions[vi + 2] = z;
        colors[vi] = r;
        colors[vi + 1] = g;
        colors[vi + 2] = b;
        if (sortHeights != null) sortHeights[pair * 2 + s] = sortHeight!;
      }
    }
  }
  return MeshData(
    positions: positions,
    indices: stripIndices(pairCount),
    colors: colors,
    opacity: opacity,
    sortHeights: sortHeights,
    strokeHalfWidthPx: strokeHalfWidthPx,
  );
}
