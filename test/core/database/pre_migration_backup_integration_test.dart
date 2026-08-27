import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// The live-database key an install with password protection would hold.
const _liveKeyHex =
    '4a5f1c9d3e8b0726114d90ab63fe2d58c7093a41bb5e6f28d0c1a7935e4b8206';

/// Leaves [dbPath] in the state a crash or force-kill produces: one row
/// durably in the main file, a second committed row living only in a hot
/// `-wal` that was never checkpointed.
///
/// SQLite checkpoints and deletes the `-wal` when the last connection closes,
/// so the sidecars are snapshotted while the connection is still open and
/// written back afterwards, the only way to manufacture a hot WAL from a
/// single-process test.
void seedHotWal(String dbPath, {String? keyHex}) {
  final db = DatabaseService.openRaw(
    dbPath,
    mode: sqlite3.OpenMode.readWriteCreate,
    keyHex: keyHex,
  );
  db.select('PRAGMA journal_mode = WAL');
  db.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
  db.execute('INSERT INTO sentinel VALUES (42)');
  db.execute('PRAGMA user_version = 63');
  db.select('PRAGMA wal_checkpoint(TRUNCATE)');

  // Committed, but small enough that no auto-checkpoint folds it in.
  db.execute('INSERT INTO sentinel VALUES (99)');
  final mainBytes = File(dbPath).readAsBytesSync();
  final walBytes = File('$dbPath-wal').readAsBytesSync();
  db.close();

  File(dbPath).writeAsBytesSync(mainBytes);
  File('$dbPath-wal').writeAsBytesSync(walBytes);
}

/// The `sentinel` ids readable from [dbPath], opened standalone (no sidecars).
List<Object?> sentinelIds(String dbPath, {String? keyHex}) {
  final db = DatabaseService.openRaw(
    dbPath,
    mode: sqlite3.OpenMode.readOnly,
    keyHex: keyHex,
  );
  try {
    return db
        .select('SELECT id FROM sentinel ORDER BY id')
        .map((row) => row.values.first)
        .toList();
  } finally {
    db.close();
  }
}

