import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

import 'package:submersion/core/services/sync/changeset_log/sync_temp_sink.dart';

/// A [SyncTempSink] that gzips as it writes, so a base streamed to disk is
/// stored compressed only, never staged plain with a compressed copy written
/// beside it (issue #4256).
///
/// The file is one ordinary gzip member (RFC 1952), so any gzip reader takes
/// it. Bytes added before [endHead] are the head: kept in memory, patchable
/// through [writeAt] (the base export fills its checksum in over a
/// placeholder there), and written on [close] as stored, uncompressed deflate
/// blocks into space reserved for them after the gzip header. A stored
/// block's size depends only on how many bytes it holds, so the reservation
/// is exact before the head's final bytes are known. Everything added after
/// [endHead] streams through a raw deflate encoder, whose stream continues
/// the stored blocks and ends the member. The trailer's CRC-32 joins the
/// head's, known only at the end, with the body's, kept as it streams.
///
/// [length] counts uncompressed bytes, the offsets [writeAt] takes;
/// [diskLength] is the size of the file.
///
/// Native only: a browser never writes a compressed base.
class GzipTempSink implements SyncTempSink {
  GzipTempSink(this._file);

  /// RFC 1952 header: magic, deflate, no flags, no mtime, no extra flags,
  /// unknown OS.
  static const List<int> _gzipHeader = [
    0x1f,
    0x8b,
    0x08,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0xff,
  ];

  /// The most bytes one stored deflate block holds.
  static const int _maxStoredBlock = 0xffff;

  final SyncTempSink _file;
  final List<int> _head = [];
  final List<List<int>> _compressed = [];
  ByteConversionSink? _encoder;
  int _reserved = 0;
  int _bodyCrc = 0;
  int _bodyLength = 0;
  bool _closing = false;

  @override
  String get path => _file.path;

  @override
  int get length => _head.length + _bodyLength;

  /// Bytes on disk so far; the file's size once closed.
  int get diskLength => _file.length;

  @override
  Future<void> add(List<int> bytes) async {
    _checkOpen();
    final encoder = _encoder;
    if (encoder == null) {
      _head.addAll(bytes);
      return;
    }
    _bodyCrc = getCrc32(bytes, _bodyCrc);
    _bodyLength += bytes.length;
    encoder.add(bytes);
    await _drain();
  }

  /// Ends the head: the bytes added so far stay patchable, and every later
  /// one is compressed on its way to disk.
  Future<void> endHead() async {
    _checkOpen();
    return _endHead();
  }

  Future<void> _endHead() async {
    if (_encoder != null) throw StateError('the head has already ended');
    _reserved = _gzipHeader.length + _storedLength(_head.length);
    await _file.add(Uint8List(_reserved));
    _encoder = ZLibEncoder(
      raw: true,
    ).startChunkedConversion(_ChunkCollector(_compressed));
  }

  /// Overwrites [bytes] at [offset], which must lie within the head.
  @override
  Future<void> writeAt(int offset, List<int> bytes) async {
    _checkOpen();
    RangeError.checkValueInInterval(offset, 0, _head.length, 'offset');
    RangeError.checkValueInInterval(
      offset + bytes.length,
      0,
      _head.length,
      'end',
    );
    _head.setRange(offset, offset + bytes.length, bytes);
  }

  @override
  Future<String> close() async {
    // A failed close is retried by the caller's cleanup; the file is shut
    // already by then.
    if (_closing) return path;
    _closing = true;
    try {
      if (_encoder == null) await _endHead();
      _encoder!.close();
      await _drain();
      final crc = _crc32Combine(getCrc32(_head), _bodyCrc, _bodyLength);
      await _file.add(_uint32Le(crc) + _uint32Le(length & 0xffffffff));
      final front = [..._gzipHeader, ..._storedBlocks(_head)];
      if (front.length != _reserved) {
        throw StateError(
          'stored gzip head is ${front.length} bytes, $_reserved reserved',
        );
      }
      await _file.writeAt(0, front);
      // Inside the try: a failed close is tried once more below, since a
      // later close of this sink returns at once.
      return await _file.close();
    } catch (_) {
      await _file.close().catchError((Object _) => path);
      rethrow;
    }
  }

