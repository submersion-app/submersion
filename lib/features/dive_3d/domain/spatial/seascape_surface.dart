import 'dart:typed_data';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';

/// Builds the viewport's pick lattice for the seascape terrain by reusing
/// the terrain mesh's OWN vertex array: with `columns = grid.rows` and
/// `compartments = grid.cols`, the pick index `col * compartments + comp`
/// equals the mesh's `row * cols + col`, so hover picking aligns
/// pixel-for-pixel with the rendered surface — the same guarantee the
/// tissue view documents. Tissue-specific fields stay empty; the
/// viewport's hover path never reads them.
TissueSurfaceGrid seascapePickGrid(BathymetryGrid grid, MeshData terrainMesh) {
  if (terrainMesh.positions.length != grid.rows * grid.cols * 3) {
    return TissueSurfaceGrid.empty;
  }
  return TissueSurfaceGrid(
    columns: grid.rows,
    compartments: grid.cols,
    positions: terrainMesh.positions,
    normalizedTimes: const [],
    compartmentNumbers: const [],
    halfTimesN2: const [],
    saturationPct: Float32List(0),
  );
}

/// Geographic + depth readout for a picked terrain vertex. By the
/// [seascapePickGrid] convention, `pick.col` is the grid ROW (latitude
/// axis) and `pick.comp` the grid COLUMN (longitude axis). Land and
/// nodata cells report a null depth.
({double latitude, double longitude, double? depthMeters}) seascapeCellInfo(
  BathymetryGrid grid,
  TissuePick pick,
) {
  final row = pick.col, col = pick.comp;
  final depth = grid.depthAt(row, col);
  return (
    latitude: grid.originLat + grid.cellSizeLatDeg * row,
    longitude: grid.originLon + grid.cellSizeLonDeg * col,
    depthMeters: (depth == null || depth <= 0) ? null : depth,
  );
}
