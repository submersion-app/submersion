import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/same_folder_probe.dart';

void main() {
  late Directory root;
  late String folder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('same-folder-probe');
    folder = p.join(root.path, 'logs');
    await Directory(folder).create();
  });

  tearDown(() => root.delete(recursive: true));

  test('one spelling of a folder is the same folder', () async {
    expect(await isSameFolder(folder, folder), isTrue);
  });

  test(
    'a second name for the folder is the same folder (issue #4834)',
    () async {
      // A symlink stands in for a NAS reached through a second server name, or
      // a mapped drive letter for its UNC path: two strings, one folder.
      final alias = p.join(root.path, 'alias');
      await Link(alias).create(folder);

      expect(await isSameFolder(folder, alias), isTrue);
      expect(await isSameFolder(alias, folder), isTrue);
    },
  );

  test('two different folders are not the same folder', () async {
    final other = p.join(root.path, 'other');
    await Directory(other).create();

    expect(await isSameFolder(folder, other), isFalse);
  });

  test('a folder that cannot be reached is not the same folder', () async {
    final missing = p.join(root.path, 'missing');

    expect(await isSameFolder(missing, folder), isFalse);
    expect(await isSameFolder(folder, missing), isFalse);
  });

  test('leaves nothing behind in either folder', () async {
    final alias = p.join(root.path, 'alias');
    await Link(alias).create(folder);
    final other = p.join(root.path, 'other');
    await Directory(other).create();

    await isSameFolder(folder, alias);
    await isSameFolder(folder, other);

    expect(Directory(folder).listSync(), isEmpty);
    expect(Directory(other).listSync(), isEmpty);
  });
}
