import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database_connection_setup.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('conn_setup');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('puts a main-database connection into WAL journal mode', () {
    final db = sqlite3.sqlite3.open('${tmp.path}/main.db');
    try {
      expect(applyMainDatabaseSetup(db), 'wal');
      expect(
        db.select('PRAGMA journal_mode').first.values.first,
        'wal',
        reason: 'the mode must stick on the connection, not just be reported',
      );
    } finally {
      db.close();
    }
  });

  test('the busy timeout is still applied alongside the journal mode', () {
    final db = sqlite3.sqlite3.open('${tmp.path}/main.db');
    try {
      applyMainDatabaseSetup(db);
      expect(
        db.select('PRAGMA busy_timeout').first.values.first,
        kDatabaseBusyTimeout.inMilliseconds,
      );
    } finally {
      db.close();
    }
  });

  test('WAL persists in the file, so a later connection inherits it', () {
    final path = '${tmp.path}/main.db';
    final first = sqlite3.sqlite3.open(path);
    applyMainDatabaseSetup(first);
    first.execute('CREATE TABLE t (id INTEGER)');
    first.close();

    // journal_mode lives in the database header, so a connection that never
    // ran the setup (a raw probe, an external tool) still sees WAL.
    final second = sqlite3.sqlite3.open(path);
    try {
      expect(second.select('PRAGMA journal_mode').first.values.first, 'wal');
    } finally {
      second.close();
    }
  });

  test('an in-memory database degrades instead of failing the open', () {
    // WAL requires a real file with shared memory beside it. In-memory stands
    // in here for the filesystems that cannot host `-wal`/`-shm` at all
    // (some network mounts, an Android SAF tree): SQLite refuses the mode
    // rather than erroring, and the connection must stay usable.
    final db = sqlite3.sqlite3.openInMemory();
    try {
      expect(applyMainDatabaseSetup(db), isNot('wal'));
      db.execute('CREATE TABLE t (id INTEGER)');
      db.execute('INSERT INTO t VALUES (1)');
      expect(db.select('SELECT id FROM t').first.values.first, 1);
    } finally {
      db.close();
    }
  });
}
