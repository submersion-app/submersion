import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

/// The synthesized seascape geometry: a seafloor heightmap that cradles the
/// swim path and a translucent water-surface plane at the waterline.
class SpatialTerrain {
  final MeshData terrain;
  final MeshData water;

  const SpatialTerrain({required this.terrain, required this.water});
}

/// Synthesizes a plausible seafloor from the reconstructed path: each grid
/// cell's depth is inverse-distance-weighted from nearby path samples and
/// floored to cradle the deepest nearby excursion, so the path always rides
/// above the terrain. NOT surveyed bathymetry - a defensible reconstruction.
class TerrainBuilder {
  static const Color _shallow = Color(0xFF2DD4BF);
  static const Color _deep = Color(0xFF1E3A8A);
  static const Color _water = Color(0xFF3B82F6);
  static const double _waterOpacity = 0.22;

  /// Grids the seafloor over the caller-provided world box (already padded)
  /// so the terrain and its projection share one box and stay inside the
  /// projector's fit.
  static SpatialTerrain build({
    required ReckonedPath path,
    required SpatialProjection projection,
    required double minEast,
    required double maxEast,
    required double minNorth,
    required double maxNorth,
    int gridResolution = 28,
  }) {
    final g = gridResolution;
    final pts = path.points;
    final minE = minEast, maxE = maxEast;
    final minN = minNorth, maxN = maxNorth;

    final floor = path.maxDepth;
    final positions = Float32List(g * g * 3);
    final colors = Float32List(g * g * 3);
    for (var iz = 0; iz < g; iz++) {
      final fz = g == 1 ? 0.0 : iz / (g - 1);
      final north = minN + (maxN - minN) * fz;
      for (var ix = 0; ix < g; ix++) {
        final fx = g == 1 ? 0.0 : ix / (g - 1);
        final east = minE + (maxE - minE) * fx;
        final depth = _terrainDepth(east, north, pts, floor);
        final vi = (iz * g + ix) * 3;
        positions[vi] = projection.xOf(east);
        positions[vi + 1] = projection.yOf(depth);
        positions[vi + 2] = projection.zOf(north);
        final t = projection.maxDepth <= 0
            ? 0.0
            : (depth / projection.maxDepth).clamp(0.0, 1.0);
        final color = Color.lerp(_shallow, _deep, t)!;
        colors[vi] = color.r;
        colors[vi + 1] = color.g;
        colors[vi + 2] = color.b;
      }
    }
    final terrain = MeshData(
      positions: positions,
      indices: _gridIndices(g),
      colors: colors,
    );

    // Water plane: one quad over the same box at Y = 0.
    final wPos = Float32List(4 * 3);
    final wCol = Float32List(4 * 3);
    final corners = [
      [minE, minN],
      [maxE, minN],
      [minE, maxN],
      [maxE, maxN],
    ];
    for (var i = 0; i < 4; i++) {
      wPos[i * 3] = projection.xOf(corners[i][0]);
      wPos[i * 3 + 1] = 0;
      wPos[i * 3 + 2] = projection.zOf(corners[i][1]);
      wCol[i * 3] = _water.r;
      wCol[i * 3 + 1] = _water.g;
      wCol[i * 3 + 2] = _water.b;
    }
    final water = MeshData(
      positions: wPos,
      indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
      colors: wCol,
      opacity: _waterOpacity,
    );

    return SpatialTerrain(terrain: terrain, water: water);
  }

  static double _terrainDepth(
    double east,
    double north,
    List<ReckonedPoint> pts,
    double floor,
  ) {
    if (pts.isEmpty) return floor;
    var num = 0.0, den = 0.0, nearMax = 0.0;
    for (final p in pts) {
      final de = east - p.east, dn = north - p.north;
      final d2 = de * de + dn * dn;
      final w = 1.0 / (d2 + 4.0);
      num += p.depth * w;
      den += w;
      if (d2 < 25.0 && p.depth > nearMax) nearMax = p.depth;
    }
    final idw = den > 0 ? num / den : floor;
    // Cradle: at least as deep as the deepest nearby excursion.
    return idw > nearMax ? idw : nearMax;
  }

  static Uint32List _gridIndices(int g) {
    if (g < 2) return Uint32List(0);
    final indices = Uint32List((g - 1) * (g - 1) * 6);
    var q = 0;
    for (var iz = 0; iz < g - 1; iz++) {
      for (var ix = 0; ix < g - 1; ix++) {
        final a = iz * g + ix;
        final b = iz * g + ix + 1;
        final c = (iz + 1) * g + ix;
        final d = (iz + 1) * g + ix + 1;
        indices[q++] = a;
        indices[q++] = b;
        indices[q++] = c;
        indices[q++] = b;
        indices[q++] = d;
        indices[q++] = c;
      }
    }
    return indices;
  }
}