  void _checkOpen() {
    if (_closing) throw StateError('the sink is closed');
  }

  Future<void> _drain() async {
    for (final chunk in _compressed) {
      await _file.add(chunk);
    }
    _compressed.clear();
  }

  /// The size of [_storedBlocks] for [n] bytes: five framing bytes for each
  /// block of up to [_maxStoredBlock], and at least one block.
  static int _storedLength(int n) {
    final blocks = n == 0 ? 1 : (n + _maxStoredBlock - 1) ~/ _maxStoredBlock;
    return n + 5 * blocks;
  }

  /// [bytes] as stored deflate blocks, none of them final: the body's raw
  /// deflate stream follows and carries the final block. An empty head is
  /// one empty block.
  static List<int> _storedBlocks(List<int> bytes) {
    final out = <int>[];
    var start = 0;
    do {
      final end = bytes.length - start > _maxStoredBlock
          ? start + _maxStoredBlock
          : bytes.length;
      final n = end - start;
      // BFINAL 0, BTYPE 00, padded to the byte; then LEN and its complement.
      out
        ..add(0x00)
        ..addAll(_uint16Le(n))
        ..addAll(_uint16Le(~n & 0xffff))
        ..addAll(bytes.sublist(start, end));
      start = end;
    } while (start < bytes.length);
    return out;
  }

  static List<int> _uint16Le(int v) => [v & 0xff, (v >> 8) & 0xff];

  static List<int> _uint32Le(int v) => [
    v & 0xff,
    (v >> 8) & 0xff,
    (v >> 16) & 0xff,
    (v >> 24) & 0xff,
  ];
}

/// The CRC-32 of A followed by B, from A's CRC [crc1], B's CRC [crc2] and
/// B's length [len2]: zlib's `crc32_combine`, which shifts [crc1] past
/// [len2] zero bytes by repeated squaring of the CRC's GF(2) operator.
int _crc32Combine(int crc1, int crc2, int len2) {
  if (len2 <= 0) return crc1;
  final odd = List<int>.filled(32, 0);
  final even = List<int>.filled(32, 0);
  // The operator for one zero bit.
  odd[0] = 0xedb88320;
  var row = 1;
  for (var n = 1; n < 32; n++) {
    odd[n] = row;
    row <<= 1;
  }
  _gf2Square(even, odd); // two zero bits
  _gf2Square(odd, even); // four zero bits
  var crc = crc1;
  var len = len2;
  // Each pass squares the operator into a whole byte, then two, four...,
  // applying it wherever [len] has a bit set.
  do {
    _gf2Square(even, odd);
    if (len & 1 != 0) crc = _gf2Times(even, crc);
    len >>= 1;
    if (len == 0) break;
    _gf2Square(odd, even);
    if (len & 1 != 0) crc = _gf2Times(odd, crc);
    len >>= 1;
  } while (len != 0);
  return crc ^ crc2;
}

int _gf2Times(List<int> mat, int vec) {
  var sum = 0;
  var v = vec;
  var i = 0;
  while (v != 0) {
    if (v & 1 != 0) sum ^= mat[i];
    v >>= 1;
    i++;
  }
  return sum;
}

void _gf2Square(List<int> square, List<int> mat) {
  for (var n = 0; n < 32; n++) {
    square[n] = _gf2Times(mat, mat[n]);
  }
}

/// Collects the encoder's output, which it hands over synchronously from
/// each `add`, for [GzipTempSink] to write out.
class _ChunkCollector implements Sink<List<int>> {
  _ChunkCollector(this._chunks);

  final List<List<int>> _chunks;

  @override
  void add(List<int> data) => _chunks.add(data);

  @override
  void close() {}
}
