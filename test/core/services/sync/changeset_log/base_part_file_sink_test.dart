import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';

void main() {
  late Directory dir;
  late BasePartFileSink sink;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('base_sink_test');
    sink = BasePartFileSink(tempDirProvider: () async => dir);
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  test('assembles parts into one file and returns its path', () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final whole = BaseChunker.checksum(bytes('hello world'));
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: whole,
      partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsString(), 'hello world');
  });

  test(
    'returns null and deletes the file on a per-part checksum mismatch',
    () async {
      final p0 = bytes('hello ');
      final p1 = bytes('world');
      final path = await sink.assemble(
        name: 'base',
        partCount: 2,
        wholeChecksum: null,
        partChecksums: [BaseChunker.checksum(p0), 'sha256:deadbeef'],
        downloadPart: (i) async => [p0, p1][i],
      );
      expect(path, isNull);
      expect(dir.listSync().whereType<File>(), isEmpty);
    },
  );

  test('returns null when a part is missing', () async {
    final p0 = bytes('hello ');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: null,
      partChecksums: [BaseChunker.checksum(p0), 'sha256:whatever'],
      downloadPart: (i) async => i == 0 ? p0 : null,
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('returns null on a whole-file checksum mismatch', () async {
    final p0 = bytes('hello ');
    final p1 = bytes('world');
    final path = await sink.assemble(
      name: 'base',
      partCount: 2,
      wholeChecksum: 'sha256:notreal',
      partChecksums: [BaseChunker.checksum(p0), BaseChunker.checksum(p1)],
      downloadPart: (i) async => [p0, p1][i],
    );
    expect(path, isNull);
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('verifies whole-file checksum across many parts', () async {
    final parts = List.generate(10, (i) => bytes('chunk$i-'));
    final joined = bytes(parts.map((p) => String.fromCharCodes(p)).join());
    final path = await sink.assemble(
      name: 'multi',
      partCount: parts.length,
      wholeChecksum: BaseChunker.checksum(joined),
      partChecksums: parts.map(BaseChunker.checksum).toList(),
      downloadPart: (i) async => parts[i],
    );
    expect(path, isNotNull);
    expect(await File(path!).readAsBytes(), joined);
  });

  test('deleteQuietly removes a file and never throws', () async {
    final f = File('${dir.path}/x');
    await f.writeAsString('y');
    await sink.deleteQuietly(f.path);
    expect(f.existsSync(), isFalse);
    await sink.deleteQuietly('${dir.path}/does-not-exist'); // no throw
  });
}
