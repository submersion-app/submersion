import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// How high the rendered seafloor reaches within one grid cell, in scene Y.
///
/// The renderer has no depth buffer; it paints triangles ordered by their
/// view-space centroid. That ordering breaks down for a thin drape lying on
/// a large terrain triangle, because one ~115 m cell of real bathymetry can
/// fall a hundred metres across its own width, putting its centroid nearer
/// the camera than the contour riding it. Draped geometry therefore sorts
/// at the CEILING of the cell it sits in -- the shallowest of the cell's
/// four corners -- which clears every triangle of that cell while staying
/// bounded by local relief, so a distant hill can still hide it in the
/// orbit views.
class TerrainCeiling {
  final BathymetryGrid _grid;
  final SpatialProjection _projection;
  final GeoPoint _center;
  final double _metersPerDegLon;

  /// Hoisted out of [atScene]: this runs per draped vertex, four corners
  /// each, and the cap is fixed for the whole scene.
  final double _landCap;

  TerrainCeiling({
    required BathymetryGrid grid,
    required GeoPoint center,
    required SpatialProjection projection,
  }) : _grid = grid,
       _center = center,
       _projection = projection,
       _metersPerDegLon = metersPerDegreeLongitude(center.latitude),
       _landCap = BathymetryTerrainBuilder.landHeightCap(projection);

  /// The shallowest surface height of the cell containing scene [x], [z].
  /// Points outside the grid clamp to the nearest edge cell.
  double atScene(double x, double z) {
    final lon = _center.longitude + _projection.eastAt(x) / _metersPerDegLon;
    final lat =
        _center.latitude +
        _projection.northAt(z) / BathymetryTerrainBuilder.metersPerDegLat;
    final c = _cellIndex(
      (lon - _grid.originLon) / _grid.cellSizeLonDeg,
      _grid.cols,
    );
    final r = _cellIndex(
      (lat - _grid.originLat) / _grid.cellSizeLatDeg,
      _grid.rows,
    );

    // Shallowest corner = greatest scene Y, and yOf is monotonic, so take
    // the minimum DEPTH and convert once.
    var shallowest = double.infinity;
    for (var dr = 0; dr <= 1; dr++) {
      for (var dc = 0; dc <= 1; dc++) {
        final depth = BathymetryTerrainBuilder.surfaceDepth(
          _grid.depthAt(
            (r + dr).clamp(0, _grid.rows - 1),
            (c + dc).clamp(0, _grid.cols - 1),
          ),
          _landCap,
        );
        if (depth < shallowest) shallowest = depth;
      }
    }
    return _projection.yOf(shallowest);
  }

  /// The lower corner of the cell holding fractional index [t], clamped so
  /// the cell's far corner stays inside a grid of [count] nodes.
  static int _cellIndex(double t, int count) {
    if (count < 2 || !t.isFinite) return 0;
    return t.floor().clamp(0, count - 2);
  }
}
