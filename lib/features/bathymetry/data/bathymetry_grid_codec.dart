import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// The compact, lossless form the terrain caches store a [BathymetryGrid]
/// in (issue #4258), in place of the JSON text they held before.
///
/// Layout, little-endian throughout:
///
/// | bytes | field |
/// | --- | --- |
/// | 4 | magic `SBG` and format version 1 |
/// | 4 + 4 | rows, cols (uint32) |
/// | 6 x 8 | originLat, originLon, cellSizeLatDeg, cellSizeLonDeg, resolutionMeters, fetchedAt in UTC microseconds (float64) |
/// | 2 + n | sourceId length (uint16) and its UTF-8 bytes |
/// | rest | zlib stream of the depths |
///
/// The depths are float64, so every value comes back bit for bit, with NaN
/// standing for a no-data cell. Before deflating they are byte-shuffled:
/// plane k holds byte k of every value. Neighbouring depths share their sign
/// and exponent bytes, so the shuffle hands deflate long runs it cannot see
/// in interleaved doubles. Measured on synthetic terrain, a 120 x 120 base
/// square stores in a fifth to a third of its JSON bytes, the smaller figure
/// for depths a float32 source delivered.
///
/// The header stays outside the stream so a reader knows the exact body size
/// before inflating, and refuses a damaged row without allocating for it.
/// The fetch time travels as a float64 rather than an int64 because the web
/// build's `ByteData` has no 64-bit integer accessors; microseconds stay
/// exact in a double until the year 2255.
abstract final class BathymetryGridCodec {
  static const List<int> _magic = [0x53, 0x42, 0x47, 0x01];
  static const int _rowsAt = 4;
  static const int _colsAt = 8;
  static const int _fieldsAt = 12;
  static const int _sourceIdLengthAt = _fieldsAt + 6 * 8;
  static const int _fixedHeaderBytes = _sourceIdLengthAt + 2;

  /// More cells than any shipped source produces (a superFine patch is
  /// capped at 600 x 600, a swissBATHY3D tile is 1 km at its native ~2 m).
  /// Bounds what a damaged header can make [decode] allocate.
  static const int maxCells = 4096 * 4096;

