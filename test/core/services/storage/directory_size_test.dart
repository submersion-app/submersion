import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/storage/directory_size.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_size_test');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<File> writeFile(String relative, int bytes) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List<int>.filled(bytes, 0));
    return file;
  }

  group('measureDirectoryBytes', () {
    test('sums every file in the tree, including nested ones', () async {
      await writeFile('a.bin', 100);
      await writeFile('nested/b.bin', 250);
      await writeFile('nested/deeper/c.bin', 50);

      expect(await measureDirectoryBytes(root), 400);
    });

    test('an empty directory measures zero', () async {
      expect(await measureDirectoryBytes(root), 0);
    });

    test('a directory that does not exist measures zero, not null', () async {
      final absent = Directory(p.join(root.path, 'never_created'));
      expect(await measureDirectoryBytes(absent), 0);
    });
  });

  group('measureFileGroupBytes', () {
    test('sums the files that exist and skips those that do not', () async {
      final present = await writeFile('db.sqlite', 300);
      final absent = File(p.join(root.path, 'db.sqlite-wal'));

      expect(await measureFileGroupBytes([present, absent]), 300);
    });
  });

  group('measureLooseFilesBytes', () {
    test('counts files in the top level only, never subdirectories', () async {
      await writeFile('export.csv', 100);
      await writeFile('Submersion/database.db', 9999);

      final total = await measureLooseFilesBytes(
        root,
        exclude: (name) => false,
      );

      expect(total, 100);
    });

    test('honours the exclusion predicate', () async {
      await writeFile('export.csv', 100);
      await writeFile('database.db', 500);

      final total = await measureLooseFilesBytes(
        root,
        exclude: (name) => name.startsWith('database.db'),
      );

      expect(total, 100);
    });
  });
}
