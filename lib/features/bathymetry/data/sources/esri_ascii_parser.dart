import 'dart:math' as math;

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// A parsed ESRI ASCII grid header plus its raw cell values (south-first row
/// order), before any coordinate system or depth-sign convention is applied.
/// [xll]/[yll]/[cellsize] are in whatever units and coordinate system the
/// source file uses (WGS84 degrees for GMRT/EMODnet; LV95 meters for
/// swissBATHY3D) — callers are responsible for interpreting them.
class RawEsriGrid {
  final int ncols;
  final int nrows;
  final double xll;
  final double yll;
  final double cellsize;
  final List<double?> values; // row-major, south-first, length nrows*ncols

  const RawEsriGrid({
    required this.ncols,
    required this.nrows,
    required this.xll,
    required this.yll,
    required this.cellsize,
    required this.values,
  });
}

/// Parses an ESRI ASCII grid (GMRT `format=esriascii`, swissBATHY3D `.asc`).
/// Quirks handled: scientific-notation cellsize, literal `nodata_value`
/// cells, and data lines running NORTH to SOUTH (flipped here to the app's
/// south-first row order).
class EsriAsciiGridParser {
  static RawEsriGrid parseRaw(String body) {
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

    final values = List<double?>.filled(nrows * ncols, null);
    for (var r = 0; r < nrows; r++) {
      final vals = lines[i + r].trim().split(RegExp(r'\s+'));
      if (vals.length < ncols) {
        throw const FormatException('ESRI data line shorter than ncols');
      }
      final gridRow = nrows - 1 - r; // flip: first line is northernmost
      for (var c = 0; c < ncols; c++) {
        final v = double.parse(vals[c]);
        values[gridRow * ncols + c] = (nodata != null && v == nodata)
            ? null
            : v;
      }
    }

    return RawEsriGrid(
      ncols: ncols,
      nrows: nrows,
      xll: xll,
      yll: yll,
      cellsize: cellsize,
      values: values,
    );
  }

  /// Values are elevation meters relative to sea level, and [xllcorner] /
  /// [yllcorner] are already WGS84 degrees — negated into the app's
  /// positive-down depth convention. Used by global/regional ocean sources
  /// (GMRT) whose servers are requested to answer in WGS84.
  static BathymetryGrid parse(
    String body, {
    required String sourceId,
    required DateTime fetchedAt,
  }) {
    final raw = parseRaw(body);
    final centerLat = raw.yll + raw.cellsize * raw.nrows / 2;
    return BathymetryGrid(
      originLat: raw.yll + raw.cellsize / 2,
      originLon: raw.xll + raw.cellsize / 2,
      cellSizeLatDeg: raw.cellsize,
      cellSizeLonDeg: raw.cellsize,
      rows: raw.nrows,
      cols: raw.ncols,
      depthsMeters: [for (final v in raw.values) v == null ? null : -v],
      sourceId: sourceId,
      resolutionMeters:
          raw.cellsize * 111320.0 * math.cos(centerLat * math.pi / 180.0),
      fetchedAt: fetchedAt,
    );
  }
}
