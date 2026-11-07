/// Unpacks the bundled FES2022 grid files into the layout [FesTile] and
/// [FesGlobalLayer] index directly.
///
/// The bundled files are packed losslessly (issue #4245): each cell field
/// becomes one plane per constituent, stored as zigzag deltas from the
/// previous cell with the low bytes before the high bytes, all deflated.
/// Neighbouring cells carry nearly the same values, so this packs the grid
/// to under a third of its decoded size while every file stays readable on
/// its own. `scripts/tide/fes_grid_format.py` documents the layout and
/// writes it.
///
/// Inflating is the costly step, so it goes through [ComputeJobs]: off the
/// UI isolate for a file as large as the global layer, inline for a typical
/// tile, where a hop would cost more than the inflate.
library;

import 'dart:typed_data';

import 'package:submersion/core/platform/compute/compute_jobs.dart';
import 'package:submersion/core/platform/zlib/zlib_exceptions.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';

const int _packedVersion = 2;
const String _packedTileMagic = 'SFT2';
const String _packedGlobalMagic = 'SFG2';
const int _tileHeaderBytes = 16;
const int _globalHeaderBytes = 12;

/// Phases are hundredths of a degree, so their deltas wrap at 360 degrees.
const int _phaseModulus = 36000;

/// Unpacks a bundled coastal tile into the bytes [FesTile.parse] reads.
/// Throws [FormatException] for anything that is not a packed tile, or
/// whose body disagrees with its header and bitmap.
Future<ByteData> unpackFesTile(ByteData packed) async {
  _checkHeader(packed, _packedTileMagic, _tileHeaderBytes, 'FES tile');
  final rows = packed.getUint16(10, Endian.little);
  final cols = packed.getUint16(12, Endian.little);
  final count = packed.getUint16(14, Endian.little);
  final bitmapBytes = (rows * cols + 7) ~/ 8;
  final body = await _inflate(
    packed,
    _tileHeaderBytes,
    maxBytes: bitmapBytes + rows * cols * count * fesBytesPerConstituent,
    what: 'FES tile',
  );
  if (body.length < bitmapBytes) {
    throw const FormatException('Packed FES tile is truncated');
  }

  // The packed file leaves out the per-row counts; rebuild them.
  final before = Uint32List(rows);
  var populated = 0;
  for (var row = 0; row < rows; row++) {
    before[row] = populated;
    for (var bit = row * cols; bit < (row + 1) * cols; bit++) {
      if ((body[bit >> 3] >> (bit & 7)) & 1 == 1) populated++;
    }
  }
  final cellBytes = populated * count * fesBytesPerConstituent;
  if (body.length != bitmapBytes + cellBytes) {
    throw const FormatException(
      'Packed FES tile body does not match its bitmap',
    );
  }

  final rowCountsOffset = _tileHeaderBytes + bitmapBytes;
  final cellsOffset = rowCountsOffset + rows * 4;
  final out = ByteData(cellsOffset + cellBytes);
  _writeDecodedHeader(out, packed, FesTile.magic, _tileHeaderBytes);
  out.buffer.asUint8List().setRange(_tileHeaderBytes, rowCountsOffset, body);
  for (var row = 0; row < rows; row++) {
    out.setUint32(rowCountsOffset + row * 4, before[row], Endian.little);
  }
  _unpackPlanes(body, bitmapBytes, out, cellsOffset, populated, count);
  return out;
}

/// Unpacks the bundled global layer into the bytes [FesGlobalLayer.parse]
/// reads. Throws [FormatException] for anything that is not a packed
/// global layer of the size its header states.
Future<ByteData> unpackFesGlobalLayer(ByteData packed) async {
  _checkHeader(
    packed,
    _packedGlobalMagic,
    _globalHeaderBytes,
    'FES global layer',
  );
  final cells =
      packed.getUint16(6, Endian.little) * packed.getUint16(8, Endian.little);
  final count = packed.getUint16(10, Endian.little);
  final cellBytes = cells * count * fesBytesPerConstituent;
  final body = await _inflate(
    packed,
    _globalHeaderBytes,
    maxBytes: cellBytes,
    what: 'FES global layer',
  );
  if (body.length != cellBytes) {
    throw const FormatException('Packed FES global layer length mismatch');
  }
  final out = ByteData(_globalHeaderBytes + cellBytes);
  _writeDecodedHeader(out, packed, FesGlobalLayer.magic, _globalHeaderBytes);
  _unpackPlanes(body, 0, out, _globalHeaderBytes, cells, count);
  return out;
}

void _checkHeader(ByteData data, String magic, int headerBytes, String what) {
  if (data.lengthInBytes < headerBytes || !hasFesMagic(data, magic)) {
    throw FormatException('Not a packed $what');
  }
  final version = data.getUint16(4, Endian.little);
  if (version != _packedVersion) {
    throw FormatException('Unsupported packed $what version $version');
  }
}

Future<Uint8List> _inflate(
  ByteData packed,
  int headerBytes, {
  required int maxBytes,
  required String what,
}) async {
  try {
    return await ComputeJobs.inflateBounded(
      packed.buffer.asUint8List(
        packed.offsetInBytes + headerBytes,
        packed.lengthInBytes - headerBytes,
      ),
      maxBytes: maxBytes,
    );
  } on ZlibFormatException catch (e) {
    throw FormatException('Packed $what is corrupt: ${e.message}');
  } on ZlibBoundExceeded {
    throw FormatException('Packed $what is larger than its header allows');
  }
}

/// The decoded header: the decoded [magic] and version, then the packed
/// header's remaining fields, which the two layouts share.
void _writeDecodedHeader(
  ByteData out,
  ByteData packed,
  String magic,
  int headerBytes,
) {
  for (var i = 0; i < magic.length; i++) {
    out.setUint8(i, magic.codeUnitAt(i));
  }
  out.setUint16(4, fesDecodedVersion, Endian.little);
  for (var i = 6; i < headerBytes; i++) {
    out.setUint8(i, packed.getUint8(i));
  }
}

/// Writes [cells] cells of [count] constituents at [outOffset], read from
/// the planes at [srcOffset]: every amplitude plane, then every phase plane,
/// each [cells] zigzag deltas long, all low bytes before all high bytes.
void _unpackPlanes(
  Uint8List src,
  int srcOffset,
  ByteData out,
  int outOffset,
  int cells,
  int count,
) {
  final highOffset = 2 * count * cells;
  final stride = count * fesBytesPerConstituent;
  for (var plane = 0; plane < 2 * count; plane++) {
    final isPhase = plane >= count;
    var at =
        outOffset +
        (plane % count) * fesBytesPerConstituent +
        (isPhase ? 2 : 0);
    var i = srcOffset + plane * cells;
    var value = 0;
    for (var cell = 0; cell < cells; cell++, i++, at += stride) {
      final zigzag = src[i] | (src[i + highOffset] << 8);
      final delta = (zigzag >> 1) ^ -(zigzag & 1);
      // Dart's % is never negative for a positive divisor.
      value = isPhase
          ? (value + delta) % _phaseModulus
          : (value + delta) & 0xffff;
      out.setUint16(at, value, Endian.little);
    }
  }
}
