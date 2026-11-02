import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:submersion/core/platform/zlib/zlib_exceptions.dart';
import 'package:submersion/core/platform/zlib/zlib_framing.dart';

/// Native implementation of the zlib facade: `dart:io`'s codecs, which link
/// the platform's zlib.
abstract final class PlatformZlib {
  /// Compresses [bytes] into a zlib stream at [level] (zlib's 6 by default).
  static Uint8List deflate(List<int> bytes, {int level = 6}) =>
      _asBytes(io.ZLibCodec(level: level).encode(bytes));

  /// Inflates a zlib stream with no cap on the body.
  static Uint8List inflate(List<int> bytes) =>
      _decode(io.ZLibCodec().decoder, bytes);

  /// Inflates a stream in [framing], refusing a body that would pass
  /// [maxBytes].
  ///
  /// The decoder runs chunked, so a compression bomb is abandoned at the
  /// first chunk over the cap rather than after the whole body is in memory.
  /// Throws [ZlibBoundExceeded] at the cap and [ZlibFormatException] for
  /// bytes that are not a stream in [framing].
  static Uint8List inflateBounded(
    List<int> bytes, {
    required int maxBytes,
    ZlibFraming framing = ZlibFraming.zlib,
  }) {
    RangeError.checkNotNegative(maxBytes, 'maxBytes');
    final decoder = switch (framing) {
      ZlibFraming.zlib => io.ZLibCodec().decoder,
      ZlibFraming.gzip => io.GZipCodec().decoder,
    };
    final sink = _BoundedByteSink(maxBytes);
    try {
      decoder.startChunkedConversion(sink)
        ..add(bytes)
        ..close();
    } on FormatException catch (e) {
      throw ZlibFormatException(e.message);
    }
    return sink.takeBytes();
  }

  /// Compresses [bytes] into a gzip stream at [level].
  static Uint8List gzip(List<int> bytes, {int level = 6}) =>
      _asBytes(io.GZipCodec(level: level).encode(bytes));

  /// Inflates a gzip stream with no cap on the body.
  static Uint8List gunzip(List<int> bytes) =>
      _decode(io.GZipCodec().decoder, bytes);

  static Uint8List _decode(
    Converter<List<int>, List<int>> decoder,
    List<int> bytes,
  ) {
    try {
      return _asBytes(decoder.convert(bytes));
    } on FormatException catch (e) {
      throw ZlibFormatException(e.message);
    }
  }

  static Uint8List _asBytes(List<int> bytes) =>
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

/// Collects inflated chunks and throws as soon as they pass [_maxBytes].
class _BoundedByteSink implements Sink<List<int>> {
  _BoundedByteSink(this._maxBytes);

  final int _maxBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (_builder.length + chunk.length > _maxBytes) {
      // Thrown from inside the inflate filter's own add, which unwinds it.
      throw ZlibBoundExceeded(_maxBytes);
    }
    _builder.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}
