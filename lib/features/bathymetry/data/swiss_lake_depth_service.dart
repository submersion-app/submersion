import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/bathymetry/domain/bilinear_depth_interpolation.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Answers "what is the real lake depth at this coordinate?" for Swiss dive
/// sites, using swissBATHY3D. Scope: Part 1 of the Bathymetrie-Daten Schweiz
/// task — a depth VALUE only, no map/overlay rendering (that is Part 2).
///
/// Never throws: any failure (no coverage, no tile for this coordinate, or
/// a transient network/STAC error) surfaces as a null depth, meaning "no
/// real depth available here" — existing app behavior is unchanged.
class SwissLakeDepthService {
  final SwissBathy3dSource _source;

  const SwissLakeDepthService(this._source);

  Future<double?> depthForCoordinate(GeoPoint point) async {
    if (!_source.covers(point)) return null;
    final BathymetryGrid grid;
    try {
      // spanMeters: 0 resolves to exactly the one tile containing `point` —
      // tileEMin/tileEMax (and tileNMin/tileNMax) come out identical since
      // both are floor((coord +/- 0) / tileSizeMeters). A span equal to a
      // full tileSizeMeters instead always spans exactly two tiles per axis
      // (four total), because adding a whole tile width to a floor() shifts
      // it by exactly one tile regardless of where `point` sits — a single
      // coordinate lookup was downloading up to four tiles for what
      // bilinearInterpolateDepth's edge clamping (see that function) only
      // ever needed one of.
      grid = await _source.fetch(point, spanMeters: 0);
    } on BathymetryFetchException {
      return null;
    }
    final depth = bilinearInterpolateDepth(
      grid,
      point.latitude,
      point.longitude,
    );
    // A negative interpolated value means the point is above the lake's
    // mean level (shore/land) — not a real dive depth.
    if (depth == null || depth <= 0) return null;
    return depth;
  }
}
