import 'dart:typed_data';

/// The latitude and longitude grid the model pack's region table uses.
///
/// Cells are numbered row by row from latitude -90 and longitude -180.
/// Latitude 90 falls in the last row; longitude 180 is longitude -180. The
/// pack builder computes the same cells in `region_grid.py` of
/// submersion-app/species-pack, and both are checked against
/// `test/features/species_id/domain/fixtures/region_vectors.json`.
class RegionGrid {
  const RegionGrid({required this.cellDegrees});

  final int cellDegrees;

  int get columns => 360 ~/ cellDegrees;
  int get rows => 180 ~/ cellDegrees;
  int get cellCount => columns * rows;

  /// The cell holding a point. A latitude past a pole clamps to that pole.
  int cellOf(double latitude, double longitude) {
    final row = ((latitude + 90) / cellDegrees).floor().clamp(0, rows - 1);
    final col = ((longitude + 180) / cellDegrees).floor() % columns;
    return row * columns + col;
  }

  /// [cell] and every cell within [rings] steps. Longitude wraps; latitude
  /// stops at the poles.
  Set<int> neighbourhood(int cell, {required int rings}) {
    final row = cell ~/ columns;
    final col = cell % columns;
    return {
      for (var dr = -rings; dr <= rings; dr++)
        if (row + dr >= 0 && row + dr < rows)
          for (var dc = -rings; dc <= rings; dc++)
            (row + dr) * columns + (col + dc) % columns,
    };
  }
}

/// Where each candidate species has been recorded: one bit per candidate per
/// cell of [grid].
class RegionTable {
  /// [bits] holds one row per candidate, each `(cellCount + 7) ~/ 8` bytes;
  /// cell `c` is bit `c % 8` of byte `c ~/ 8`.
  RegionTable({
    required this.grid,
    required Uint8List bits,
    required this.candidateCount,
  }) : _bits = bits,
       _rowBytes = (grid.cellCount + 7) ~/ 8 {
    if (bits.length != candidateCount * _rowBytes) {
      throw ArgumentError.value(
        bits.length,
        'bits',
        'expected ${candidateCount * _rowBytes} bytes for $candidateCount '
            'candidates',
      );
    }
  }

  final RegionGrid grid;
  final int candidateCount;
  final Uint8List _bits;
  final int _rowBytes;

  bool recorded(int candidateIndex, int cell) {
    final byte = _bits[candidateIndex * _rowBytes + cell ~/ 8];
    return (byte >> (cell % 8)) & 1 == 1;
  }

  /// One entry per candidate: whether it was recorded in any of [cells].
  List<bool> allowedMask(Set<int> cells) {
    final positions = [for (final c in cells) (c ~/ 8, 1 << (c % 8))];
    return List<bool>.generate(candidateCount, (i) {
      final base = i * _rowBytes;
      for (final (offset, mask) in positions) {
        if (_bits[base + offset] & mask != 0) return true;
      }
      return false;
    }, growable: false);
  }
}
