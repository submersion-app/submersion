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

  // Issue #1032: a wiped backend forces a full base republish -- 80 parts for
  // the reporting user. Without a per-part tick the sync UI sits motionless at
  // its single "uploading" step for the whole transfer and reads as frozen.
  test(
    'reports each part against a total known before the first upload',
    () async {
      final dir = await Directory.systemTemp.createTemp('src_progress');
      final path = '${dir.path}/base.json';
      await File(
        path,
      ).writeAsBytes(Uint8List.fromList(List.generate(1000, (i) => i % 256)));

      final ticks = <({int uploaded, int total})>[];
      final res = await BasePartFileSource(path, partSize: 256).uploadAll(
        (i, bytes) async {},
        onPartUploaded: (uploaded, total) =>
            ticks.add((uploaded: uploaded, total: total)),
      );

      expect(res.partCount, 4);
      expect(
        ticks.map((t) => t.uploaded),
        orderedEquals([1, 2, 3, 4]),
        reason: 'one tick per part, after it lands',
      );
      expect(
        ticks.every((t) => t.total == 4),
        isTrue,
        reason:
            'the denominator is fixed from the file length up front, so the '
            'bar cannot grow under the user mid-upload',
      );
      await dir.delete(recursive: true);
    },
  );

  test('reports a single part for an empty base', () async {
    final dir = await Directory.systemTemp.createTemp('src_progress_empty');
    final path = '${dir.path}/base.json';
    await File(path).writeAsBytes(Uint8List(0));

    final ticks = <({int uploaded, int total})>[];
    await BasePartFileSource(path).uploadAll(
      (i, bytes) async {},
      onPartUploaded: (uploaded, total) =>
          ticks.add((uploaded: uploaded, total: total)),
    );

    expect(ticks, [(uploaded: 1, total: 1)]);
    await dir.delete(recursive: true);
  });

  test(
    'empty file yields one empty part (mirrors BaseChunker.slice)',
    () async {
      final dir = await Directory.systemTemp.createTemp('src_empty');
      final path = '${dir.path}/base.json';
      await File(path).writeAsBytes(Uint8List(0));

      final uploaded = <int, Uint8List>{};
      final res = await BasePartFileSource(path).uploadAll((i, bytes) async {
        uploaded[i] = Uint8List.fromList(bytes);
      });

      expect(res.partCount, 1);
      expect(res.byteLength, 0);
      expect(uploaded[0], isEmpty);
      expect(res.wholeChecksum, BaseChunker.checksum(Uint8List(0)));
      expect(res.partChecksums.single, BaseChunker.checksum(Uint8List(0)));
      await dir.delete(recursive: true);
    },
  );
}
