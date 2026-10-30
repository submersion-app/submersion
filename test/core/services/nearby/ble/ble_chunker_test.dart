import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/ble/ble_chunker.dart';

void main() {
  test('split uses mtu minus 3 and never below 20', () {
    final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
    final big = BleChunker.split(bytes, 185);
    expect(big.map((c) => c.length), [182, 182, 136]);
    expect(big.expand((c) => c), bytes);

    final tiny = BleChunker.split(bytes, 10);
    expect(tiny.first, hasLength(20));
    expect(tiny.expand((c) => c), bytes);
  });

  test('split of an empty payload yields no chunks', () {
    expect(BleChunker.split(Uint8List(0), 185), isEmpty);
  });

  test('payloadSize clamps the negotiated mtu, never above the 512-byte '
      'attribute value limit', () {
    expect(BleChunker.payloadSize(517), 512);
    expect(BleChunker.payloadSize(515), 512);
    expect(BleChunker.payloadSize(247), 244);
    expect(BleChunker.payloadSize(23), 20);
    expect(BleChunker.payloadSize(null), 20);
  });
}
