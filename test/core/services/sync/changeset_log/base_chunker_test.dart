import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

void main() {
  Uint8List bytes(int n) =>
      Uint8List.fromList(List.generate(n, (i) => i % 256));

  test('checksum is stable and detects corruption', () {
    final data = bytes(300);
    final c1 = BaseChunker.checksum(data);
    expect(c1, startsWith('sha256:'));
    expect(BaseChunker.checksum(data), c1);
    final corrupted = Uint8List.fromList(data)..[0] ^= 0xFF;
    expect(BaseChunker.checksum(corrupted), isNot(c1));
  });
}
