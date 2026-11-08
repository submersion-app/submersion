import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/zigzag.dart';

void main() {
  test('zigzagDecode alternates signs from zero', () {
    expect(
      [for (var z = 0; z < 7; z++) zigzagDecode(z)],
      [0, -1, 1, -2, 2, -3, 3],
    );
  });

  test('zigzagDecode reaches both ends of the uint16 range', () {
    expect(zigzagDecode(65534), 32767);
    expect(zigzagDecode(65535), -32768);
  });
}
