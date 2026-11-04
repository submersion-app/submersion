import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart';

import 'package:submersion/core/platform/sqlite/raw_sqlite.dart';

void main() {
  test('RawSqlite is available on the VM and opens an in-memory database', () {
    expect(RawSqlite.isAvailable, isTrue);
    final db = RawSqlite.openInMemory();
    addTearDown(db.close);
    expect(db.select('SELECT 1 AS one').single['one'], 1);
  });

  test('RawSqlite.open honours read-only mode', () {
    final dir = Directory.systemTemp.createTempSync('raw_sqlite_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'probe.db');

    // The default mode creates the file, as `sqlite3.open` does.
    final writer = RawSqlite.open(path);
    writer.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    writer.close();
    expect(File(path).existsSync(), isTrue);

    final reader = RawSqlite.open(path, mode: OpenMode.readOnly);
    addTearDown(reader.close);
    expect(
      () => reader.execute('INSERT INTO t DEFAULT VALUES'),
      throwsA(isA<SqliteException>()),
    );
    expect(reader.select('SELECT COUNT(*) AS n FROM t').single['n'], 0);
  });
}
