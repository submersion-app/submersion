import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/services/float16.dart';

void main() {
  test('values survive a round trip within half precision', () {
    final values = Float32List.fromList([
      0,
      1,
      -1,
      0.5,
      0.001953125,
      65504,
      -0.333,
    ]);
    final back = decodeFloat16(encodeFloat16(values));
    expect(back, hasLength(values.length));
    for (var i = 0; i < values.length; i++) {
      expect(back[i], closeTo(values[i], values[i].abs() * 1e-3 + 1e-6));
    }
  });

  test('one is 0x3C00, little endian', () {
    expect(encodeFloat16(Float32List.fromList([1])), [0x00, 0x3C]);
    expect(decodeFloat16(Uint8List.fromList([0x00, 0x3C])), [1.0]);
  });

  test('minus two is 0xC000', () {
    expect(encodeFloat16(Float32List.fromList([-2])), [0x00, 0xC0]);
  });

  test('a subnormal half decodes', () {
    // 0x0001 is the smallest positive subnormal: 2^-24.
    expect(
      decodeFloat16(Uint8List.fromList([0x01, 0x00])).single,
      closeTo(5.960464477539063e-8, 1e-12),
    );
  });

  test('infinity and NaN decode', () {
    expect(
      decodeFloat16(Uint8List.fromList([0x00, 0x7C])).single,
      double.infinity,
    );
    expect(
      decodeFloat16(Uint8List.fromList([0x00, 0x7E])).single.isNaN,
      isTrue,
    );
  });

  test('a value too large for half precision encodes as infinity', () {
    expect(encodeFloat16(Float32List.fromList([1e6])), [0x00, 0x7C]);
  });

  test('an odd byte count is refused', () {
    expect(
      () => decodeFloat16(Uint8List.fromList([1, 2, 3])),
      throwsArgumentError,
    );
  });
}
