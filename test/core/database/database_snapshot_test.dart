import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database_snapshot.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('db_snapshot');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('copies the source database to the target', () async {
    final src = '${tmp.path}/source.db';
    final db = sqlite3.sqlite3.open(src);
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    db.execute('INSERT INTO t VALUES (7)');
    db.close();

    final target = '${tmp.path}/snapshot.db';
    await vacuumIntoSnapshot(sourcePath: src, targetPath: target);

    final out = sqlite3.sqlite3.open(target, mode: sqlite3.OpenMode.readOnly);
    try {
      expect(out.select('SELECT id FROM t').first.values.first, 7);
    } finally {
      out.close();
    }
  });

  test('a missing source fails instead of fabricating an empty one', () async {
    // sqlite3.open defaults to readWriteCreate, which would CREATE an empty
    // database at the missing path and then export it happily -- a backup that
    // reports success and contains nothing, and a resurrected empty file at
    // the live database path. The caller checks the source exists first, so
    // reaching here means it vanished underneath us (ejected volume, raced
    // delete) and the only honest answer is to fail.
    final missing = '${tmp.path}/gone.db';
    final target = '${tmp.path}/snapshot.db';

    await expectLater(
      vacuumIntoSnapshot(sourcePath: missing, targetPath: target),
      throwsA(isA<sqlite3.SqliteException>()),
    );

    expect(File(missing).existsSync(), isFalse);
    expect(File(target).existsSync(), isFalse);
  });

  test('refuses to overwrite an existing target', () async {
    // VACUUM INTO will not write over a file that is already there, which is
    // why callers stage to a fresh path and rename.
    final src = '${tmp.path}/source.db';
    final db = sqlite3.sqlite3.open(src);
    db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    db.close();

    final target = '${tmp.path}/snapshot.db';
    File(target).writeAsStringSync('already here');

    await expectLater(
      vacuumIntoSnapshot(sourcePath: src, targetPath: target),
      throwsA(isA<sqlite3.SqliteException>()),
    );
    expect(File(target).readAsStringSync(), 'already here');
  });
}
