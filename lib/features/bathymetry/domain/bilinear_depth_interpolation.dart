import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// The depth (meters) at (lat, lon) bilinearly interpolated from the four
/// grid cells surrounding it, or null when the point falls outside the
/// grid or any of those four cells is nodata. Unlike [sampleGridDepth]'s
/// nearest-cell lookup, this does not clamp a negative (land) result to
/// null — callers that want "underwater only" apply that themselves.
double? bilinearInterpolateDepth(BathymetryGrid grid, double lat, double lon) {
  final rowF = (lat - grid.originLat) / grid.cellSizeLatDeg;
  final colF = (lon - grid.originLon) / grid.cellSizeLonDeg;
  // [grid.originLat]/[originLon] are the CENTER of cell (0, 0), not its
  // south-west corner, so the grid's true footprint extends half a cell
  // beyond the first/last row and column centers. A point out there has no
  // second row/column to blend against; clamp the reference cell to the
  // nearest valid pair and let the fraction clamp to that edge instead of
  // rejecting a point that is genuinely still inside the grid.
  if (rowF < -0.5 || rowF > grid.rows - 0.5) return null;
  if (colF < -0.5 || colF > grid.cols - 0.5) return null;

  final r0Raw = rowF.floor();
  final c0Raw = colF.floor();
  final r0 = _clampIndex(r0Raw, grid.rows - 1);
  final c0 = _clampIndex(c0Raw, grid.cols - 1);
  // In the south/west half-cell margin (rowF/colF in [-0.5, 0)), r0Raw/c0Raw
  // is -1 and gets clamped up to 0 above — but a plain +1 neighbor would then
  // point at row/col 1, an interior cell the blend weight (fr/fc) is clamped
  // to ignore. If that interior cell is nodata, the null check below would
  // reject a point that is genuinely still inside the grid. Keep r1/c1 at
  // the same edge index instead, so a nodata interior neighbor can't leak in.
  final r1 = r0Raw < 0 ? r0 : _clampIndex(r0 + 1, grid.rows - 1);
  final c1 = c0Raw < 0 ? c0 : _clampIndex(c0 + 1, grid.cols - 1);

  final d00 = grid.depthAt(r0, c0);
  final d01 = grid.depthAt(r0, c1);
  final d10 = grid.depthAt(r1, c0);
  final d11 = grid.depthAt(r1, c1);
  if (d00 == null || d01 == null || d10 == null || d11 == null) return null;

  final fr = _clampUnit(rowF - r0);
  final fc = _clampUnit(colF - c0);
  final top = d00 + (d01 - d00) * fc;
  final bottom = d10 + (d11 - d10) * fc;
  return top + (bottom - top) * fr;
}

int _clampIndex(int i, int maxIndex) {
  if (i < 0) return 0;
  if (i > maxIndex) return maxIndex;
  return i;
}

/// Clamps to [0, 1]: at the grid's edge margin, r0/r1 (or c0/c1) collapse
/// onto the same row/column, so the blend weight would otherwise land
/// outside that range and skew a value that should just be that edge's.
double _clampUnit(double v) {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}
