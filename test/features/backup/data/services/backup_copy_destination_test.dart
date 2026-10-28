import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/backup/data/services/backup_copy_destination.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('copy_destination_');
  });

  tearDown(() => dir.delete(recursive: true));

  test('uniqueDestinationPath returns the plain name when free', () async {
    expect(
      await uniqueDestinationPath(dir.path, 'a.db'),
      p.join(dir.path, 'a.db'),
    );
  });

  test('uniqueDestinationPath skips existing names', () async {
    await File(p.join(dir.path, 'a.db')).writeAsString('x');
    await File(p.join(dir.path, 'a (1).db')).writeAsString('x');

    expect(
      await uniqueDestinationPath(dir.path, 'a.db'),
      p.join(dir.path, 'a (2).db'),
    );
  });

  test('uniqueDestinationPath skips a folder holding the name', () async {
    await Directory(p.join(dir.path, 'a.db')).create();

    expect(
      await uniqueDestinationPath(dir.path, 'a.db'),
      p.join(dir.path, 'a (1).db'),
    );
  });

  test('copyWithoutPartial copies the bytes', () async {
    final source = File(p.join(dir.path, 'source.db'));
    await source.writeAsBytes([1, 2, 3]);
    final dest = p.join(dir.path, 'out.db');

    await copyWithoutPartial(source.path, dest);

    expect(await File(dest).readAsBytes(), [1, 2, 3]);
    expect(dir.listSync().map((e) => p.basename(e.path)).toSet(), {
      'source.db',
      'out.db',
    });
  });

  test(
    'copyWithoutPartial leaves nothing behind when it fails part way',
    () async {
      final source = File(p.join(dir.path, 'source.db'));
      await source.writeAsBytes([1, 2, 3]);
      // The bytes copy, then the final move fails: a folder holds the name.
      final dest = p.join(dir.path, 'out.db');
      await Directory(dest).create();

      await expectLater(
        copyWithoutPartial(source.path, dest),
        throwsA(isA<FileSystemException>()),
      );

      expect(dir.listSync().map((e) => p.basename(e.path)).toSet(), {
        'source.db',
        'out.db',
      });
      expect(FileSystemEntity.isDirectorySync(dest), isTrue);
    },
  );
}
