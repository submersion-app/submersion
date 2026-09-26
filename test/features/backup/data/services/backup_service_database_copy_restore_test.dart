import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';

/// The live-database key an encrypted install would hold in memory.
const _liveKeyHex =
    '4a5f1c9d3e8b0726114d90ab63fe2d58c7093a41bb5e6f28d0c1a7935e4b8206';

/// Fake adapter whose swap copies ONLY the source's main file, the way
/// `DatabaseService.restore` stages a restore, so a test can see exactly
/// what a restore would have put live.
class _FakeBackupDatabaseAdapter implements BackupDatabaseAdapter {
  _FakeBackupDatabaseAdapter({
    required this.swappedInPath,
    this.databaseKeyHex,
  });

  @override
  final String? databaseKeyHex;

  /// Where [restore] copies the source's main file.
  final String swappedInPath;

  int backupCallCount = 0;
  int restoreCallCount = 0;
  String? lastRestorePath;

  @override
  Future<void> backup(String destinationPath) async {
    backupCallCount++;
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake backup data');
  }

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {
    restoreCallCount++;
    lastRestorePath = backupPath;
    await File(backupPath).copy(swappedInPath);
  }

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database =>
      throw UnimplementedError('Fake database does not support direct queries');
}

class _SpySyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'live-device-id';

  @override
  Future<String?> getLastAcceptedEpochId() async => null;

  @override
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SharedPreferences prefs;
  late String swappedIn;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('db_copy_restore_');
    swappedIn = p.join(tempDir.path, 'swapped-in.db');
  });

  tearDown(() => tempDir.delete(recursive: true));

  /// A quarantined copy's name, which carries no backup file extension.
  String copyPath() =>
      p.join(tempDir.path, 'submersion.db.pre-restore.20260926T134501Z');

  /// Writes a Submersion-shaped database at [path] holding [dives] dives.
  void writeDatabase(String path, {int dives = 1, int schema = 63}) {
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    for (var i = 0; i < dives; i++) {
      db.execute("INSERT INTO dives VALUES ('dive-$i')");
    }
    db.execute('PRAGMA user_version = $schema');
    db.close();
  }

  int diveCount(String path, {String? keyHex}) {
    final db = sqlite3.sqlite3.open(path);
    try {
      if (keyHex != null) db.execute("PRAGMA key = \"x'$keyHex'\"");
      return db.select('SELECT COUNT(*) AS n FROM dives').first['n'] as int;
    } finally {
      db.close();
    }
  }

  BackupService serviceFor(_FakeBackupDatabaseAdapter adapter) => BackupService(
    dbAdapter: adapter,
    preferences: BackupPreferences(prefs),
    syncRepository: _SpySyncRepository(),
    postRestoreSyncStore: PostRestoreSyncStore(prefs),
  );

  test('restores a copy whose name carries no backup extension', () async {
    final path = copyPath();
    writeDatabase(path, dives: 3);
    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);

    await serviceFor(adapter).restoreFromDatabaseCopy(path);

    expect(adapter.backupCallCount, 1, reason: 'safety backup first');
    expect(adapter.restoreCallCount, 1);
    expect(adapter.lastRestorePath, path);
    expect(diveCount(swappedIn), 3);
    expect(File(path).existsSync(), isTrue, reason: 'the copy is kept');
  });

  test('folds the copy\'s -wal into it before the swap copies the main file '
      'alone', () async {
    // A database stopped mid-session: committed dives sit in the -wal, not
    // yet checkpointed into the main file. That is what a quarantined copy
    // looks like when the app was killed with the database open.
    final live = p.join(tempDir.path, 'live.db');
    final db = sqlite3.sqlite3.open(live);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA wal_autocheckpoint = 0');
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    db.execute('PRAGMA user_version = 63');
    for (var i = 0; i < 5; i++) {
      db.execute("INSERT INTO dives VALUES ('dive-$i')");
    }
    final path = copyPath();
    File(live).copySync(path);
    File('$live-wal').copySync('$path-wal');
    db.close();
    expect(
      File('$path-wal').lengthSync(),
      greaterThan(0),
      reason: 'fixture must carry committed pages in its -wal',
    );

    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);
    await serviceFor(adapter).restoreFromDatabaseCopy(path);

    expect(diveCount(swappedIn), 5);
  });

  test('refuses a copy whose journal cannot be folded in, before the safety '
      'backup or the swap', () async {
    // Same crash-shaped fixture as above, but another connection holds a
    // read snapshot on the copy's -wal, so the checkpoint cannot empty it.
    final live = p.join(tempDir.path, 'live.db');
    final db = sqlite3.sqlite3.open(live);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA wal_autocheckpoint = 0');
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    db.execute('PRAGMA user_version = 63');
    db.execute("INSERT INTO dives VALUES ('dive-0')");
    final path = copyPath();
    File(live).copySync(path);
    File('$live-wal').copySync('$path-wal');
    db.close();

    final reader = sqlite3.sqlite3.open(path);
    addTearDown(reader.close);
    reader.execute('BEGIN');
    reader.select('SELECT COUNT(*) FROM dives');

    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);
    await expectLater(
      serviceFor(adapter).restoreFromDatabaseCopy(path),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('Could not prepare the database copy'),
        ),
      ),
    );
    expect(adapter.backupCallCount, 0);
    expect(adapter.restoreCallCount, 0);
    reader.execute('COMMIT');
  });

  test('restores a copy encrypted with the live key', () async {
    final path = copyPath();
    writeDatabase(path, dives: 2);
    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: path,
      keyHex: _liveKeyHex,
    );
    final adapter = _FakeBackupDatabaseAdapter(
      swappedInPath: swappedIn,
      databaseKeyHex: _liveKeyHex,
    );

    await serviceFor(adapter).restoreFromDatabaseCopy(path);

    expect(adapter.restoreCallCount, 1);
    expect(diveCount(swappedIn, keyHex: _liveKeyHex), 2);
  });

  test('refuses a copy from a newer build, with no side effects', () async {
    final path = copyPath();
    writeDatabase(path, schema: AppDatabase.currentSchemaVersion + 1);
    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);

    await expectLater(
      serviceFor(adapter).restoreFromDatabaseCopy(path),
      throwsA(isA<BackupException>()),
    );
    expect(adapter.backupCallCount, 0);
    expect(adapter.restoreCallCount, 0);
  });

  test('refuses a copy that does not open', () async {
    final path = copyPath();
    await File(path).writeAsString('not a database');
    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);

    await expectLater(
      serviceFor(adapter).restoreFromDatabaseCopy(path),
      throwsA(isA<BackupException>()),
    );
    expect(adapter.backupCallCount, 0);
    expect(adapter.restoreCallCount, 0);
  });

  test('refuses a copy that is gone', () async {
    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);

    await expectLater(
      serviceFor(adapter).restoreFromDatabaseCopy(copyPath()),
      throwsA(isA<BackupException>()),
    );
    expect(adapter.restoreCallCount, 0);
  });

  test('a merge restore arms the post-restore sync', () async {
    final path = copyPath();
    writeDatabase(path);
    final adapter = _FakeBackupDatabaseAdapter(swappedInPath: swappedIn);

    await serviceFor(
      adapter,
    ).restoreFromDatabaseCopy(path, mode: RestoreMode.merge);

    expect(PostRestoreSyncStore(prefs).pending, isTrue);
  });
}
