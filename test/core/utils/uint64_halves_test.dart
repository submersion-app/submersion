import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/uint64_halves.dart';

/// The halves must be the bytes setUint64 writes, so data the desktop app
/// wrote with it (backup frame AAD, the Suunto sign-in counter) still
/// matches. test/web/js_integers covers the browser side.
void main() {
  for (final value in [
    0,
    1,
    255,
    0xFFFFFFFF,
    0x100000000,
    4294967297,
    56666666,
  ]) {
    test('$value matches setUint64', () {
      final halves = ByteData(10)..setUint64Halves(1, value);
      final whole = ByteData(10)..setUint64(1, value);
      expect(halves.buffer.asUint8List(), whole.buffer.asUint8List());
    });
  }

  test('a negative value is refused', () {
    expect(() => ByteData(8).setUint64Halves(0, -1), throwsRangeError);
  });
}
