import 'dart:typed_data';

import 'package:submersion/core/platform/zlib/platform_zlib.dart';

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
/// [framing] chooses the wrapper, so the same guard covers zlib and gzip.
/// The decoder runs chunked, so a compression bomb is abandoned at the first
/// chunk over the cap rather than after the whole body is in memory.
///
/// Throws [BoundedInflateException] if [bytes] is longer than
/// [maxBlobBytes], is not a stream in [framing], or inflates past
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
  required ZlibFraming framing,
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
  // Before the conversion, not inside the decoder: the native filter copies
  // the whole input before it emits a first chunk, so a check on the output
  // side never sees an oversized blob.
  if (bytes.length > maxBlobBytes) {
    throw BoundedInflateException(
      'blob of ${bytes.length} byte(s) exceeds the $maxBlobBytes allowed',
    );
  }
  try {
    return PlatformZlib.inflateBounded(
      bytes,
      maxBytes: maxBytes,
      framing: framing,
    );
  } on ZlibBoundExceeded {
    throw BoundedInflateException(
      'inflated body exceeds the $maxBytes byte(s) allowed',
    );
  } on ZlibFormatException catch (e) {
    throw BoundedInflateException(
      'not a valid compressed stream: ${e.message}',
    );
  }
}
