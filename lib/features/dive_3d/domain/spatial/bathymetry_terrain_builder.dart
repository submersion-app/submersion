import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_builder.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Converts real bathymetry into the seascape terrain mesh. Unlike the
/// synthesized [TerrainBuilder], this surface is measured data: it never
/// bends to cradle a dive path. Land cells render sand-toned above the
/// waterline (height capped so shorelines read without dominating);
/// nodata cells fill as shoreline at the waterline.
class BathymetryTerrainBuilder {
  static const Color _shallow = Color(0xFF2DD4BF);
  static const Color _deep = Color(0xFF1E3A8A);
  static const Color _land = Color(0xFFC2A878);
  static const Color _water = Color(0xFF3B82F6);
  static const double _waterOpacity = 0.22;
  static const double _landHeightCapFraction = 0.15;

  static const double _metersPerDegLat = 110540.0;

  /// The grid's extent in local east-north meters relative to [center].
  static ({double minEast, double maxEast, double minNorth, double maxNorth})
  enuBounds(BathymetryGrid grid, GeoPoint center) {
    final mLon = metersPerDegreeLongitude(center.latitude);
    final minEast = (grid.originLon - center.longitude) * mLon;
    final maxEast =
        (grid.originLon +
            grid.cellSizeLonDeg * (grid.cols - 1) -
            center.longitude) *
        mLon;
    final minNorth = (grid.originLat - center.latitude) * _metersPerDegLat;
    final maxNorth =
        (grid.originLat +
            grid.cellSizeLatDeg * (grid.rows - 1) -
            center.latitude) *
        _metersPerDegLat;
    return (
      minEast: minEast,
      maxEast: maxEast,
      minNorth: minNorth,
      maxNorth: maxNorth,
    );
  }

  static SpatialTerrain build({
    required BathymetryGrid grid,
    required GeoPoint center,
    required SpatialProjection projection,
  }) {
    final rows = grid.rows, cols = grid.cols;
    final mLon = metersPerDegreeLongitude(center.latitude);
    final maxDepth = math.max(projection.maxDepth, 1.0);
    final landCap = _landHeightCapFraction * maxDepth;

    final positions = Float32List(rows * cols * 3);
    final colors = Float32List(rows * cols * 3);
    for (var r = 0; r < rows; r++) {
      final north =
          (grid.originLat + grid.cellSizeLatDeg * r - center.latitude) *
          _metersPerDegLat;
      for (var c = 0; c < cols; c++) {
        final east =
            (grid.originLon + grid.cellSizeLonDeg * c - center.longitude) *
            mLon;
        final raw = grid.depthAt(r, c);
        // nodata -> shoreline; land elevation capped so peaks stay modest.
        final depth = raw == null ? 0.0 : math.max(raw, -landCap);
        final vi = (r * cols + c) * 3;
        positions[vi] = projection.xOf(east);
        positions[vi + 1] = projection.yOf(depth);
        positions[vi + 2] = projection.zOf(north);
        final Color color;
        if (raw == null || raw <= 0) {
          color = _land;
        } else {
          final t = (depth / maxDepth).clamp(0.0, 1.0);
          color = Color.lerp(_shallow, _deep, t)!;
        }
        colors[vi] = color.r;
        colors[vi + 1] = color.g;
        colors[vi + 2] = color.b;
      }
    }
    final terrain = MeshData(
      positions: positions,
      indices: _gridIndices(rows, cols),
      colors: colors,
    );

    final b = enuBounds(grid, center);
    final wPos = Float32List(4 * 3);
    final wCol = Float32List(4 * 3);
    final corners = [
      [b.minEast, b.minNorth],
      [b.maxEast, b.minNorth],
      [b.minEast, b.maxNorth],
      [b.maxEast, b.maxNorth],
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

  static Uint32List _gridIndices(int rows, int cols) {
    if (rows < 2 || cols < 2) return Uint32List(0);
    final indices = Uint32List((rows - 1) * (cols - 1) * 6);
    var q = 0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final a = r * cols + c;
        final b = r * cols + c + 1;
        final d = (r + 1) * cols + c;
        final e = (r + 1) * cols + c + 1;
        indices[q++] = a;
        indices[q++] = b;
        indices[q++] = d;
        indices[q++] = b;
        indices[q++] = e;
        indices[q++] = d;
      }
    }
    return indices;
  }
}
