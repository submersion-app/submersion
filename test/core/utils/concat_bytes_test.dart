import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/concat_bytes.dart';

void main() {
  test('joins two byte lists into one Uint8List', () {
    final out = concatBytes([1, 2, 3], Uint8List.fromList([4, 5]));
    expect(out, isA<Uint8List>());
    expect(out, [1, 2, 3, 4, 5]);
  });

  test('either side may be empty', () {
    expect(concatBytes([], [7]), [7]);
    expect(concatBytes([7], []), [7]);
    expect(concatBytes([], []), isEmpty);
  });

  test('the result is a copy', () {
    final a = Uint8List.fromList([1]);
    final out = concatBytes(a, [2]);
    a[0] = 9;
    expect(out, [1, 2]);
  });
}
