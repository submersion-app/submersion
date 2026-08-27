import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/database_service.dart';

/// Leaves [dbPath] as a WAL-mode database whose newest committed row lives
/// only in a hot `-wal`, exactly as a running app or a force-killed one does.
///
/// SQLite checkpoints and deletes the `-wal` when the last connection closes,
/// so the sidecars are snapshotted while the connection is still open and
/// written back afterwards -- the only way to manufacture a hot WAL from a
/// single-process test.
void seedWalResidentRow(String dbPath) {
  final db = DatabaseService.openRaw(
    dbPath,
    mode: sqlite3.OpenMode.readWriteCreate,
  );
  db.select('PRAGMA journal_mode = WAL');
  db.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
  db.execute('INSERT INTO sentinel VALUES (42)');
  db.select('PRAGMA wal_checkpoint(TRUNCATE)');

  // Committed, but small enough that no auto-checkpoint folds it in, so it
  // exists ONLY in the -wal.
  db.execute('INSERT INTO sentinel VALUES (99)');
  final mainBytes = File(dbPath).readAsBytesSync();
  final walBytes = File('$dbPath-wal').readAsBytesSync();
  db.close();

  File(dbPath).writeAsBytesSync(mainBytes);
  File('$dbPath-wal').writeAsBytesSync(walBytes);
}

/// The `sentinel` ids readable from [dbPath] opened STANDALONE -- no sidecars
/// alongside it, which is the only state a backup artifact ever travels in.
List<Object?> sentinelIds(String dbPath) {
  final db = DatabaseService.openRaw(dbPath, mode: sqlite3.OpenMode.readOnly);
  try {
    return db
        .select('SELECT id FROM sentinel ORDER BY id')
        .map((row) => row.values.first)
        .toList();
  } finally {
    db.close();
  }
}

/// The `sentinel` ids a naive byte copy of the main file alone would carry --
/// i.e. what a backup loses when it ignores the `-wal`. Copied to a scratch
/// path first, because reading [dbPath] in place would pick up its sidecar.
List<Object?> sentinelIdsOfMainFileAlone(String dbPath) {
  final bare = '$dbPath.mainfileonly';
  File(dbPath).copySync(bare);
  try {
    return sentinelIds(bare);
  } finally {
    File(bare).deleteSync();
  }
}

String journalModeOf(String dbPath) {
  final db = DatabaseService.openRaw(dbPath);
  try {
    return db.select('PRAGMA journal_mode').first.values.first as String;
  } finally {
    db.close();
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wal_backup');
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    await tmp.delete(recursive: true);
  });

  test('backup of a WAL database carries the WAL-resident rows', () async {
    final src = '${tmp.path}/submersion.db';
    seedWalResidentRow(src);
    // Precondition: the newest row really is only in the sidecar.
    expect(File('$src-wal').lengthSync(), greaterThan(0));
    expect(sentinelIdsOfMainFileAlone(src), [
      42,
    ], reason: 'a byte copy of the main file alone is missing 99');

    DatabaseService.instance
      ..databaseKeyHex = null
      ..setCurrentPathForTesting(src);

    final dest = '${tmp.path}/out/backup.db';
    await DatabaseService.instance.backup(dest);

    expect(sentinelIds(dest), [42, 99]);
  });

  test('backup artifact is a single self-contained file', () async {
    final src = '${tmp.path}/submersion.db';
    seedWalResidentRow(src);

    DatabaseService.instance
      ..databaseKeyHex = null
      ..setCurrentPathForTesting(src);

    final dest = '${tmp.path}/out/backup.db';
    await DatabaseService.instance.backup(dest);

    // No sidecars travel with a backup, so the artifact must not need any --
    // and must not be left in WAL mode, which would make a read-only open in
    // a sandboxed directory require an -shm it cannot create.
    expect(File('$dest-wal').existsSync(), false);
    expect(File('$dest-shm').existsSync(), false);
    expect(journalModeOf(dest), 'delete');
  });

  test('backup costs the live database no data and no journal mode', () async {
    final src = '${tmp.path}/submersion.db';
    seedWalResidentRow(src);

    DatabaseService.instance
      ..databaseKeyHex = null
      ..setCurrentPathForTesting(src);

    await DatabaseService.instance.backup('${tmp.path}/out/backup.db');

    // A backup is a read. The export connection may fold the -wal back into
    // the main file when it turns out to be the last one open (it is here; in
    // the app the drift isolate still holds the database), which is a move of
    // data, not a loss of it. What must never change is what the live database
    // holds or how it journals.
    expect(sentinelIds(src), [42, 99]);
    expect(journalModeOf(src), 'wal');
  });

  test('backup overwrites an existing destination file', () async {
    final src = '${tmp.path}/submersion.db';
    seedWalResidentRow(src);
    final dest = '${tmp.path}/backup.db';
    File(dest).writeAsStringSync('stale artifact from an earlier backup');

    DatabaseService.instance
      ..databaseKeyHex = null
      ..setCurrentPathForTesting(src);

    await DatabaseService.instance.backup(dest);

    expect(sentinelIds(dest), [42, 99]);
    expect(File('$dest.export-staging').existsSync(), false);
  });

  test(
    'a failure to place the finished export surfaces, never degrades',
    () async {
      // The degraded byte copy exists for a source that cannot be EXPORTED. Once
      // a good artifact has been produced, a placement failure must not swap it
      // for a lossy copy over a problem the copy would hit too.
      final src = '${tmp.path}/submersion.db';
      seedWalResidentRow(src);

      DatabaseService.instance
        ..databaseKeyHex = null
        ..setCurrentPathForTesting(src)
        // Reports success without writing the staging file, so the rename that
        // follows fails on a missing source.
        ..debugSnapshotterOverride =
            ({required String sourcePath, required String targetPath}) async {};

      await expectLater(
        DatabaseService.instance.backup('${tmp.path}/out/backup.db'),
        throwsA(isA<FileSystemException>()),
      );
      expect(File('${tmp.path}/out/backup.db').existsSync(), false);
    },
  );

  test(
    'a source that is not an openable database still gets a byte copy',
    () async {
      // Degraded path: a corrupt or truncated live file cannot be exported
      // through SQL, and a raw copy is worth more to a diver than no artifact
      // at all -- the pre-migration backup makes the same trade.
      final src = '${tmp.path}/submersion.db';
      File(src).writeAsBytesSync([
        ...'SQLite format 3'.codeUnits,
        0,
        ...List.filled(100, 7),
      ]);

      DatabaseService.instance
        ..databaseKeyHex = null
        ..setCurrentPathForTesting(src);

      final dest = '${tmp.path}/out/backup.db';
      await DatabaseService.instance.backup(dest);

      expect(File(dest).existsSync(), true);
      expect(File(dest).readAsBytesSync(), File(src).readAsBytesSync());
      expect(File('$dest.export-staging').existsSync(), false);
    },
  );
}
