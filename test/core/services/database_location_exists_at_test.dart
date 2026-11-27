import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_location_service.dart';

void main() {
  late Directory root;
  late DatabaseLocationService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('database-exists-at');
    SharedPreferences.setMockInitialValues({});
    service = DatabaseLocationService(await SharedPreferences.getInstance());
  });

  tearDown(() => root.delete(recursive: true));

  test('finds a dive log in the folder', () async {
    File(
      p.join(root.path, DatabaseLocationService.databaseFilename),
    ).writeAsStringSync('');

    expect(await service.databaseExistsAt(root.path), isTrue);
  });

  test('reports none for an empty folder or one that is not there', () async {
    expect(await service.databaseExistsAt(root.path), isFalse);
    expect(
      await service.databaseExistsAt(p.join(root.path, 'missing')),
      isFalse,
    );
  });

  test('throws for a folder it cannot read, rather than report no dive log '
      '(issue #4834)', () async {
    final locked = p.join(root.path, 'locked');
    await Directory(locked).create();
    File(
      p.join(locked, DatabaseLocationService.databaseFilename),
    ).writeAsStringSync('');
    await Process.run('chmod', ['000', locked]);
    try {
      try {
        Directory(locked).listSync();
        markTestSkipped('permissions are not enforced for this user');
        return;
      } on FileSystemException {
        // Unreadable, as intended.
      }

      await expectLater(
        service.databaseExistsAt(locked),
        throwsA(isA<FileSystemException>()),
      );
    } finally {
      await Process.run('chmod', ['755', locked]);
    }
  }, skip: Platform.isWindows ? 'chmod is POSIX only' : false);
}
