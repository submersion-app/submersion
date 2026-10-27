import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';

void main() {
  late Directory dir;
  late DemoPaths paths;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('demo_extract');
    paths = DemoPaths(dir.path);
    Directory(paths.root).createSync(recursive: true);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  File zipOf(Map<String, String> files) {
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile.bytes(e.key, utf8.encode(e.value)));
    }
    final file = File(paths.packageFile)
      ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    return file;
  }

  test('extract writes the database and photos into DemoPaths', () async {
    final zip = zipOf({
      'submersion_demo.db': 'DB',
      'photos/reef.jpg': 'JPG',
      'photos/turtle.webp': 'WEBP',
    });

    await DemoPackageExtractor().extract(zip, paths);

    expect(File(paths.databaseFile).readAsStringSync(), 'DB');
    expect(File(p.join(paths.photosDir, 'reef.jpg')).readAsStringSync(), 'JPG');
    expect(File(p.join(paths.photosDir, 'turtle.webp')).existsSync(), isTrue);
  });

  test('extract refuses a package that expands past the cap', () async {
    // 64 KB of one byte compresses to almost nothing.
    final zip = zipOf({'submersion_demo.db': 'A' * 65536});

    await expectLater(
      DemoPackageExtractor(maxExtractedBytes: 4096).extract(zip, paths),
      throwsFormatException,
    );
    expect(File(paths.databaseFile).existsSync(), isFalse);
  });

  test('the bounded sink refuses bytes past its limit', () {
    final out = BoundedOutput(8)..writeBytes(List.filled(8, 1));

    expect(() => out.writeBytes([1]), throwsFormatException);
    expect(() => out.writeByte(1), throwsFormatException);
    expect(out.length, 8);
  });

  test('extract refuses an entry whose header understates its size', () async {
    final big = Uint8List.fromList(List.filled(65536, 65));
    final zip = Uint8List.fromList(
      ZipEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('submersion_demo.db', big)),
      ),
    );
    // Every little-endian 65536 is the declared size; claim 10 bytes.
    for (var i = 0; i + 4 <= zip.length; i++) {
      if (zip[i] == 0 &&
          zip[i + 1] == 0 &&
          zip[i + 2] == 1 &&
          zip[i + 3] == 0) {
        zip[i] = 10;
        zip[i + 2] = 0;
      }
    }
    final file = File(paths.packageFile)..writeAsBytesSync(zip);

    await expectLater(
      DemoPackageExtractor(maxExtractedBytes: 4096).extract(file, paths),
      throwsFormatException,
    );
    expect(File(paths.databaseFile).existsSync(), isFalse);
  });

  test('extract refuses a zip-slip entry ../evil.txt', () async {
    final zip = zipOf({'submersion_demo.db': 'DB', '../evil.txt': 'x'});

    await expectLater(
      DemoPackageExtractor().extract(zip, paths),
      throwsFormatException,
    );
    expect(File(p.join(dir.path, 'evil.txt')).existsSync(), isFalse);
  });

  test('extract refuses an unexpected top-level file', () async {
    final zip = zipOf({'submersion_demo.db': 'DB', 'run.sh': 'x'});

    await expectLater(
      DemoPackageExtractor().extract(zip, paths),
      throwsFormatException,
    );
  });

  test('extract refuses a package without the database', () async {
    final zip = zipOf({'photos/reef.jpg': 'JPG'});

    await expectLater(
      DemoPackageExtractor().extract(zip, paths),
      throwsFormatException,
    );
  });

  test('extract refuses bytes that are not a zip', () async {
    final file = File(paths.packageFile)..writeAsStringSync('<html>');

    await expectLater(
      DemoPackageExtractor().extract(file, paths),
      throwsFormatException,
    );
  });
}
