import 'dart:convert';
import 'dart:typed_data';

/// A compressed blob was refused: too long, not a stream, or it expanded
/// past the cap its caller allowed.
///
/// Callers translate this into whatever their own layer calls malformed
/// input, so a bad blob never escapes as a private runtime type.
class BoundedInflateException implements Exception {
  final String message;

  const BoundedInflateException(this.message);

  @override
  String toString() => 'BoundedInflateException: $message';
}

/// Inflates a compressed stream, refusing anything that expands past
/// [maxBytes].
///
/// [decoder] chooses the framing, so the same guard covers zlib
/// (`zlib.decoder`) and gzip (`gzip.decoder`). The decoder runs chunked, so
/// a compression bomb is abandoned at the first chunk over the cap rather
/// than after the whole body is in memory.
///
/// Throws [BoundedInflateException] if [bytes] is longer than
/// [maxBlobBytes], is not a stream [decoder] accepts, or inflates past
/// [maxBytes]. Errors that are not malformed input, an [ArgumentError] from
/// a bad cap among them, are left to surface.
///
/// Not a completeness check. Both framings accept a truncated stream,
/// returning the bytes they managed to inflate with no error, and a stream
/// missing only its trailer returns its body in full, so the checksum is
/// never verified. Both were measured. Callers must frame their own
/// payload.
Uint8List inflateBounded(
  List<int> bytes, {
  required Converter<List<int>, List<int>> decoder,
  required int maxBytes,
  required int maxBlobBytes,
}) {
  if (maxBytes < 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'must not be negative');
  }
  if (maxBlobBytes < 0) {
    throw ArgumentError.value(
      maxBlobBytes,
      'maxBlobBytes',
      'must not be negative',
    );
  }
  // Before the conversion, not inside the sink: the filter copies the whole
  // input natively before it emits a first chunk, so a sink-side check
  // never sees an oversized blob.
  if (bytes.length > maxBlobBytes) {
    throw BoundedInflateException(
      'blob of ${bytes.length} byte(s) exceeds the $maxBlobBytes allowed',
    );
  }
  final sink = _BoundedByteSink(maxBytes);
  try {
    final input = decoder.startChunkedConversion(sink);
    input
      ..add(bytes)
      ..close();
  } on FormatException catch (e) {
    throw BoundedInflateException(
      'not a valid compressed stream: ${e.message}',
    );
  }
  return sink.takeBytes();
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
      throw BoundedInflateException(
        'inflated body exceeds the $_maxBytes byte(s) allowed',
      );
    }
    _builder.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}
