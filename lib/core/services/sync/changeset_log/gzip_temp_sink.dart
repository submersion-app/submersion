import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/services/sync/changeset_log/sync_temp_sink.dart';

/// A [SyncTempSink] that gzips as it writes, so a base streamed to disk is
/// stored compressed only, never staged plain with a compressed copy written
/// beside it (issue #4256).
///
/// The file holds two gzip members, which a gzip reader joins into one
/// document. Bytes added before [endHead] are the head: kept in memory,
/// patchable through [writeAt] (the base export fills its checksum in over a
/// placeholder there), and written on [close] as a stored, uncompressed
/// member into space reserved for it at the start of the file. A stored
/// member's size depends only on how many bytes it holds, so the reservation
/// is exact before the head's final bytes are known. Everything added after
/// [endHead] streams through the gzip encoder as the second member.
///
/// [length] counts uncompressed bytes, the offsets [writeAt] takes;
/// [diskLength] is the size of the file.
///
/// Native only: a browser never writes a compressed base.
class GzipTempSink implements SyncTempSink {
  GzipTempSink(this._file);

  static final GZipCodec _stored = GZipCodec(level: 0);

  final SyncTempSink _file;
  final List<int> _head = [];
  final List<List<int>> _compressed = [];
  ByteConversionSink? _encoder;
  int _reserved = 0;
  int _length = 0;
  bool _closing = false;

  @override
  String get path => _file.path;

  @override
  int get length => _length;

  /// Bytes on disk so far; the file's size once closed.
  int get diskLength => _file.length;

  @override
  Future<void> add(List<int> bytes) async {
    _length += bytes.length;
    final encoder = _encoder;
    if (encoder == null) {
      _head.addAll(bytes);
      return;
    }
    encoder.add(bytes);
    await _drain();
  }

  /// Ends the head: the bytes added so far stay patchable, and every later
  /// one is compressed on its way to disk.
  Future<void> endHead() async {
    if (_encoder != null) throw StateError('the head has already ended');
    _reserved = _stored.encode(_head).length;
    await _file.add(Uint8List(_reserved));
    _encoder = gzip.encoder.startChunkedConversion(
      _ChunkCollector(_compressed),
    );
  }

  /// Overwrites [bytes] at [offset], which must lie within the head.
  @override
  Future<void> writeAt(int offset, List<int> bytes) async {
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
      if (_encoder == null) await endHead();
      _encoder!.close();
      await _drain();
      final head = _stored.encode(_head);
      if (head.length != _reserved) {
        throw StateError(
          'stored gzip head is ${head.length} bytes, $_reserved reserved',
        );
      }
      await _file.writeAt(0, head);
    } catch (_) {
      await _file.close().catchError((Object _) => path);
      rethrow;
    }
    return _file.close();
  }

  Future<void> _drain() async {
    for (final chunk in _compressed) {
      await _file.add(chunk);
    }
    _compressed.clear();
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
