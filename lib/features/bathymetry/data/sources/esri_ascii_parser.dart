import 'dart:math' as math;

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// Parses an ESRI ASCII grid (GMRT `format=esriascii`). Quirks handled:
/// scientific-notation cellsize, literal `nodata_value` cells, and data
/// lines running NORTH to SOUTH (flipped here to the app's south-first
/// row order). Values are elevation meters — negated into positive-down
/// depths.
class EsriAsciiGridParser {
  static BathymetryGrid parse(
    String body, {
    required String sourceId,
    required DateTime fetchedAt,
  }) {
    final lines = body.trim().split(RegExp(r'\r?\n'));
    final header = <String, double>{};
    var i = 0;
    while (i < lines.length) {
      final parts = lines[i].trim().split(RegExp(r'\s+'));
      if (parts.length == 2 &&
          double.tryParse(parts[0]) == null &&
          double.tryParse(parts[1]) != null) {
        header[parts[0].toLowerCase()] = double.parse(parts[1]);
        i++;
      } else {
        break;
      }
    }
    double require(String key) =>
        header[key] ?? (throw FormatException('missing ESRI header: $key'));
    final ncols = require('ncols').toInt();
    final nrows = require('nrows').toInt();
    final xll = require('xllcorner');
    final yll = require('yllcorner');
    final cellsize = require('cellsize');
    final nodata = header['nodata_value'];
    if (lines.length - i < nrows) {
      throw const FormatException('ESRI grid has fewer data lines than nrows');
    }

    final depths = List<double?>.filled(nrows * ncols, null);
    for (var r = 0; r < nrows; r++) {
      final vals = lines[i + r].trim().split(RegExp(r'\s+'));
      if (vals.length < ncols) {
        throw const FormatException('ESRI data line shorter than ncols');
      }
      final gridRow = nrows - 1 - r; // flip: first line is northernmost
      for (var c = 0; c < ncols; c++) {
        final v = double.parse(vals[c]);
        depths[gridRow * ncols + c] = (nodata != null && v == nodata)
            ? null
            : -v;
      }
    }

    final centerLat = yll + cellsize * nrows / 2;
    return BathymetryGrid(
      originLat: yll + cellsize / 2,
      originLon: xll + cellsize / 2,
      cellSizeLatDeg: cellsize,
      cellSizeLonDeg: cellsize,
      rows: nrows,
      cols: ncols,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters:
          cellsize * 111320.0 * math.cos(centerLat * math.pi / 180.0),
      fetchedAt: fetchedAt,
    );
  }
}
