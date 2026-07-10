import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_migration_service.dart';
import 'package:submersion/core/services/database_service.dart';

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

  @override
  Future<void> saveStorageConfig(StorageConfig config) async {}

  @override
  Future<bool> createAndStoreBookmark(String folderPath) async => true;

  @override
  Future<void> clearStoredBookmark() async {}

  @override
  Future<void> resetToDefault() async {}

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

  Future<DatabaseMigrationService> initServiceAt(String defaultDir) async {
    final location = _FakeLocation(
      currentPath: currentPath,
      defaultDir: defaultDir,
    );
    await DatabaseService.instance.initialize(locationService: location);
    // Force the background executor to materialize the file so the pre-close
    // backup/copy have real bytes.
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    return DatabaseMigrationService(DatabaseService.instance, location);
  }

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
    final one = await DatabaseService.instance.database
        .customSelect('SELECT 1 AS v')
        .getSingle();
    expect(one.read<int>('v'), 1);
  });
}
