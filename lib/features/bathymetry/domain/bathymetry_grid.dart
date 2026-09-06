import 'dart:math' as math;

/// A rectangular grid of seafloor depths around a coordinate, in the app's
/// depth convention: meters positive DOWN. Negative values are land
/// elevation above the waterline; null cells are nodata. Rows run
/// south -> north from [originLat], columns west -> east from [originLon];
/// the origin is a cell CENTER, not a corner.
class BathymetryGrid {
  final double originLat;
  final double originLon;
  final double cellSizeLatDeg;
  final double cellSizeLonDeg;
  final int rows;
  final int cols;
  final List<double?> depthsMeters; // row-major, length rows * cols
  final String sourceId;
  final double resolutionMeters;
  final DateTime fetchedAt;

  const BathymetryGrid({
    required this.originLat,
    required this.originLon,
    required this.cellSizeLatDeg,
    required this.cellSizeLonDeg,
    required this.rows,
    required this.cols,
    required this.depthsMeters,
    required this.sourceId,
    required this.resolutionMeters,
    required this.fetchedAt,
  });

  double? depthAt(int row, int col) => depthsMeters[row * cols + col];

  /// Fraction of known (non-null) cells that are under water.
  double get wetFraction {
    var wet = 0, known = 0;
    for (final d in depthsMeters) {
      if (d == null) continue;
      known++;
      if (d > 0) wet++;
    }
    return known == 0 ? 0 : wet / known;
  }

  /// Fraction of cells that carry a reading at all. A grid can be almost
  /// entirely wet and still be mostly holes: EMODnet's Caribbean tile
  /// answers 99.96% wet on 48% coverage. The resolver needs both numbers.
  double get knownFraction {
    if (depthsMeters.isEmpty) return 0;
    var known = 0;
    for (final d in depthsMeters) {
      if (d != null) known++;
    }
    return known / depthsMeters.length;
  }

  double get maxDepthMeters {
    var m = 0.0;
    for (final d in depthsMeters) {
      if (d != null && d > m) m = d;
    }
    return m;
  }

  /// Block-mean downsample so neither dimension exceeds [maxDim]. Averaging
  /// rather than striding keeps the information in the discarded cells: a
  /// stride of 2 throws away three quarters of a grid outright.
  BathymetryGrid downsampleTo(int maxDim) {
    if (rows <= maxDim && cols <= maxDim) return this;
    final stepR = (rows / maxDim).ceil();
    final stepC = (cols / maxDim).ceil();
    final newRows = (rows + stepR - 1) ~/ stepR;
    final newCols = (cols + stepC - 1) ~/ stepC;
    final out = List<double?>.filled(newRows * newCols, null);
    for (var r = 0; r < newRows; r++) {
      final r1 = math.min((r + 1) * stepR, rows);
      for (var c = 0; c < newCols; c++) {
        final c1 = math.min((c + 1) * stepC, cols);
        var sum = 0.0;
        var n = 0;
        for (var sr = r * stepR; sr < r1; sr++) {
          for (var sc = c * stepC; sc < c1; sc++) {
            final v = depthsMeters[sr * cols + sc];
            if (v == null) continue;
            sum += v;
            n++;
          }
        }
        // An entirely unmeasured block stays unmeasured: averaging must
        // never invent a reading where the source had none.
        out[r * newCols + c] = n == 0 ? null : sum / n;
      }
    }
    return BathymetryGrid(
      // Origin is the SOUTH-WEST CELL CENTER, so it has to follow the data.
      // Striding kept the block's first sample, whose center already WAS
      // the origin; a block mean sits at the block's centroid instead, half
      // a stride further north and east. Leaving the origin put would
      // report every cell half a block south-west of the depths it holds,
      // dragging the 3D mesh, the 2D overlay bounds, the imagery mosaic and
      // the hover lat/lon readout with it. The south-west edge of the
      // footprint is unchanged by this shift, which is the invariant those
      // consumers actually depend on.
      originLat: originLat + cellSizeLatDeg * (stepR - 1) / 2,
      originLon: originLon + cellSizeLonDeg * (stepC - 1) / 2,
      cellSizeLatDeg: cellSizeLatDeg * stepR,
      cellSizeLonDeg: cellSizeLonDeg * stepC,
      rows: newRows,
      cols: newCols,
      depthsMeters: out,
      sourceId: sourceId,
      // The coarser stride sets the effective spacing: never claim more
      // detail than the downsampled grid actually has.
      resolutionMeters: resolutionMeters * (stepR > stepC ? stepR : stepC),
      fetchedAt: fetchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'originLat': originLat,
    'originLon': originLon,
    'cellSizeLatDeg': cellSizeLatDeg,
    'cellSizeLonDeg': cellSizeLonDeg,
    'rows': rows,
    'cols': cols,
    'depths': depthsMeters,
    'sourceId': sourceId,
    'resolutionMeters': resolutionMeters,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };

  factory BathymetryGrid.fromJson(Map<String, dynamic> json) => BathymetryGrid(
    originLat: (json['originLat'] as num).toDouble(),
    originLon: (json['originLon'] as num).toDouble(),
    cellSizeLatDeg: (json['cellSizeLatDeg'] as num).toDouble(),
    cellSizeLonDeg: (json['cellSizeLonDeg'] as num).toDouble(),
    rows: json['rows'] as int,
    cols: json['cols'] as int,
    depthsMeters: [
      for (final d in json['depths'] as List) (d as num?)?.toDouble(),
    ],
    sourceId: json['sourceId'] as String,
    resolutionMeters: (json['resolutionMeters'] as num).toDouble(),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );
}
