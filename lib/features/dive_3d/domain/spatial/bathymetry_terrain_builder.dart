import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/slippy_tiles.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
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
  static const Color shallowColor = Color(0xFF2DD4BF);
  static const Color deepColor = Color(0xFF1E3A8A);
  static const Color landColor = Color(0xFFC2A878);
  static const Color _water = Color(0xFF3B82F6);
  static const double _waterOpacity = 0.22;
  static const double _landHeightCapFraction = 0.15;

  static const double metersPerDegLat = 110540.0;

  /// How far above the waterline land is allowed to rise, so shorelines
  /// read without dominating the scene. Hoist it out of per-node loops.
  static double landHeightCap(SpatialProjection projection) =>
      _landHeightCapFraction * math.max(projection.maxDepth, 1.0);

  /// The depth one raw grid sample renders at: nodata fills as shoreline,
  /// land elevation is capped. THE definition of the rendered surface, so
  /// the mesh and anything draped on it cannot drift apart.
  static double surfaceDepth(double? raw, double landCap) =>
      raw == null ? 0.0 : math.max(raw, -landCap);

  /// The ramp color at normalized depth [t] (0 = shallow, 1 = ramp max).
  /// Banded mode quantizes into 10 equal segments sampled at their centers
  /// so the seascape reads like a stepped nautical chart tint.
  static Color depthColor(double t, {bool banded = false}) {
    final tc = t.clamp(0.0, 1.0);
    final tt = banded ? (((tc * 10).floor().clamp(0, 9)) + 0.5) / 10 : tc;
    return Color.lerp(shallowColor, deepColor, tt)!;
  }

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
    final minNorth = (grid.originLat - center.latitude) * metersPerDegLat;
    final maxNorth =
        (grid.originLat +
            grid.cellSizeLatDeg * (grid.rows - 1) -
            center.latitude) *
        metersPerDegLat;
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
    double? rampMaxDepthMeters,
    bool rampBanded = false,
    TerrainImageryFrame? imageryFrame,
    SeascapeSurfaceMode surfaceMode = SeascapeSurfaceMode.depth,
  }) {
    final rows = grid.rows, cols = grid.cols;
    final mLon = metersPerDegreeLongitude(center.latitude);
    final maxDepth = math.max(projection.maxDepth, 1.0);
    final landCap = landHeightCap(projection);

    final positions = Float32List(rows * cols * 3);
    final colors = Float32List(rows * cols * 3);
    final uvs = imageryFrame == null ? null : Float32List(rows * cols * 2);
    for (var r = 0; r < rows; r++) {
      final lat = grid.originLat + grid.cellSizeLatDeg * r;
      final north = (lat - center.latitude) * metersPerDegLat;
      for (var c = 0; c < cols; c++) {
        final lon = grid.originLon + grid.cellSizeLonDeg * c;
        final east = (lon - center.longitude) * mLon;
        final raw = grid.depthAt(r, c);
        final depth = surfaceDepth(raw, landCap);
        final vi = (r * cols + c) * 3;
        positions[vi] = projection.xOf(east);
        positions[vi + 1] = projection.yOf(depth);
        positions[vi + 2] = projection.zOf(north);
        if (uvs != null) {
          final f = imageryFrame!;
          final uvi = (r * cols + c) * 2;
          uvs[uvi] = (mercatorX(lon) - f.u0MercX) / (f.u1MercX - f.u0MercX);
          uvs[uvi + 1] = (mercatorY(lat) - f.v0MercY) / (f.v1MercY - f.v0MercY);
        }
        final Color color;
        if (surfaceMode == SeascapeSurfaceMode.imagery) {
          // The photo carries the surface; vertex colors stay neutral so
          // only the baked flat shading modulates it.
          color = const Color(0xFFFFFFFF);
        } else if (raw == null || raw <= 0) {
          color = landColor;
        } else {
          final ramp = math.max(rampMaxDepthMeters ?? maxDepth, 1.0);
          color = depthColor(depth / ramp, banded: rampBanded);
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
      textureCoordinates: uvs,
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
