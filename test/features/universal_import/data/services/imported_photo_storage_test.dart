import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/imported_photo_storage.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ips_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('writes to <mediaRoot>/dive/<diveId>/<position>-<filename>', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    const ref = ImportImageRef(
      originalPath: '/orig/a.jpg',
      diveSourceUuid: 'ignored-here',
      position: 2,
    );
    final file = await storage.store(
      diveId: 'dive-internal-id-1',
      ref: ref,
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(file.existsSync(), isTrue);
    expect(file.path, endsWith('dive/dive-internal-id-1/2-a.jpg'));
    expect(await file.readAsBytes(), [1, 2, 3]);
  });

  test('creates parent directory when missing', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    const ref = ImportImageRef(originalPath: 'a.jpg', diveSourceUuid: 'd');
    final file = await storage.store(
      diveId: 'new-dive',
      ref: ref,
      bytes: Uint8List.fromList([1]),
    );
    expect(file.parent.existsSync(), isTrue);
    expect(Directory('${tmp.path}/dive/new-dive').existsSync(), isTrue);
  });

  test('appends -1, -2, … on basename collision', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    const ref = ImportImageRef(
      originalPath: 'a.jpg',
      diveSourceUuid: 'd',
      position: 0,
    );

    final f1 = await storage.store(
      diveId: 'dive-1',
      ref: ref,
      bytes: Uint8List.fromList([1]),
    );
    final f2 = await storage.store(
      diveId: 'dive-1',
      ref: ref,
      bytes: Uint8List.fromList([2]),
    );
    final f3 = await storage.store(
      diveId: 'dive-1',
      ref: ref,
      bytes: Uint8List.fromList([3]),
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
    const ref1 = ImportImageRef(
      originalPath: 'shark.jpeg',
      diveSourceUuid: 'd',
      position: 1,
    );
    final f1 = await storage.store(
      diveId: 'dive-1',
      ref: ref1,
      bytes: Uint8List.fromList([1]),
    );
    final f2 = await storage.store(
      diveId: 'dive-1',
      ref: ref1,
      bytes: Uint8List.fromList([2]),
    );
    expect(f1.path, endsWith('.jpeg'));
    expect(f2.path, endsWith('.jpeg'));
    expect(f2.path, isNot(f1.path));
  });

  test('handles filename without extension', () async {
    final storage = ImportedPhotoStorage(mediaRoot: tmp.path);
    const ref = ImportImageRef(originalPath: 'IMG_0001', diveSourceUuid: 'd');
    final f1 = await storage.store(
      diveId: 'd',
      ref: ref,
      bytes: Uint8List.fromList([1]),
    );
    final f2 = await storage.store(
      diveId: 'd',
      ref: ref,
      bytes: Uint8List.fromList([2]),
    );
    expect(f1.path, isNot(f2.path));
  });
}
