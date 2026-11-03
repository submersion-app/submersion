import 'dart:typed_data';

/// A big-endian uint64 write that also runs in the web app, where
/// ByteData's 64-bit accessors throw "not supported by dart2js" (#4194).
extension Uint64Halves on ByteData {
  /// Writes [value] at [byteOffset] as two big-endian 32-bit halves: the
  /// bytes `setUint64(byteOffset, value)` writes on the VM. Compiled to
  /// JavaScript it is exact up to 2^53.
  ///
  /// Throws [RangeError] on a negative [value]. The halves would otherwise
  /// wrap it silently, since `~/` truncates and `%` is never negative.
  void setUint64Halves(int byteOffset, int value) {
    RangeError.checkNotNegative(value, 'value');
    setUint32(byteOffset, value ~/ 0x100000000);
    setUint32(byteOffset + 4, value % 0x100000000);
  }
}
