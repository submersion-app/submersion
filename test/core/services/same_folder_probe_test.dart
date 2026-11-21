import 'dart:async';
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
    expect(await compareFolders(folder, folder), FolderIdentity.same);
  });

  test(
    'a second name for the folder is the same folder (issue #4834)',
    () async {
      // A symlink stands in for a NAS reached through a second server name, or
      // a mapped drive letter for its UNC path: two strings, one folder.
      final alias = p.join(root.path, 'alias');
      await Link(alias).create(folder);

      expect(await compareFolders(folder, alias), FolderIdentity.same);
      expect(await compareFolders(alias, folder), FolderIdentity.same);
    },
  );

  test('two different folders are different', () async {
    final other = p.join(root.path, 'other');
    await Directory(other).create();

    expect(await compareFolders(folder, other), FolderIdentity.different);
  });

  test('a first folder that cannot be written is unknown, not different: '
      'nothing proves the second is another folder', () async {
    final missing = p.join(root.path, 'missing');

    expect(await compareFolders(missing, folder), FolderIdentity.unknown);
  });

  test('a second folder that is not there is different', () async {
    final missing = p.join(root.path, 'missing');

    expect(await compareFolders(folder, missing), FolderIdentity.different);
  });

  test('a look-up that never answers is unknown once the time is up, and '
      'the marker is still cleared away', () async {
    final alias = p.join(root.path, 'alias');
    await Link(alias).create(folder);

    final result = await compareFolders(
      folder,
      alias,
      timeout: const Duration(milliseconds: 50),
      exists: (_) => Completer<bool>().future,
    );

    expect(result, FolderIdentity.unknown);
    expect(Directory(folder).listSync(), isEmpty);
  });

  test('a marker that takes too long to write is unknown, and is cleared '
      'away once it does land', () async {
    final alias = p.join(root.path, 'alias');
    await Link(alias).create(folder);
    final landed = Completer<void>();

    final result = await compareFolders(
      folder,
      alias,
      timeout: const Duration(milliseconds: 50),
      create: (marker) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await marker.create(exclusive: true);
        landed.complete();
      },
    );

    expect(result, FolderIdentity.unknown);
    await landed.future;
    // The late cleanup runs on the next turns of the event loop.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(Directory(folder).listSync(), isEmpty);
  });

  test('a look-up the file system refuses is unknown', () async {
    final result = await compareFolders(
      folder,
      p.join(root.path, 'other'),
      exists: (path) async =>
          throw FileSystemException('Access is denied', path),
    );

    expect(result, FolderIdentity.unknown);
    expect(Directory(folder).listSync(), isEmpty);
  });

  test('leaves nothing behind in either folder', () async {
    final alias = p.join(root.path, 'alias');
    await Link(alias).create(folder);
    final other = p.join(root.path, 'other');
    await Directory(other).create();

    await compareFolders(folder, alias);
    await compareFolders(folder, other);

    expect(Directory(folder).listSync(), isEmpty);
    expect(Directory(other).listSync(), isEmpty);
  });
}
