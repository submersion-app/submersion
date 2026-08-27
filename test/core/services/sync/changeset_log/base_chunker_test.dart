import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';

void main() {
  Uint8List bytes(int n) =>
      Uint8List.fromList(List.generate(n, (i) => i % 256));

  test('slice then reassemble is identity', () {
    final data = bytes(1000);
    final parts = BaseChunker.slice(data, partSize: 256);
    expect(parts.length, 4); // 256+256+256+232
    expect(BaseChunker.reassemble(parts), data);
  });

  test('exact multiple of partSize slices evenly', () {
    final data = bytes(512);
    final parts = BaseChunker.slice(data, partSize: 256);
    expect(parts.length, 2);
    expect(BaseChunker.reassemble(parts), data);
  });

  test('empty data yields one empty part and round-trips', () {
    final parts = BaseChunker.slice(Uint8List(0), partSize: 256);
    expect(parts.length, 1);
    expect(BaseChunker.reassemble(parts).length, 0);
  });

  test('checksum is stable and detects corruption', () {
    final data = bytes(300);
    final c1 = BaseChunker.checksum(data);
    expect(c1, startsWith('sha256:'));
    expect(BaseChunker.checksum(data), c1);
    final corrupted = Uint8List.fromList(data)..[0] ^= 0xFF;
    expect(BaseChunker.checksum(corrupted), isNot(c1));
  });
}
