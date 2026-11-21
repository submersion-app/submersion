import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/same_folder_probe.dart';

/// Waits until [dir] is empty, for a cleanup that runs in the background.
Future<void> _untilEmpty(String dir) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (Directory(dir).listSync().isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

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
      // Written at once, so the short deadline only bounds the look-up.
      create: (marker) async => marker.createSync(exclusive: true),
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
    await _untilEmpty(folder);
    expect(Directory(folder).listSync(), isEmpty);
  });

  test(
    'a second folder that cannot be read is unknown, not different',
    () async {
      final other = p.join(root.path, 'other');
      await Directory(other).create();
      await Process.run('chmod', ['000', other]);
      try {
        try {
          Directory(other).listSync();
          markTestSkipped('permissions are not enforced for this user');
          return;
        } on FileSystemException {
          // Unreadable, as intended.
        }

        expect(await compareFolders(folder, other), FolderIdentity.unknown);
      } finally {
        await Process.run('chmod', ['755', other]);
      }
    },
    skip: Platform.isWindows ? 'chmod is POSIX only' : false,
  );

  test('a marker already gone at cleanup still gives an answer', () async {
    // Something else (a sync client, say) removed the marker first.
    final result = await compareFolders(
      folder,
      p.join(root.path, 'alias'),
      exists: (path) async {
        Directory(
          folder,
        ).listSync().whereType<File>().forEach((marker) => marker.deleteSync());
        return true;
      },
    );

    expect(result, FolderIdentity.same);
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
