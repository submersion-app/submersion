import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('import_media_resolver_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> writeFile(String relativePath) async {
    final file = File(p.join(root.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString('bytes');
  }

  Map<String, dynamic> picture(String filename, {int index = 0}) => {
    'filename': filename,
    'offsetSeconds': 200,
    '_diveIndex': index,
  };

  test('re-roots a whole moved tree', () async {
    await writeFile(p.join('2025', 'dive042.jpg'));
    await writeFile(p.join('2025', 'dive043.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [
        picture('/home/jai/Pictures/2025/dive042.jpg'),
        picture('/home/jai/Pictures/2025/dive043.jpg', index: 1),
      ],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 2);
    expect(resolution.reRootedCount, 2);
    expect(resolution.filenameOnlyCount, 0);
    expect(resolution.notFoundCount, 0);
    expect(
      resolution.resolvedPathByIndex[0],
      p.join(root.path, '2025', 'dive042.jpg'),
    );
  });

  test('falls back to a filename match in a reorganised tree', () async {
    await writeFile(p.join('Archive', 'Bonaire', 'dive042.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/2025/dive042.jpg')],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 1);
    expect(resolution.filenameOnlyCount, 1);
    expect(resolution.reRootedCount, 0);
    expect(
      resolution.resolvedPathByIndex[0],
      p.join(root.path, 'Archive', 'Bonaire', 'dive042.jpg'),
    );
  });

  test('reports a picture that is nowhere under the root', () async {
    await writeFile(p.join('2025', 'other.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/2025/missing.jpg')],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 1);
    expect(resolution.resolvedPathByIndex, isEmpty);
  });

  test('resolves an ambiguous filename to a single candidate', () async {
    await writeFile(p.join('a', 'dive042.jpg'));
    await writeFile(p.join('b', 'dive042.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/dive042.jpg')],
      rootPath: root.path,
    );

    // One picture yields at most one resolved path; which of the two
    // candidates wins is not contractual, only that it resolves exactly once
    // and is reported as a filename-only match.
    expect(resolution.matchedCount, 1);
    expect(resolution.filenameOnlyCount, 1);
  });

  test('reports every picture as not found when the root is missing', () async {
    final resolution = await const ImportMediaResolver().resolve(
      media: [picture('/home/jai/Pictures/dive042.jpg')],
      rootPath: p.join(root.path, 'no-such-folder'),
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 1);
  });

  test('resolves a path exported from Windows', () async {
    await writeFile(p.join('2025', 'dive042.jpg'));

    final resolution = await const ImportMediaResolver().resolve(
      media: [picture(r'C:\Users\jai\Pictures\2025\dive042.jpg')],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 1);
    expect(
      resolution.resolvedPathByIndex[0],
      p.join(root.path, '2025', 'dive042.jpg'),
    );
  });

  test('foreignBasename treats both separators as separators', () {
    expect(foreignBasename(r'C:\Users\jai\dive.jpg'), 'dive.jpg');
    expect(foreignBasename('/home/jai/dive.jpg'), 'dive.jpg');
    expect(foreignBasename('dive.jpg'), 'dive.jpg');
  });

  test('skips a picture whose filename is missing or empty', () async {
    final resolution = await const ImportMediaResolver().resolve(
      media: [
        {'offsetSeconds': 1, '_diveIndex': 0},
        {'filename': '', '_diveIndex': 1},
      ],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 2);
  });

  test('an empty media list resolves to nothing without scanning', () async {
    final resolution = await const ImportMediaResolver().resolve(
      media: const [],
      rootPath: root.path,
    );

    expect(resolution.matchedCount, 0);
    expect(resolution.notFoundCount, 0);
  });
}
