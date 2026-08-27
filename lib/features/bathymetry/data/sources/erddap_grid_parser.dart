import 'dart:collection';
import 'dart:convert';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// Parses an ERDDAP griddap `.json` table response into a [BathymetryGrid].
///
/// The depth variable is the LAST column (`z` on NOAA servers, `elevation`
/// on EMODnet); values are elevation in meters (negative under water) and
/// arrive as int, double, or null — always read as `num?`. Rows iterate
/// latitude-major with both axes ascending on the dataset's fixed cell
/// centers, but this parser tolerates any ordering by indexing rows into
/// the sorted axis sets.
class ErddapGridParser {
  static BathymetryGrid parse(
    String body, {
    required String sourceId,
    required double resolutionMeters,
    required DateTime fetchedAt,
  }) {
    final root = jsonDecode(body) as Map<String, dynamic>;
    final table = root['table'] as Map<String, dynamic>;
    final rows = (table['rows'] as List).cast<List<dynamic>>();
    if (rows.isEmpty) {
      throw const FormatException('ERDDAP response has no rows');
    }

    final lats = SplayTreeSet<double>();
    final lons = SplayTreeSet<double>();
    for (final r in rows) {
      lats.add((r[0] as num).toDouble());
      lons.add((r[1] as num).toDouble());
    }
    if (lats.length < 2 || lons.length < 2) {
      throw const FormatException('ERDDAP grid is degenerate (single row/col)');
    }

    final latList = lats.toList();
    final lonList = lons.toList();
    final latIndex = {for (var i = 0; i < latList.length; i++) latList[i]: i};
    final lonIndex = {for (var i = 0; i < lonList.length; i++) lonList[i]: i};

    final depths = List<double?>.filled(latList.length * lonList.length, null);
    for (final r in rows) {
      final row = latIndex[(r[0] as num).toDouble()]!;
      final col = lonIndex[(r[1] as num).toDouble()]!;
      final elevation = (r[2] as num?)?.toDouble();
      depths[row * lonList.length + col] = elevation == null
          ? null
          : -elevation;
    }

    return BathymetryGrid(
      originLat: latList.first,
      originLon: lonList.first,
      cellSizeLatDeg: latList[1] - latList[0],
      cellSizeLonDeg: lonList[1] - lonList[0],
      rows: latList.length,
      cols: lonList.length,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters: resolutionMeters,
      fetchedAt: fetchedAt,
    );
  }
}
