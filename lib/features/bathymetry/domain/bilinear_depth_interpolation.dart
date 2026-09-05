import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// The depth (meters) at (lat, lon) bilinearly interpolated from the four
/// grid cells surrounding it, or null when the point falls outside the
/// grid or any of those four cells is nodata. Unlike [sampleGridDepth]'s
/// nearest-cell lookup, this does not clamp a negative (land) result to
/// null — callers that want "underwater only" apply that themselves.
double? bilinearInterpolateDepth(BathymetryGrid grid, double lat, double lon) {
  final rowF = (lat - grid.originLat) / grid.cellSizeLatDeg;
  final colF = (lon - grid.originLon) / grid.cellSizeLonDeg;
  final r0 = rowF.floor();
  final c0 = colF.floor();
  final r1 = r0 + 1;
  final c1 = c0 + 1;
  if (r0 < 0 || c0 < 0 || r1 >= grid.rows || c1 >= grid.cols) return null;

  final d00 = grid.depthAt(r0, c0);
  final d01 = grid.depthAt(r0, c1);
  final d10 = grid.depthAt(r1, c0);
  final d11 = grid.depthAt(r1, c1);
  if (d00 == null || d01 == null || d10 == null || d11 == null) return null;

  final fr = rowF - r0;
  final fc = colF - c0;
  final top = d00 + (d01 - d00) * fc;
  final bottom = d10 + (d11 - d10) * fc;
  return top + (bottom - top) * fr;
}
