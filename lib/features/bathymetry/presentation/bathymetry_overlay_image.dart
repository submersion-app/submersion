import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';

/// Fill alpha for wet cells: translucent so the basemap reads through.
const double _fillOpacity = 0.72;
const double _contourOpacity = 0.9;
const double _minorStrokeCells = 0.25;
const double _majorStrokeCells = 0.45;
const Color _contourInk = Color(0xFFF8FAFC);

/// The rendered overlay plus where it sits on the map.
class BathymetryOverlayData {
  final Uint8List pngBytes;
  final LatLngBounds bounds;
  const BathymetryOverlayData({required this.pngBytes, required this.bounds});
}

/// The grid's footprint as cell-EDGE extents: origin coordinates are cell
/// CENTERS, so the image reaches half a cell beyond them on every side.
LatLngBounds bathymetryGridBounds(BathymetryGrid grid) {
  final halfLat = grid.cellSizeLatDeg / 2;
  final halfLon = grid.cellSizeLonDeg / 2;
  return LatLngBounds(
    LatLng(grid.originLat - halfLat, grid.originLon - halfLon),
    LatLng(
      grid.originLat + grid.cellSizeLatDeg * (grid.rows - 1) + halfLat,
      grid.originLon + grid.cellSizeLonDeg * (grid.cols - 1) + halfLon,
    ),
  );
}

/// Renders [grid] to a translucent PNG: wet cells tinted by the depth ramp
/// (honoring the ramp range and banding in [appearance]), land and nodata
/// cells FULLY TRANSPARENT so the basemap's real cartography shows
/// through, and contour lines stroked on top (majors heavier, custom
/// colors respected). Returns null for degenerate grids.
Future<BathymetryOverlayData?> buildBathymetryOverlay({
  required BathymetryGrid grid,
  required SeascapeAppearance appearance,
  required double displayUnitInMeters,
  required String depthSymbol,
  int pixelsPerCell = 4,
}) async {
  if (grid.rows < 2 || grid.cols < 2) return null;
  final ppc = pixelsPerCell.toDouble();
  final width = grid.cols * pixelsPerCell;
  final height = grid.rows * pixelsPerCell;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rampMax = math.max(
    appearance.rampMaxDepthMeters ?? grid.maxDepthMeters,
    1.0,
  );

  // Cell fills. Grid rows run south to north; image y grows down, so grid
  // row r paints at image row (rows - 1 - r).
  final fill = ui.Paint();
  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      final depth = grid.depthAt(r, c);
      if (depth == null || depth <= 0) continue; // transparent window
      final t = (depth / rampMax).clamp(0.0, 1.0);
      fill.color = BathymetryTerrainBuilder.depthColor(
        t,
        banded: appearance.rampBanded,
      ).withValues(alpha: _fillOpacity);
      canvas.drawRect(
        ui.Rect.fromLTWH(c * ppc, (grid.rows - 1 - r) * ppc, ppc, ppc),
        fill,
      );
    }
  }

  // Contours: march in image space. Cell centers sit at (c + 0.5, r + 0.5)
  // cell units; y flips to image coordinates.
  final levels = resolvedContourLevels(
    maxDepthMeters: grid.maxDepthMeters,
    displayUnitInMeters: displayUnitInMeters,
    depthSymbol: depthSymbol,
    appearance: appearance,
  );
  for (final level in levels) {
    final polylines = marchGrid(
      rows: grid.rows,
      cols: grid.cols,
      depthAt: grid.depthAt,
      eastOf: (c) => (c + 0.5) * ppc,
      northOf: (r) => (r + 0.5) * ppc,
      levelMeters: level.depthMeters,
    );
    if (polylines.isEmpty) continue;
    final stroke = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth =
          (level.isMajor ? _majorStrokeCells : _minorStrokeCells) * ppc
      ..color =
          (level.colorArgb != null ? Color(level.colorArgb!) : _contourInk)
              .withValues(alpha: _contourOpacity);
    for (final line in polylines) {
      final pts = line.pointsEastNorth;
      final path = ui.Path();
      for (var i = 0; i < pts.length ~/ 2; i++) {
        final x = pts[i * 2];
        final y = height - pts[i * 2 + 1];
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, stroke);
    }
  }

  final image = await recorder.endRecording().toImage(width, height);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return BathymetryOverlayData(
      pngBytes: byteData.buffer.asUint8List(),
      bounds: bathymetryGridBounds(grid),
    );
  } finally {
    image.dispose();
  }
}
