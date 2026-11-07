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
/// Inflating a file and rebuilding its planes cost about the same, so on a
/// native build both run in one hop off the calling isolate for a file as
/// large as the global layer, and inline for a typical tile, where a hop
/// would cost more than the work. A browser has no isolates: there the
/// compute worker inflates a large file and the planes rebuild inline.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:submersion/core/platform/compute/compute_jobs.dart';
import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/core/utils/off_isolate.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';

const int _packedVersion = 2;

/// Phases are hundredths of a degree, so their deltas wrap at 360 degrees.
const int _phaseModulus = 36000;

/// Unpacks a bundled coastal tile into the bytes [FesTile.parse] reads.
/// Throws [FormatException] for anything that is not a packed tile, or
/// whose body disagrees with its header and bitmap.
Future<ByteData> unpackFesTile(ByteData packed) => _unpack(packed, _tile);

/// Unpacks the bundled global layer into the bytes [FesGlobalLayer.parse]
/// reads. Throws [FormatException] for anything that is not a packed
/// global layer of the size its header states.
Future<ByteData> unpackFesGlobalLayer(ByteData packed) =>
    _unpack(packed, _global);

/// One kind of packed file: its header, the most its body may inflate to,
/// and how the decoded bytes are rebuilt from the header and body.
final class _Kind {
  const _Kind({
    required this.magic,
    required this.headerBytes,
    required this.what,
    required this.maxBody,
    required this.rebuild,
  });

  final String magic;
  final int headerBytes;
  final String what;
  final int Function(ByteData packed) maxBody;
  final ByteData Function(ByteData packed, Uint8List body) rebuild;
}

const _tile = _Kind(
  magic: 'SFT2',
  headerBytes: 16,
  what: 'FES tile',
  maxBody: _tileMaxBody,
  rebuild: _rebuildTile,
);

const _global = _Kind(
  magic: 'SFG2',
  headerBytes: 12,
  what: 'FES global layer',
  maxBody: _globalCellBytes,
  rebuild: _rebuildGlobal,
);

Future<ByteData> _unpack(ByteData packed, _Kind kind) async {
  if (packed.lengthInBytes < kind.headerBytes ||
      !hasFesMagic(packed, kind.magic)) {
    throw FormatException('Not a packed ${kind.what}');
  }
  final version = packed.getUint16(4, Endian.little);
  if (version != _packedVersion) {
    throw FormatException('Unsupported packed ${kind.what} version $version');
  }
  final stream = packed.buffer.asUint8List(
    packed.offsetInBytes + kind.headerBytes,
    packed.lengthInBytes - kind.headerBytes,
  );
  final maxBytes = kind.maxBody(packed);
  if (!kIsWeb) return _unpackOffIsolate(packed, stream, maxBytes, kind);
  final Uint8List body;
  try {
    body = await ComputeJobs.inflateBounded(stream, maxBytes: maxBytes);
  } on ZlibFormatException catch (e) {
    throw _corrupt(kind.what, e);
  } on ZlibBoundExceeded {
    throw _tooLarge(kind.what);
  }
  return kind.rebuild(packed, body);
}

/// Inflates and rebuilds in one hop. Not async, so the closure captures
/// these parameters alone.
Future<ByteData> _unpackOffIsolate(
  ByteData packed,
  Uint8List stream,
  int maxBytes,
  _Kind kind,
) => runOffIsolate(
  () => kind.rebuild(packed, _inflate(stream, maxBytes, kind.what)),
  bytes: stream.length,
  isExpected: (e) => e is FormatException,
);

Uint8List _inflate(Uint8List stream, int maxBytes, String what) {
  try {
    return PlatformZlib.inflateBounded(stream, maxBytes: maxBytes);
  } on ZlibFormatException catch (e) {
    throw _corrupt(what, e);
  } on ZlibBoundExceeded {
    throw _tooLarge(what);
  }
}

FormatException _corrupt(String what, ZlibFormatException e) =>
    FormatException('Packed $what is corrupt: ${e.message}');

FormatException _tooLarge(String what) =>
    FormatException('Packed $what is larger than its header allows');

int _tileMaxBody(ByteData packed) {
  final rows = packed.getUint16(10, Endian.little);
  final cols = packed.getUint16(12, Endian.little);
  final count = packed.getUint16(14, Endian.little);
  return (rows * cols + 7) ~/ 8 + rows * cols * count * fesBytesPerConstituent;
}

ByteData _rebuildTile(ByteData packed, Uint8List body) {
  final rows = packed.getUint16(10, Endian.little);
  final cols = packed.getUint16(12, Endian.little);
  final count = packed.getUint16(14, Endian.little);
  final bitmapBytes = (rows * cols + 7) ~/ 8;
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

  final rowCountsOffset = _tile.headerBytes + bitmapBytes;
  final cellsOffset = rowCountsOffset + rows * 4;
  final out = ByteData(cellsOffset + cellBytes);
  _writeDecodedHeader(out, packed, FesTile.magic, _tile.headerBytes);
  out.buffer.asUint8List().setRange(_tile.headerBytes, rowCountsOffset, body);
  for (var row = 0; row < rows; row++) {
    out.setUint32(rowCountsOffset + row * 4, before[row], Endian.little);
  }
  _unpackPlanes(body, bitmapBytes, out, cellsOffset, populated, count);
  return out;
}

int _globalCellBytes(ByteData packed) =>
    packed.getUint16(6, Endian.little) *
    packed.getUint16(8, Endian.little) *
    packed.getUint16(10, Endian.little) *
    fesBytesPerConstituent;

ByteData _rebuildGlobal(ByteData packed, Uint8List body) {
  final cellBytes = _globalCellBytes(packed);
  if (body.length != cellBytes) {
    throw const FormatException('Packed FES global layer length mismatch');
  }
  final cells =
      packed.getUint16(6, Endian.little) * packed.getUint16(8, Endian.little);
  final count = packed.getUint16(10, Endian.little);
  final out = ByteData(_global.headerBytes + cellBytes);
  _writeDecodedHeader(out, packed, FesGlobalLayer.magic, _global.headerBytes);
  _unpackPlanes(body, 0, out, _global.headerBytes, cells, count);
  return out;
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
///
/// The arithmetic avoids bitwise operators on negative numbers: compiled to
/// JavaScript they work on 32 bits and return unsigned results, so the usual
/// `(z >> 1) ^ -(z & 1)` decodes -6 as 4294967290 there.
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
    final modulus = isPhase ? _phaseModulus : 0x10000;
    var at =
        outOffset +
        (plane % count) * fesBytesPerConstituent +
        (isPhase ? 2 : 0);
    var i = srcOffset + plane * cells;
    var value = 0;
    for (var cell = 0; cell < cells; cell++, i++, at += stride) {
      final zigzag = src[i] + src[i + highOffset] * 256;
      final delta = zigzag.isEven ? zigzag ~/ 2 : -(zigzag ~/ 2) - 1;
      // Dart's % is never negative for a positive divisor.
      value = (value + delta) % modulus;
      out.setUint16(at, value, Endian.little);
    }
  }
}
