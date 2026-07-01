import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_source.dart';

void main() {
  test(
    'yields parts + checksums matching BaseChunker over a multi-part file',
    () async {
      final dir = await Directory.systemTemp.createTemp('src');
      final path = '${dir.path}/base.json';
      // 2.5 parts of the 8 MB default so we cross part boundaries with a remainder.
      final data = Uint8List.fromList(
        List.generate(2 * BaseChunker.defaultPartSize + 12345, (i) => i % 256),
      );
      await File(path).writeAsBytes(data);
      final expected = BaseChunker.slice(data);

      final uploaded = <int, Uint8List>{};
      final res = await BasePartFileSource(path).uploadAll((i, bytes) async {
        uploaded[i] = Uint8List.fromList(bytes);
      });

      expect(res.partCount, expected.length);
      expect(res.byteLength, data.length);
      expect(res.wholeChecksum, BaseChunker.checksum(data));
      for (var i = 0; i < expected.length; i++) {
        expect(uploaded[i], expected[i], reason: 'part $i bytes');
        expect(res.partChecksums[i], BaseChunker.checksum(expected[i]));
      }
      await dir.delete(recursive: true);
    },
  );

  test('small partSize slices a file into many parts', () async {
    final dir = await Directory.systemTemp.createTemp('src_small');
    final path = '${dir.path}/base.json';
    final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    await File(path).writeAsBytes(data);

    final uploaded = <int, Uint8List>{};
    final res = await BasePartFileSource(path, partSize: 256).uploadAll((
      i,
      bytes,
    ) async {
      uploaded[i] = Uint8List.fromList(bytes);
    });

    expect(res.partCount, 4); // 256 + 256 + 256 + 232
    final reassembled = <int>[
      for (final i in uploaded.keys.toList()..sort()) ...uploaded[i]!,
    ];
    expect(reassembled, data);
    expect(res.wholeChecksum, BaseChunker.checksum(data));
    await dir.delete(recursive: true);
  });
}
