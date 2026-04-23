import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/imported_photo_storage.dart';

/// Create a file under [dir] whose bytes are [bytes] and return the File.
File _sourceFile(Directory dir, String name, List<int> bytes) {
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(bytes);
  return file;
}

void main() {
  late Directory tmp;
  late Directory sources;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ips_');
    sources = Directory.systemTemp.createTempSync('ips_src_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    if (sources.existsSync()) sources.deleteSync(recursive: true);
  });

  test('writes to <mediaRoot>/dive/<diveId>/<position>-<filename>', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    final source = _sourceFile(sources, 'a.jpg', [1, 2, 3]);
    const ref = ImportImageRef(
      originalPath: '/orig/a.jpg',
      diveSourceUuid: 'ignored-here',
      position: 2,
    );
    final file = await storage.store(
      diveId: 'dive-internal-id-1',
      ref: ref,
      sourcePath: source.path,
    );

    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('dive/dive-internal-id-1/2-a.jpg'));
    expect(await file.readAsBytes(), [1, 2, 3]);
  });

  test('creates parent directory when missing', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    final source = _sourceFile(sources, 'a.jpg', [1]);
    const ref = ImportImageRef(originalPath: 'a.jpg', diveSourceUuid: 'd');
    final file = await storage.store(
      diveId: 'new-dive',
      ref: ref,
      sourcePath: source.path,
    );
    expect(file.parent.existsSync(), isTrue);
    expect(Directory('${tmp.path}/dive/new-dive').existsSync(), isTrue);
  });

  test('appends -1, -2, … on basename collision', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    // Three distinct source files sharing a basename (the storage layer's
    // collision handling keys on target basename, not source identity).
    final src1 = _sourceFile(sources, 'a1.jpg', [1]);
    final src2 = _sourceFile(sources, 'a2.jpg', [2]);
    final src3 = _sourceFile(sources, 'a3.jpg', [3]);
    const ref = ImportImageRef(
      originalPath: 'a.jpg',
      diveSourceUuid: 'd',
      position: 0,
    );

    final f1 = await storage.store(
      diveId: 'dive-1',
      ref: ref,
      sourcePath: src1.path,
    );
    final f2 = await storage.store(
      diveId: 'dive-1',
      ref: ref,
      sourcePath: src2.path,
    );
    final f3 = await storage.store(
      diveId: 'dive-1',
      ref: ref,
      sourcePath: src3.path,
    );

    expect(f1.path, isNot(f2.path));
    expect(f2.path, isNot(f3.path));
    expect(await f1.readAsBytes(), [1]);
    expect(await f2.readAsBytes(), [2]);
    expect(await f3.readAsBytes(), [3]);

    final names = {
      f1.uri.pathSegments.last,
      f2.uri.pathSegments.last,
      f3.uri.pathSegments.last,
    };
    expect(
      names.length,
      3,
      reason: 'each store must produce a unique filename',
    );
  });

  test('preserves extension when appending collision counter', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    final src1 = _sourceFile(sources, 'sharkA.jpeg', [1]);
    final src2 = _sourceFile(sources, 'sharkB.jpeg', [2]);
    const ref1 = ImportImageRef(
      originalPath: 'shark.jpeg',
      diveSourceUuid: 'd',
      position: 1,
    );
    final f1 = await storage.store(
      diveId: 'dive-1',
      ref: ref1,
      sourcePath: src1.path,
    );
    final f2 = await storage.store(
      diveId: 'dive-1',
      ref: ref1,
      sourcePath: src2.path,
    );
    expect(f1.path, endsWith('.jpeg'));
    expect(f2.path, endsWith('.jpeg'));
    expect(f2.path, isNot(f1.path));
  });

  test('handles filename without extension', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    final src1 = _sourceFile(sources, 'imgA', [1]);
    final src2 = _sourceFile(sources, 'imgB', [2]);
    const ref = ImportImageRef(originalPath: 'IMG_0001', diveSourceUuid: 'd');
    final f1 = await storage.store(
      diveId: 'd',
      ref: ref,
      sourcePath: src1.path,
    );
    final f2 = await storage.store(
      diveId: 'd',
      ref: ref,
      sourcePath: src2.path,
    );
    expect(f1.path, isNot(f2.path));
  });
}
