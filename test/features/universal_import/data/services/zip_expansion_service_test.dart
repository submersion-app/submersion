import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/universal_import/data/services/zip_expansion_service.dart';

Uint8List _buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

List<int> _zxu() =>
    ('FSH|^~<>{}|OCI201^^|ZXU|20240613080000|\n'
            'ZDH|1|1|I|Q1S|20240612093000|28.0||FO2|\n'
            'ZDT|1|1|18.29|20240612093600|0.000000|0|\n')
        .codeUnits;

void main() {
  const service = ZipExpansionService();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('zip_expansion_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> writeZip(String name, Map<String, List<int>> entries) async {
    final path = p.join(tmp.path, name);
    await File(path).writeAsBytes(_buildZip(entries));
    return path;
  }

  group('isZipBytes', () {
    test('recognizes the PK magic and rejects other content', () {
      expect(
        ZipExpansionService.isZipBytes(_buildZip({'a.zxu': _zxu()})),
        isTrue,
      );
      expect(
        ZipExpansionService.isZipBytes(
          Uint8List.fromList('FSH|^~<>{}|'.codeUnits),
        ),
        isFalse,
      );
      expect(ZipExpansionService.isZipBytes(Uint8List(0)), isFalse);
    });
  });

  group('expandAll', () {
    test('passes non-zip paths through unchanged', () async {
      final plain = p.join(tmp.path, 'dive.zxu');
      await File(plain).writeAsBytes(_zxu());
      final expansion = await service.expandAll([plain]);
      expect(expansion.filePaths, [plain]);
      expect(expansion.photoPathsByBaseName, isEmpty);
    });

    test(
      'expands a DiveCloud-style zip: dive files + prefixed photos',
      () async {
        final zipPath = await writeZip('divecloud_export.zip', {
          '7168_13960_20220224130600_1.zxu': _zxu(),
          '7168_13960_20220224130600_1_photo1.jpg': [1, 2, 3],
          '7168_13960_20220225100000_2.zxu': _zxu(),
          'README.txt': [65],
          '__MACOSX/._junk': [0],
        });

        final expansion = await service.expandAll([zipPath]);

        expect(expansion.filePaths, hasLength(2));
        expect(
          expansion.filePaths.map(p.basename),
          containsAll([
            '7168_13960_20220224130600_1.zxu',
            '7168_13960_20220225100000_2.zxu',
          ]),
        );
        for (final path in expansion.filePaths) {
          expect(File(path).existsSync(), isTrue);
        }
        expect(
          expansion.photoPathsByBaseName['7168_13960_20220224130600_1'],
          hasLength(1),
        );
        expect(expansion.unmatchedPhotoPaths, isEmpty);
        // README.txt and the __MACOSX entry were skipped.
        expect(expansion.skippedEntryCount, 2);
      },
    );

    test('matches photos placed in a per-dive folder', () async {
      final zipPath = await writeZip('folders.zip', {
        '7168_13960_20220224130600_1.zxu': _zxu(),
        '7168_13960_20220224130600_1/reef.jpg': [1],
        '7168_13960_20220224130600_1/turtle.png': [2],
      });
      final expansion = await service.expandAll([zipPath]);
      expect(
        expansion.photoPathsByBaseName['7168_13960_20220224130600_1'],
        hasLength(2),
      );
    });

    test('reports photos that match no dive file as unmatched', () async {
      final zipPath = await writeZip('orphan.zip', {
        'dive_a.zxu': _zxu(),
        'unrelated_photo.jpg': [9],
      });
      final expansion = await service.expandAll([zipPath]);
      expect(expansion.unmatchedPhotoPaths, hasLength(1));
      expect(expansion.photoPathsByBaseName, isEmpty);
    });

    test('mixed selection: zip members join plain files', () async {
      final plain = p.join(tmp.path, 'other.zxu');
      await File(plain).writeAsBytes(_zxu());
      final zipPath = await writeZip('one.zip', {'inner.zxu': _zxu()});
      final expansion = await service.expandAll([plain, zipPath]);
      expect(expansion.filePaths, hasLength(2));
      expect(expansion.filePaths.first, plain);
    });

    test('throws FormatException for an unreadable archive', () async {
      final bad = p.join(tmp.path, 'corrupt.zip');
      await File(bad).writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0, 0, 0]);
      expect(() => service.expandAll([bad]), throwsA(isA<FormatException>()));
    });
  });

  group('expandZipBytes', () {
    test('expands raw zip bytes (share-intent path)', () async {
      final bytes = _buildZip({
        'dive.zxu': _zxu(),
        'dive_pic.jpeg': [7],
      });
      final expansion = await service.expandZipBytes(bytes, 'shared.zip');
      expect(expansion.filePaths, hasLength(1));
      expect(expansion.photoPathsByBaseName['dive'], hasLength(1));
    });
  });
}
