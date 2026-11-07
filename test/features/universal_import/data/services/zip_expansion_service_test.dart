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
  return Uint8List.fromList(ZipEncoder().encode(archive));
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

    test('recognizes all three ZIP signatures', () {
      // Local file header (normal), empty archive, spanned/data-descriptor.
      expect(
        ZipExpansionService.isZipBytes(Uint8List.fromList([0x50, 0x4B, 3, 4])),
        isTrue,
      );
      expect(
        ZipExpansionService.isZipBytes(Uint8List.fromList([0x50, 0x4B, 5, 6])),
        isTrue,
      );
      expect(
        ZipExpansionService.isZipBytes(Uint8List.fromList([0x50, 0x4B, 7, 8])),
        isTrue,
      );
      // "PK" followed by an unrelated signature is not a ZIP.
      expect(
        ZipExpansionService.isZipBytes(Uint8List.fromList([0x50, 0x4B, 1, 2])),
        isFalse,
      );
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

    test('reports a real temp directory that the caller can delete', () async {
      final zipPath = await writeZip('temp.zip', {'dive.zxu': _zxu()});
      final expansion = await service.expandAll([zipPath]);

      expect(expansion.tempDirPaths, hasLength(1));
      final tempDir = Directory(expansion.tempDirPaths.single);
      expect(tempDir.existsSync(), isTrue);
      // Extracted files live inside the reported temp dir.
      expect(p.isWithin(tempDir.path, expansion.filePaths.single), isTrue);
      // Caller owns cleanup; deleting the reported dir removes the members.
      await tempDir.delete(recursive: true);
      expect(File(expansion.filePaths.single).existsSync(), isFalse);
    });

    test(
      'an archive with no dive files leaves no temp directory behind',
      () async {
        final before = Directory.systemTemp
            .listSync()
            .whereType<Directory>()
            .where((d) => p.basename(d.path).startsWith('submersion_zip_'))
            .length;

        // Photos only, no .zxu/.zxl: nothing importable.
        final zipPath = await writeZip('photos_only.zip', {
          'holiday.jpg': [1, 2, 3],
          'readme.txt': [65],
        });
        final expansion = await service.expandAll([zipPath]);

        expect(expansion.filePaths, isEmpty);
        expect(expansion.tempDirPaths, isEmpty);
        expect(expansion.photoPathsByBaseName, isEmpty);

        final after = Directory.systemTemp
            .listSync()
            .whereType<Directory>()
            .where((d) => p.basename(d.path).startsWith('submersion_zip_'))
            .length;
        expect(after, before, reason: 'the empty extraction dir is removed');
      },
    );

    test('a corrupt archive leaves no temp directory behind', () async {
      final before = Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('submersion_zip_'))
          .length;

      final bad = p.join(tmp.path, 'corrupt.zip');
      await File(bad).writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0, 0, 0]);
      await expectLater(
        service.expandAll([bad]),
        throwsA(isA<FormatException>()),
      );

      final after = Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('submersion_zip_'))
          .length;
      expect(after, before);
    });

    test('throws FormatException for an unreadable archive', () async {
      final bad = p.join(tmp.path, 'corrupt.zip');
      await File(bad).writeAsBytes([0x50, 0x4B, 0x03, 0x04, 0, 0, 0]);
      expect(() => service.expandAll([bad]), throwsA(isA<FormatException>()));
    });
  });

  // Issue #4248: extraction used to read the whole ZIP into one buffer and
  // inflate every member with readBytes(), which caches the inflated bytes on
  // its ArchiveFile for as long as the Archive lives.
  group('memory retention (#4248)', () {
    // Highly compressible, so the encoder deflates it.
    final photo = List<int>.filled(256 * 1024, 0x41);

    test(
      'archive members read from the file, not a whole-file buffer',
      () async {
        final zipPath = await writeZip('backed.zip', {
          'dive.zxu': _zxu(),
          'dive_photo.jpg': photo,
        });

        final rawStreams = await ZipExpansionService.withArchiveFile(
          zipPath,
          (archive) async => [
            for (final entry in archive)
              if (entry.isFile)
                (entry.rawContent! as ZipFile).getStream(decompress: false),
          ],
        );

        expect(rawStreams, hasLength(2));
        expect(rawStreams, everyElement(isA<InputFileStream>()));
      },
    );

    test('writing a member leaves no inflated copy on the entry', () async {
      final zipPath = await writeZip('inflate.zip', {'dive_photo.jpg': photo});
      final outPath = p.join(tmp.path, 'out.jpg');

      await ZipExpansionService.withArchiveFile(zipPath, (archive) async {
        final entry = archive.single;
        expect(entry.isCompressed, isTrue, reason: 'precondition: deflated');

        await ZipExpansionService.writeEntryToFile(entry, outPath);

        expect(
          entry.isCompressed,
          isTrue,
          reason: 'inflated bytes must stream to disk, not stay cached',
        );
      });

      expect(File(outPath).readAsBytesSync(), photo);
    });

    test('a stored (uncompressed) member is written intact', () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile('dive.zxu', _zxu().length, _zxu())
            ..compression = CompressionType.none,
        );
      final zipPath = p.join(tmp.path, 'stored.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final expansion = await service.expandAll([zipPath]);

      expect(File(expansion.filePaths.single).readAsBytesSync(), _zxu());
    });

    test('expandAll extracts large deflated photos byte for byte', () async {
      final zipPath = await writeZip('photos.zip', {
        'dive.zxu': _zxu(),
        for (var i = 0; i < 4; i++) 'dive_$i.jpg': photo,
      });

      final expansion = await service.expandAll([zipPath]);

      final photos = expansion.photoPathsByBaseName['dive']!;
      expect(photos, hasLength(4));
      for (final path in photos) {
        expect(File(path).readAsBytesSync(), photo);
      }
    });

    test('withArchiveFile closes the archive file afterwards', () async {
      final zipPath = await writeZip('release.zip', {'dive.zxu': _zxu()});

      // Member streams share the archive's file handle, so one of them shows
      // whether the handle is still open.
      final raw = await ZipExpansionService.withArchiveFile(zipPath, (
        archive,
      ) async {
        final stream =
            (archive.single.rawContent! as ZipFile).getStream(decompress: false)
                as InputFileStream;
        expect(stream.file.isOpen, isTrue, reason: 'precondition');
        return stream;
      });

      expect(raw.file.isOpen, isFalse);
    });

    test('withArchiveFile closes the archive file when use throws', () async {
      final zipPath = await writeZip('throws.zip', {'dive.zxu': _zxu()});
      late InputFileStream raw;

      await expectLater(
        ZipExpansionService.withArchiveFile<void>(zipPath, (archive) async {
          raw =
              (archive.single.rawContent! as ZipFile).getStream(
                    decompress: false,
                  )
                  as InputFileStream;
          throw StateError('extraction failed');
        }),
        throwsStateError,
      );

      expect(raw.file.isOpen, isFalse);
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

    test('extracts the FIT file from a Garmin Connect export ZIP', () async {
      // Connect's "Export Original" wraps one activity's FIT file in a ZIP
      // named after the activity; it used to expand to nothing (#1635).
      final fit = File(
        p.join('test', 'dives', '005_oc-trimix-two-deco-gases.fit'),
      ).readAsBytesSync();
      final bytes = _buildZip({'21874512345_ACTIVITY.fit': fit});

      final expansion = await service.expandZipBytes(bytes, '21874512345.zip');

      expect(expansion.filePaths, hasLength(1));
      expect(
        p.basename(expansion.filePaths.single),
        '21874512345_ACTIVITY.fit',
      );
      expect(File(expansion.filePaths.single).readAsBytesSync(), fit);
    });

    // expandZipBytes is public and does not require callers to have run
    // isZipBytes first, so the signature probe must be length-guarded rather
    // than indexing bytes[2]/bytes[3] blind.
    test(
      'does not throw RangeError on input shorter than a signature',
      () async {
        for (final short in <List<int>>[
          <int>[],
          <int>[0x50],
          <int>[0x50, 0x4B],
          <int>[0x50, 0x4B, 0x03],
        ]) {
          try {
            await service.expandZipBytes(
              Uint8List.fromList(short),
              'short.zip',
            );
          } on RangeError catch (e) {
            fail('indexed past the end for ${short.length} bytes: $e');
          } on FormatException {
            // Fine: an unreadable archive is a documented outcome. Only a
            // RangeError from probing the signature is a defect.
          }
        }
      },
    );
  });
}
