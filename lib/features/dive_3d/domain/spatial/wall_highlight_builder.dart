import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const Color _wallColor = Color(0xFFEF4444);
const double _wallOpacity = 0.45;
const double _wallLiftSceneUnits = 0.015;

/// Mean slope of one grid cell from its corner depths, in degrees, or null
/// when any corner is nodata or land. Grid resolution SMOOTHS real walls:
/// a sheer wall inside one ~67 m cell reads as a modest slope, which is
/// why the default threshold is 22 degrees, not 45.
double? wallCellSlopeDegrees({
  required double? sw,
  required double? se,
  required double? nw,
  required double? ne,
  required double eastSpacingMeters,
  required double northSpacingMeters,
}) {
  if (sw == null || se == null || nw == null || ne == null) return null;
  if (sw <= 0 || se <= 0 || nw <= 0 || ne <= 0) return null;
  if (eastSpacingMeters <= 0 || northSpacingMeters <= 0) return null;
  final dEast = ((se + ne) - (sw + nw)) / 2 / eastSpacingMeters;
  final dNorth = ((nw + ne) - (sw + se)) / 2 / northSpacingMeters;
  return math.atan(math.sqrt(dEast * dEast + dNorth * dNorth)) * 180 / math.pi;
}

/// A translucent red quilt over every cell steeper than [thresholdDeg],
/// riding the terrain surface lifted a hair so it never z-fights the mesh.
/// Returns null when nothing qualifies (no empty layers in the scene).
MeshData? buildWallHighlightMesh({
  required BathymetryGrid grid,
  required GeoPoint center,
  required SpatialProjection projection,
  required double thresholdDeg,
}) {
  if (grid.rows < 2 || grid.cols < 2) return null;
  final mLon = metersPerDegreeLongitude(center.latitude);
  final eastSpacing = grid.cellSizeLonDeg * mLon;
  final northSpacing =
      grid.cellSizeLatDeg * BathymetryTerrainBuilder.metersPerDegLat;

  double eastOf(int c) =>
      (grid.originLon + grid.cellSizeLonDeg * c - center.longitude) * mLon;
  double northOf(int r) =>
      (grid.originLat + grid.cellSizeLatDeg * r - center.latitude) *
      BathymetryTerrainBuilder.metersPerDegLat;

  final positions = <double>[];
  final indices = <int>[];
  for (var r = 0; r < grid.rows - 1; r++) {
    for (var c = 0; c < grid.cols - 1; c++) {
      final sw = grid.depthAt(r, c);
      final se = grid.depthAt(r, c + 1);
      final nw = grid.depthAt(r + 1, c);
      final ne = grid.depthAt(r + 1, c + 1);
      final slope = wallCellSlopeDegrees(
        sw: sw,
        se: se,
        nw: nw,
        ne: ne,
        eastSpacingMeters: eastSpacing,
        northSpacingMeters: northSpacing,
      );
      if (slope == null || slope < thresholdDeg) continue;

      final base = positions.length ~/ 3;
      void vertex(double east, double north, double depth) {
        positions
          ..add(projection.xOf(east))
          ..add(projection.yOf(depth) + _wallLiftSceneUnits)
          ..add(projection.zOf(north));
      }

      vertex(eastOf(c), northOf(r), sw!);
      vertex(eastOf(c + 1), northOf(r), se!);
      vertex(eastOf(c), northOf(r + 1), nw!);
      vertex(eastOf(c + 1), northOf(r + 1), ne!);
      indices.addAll([base, base + 1, base + 2, base + 1, base + 3, base + 2]);
    }
  }
  if (indices.isEmpty) return null;

  final colors = Float32List(positions.length);
  for (var i = 0; i < positions.length ~/ 3; i++) {
    colors[i * 3] = _wallColor.r;
    colors[i * 3 + 1] = _wallColor.g;
    colors[i * 3 + 2] = _wallColor.b;
  }
  return MeshData(
    positions: Float32List.fromList(positions),
    indices: Uint32List.fromList(indices),
    colors: colors,
    opacity: _wallOpacity,
  );
}
