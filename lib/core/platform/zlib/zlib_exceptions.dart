/// A bounded inflate was abandoned because the body would have passed
/// [maxBytes].
class ZlibBoundExceeded implements Exception {
  const ZlibBoundExceeded(this.maxBytes);

  /// The cap the caller set.
  final int maxBytes;

  @override
  String toString() =>
      'ZlibBoundExceeded: inflated body exceeds the $maxBytes byte(s) allowed';
}

/// The bytes were not a stream the chosen framing accepts.
class ZlibFormatException implements Exception {
  const ZlibFormatException(this.message);

  final String message;

  @override
  String toString() => 'ZlibFormatException: $message';
}
