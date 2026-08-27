import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// The measured depth (meters) at the grid cell nearest (lat, lon), or
/// null when the point falls outside the grid, on a nodata cell, or on
/// land. Null means "we do not know": callers leave the field blank for
/// the diver rather than inventing a number.
double? sampleGridDepth(BathymetryGrid grid, double lat, double lon) {
  final r = ((lat - grid.originLat) / grid.cellSizeLatDeg).round();
  final c = ((lon - grid.originLon) / grid.cellSizeLonDeg).round();
  if (r < 0 || r >= grid.rows || c < 0 || c >= grid.cols) return null;
  final depth = grid.depthAt(r, c);
  if (depth == null || depth <= 0) return null;
  return depth;
}
