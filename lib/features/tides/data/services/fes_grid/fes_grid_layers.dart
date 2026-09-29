import 'dart:typed_data';

/// Bytes per constituent in a cell: int16 amplitude (mm) and uint16 phase
/// (hundredths of a degree), little-endian.
const int fesBytesPerConstituent = 4;

/// Amplitude marker for a constituent with no data in a cell.
const int fesNoData = -1;

/// A read-only view of one cell's constituent values.
class FesCell {
  final ByteData _data;
  final int _offset;

  const FesCell(this._data, this._offset);

  /// Amplitude in metres, or null when this constituent has no data here.
  double? amplitudeMeters(int index) {
    final mm = _data.getInt16(
      _offset + index * fesBytesPerConstituent,
      Endian.little,
    );
    return mm == fesNoData ? null : mm / 1000.0;
  }

  /// Greenwich phase lag in degrees.
  double phaseDegrees(int index) =>
      _data.getUint16(
        _offset + index * fesBytesPerConstituent + 2,
        Endian.little,
      ) /
      100.0;
}

bool _hasMagic(ByteData data, String magic) {
  if (data.lengthInBytes < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (data.getUint8(i) != magic.codeUnitAt(i)) return false;
  }
  return true;
}

/// One coastal tile: an occupancy bitmap, per-row counts and packed cells.
class FesTile {
  static const _magic = 'SFT1';
  static const _headerBytes = 16;

  final int tileRow;
  final int tileCol;
  final int rows;
  final int cols;
  final int _constituents;
  final ByteData _data;
  final int _rowCountsOffset;
  final int _cellsOffset;

  FesTile._(
    this._data, {
    required this.tileRow,
    required this.tileCol,
    required this.rows,
    required this.cols,
    required int constituents,
  }) : _constituents = constituents,
       _rowCountsOffset = _headerBytes + (rows * cols + 7) ~/ 8,
       _cellsOffset = _headerBytes + (rows * cols + 7) ~/ 8 + rows * 4;

  /// Parses a tile. Throws [FormatException] for a wrong magic, version,
  /// constituent count or length.
  static FesTile parse(ByteData data, {required int expectedConstituents}) {
    if (data.lengthInBytes < _headerBytes || !_hasMagic(data, _magic)) {
      throw const FormatException('Not an FES grid tile');
    }
    final version = data.getUint16(4, Endian.little);
    if (version != 1) {
      throw FormatException('Unsupported FES tile version $version');
    }
    final count = data.getUint16(14, Endian.little);
    if (count != expectedConstituents) {
      throw FormatException(
        'FES tile has $count constituents, expected $expectedConstituents',
      );
    }
    final tile = FesTile._(
      data,
      tileRow: data.getInt16(6, Endian.little),
      tileCol: data.getInt16(8, Endian.little),
      rows: data.getUint16(10, Endian.little),
      cols: data.getUint16(12, Endian.little),
      constituents: count,
    );
    if (data.lengthInBytes < tile._cellsOffset) {
      throw const FormatException('FES tile is truncated');
    }
    final expectedLength =
        tile._cellsOffset +
        tile._validatedPopulatedCount() * count * fesBytesPerConstituent;
    if (data.lengthInBytes != expectedLength) {
      throw const FormatException('FES tile length does not match its bitmap');
    }
    return tile;
  }

  bool _isSet(int bit) =>
      ((_data.getUint8(_headerBytes + (bit >> 3)) >> (bit & 7)) & 1) == 1;

  /// Walks the bitmap once, checking each row's stored count of populated
  /// cells before it against the running total, and returns the total.
  /// cellAt trusts these counts for its offsets, so a wrong one must be
  /// rejected here rather than read past the buffer later.
  int _validatedPopulatedCount() {
    var count = 0;
    for (var row = 0; row < rows; row++) {
      final stored = _data.getUint32(_rowCountsOffset + row * 4, Endian.little);
      if (stored != count) {
        throw FormatException('FES tile row $row count is $stored, not $count');
      }
      for (var bit = row * cols; bit < (row + 1) * cols; bit++) {
        if (_isSet(bit)) count++;
      }
    }
    return count;
  }

  /// The cell at tile-local ([row], [col]), or null when absent.
  FesCell? cellAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    final bit = row * cols + col;
    if (!_isSet(bit)) return null;
    var index = _data.getUint32(_rowCountsOffset + row * 4, Endian.little);
    for (var b = row * cols; b < bit; b++) {
      if (_isSet(b)) index++;
    }
    return FesCell(
      _data,
      _cellsOffset + index * _constituents * fesBytesPerConstituent,
    );
  }
}

/// The dense 1-degree global layer.
class FesGlobalLayer {
  static const _magic = 'SFG1';
  static const _headerBytes = 12;

  final int rows;
  final int cols;
  final int _constituents;
  final ByteData _data;

  FesGlobalLayer._(this._data, this.rows, this.cols, this._constituents);

  /// Parses the global layer. Throws [FormatException] when malformed.
  static FesGlobalLayer parse(
    ByteData data, {
    required int expectedConstituents,
  }) {
    if (data.lengthInBytes < _headerBytes || !_hasMagic(data, _magic)) {
      throw const FormatException('Not an FES global layer');
    }
    final version = data.getUint16(4, Endian.little);
    final rows = data.getUint16(6, Endian.little);
    final cols = data.getUint16(8, Endian.little);
    final count = data.getUint16(10, Endian.little);
    if (version != 1 || count != expectedConstituents) {
      throw const FormatException('Unsupported FES global layer');
    }
    if (data.lengthInBytes !=
        _headerBytes + rows * cols * count * fesBytesPerConstituent) {
      throw const FormatException('FES global layer length mismatch');
    }
    return FesGlobalLayer._(data, rows, cols, count);
  }

  /// The cell at ([row], [col]), or null when out of range or without data
  /// (a cell's validity is its first constituent's, M2 in the real grid).
  FesCell? cellAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    final cell = FesCell(
      _data,
      _headerBytes +
          (row * cols + col) * _constituents * fesBytesPerConstituent,
    );
    return cell.amplitudeMeters(0) == null ? null : cell;
  }
}
