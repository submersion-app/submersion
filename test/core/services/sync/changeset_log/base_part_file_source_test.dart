import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_source.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher.dart';
import 'package:submersion/core/utils/off_isolate.dart';

import '../../../../helpers/base_parts.dart';
import '../../../../helpers/recording_base_part_hasher.dart';

Future<String> _fileOf(int length) async {
  final dir = await Directory.systemTemp.createTemp('src_hasher');
  addTearDown(() => dir.delete(recursive: true));
  final path = p.join(dir.path, 'base.json');
  await File(
    path,
  ).writeAsBytes(List.generate(length, (i) => i % 256), flush: true);
  return path;
}

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
      final expected = sliceBaseParts(data);

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

  test('empty file yields one empty part', () async {
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
  });

  group('through a hasher', () {
    test('a real worker gives the digests the manifest expects', () async {
      const partSize = kOffIsolateMinBytes;
      final path = await _fileOf(2 * partSize + 12345);
      final data = await File(path).readAsBytes();

      final res = await BasePartFileSource(
        path,
        partSize: partSize,
      ).uploadAll((i, bytes) async {});

      expect(res.partCount, 3);
      expect(res.wholeChecksum, BaseChunker.checksum(data));
      expect(
        res.partChecksums,
        sliceBaseParts(data, partSize: partSize).map(BaseChunker.checksum),
      );
    });

    test('a skipped part is still hashed', () async {
      final path = await _fileOf(1000);
      final hasher = RecordingBasePartHasher();

      final res = await BasePartFileSource(
        path,
        partSize: 256,
        openHasher: (_) async => hasher,
      ).uploadAll((i, bytes) async {}, skipPart: (_) => true);

      expect(hasher.added, 4);
      expect(res.partChecksums, hasLength(4));
    });

    test('the digests it returns are the ones reported', () async {
      final path = await _fileOf(300);
      final data = await File(path).readAsBytes();

      final res = await BasePartFileSource(
        path,
        partSize: 256,
        openHasher: (_) async => RecordingBasePartHasher(),
      ).uploadAll((i, bytes) async {});

      expect(
        res.partChecksums,
        sliceBaseParts(data, partSize: 256).map(BaseChunker.checksum),
      );
      expect(res.wholeChecksum, 'sha256:whole');
    });

    test('a hasher failure stops the transfer before its upload', () async {
      final path = await _fileOf(1000);
      final hasher = RecordingBasePartHasher(failOnPart: 1);
      final uploaded = <int>[];

      await expectLater(
        BasePartFileSource(
          path,
          partSize: 256,
          openHasher: (_) async => hasher,
        ).uploadAll((i, bytes) async => uploaded.add(i)),
        throwsA(isA<BasePartHasherException>()),
      );

      expect(uploaded, [0]);
      expect(hasher.disposals, 1);
    });

    test('a failed upload still releases the hasher', () async {
      final path = await _fileOf(1000);
      final hasher = RecordingBasePartHasher();

      await expectLater(
        BasePartFileSource(
          path,
          partSize: 256,
          openHasher: (_) async => hasher,
        ).uploadAll((i, bytes) async {
          if (i == 1) throw StateError('network');
        }),
        throwsStateError,
      );

      expect(hasher.disposals, 1);
    });

    test('a finished transfer releases the hasher', () async {
      final path = await _fileOf(1000);
      final hasher = RecordingBasePartHasher();

      await BasePartFileSource(
        path,
        partSize: 256,
        openHasher: (_) async => hasher,
      ).uploadAll((i, bytes) async {});

      expect(hasher.disposals, 1);
    });

    for (final (length, expected) in [(1000, 256), (256, 256), (100, 100)]) {
      test('a $length byte file opens for a $expected byte part', () async {
        final path = await _fileOf(length);
        final opened = <int>[];

        await BasePartFileSource(
          path,
          partSize: 256,
          openHasher: (firstPartBytes) async {
            opened.add(firstPartBytes);
            return RecordingBasePartHasher();
          },
        ).uploadAll((i, bytes) async {});

        expect(opened, [expected]);
      });
    }

    test('an empty file opens for no bytes and yields one part', () async {
      final path = await _fileOf(0);
      final opened = <int>[];
      final hasher = RecordingBasePartHasher();

      final res = await BasePartFileSource(
        path,
        openHasher: (firstPartBytes) async {
          opened.add(firstPartBytes);
          return hasher;
        },
      ).uploadAll((i, bytes) async {});

      expect(opened, [0]);
      expect(hasher.added, 1);
      expect(res.partCount, 1);
    });

    test('a whole multiple of the part size has no empty last part', () async {
      final path = await _fileOf(512);
      final data = await File(path).readAsBytes();

      final res = await BasePartFileSource(
        path,
        partSize: 256,
      ).uploadAll((i, bytes) async {});

      expect(res.partCount, 2);
      expect(res.wholeChecksum, BaseChunker.checksum(data));
    });
  });
}