  /// Whether [bytes] starts with this codec's magic. Cheap: reads 4 bytes.
  static bool isEncoded(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// Throws [ArgumentError] when the grid's cell list does not match its
  /// shape, or its shape or source id is too large to store.
  static Uint8List encode(BathymetryGrid grid) {
    final cells = grid.rows * grid.cols;
    if (grid.rows < 0 ||
        grid.cols < 0 ||
        grid.rows > maxCells ||
        grid.cols > maxCells ||
        cells > maxCells) {
      throw ArgumentError(
        'grid of ${grid.rows} x ${grid.cols} is not storable',
      );
    }
    if (grid.depthsMeters.length != cells) {
      throw ArgumentError(
        'grid of ${grid.rows} x ${grid.cols} holds '
        '${grid.depthsMeters.length} depth(s)',
      );
    }
    final sourceId = utf8.encode(grid.sourceId);
    if (sourceId.length > 0xFFFF) {
      throw ArgumentError('source id of ${sourceId.length} bytes is too long');
    }

    final values = ByteData(cells * 8);
    for (var i = 0; i < cells; i++) {
      values.setFloat64(
        i * 8,
        grid.depthsMeters[i] ?? double.nan,
        Endian.little,
      );
    }
    final body = PlatformZlib.deflate(
      _shuffle(values.buffer.asUint8List(), cells),
    );

    final headerBytes = _fixedHeaderBytes + sourceId.length;
    final out = Uint8List(headerBytes + body.length);
    final header = ByteData.sublistView(out, 0, headerBytes);
    out.setRange(0, _magic.length, _magic);
    header
      ..setUint32(_rowsAt, grid.rows, Endian.little)
      ..setUint32(_colsAt, grid.cols, Endian.little);
    var at = _fieldsAt;
    for (final value in [
      grid.originLat,
      grid.originLon,
      grid.cellSizeLatDeg,
      grid.cellSizeLonDeg,
      grid.resolutionMeters,
      grid.fetchedAt.toUtc().microsecondsSinceEpoch.toDouble(),
    ]) {
      header.setFloat64(at, value, Endian.little);
      at += 8;
    }
    header.setUint16(_sourceIdLengthAt, sourceId.length, Endian.little);
    out
      ..setRange(_fixedHeaderBytes, headerBytes, sourceId)
      ..setRange(headerBytes, out.length, body);
    return out;
  }

  /// Throws [FormatException] for anything [encode] did not write whole.
  static BathymetryGrid decode(Uint8List bytes) {
    if (!isEncoded(bytes)) {
      throw const FormatException('not an encoded bathymetry grid');
    }
    if (bytes.length < _fixedHeaderBytes) {
      throw const FormatException('bathymetry grid header is truncated');
    }
    final header = ByteData.sublistView(bytes);
    final rows = header.getUint32(_rowsAt, Endian.little);
    final cols = header.getUint32(_colsAt, Endian.little);
    final fields = [
      for (var i = 0; i < 6; i++)
        header.getFloat64(_fieldsAt + i * 8, Endian.little),
    ];
    final sourceIdLength = header.getUint16(_sourceIdLengthAt, Endian.little);
    final bodyStart = _fixedHeaderBytes + sourceIdLength;
    // Each dimension first: two uint32s can multiply past 64 bits.
    if (rows > maxCells || cols > maxCells || rows * cols > maxCells) {
      throw FormatException('bathymetry grid of $rows x $cols is too large');
    }
    final cells = rows * cols;
    if (bytes.length < bodyStart || !fields[5].isFinite) {
      throw const FormatException('bathymetry grid header is damaged');
    }

    final Uint8List shuffled;
    try {
      shuffled = PlatformZlib.inflateBounded(
        Uint8List.sublistView(bytes, bodyStart),
        maxBytes: cells * 8,
      );
    } on ZlibFormatException catch (e) {
      throw FormatException('bathymetry grid body: ${e.message}');
    } on ZlibBoundExceeded {
      throw const FormatException('bathymetry grid body is too long');
    }
    // inflate returns whatever a truncated stream held without complaint, so
    // the exact length is the completeness check.
    if (shuffled.length != cells * 8) {
      throw const FormatException('bathymetry grid body is truncated');
    }

    final values = ByteData.sublistView(_unshuffle(shuffled, cells));
    final depths = List<double?>.filled(cells, null);
    for (var i = 0; i < cells; i++) {
      final v = values.getFloat64(i * 8, Endian.little);
      if (!v.isNaN) depths[i] = v;
    }
    return BathymetryGrid(
      originLat: fields[0],
      originLon: fields[1],
      cellSizeLatDeg: fields[2],
      cellSizeLonDeg: fields[3],
      rows: rows,
      cols: cols,
      depthsMeters: depths,
      sourceId: utf8.decode(
        Uint8List.sublistView(bytes, _fixedHeaderBytes, bodyStart),
      ),
      resolutionMeters: fields[4],
      fetchedAt: DateTime.fromMicrosecondsSinceEpoch(
        fields[5].toInt(),
        isUtc: true,
      ),
    );
  }

  /// The grid a cache row holds: [blob] in this codec's form, or, for a row
  /// cached before the codec existed, [json] in [BathymetryGrid.toJson]'s
  /// form. Null when neither column holds a grid that decodes, which the
  /// caches treat as a corrupt row.
  static BathymetryGrid? decodeStored({Uint8List? blob, String? json}) {
    try {
      if (blob != null) return decode(blob);
      if (json != null) {
        return BathymetryGrid.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
      return null;
    } catch (_) {
      // Any failure, a cast as much as a parse, means the row is unusable.
      return null;
    }
  }

  static Uint8List _shuffle(Uint8List interleaved, int count) {
    final out = Uint8List(interleaved.length);
    for (var i = 0; i < count; i++) {
      for (var k = 0; k < 8; k++) {
        out[k * count + i] = interleaved[i * 8 + k];
      }
    }
    return out;
  }

  static Uint8List _unshuffle(Uint8List planes, int count) {
    final out = Uint8List(planes.length);
    for (var i = 0; i < count; i++) {
      for (var k = 0; k < 8; k++) {
        out[i * 8 + k] = planes[k * count + i];
      }
    }
    return out;
  }
}
