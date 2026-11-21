import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_migration_service.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// Minimal location-service fake: the migration methods drive real temp
/// files for everything except configuration/bookmark bookkeeping, which we
/// no-op here. [defaultDir] is only consulted by migrateToDefault.
class _FakeLocation implements DatabaseLocationService {
  _FakeLocation({required this.currentPath, required this.defaultDir});

  final String currentPath;
  final String defaultDir;

  @override
  Future<String> getDatabasePath() async => currentPath;

  @override
  Future<String> getDefaultDatabaseDirectory() async => defaultDir;

  @override
  Future<bool> verifyFolderAccessible(String folderPath) async => true;

  StorageConfig? savedConfig;

  @override
  Future<void> saveStorageConfig(StorageConfig config) async =>
      savedConfig = config;

  @override
  Future<bool> createAndStoreBookmark(String folderPath) async => true;

  int bookmarkClears = 0;

  @override
  Future<void> clearStoredBookmark() async => bookmarkClears++;

  @override
  Future<void> resetToDefault() async {}

  int switchMarks = 0;

  @override
  Future<void> markDatabaseSwitched() async => switchMarks++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Materialize a real Submersion database file at [path] so the migration
/// helpers (backup, copy, integrity check) have genuine bytes to work with.
Future<void> _seedDatabase(String path) async {
  await Directory(p.dirname(path)).create(recursive: true);
  final db = AppDatabase(NativeDatabase(File(path)));
  await db.customSelect('SELECT 1').get();
  await db.close();
}

void main() {
  late Directory root;
  late String currentDir;
  late String currentPath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ws5-migration-test');
    currentDir = p.join(root.path, 'current');
    currentPath = p.join(currentDir, DatabaseLocationService.databaseFilename);
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      await root.delete(recursive: true);
    }
  });

  late _FakeLocation location;

  Future<DatabaseMigrationService> initServiceAt(String defaultDir) async {
    location = _FakeLocation(currentPath: currentPath, defaultDir: defaultDir);
    await DatabaseService.instance.initialize(locationService: location);
    // Force the background executor to materialize the file so the pre-close
    // backup/copy have real bytes.
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    return DatabaseMigrationService(DatabaseService.instance, location);
  }

  test('replaceExistingDatabase keeps the overwritten database recoverable, '
      'sidecar included', () async {
    final service = await initServiceAt(p.join(root.path, 'default'));

    // A database already sitting in the target folder, in WAL mode with an
    // uncheckpointed sidecar -- the state a force-killed install leaves. It is
    // about to be overwritten, and this copy is the only way back.
    final targetDir = p.join(root.path, 'target');
    await Directory(targetDir).create(recursive: true);
    final victimPath = p.join(
      targetDir,
      DatabaseLocationService.databaseFilename,
    );
    await _seedDatabase(victimPath);
    File('$victimPath-wal').writeAsStringSync('uncheckpointed frames');

    final result = await service.replaceExistingDatabase(targetDir);
    expect(result.success, isTrue, reason: result.errorMessage);

    final copies = Directory(targetDir)
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((name) => name.contains('_backup_'))
        .toList();
    expect(
      copies.where((name) => name.endsWith('.db')),
      hasLength(1),
      reason: 'the overwritten database should have been copied aside',
    );
    expect(
      copies.where((name) => name.endsWith('.db-wal')),
      hasLength(1),
      reason:
          'a copy of `<db>` alone is not the database: the rows in the '
          'sidecar would be unrecoverable',
    );
  });

  test('migrateToCustomFolder closes strictly and reopens at the new '
      'folder', () async {
    final service = await initServiceAt(p.join(root.path, 'default'));
    // migrateToCustomFolder targets a user-picked, already-existing folder.
    final targetDir = p.join(root.path, 'target');
    await Directory(targetDir).create(recursive: true);

    final result = await service.migrateToCustomFolder(targetDir);

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(DatabaseService.instance.lastOpenMode, DatabaseOpenMode.background);
    expect(
      File(
        p.join(targetDir, DatabaseLocationService.databaseFilename),
      ).existsSync(),
      isTrue,
    );
    final one = await DatabaseService.instance.database
        .customSelect('SELECT 1 AS v')
        .getSingle();
    expect(one.read<int>('v'), 1);
  });

  test('migrateToCustomFolder waits for a sync merging before it closes the '
      'database (issue #3798)', () async {
    addTearDown(SyncCoordinator.reset);
    final service = await initServiceAt(p.join(root.path, 'default'));
    final original = DatabaseService.instance.database;
    final targetDir = p.join(root.path, 'target');
    await Directory(targetDir).create(recursive: true);
    final merging = Completer<void>();
    final sync = SyncCoordinator.run(() => merging.future);

    var moved = false;
    final moving = service
        .migrateToCustomFolder(targetDir)
        .then((_) => moved = true);
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(moved, isFalse);
    expect(DatabaseService.instance.databaseOrNull, same(original));

    merging.complete();
    await sync;
    await moving;
    expect(DatabaseService.instance.databaseOrNull, isNot(same(original)));
  });

  test('migrateToCustomFolder carries the security keyslot sidecar', () async {
    final service = await initServiceAt(p.join(root.path, 'default'));
    final targetDir = p.join(root.path, 'target');
    await Directory(targetDir).create(recursive: true);
    // A sidecar next to the live DB (as enableSecurity would write it).
    final sidecarPath = DatabaseSecuritySidecar.pathFor(currentPath);
    File(sidecarPath).writeAsStringSync('{"version":1}');

    final result = await service.migrateToCustomFolder(targetDir);

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(
      File(p.join(targetDir, DatabaseSecuritySidecar.fileName)).existsSync(),
      isTrue,
      reason: 'sidecar must travel with the database on a storage move',
    );
  });

  test('migrateToDefault closes strictly and reopens at the default '
      'directory', () async {
    final defaultDir = p.join(root.path, 'default');
    final service = await initServiceAt(defaultDir);

    final result = await service.migrateToDefault();

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(DatabaseService.instance.lastOpenMode, DatabaseOpenMode.background);
    expect(
      File(
        p.join(defaultDir, DatabaseLocationService.databaseFilename),
      ).existsSync(),
      isTrue,
    );
  });

  test('switchToExistingDatabase closes strictly and adopts the target '
      'database', () async {
    final service = await initServiceAt(p.join(root.path, 'default'));
    // Pre-create a valid database at the target location to switch to.
    final targetDir = p.join(root.path, 'existing');
    final targetPath = p.join(
      targetDir,
      DatabaseLocationService.databaseFilename,
    );
    await _seedDatabase(targetPath);

    final result = await service.switchToExistingDatabase(targetDir);

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(DatabaseService.instance.currentPath, targetPath);
    // Another dive log is open now: the storage cleanup must not trust what
    // the last sync told it about the one it replaced.
    expect(location.switchMarks, 1);
    final one = await DatabaseService.instance.database
        .customSelect('SELECT 1 AS v')
        .getSingle();
    expect(one.read<int>('v'), 1);
  });

  test(
    'checkForExistingDatabase reads the dive log in another folder',
    () async {
      final service = await initServiceAt(p.join(root.path, 'default'));
      final otherDir = p.join(root.path, 'other');
      final otherPath = p.join(
        otherDir,
        DatabaseLocationService.databaseFilename,
      );
      await _seedDatabase(otherPath);

      final info = await service.checkForExistingDatabase(otherDir);

      expect(info?.path, otherPath);
      expect(info?.fileSize, File(otherPath).lengthSync());
    },
  );

  group('the current folder picked under another name (issue #4834)', () {
    // A symlink stands in for the reporter's NAS reached through a second
    // server name: \\DXP6800\... and \\DXP6800-5g\... are one folder.
    late String aliasDir;

    Future<DatabaseMigrationService> initWithAlias() async {
      final service = await initServiceAt(p.join(root.path, 'default'));
      aliasDir = p.join(root.path, 'alias');
      await Link(aliasDir).create(currentDir);
      return service;
    }

    List<String> backupsIn(String dir) => Directory(dir)
        .listSync()
        .map((e) => p.basename(e.path))
        .where((name) => name.contains('_backup_'))
        .toList();

    test('checkForExistingDatabase describes the open dive log rather than '
        'opening it a second time through the other name', () async {
      final service = await initWithAlias();

      final info = await service.checkForExistingDatabase(aliasDir);

      expect(info, isNotNull);
      expect(info!.path, currentPath);
    });

    test('migrateToCustomFolder refuses rather than copy the dive log onto '
        'itself', () async {
      final service = await initWithAlias();
      final before = File(currentPath).lengthSync();

      final result = await service.migrateToCustomFolder(aliasDir);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('already at this location'));
      expect(backupsIn(currentDir), isEmpty);
      expect(File(currentPath).lengthSync(), before);
      expect(DatabaseService.instance.currentPath, currentPath);
      expect(location.savedConfig, isNull);
    });

    test('replaceExistingDatabase refuses rather than replace the dive log '
        'with itself', () async {
      final service = await initWithAlias();

      final result = await service.replaceExistingDatabase(aliasDir);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('already at this location'));
      expect(backupsIn(currentDir), isEmpty);
      expect(DatabaseService.instance.currentPath, currentPath);
      expect(location.savedConfig, isNull);
    });

    test('migrateToDefault does not copy the dive log onto itself when the '
        'default folder is the current one under another name', () async {
      // Here the alias is the DEFAULT folder, and the live log is in it.
      aliasDir = p.join(root.path, 'alias');
      await Link(aliasDir).create(currentDir);
      location = _FakeLocation(currentPath: currentPath, defaultDir: aliasDir);
      await DatabaseService.instance.initialize(locationService: location);
      await DatabaseService.instance.database
          .customSelect('SELECT 1')
          .getSingle();
      final service = DatabaseMigrationService(
        DatabaseService.instance,
        location,
      );

      final result = await service.migrateToDefault();

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(backupsIn(currentDir), isEmpty);
      expect(location.savedConfig?.mode, StorageLocationMode.appDefault);
      // The custom folder's bookmark goes too, as it does after a full move.
      expect(location.bookmarkClears, 1);
      final one = await DatabaseService.instance.database
          .customSelect('SELECT 1 AS v')
          .getSingle();
      expect(one.read<int>('v'), 1);
    });

    test('a move refuses when it cannot tell whether the folder is the current '
        'one, rather than risk opening or copying the live file under a second '
        'name', () async {
      final service = await initServiceAt(p.join(root.path, 'default'));
      final targetDir = p.join(root.path, 'target');
      final targetPath = p.join(
        targetDir,
        DatabaseLocationService.databaseFilename,
      );
      await _seedDatabase(targetPath);
      // No marker can be written beside the live dive log, so the folders
      // cannot be compared.
      await Process.run('chmod', ['555', currentDir]);
      try {
        try {
          File(p.join(currentDir, 'write-check')).createSync();
          markTestSkipped('permissions are not enforced for this user');
          return;
        } on FileSystemException {
          // Read-only, as intended.
        }

        // Described from its file alone: it may be the live log.
        final found = await service.checkForExistingDatabase(targetDir);
        expect(found?.path, targetPath);

        final moved = await service.migrateToCustomFolder(targetDir);
        final replaced = await service.replaceExistingDatabase(targetDir);
        final home = await service.migrateToDefault();

        for (final result in [moved, replaced, home]) {
          expect(result.success, isFalse);
          expect(result.errorMessage, contains('Could not tell'));
        }
        expect(DatabaseService.instance.currentPath, currentPath);
        expect(location.savedConfig, isNull);
      } finally {
        await Process.run('chmod', ['755', currentDir]);
      }
    }, skip: Platform.isWindows ? 'chmod is POSIX only' : false);

    test('switchToExistingDatabase moves the stored folder to the name the '
        'diver picked', () async {
      final service = await initWithAlias();

      final result = await service.switchToExistingDatabase(aliasDir);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(location.savedConfig?.customFolderPath, aliasDir);
      final one = await DatabaseService.instance.database
          .customSelect('SELECT 1 AS v')
          .getSingle();
      expect(one.read<int>('v'), 1);
    });
  });
}