void main() {
  test('end-to-end: seeds v63 DB, backs up, verifies bytes + record', () async {
    final tmp = await Directory.systemTemp.createTemp('pmbs_int_');
    addTearDown(() => tmp.delete(recursive: true));

    final livePath = p.join(tmp.path, 'submersion.db');
    final backupsDir = p.join(tmp.path, 'backups');
    await Directory(backupsDir).create(recursive: true);

    // Seed a v63 sqlite file with user_version + sentinel data.
    final seed = sqlite3.sqlite3.open(livePath);
    try {
      seed.execute('PRAGMA user_version = 63');
      seed.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
      seed.execute('INSERT INTO sentinel VALUES (42)');
    } finally {
      seed.close();
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    final service = PreMigrationBackupService(
      livePathProvider: () async => livePath,
      backupsDirProvider: () async => backupsDir,
      preferences: prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'integration-id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    // Assert backup .db exists and matches live bytes.
    final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
    expect(await File(backupPath).exists(), isTrue);
    expect(
      await File(backupPath).readAsBytes(),
      await File(livePath).readAsBytes(),
    );

    // Assert the backup DB itself reads user_version == 63 and sentinel data.
    final verify = sqlite3.sqlite3.open(
      backupPath,
      mode: sqlite3.OpenMode.readOnly,
    );
    try {
      expect(verify.select('PRAGMA user_version').first.values.first, 63);
      expect(verify.select('SELECT id FROM sentinel').first.values.first, 42);
    } finally {
      verify.close();
    }

    // Assert the BackupRecord is in the registry with the right shape.
    final records = prefs.getHistory();
    expect(records, hasLength(1));
    expect(records.single.type, BackupType.preMigration);
    expect(records.single.fromSchemaVersion, 63);
    expect(records.single.toSchemaVersion, 64);
  });

  test(
    'a hot WAL is folded in, so the copy carries every committed row',
    () async {
      final tmp = await Directory.systemTemp.createTemp('pmbs_wal_');
      addTearDown(() => tmp.delete(recursive: true));

      final livePath = p.join(tmp.path, 'submersion.db');
      final backupsDir = p.join(tmp.path, 'backups');
      await Directory(backupsDir).create(recursive: true);

      seedHotWal(livePath);
      // Precondition: row 99 really is WAL-resident, not in the main file.
      expect(File('$livePath-wal').lengthSync(), greaterThan(0));

      SharedPreferences.setMockInitialValues({});
      final prefs = BackupPreferences(await SharedPreferences.getInstance());

      final service = PreMigrationBackupService(
        livePathProvider: () async => livePath,
        backupsDirProvider: () async => backupsDir,
        preferences: prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'wal-id',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
      expect(sentinelIds(backupPath), [42, 99]);
      // The checkpoint is lossless for the live database too.
      expect(sentinelIds(livePath), [42, 99]);
    },
  );

  test('a hot WAL on an ENCRYPTED live database is folded in too', () async {
    final tmp = await Directory.systemTemp.createTemp('pmbs_wal_enc_');
    addTearDown(() => tmp.delete(recursive: true));

    final livePath = p.join(tmp.path, 'submersion.db');
    final backupsDir = p.join(tmp.path, 'backups');
    await Directory(backupsDir).create(recursive: true);

    // Create the database, encrypt it in place (as enabling protection does),
    // then leave a hot WAL on the encrypted file.
    final seed = sqlite3.sqlite3.open(livePath);
    seed.execute('PRAGMA user_version = 63');
    seed.close();
    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: livePath,
      keyHex: _liveKeyHex,
    );
    seedHotWal(livePath, keyHex: _liveKeyHex);

    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    final service = PreMigrationBackupService(
      livePathProvider: () async => livePath,
      backupsDirProvider: () async => backupsDir,
      preferences: prefs,
      databaseKeyHexProvider: () => _liveKeyHex,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'wal-enc-id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
    expect(sentinelIds(backupPath, keyHex: _liveKeyHex), [42, 99]);
  });

  test('an unopenable live database still produces a backup', () async {
    final tmp = await Directory.systemTemp.createTemp('pmbs_wal_fail_');
    addTearDown(() => tmp.delete(recursive: true));

    final livePath = p.join(tmp.path, 'submersion.db');
    final backupsDir = p.join(tmp.path, 'backups');
    await Directory(backupsDir).create(recursive: true);

    seedHotWal(livePath);
    // No key supplied for what the checkpoint will read as an unopenable
    // file: the safety copy must still be taken rather than failing startup.
    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: livePath,
      keyHex: _liveKeyHex,
    );
    File('$livePath-wal').writeAsBytesSync(List<int>.filled(64, 7));

    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    final service = PreMigrationBackupService(
      livePathProvider: () async => livePath,
      backupsDirProvider: () async => backupsDir,
      preferences: prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'wal-fail-id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
    expect(File(backupPath).existsSync(), isTrue);
    expect(prefs.getHistory(), hasLength(1));
  });

  test(
    'the artifact is left out of WAL mode, so a read-only open needs no sidecar',
    () async {
      // The live database runs in WAL (applyMainDatabaseSetup puts it there),
      // and journal mode is written into the header, so a byte copy inherits
      // it. A WAL-mode artifact is not self-contained: opening it READ-ONLY --
      // which is exactly how BackupService.validateBackupFile and the schema
      // probe read backups -- has to create an `-shm` beside it, and fails
      // outright when the picker handed the file out of a read-only directory.
      final tmp = await Directory.systemTemp.createTemp('pmbs_mode_');
      addTearDown(() => tmp.delete(recursive: true));

      final livePath = p.join(tmp.path, 'submersion.db');
      final backupsDir = p.join(tmp.path, 'backups');
      await Directory(backupsDir).create(recursive: true);

      final seed = sqlite3.sqlite3.open(livePath);
      seed.select('PRAGMA journal_mode = WAL');
      seed.execute('PRAGMA user_version = 63');
      seed.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
      seed.execute('INSERT INTO sentinel VALUES (42)');
      seed.close();

      SharedPreferences.setMockInitialValues({});
      final prefs = BackupPreferences(await SharedPreferences.getInstance());

      await PreMigrationBackupService(
        livePathProvider: () async => livePath,
        backupsDirProvider: () async => backupsDir,
        preferences: prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'mode-id',
      ).backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
      final verify = sqlite3.sqlite3.open(
        backupPath,
        mode: sqlite3.OpenMode.readOnly,
      );
      try {
        expect(
          verify.select('PRAGMA journal_mode').first.values.first,
          'delete',
        );
        expect(verify.select('SELECT id FROM sentinel').first.values.first, 42);
      } finally {
        verify.close();
      }
      // A read-only open of a WAL-mode file would have littered these next to
      // the artifact.
      expect(File('$backupPath-wal').existsSync(), isFalse);
      expect(File('$backupPath-shm').existsSync(), isFalse);
    },
  );

  test('a read-only directory can still hold the artifact', () async {
    // The concrete failure the test above prevents: iOS/macOS hand a picked
    // backup out of a read-only sandbox directory, where SQLite cannot create
    // the `-shm` a WAL-mode file needs and the read-only open fails outright.
    final tmp = await Directory.systemTemp.createTemp('pmbs_rodir_');
    final backupsDir = p.join(tmp.path, 'sealed');
    addTearDown(() async {
      await Process.run('chmod', ['755', backupsDir]);
      await tmp.delete(recursive: true);
    });

    final livePath = p.join(tmp.path, 'submersion.db');
    await Directory(backupsDir).create(recursive: true);

    final seed = sqlite3.sqlite3.open(livePath);
    seed.select('PRAGMA journal_mode = WAL');
    seed.execute('PRAGMA user_version = 63');
    seed.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
    seed.close();

    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    await PreMigrationBackupService(
      livePathProvider: () async => livePath,
      backupsDirProvider: () async => backupsDir,
      preferences: prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'rodir-id',
    ).backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
    await Process.run('chmod', ['555', backupsDir]);

    final verify = sqlite3.sqlite3.open(
      backupPath,
      mode: sqlite3.OpenMode.readOnly,
    );
    try {
      expect(verify.select('PRAGMA user_version').first.values.first, 63);
    } finally {
      verify.close();
    }
  }, testOn: 'mac-os || linux');
}
