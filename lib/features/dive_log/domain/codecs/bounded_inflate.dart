import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

/// The largest sample count either series codec will encode or decode.
///
/// 262,144 samples is over 72 hours at one hertz, where the longest dive the
/// round-trip tests call realistic is 20,000 samples. The cap is not a claim
/// about plausible dives but a bound on allocation: the profile decoder
/// sizes one list per field from this count, and decoding a full series was
/// measured to retain about 200 MB (the reference arrays, the boxed doubles
/// and ints inside the nullable columns, the per-column presence lists, and
/// the [ProfileSample] objects, which are all live at once). A declared
/// count costs one varint, so it must not size anything unbounded.
///
/// Encode enforces the same cap. A blob this codec would refuse to read must
/// never be written, because part 2 drops the source rows once a series is
/// packed.
const int kMaxSeriesSampleCount = 1 << 18;

/// The largest uncompressed body either series codec will inflate.
///
/// This is the outer bound against unbounded inflation, not the binding
/// guard. For the profile codec [kMaxSeriesSampleCount] binds first: a
/// maximal series is roughly 37 MB of body, so this leaves headroom rather
/// than sitting on the real limit. Sizing it snugly would trade that
/// headroom for the risk of refusing a legitimate series, which for packed
/// storage means data that cannot be read back.
const int kMaxSeriesBodyBytes = 64 * 1024 * 1024;

/// The largest compressed blob either series codec will accept.
///
/// zlib output for a body under [kMaxSeriesBodyBytes] cannot exceed it by
/// more than stream overhead even for incompressible input, so matching the
/// two can never refuse a blob the body cap would have accepted. Without
/// this, arbitrary bytes appended after a complete zlib stream are copied
/// whole into the native filter and then silently discarded: a 64 MiB pad
/// was measured returning a five byte body, no error, and a 135 MB spike.
const int kMaxSeriesBlobBytes = kMaxSeriesBodyBytes;

/// Inflates a zlib stream, refusing anything that expands past [maxBytes].
///
/// The decoder runs chunked, so a compression bomb is abandoned at the first
/// chunk over the cap rather than after the whole body is in memory.
///
/// Throws [ProfileSeriesCodecException] if [bytes] is longer than
/// [maxBlobBytes], is not a zlib stream, or inflates past [maxBytes].
/// Errors that are not malformed input, an [ArgumentError] from a bad cap
/// among them, are left to surface.
///
/// Not a completeness check. zlib accepts a truncated stream, returning the
/// bytes it managed to inflate with no error, and a stream missing only its
/// four byte adler-32 trailer returns its body in full, so the checksum is
/// never verified. Both were measured. Callers must frame their own payload;
/// the series codecs do, by refusing a body whose column blocks do not span
/// it exactly.
Uint8List inflateBounded(
  Uint8List bytes, {
  int maxBytes = kMaxSeriesBodyBytes,
  int maxBlobBytes = kMaxSeriesBlobBytes,
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
    throw ProfileSeriesCodecException(
      'blob of ${bytes.length} byte(s) exceeds the $maxBlobBytes allowed',
    );
  }
  final sink = _BoundedByteSink(maxBytes);
  try {
    final input = ZLibCodec().decoder.startChunkedConversion(sink);
    input
      ..add(bytes)
      ..close();
  } on FormatException catch (e) {
    throw ProfileSeriesCodecException('not a zlib stream: ${e.message}');
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
      // Thrown from inside the zlib filter's own add, which unwinds it.
      throw ProfileSeriesCodecException(
        'inflated body exceeds the $_maxBytes byte(s) allowed',
      );
    }
    _builder.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}
