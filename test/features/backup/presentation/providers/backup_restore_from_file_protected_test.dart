// Restore from file accepts a pre-update safety copy of a protected database
// when this install's key opens it (issue #3650), so a copy the diver saved
// or emailed to themselves restores on the device it came from.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/security/database_encryption_migrator.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

const _liveKeyHex =
    '4a5f1c9d3e8b0726114d90ab63fe2d58c7093a41bb5e6f28d0c1a7935e4b8206';

class _KeyedAdapter implements BackupDatabaseAdapter {
  _KeyedAdapter(this.databaseKeyHex);

  @override
  final String? databaseKeyHex;

  @override
  Future<void> backup(String destinationPath, {String? note}) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();
}

/// Real validation, recorded restore: the test is about which files reach
/// the restore, not about the swap itself.
class _RecordingBackupService extends BackupService {
  _RecordingBackupService(BackupPreferences prefs, String? keyHex)
    : super(dbAdapter: _KeyedAdapter(keyHex), preferences: prefs);

  final restoredPaths = <String>[];

  @override
  Future<void> restoreFromFile(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async => restoredPaths.add(filePath);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('restore_protected_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  String writeSubmersionDb(String name) {
    final path = p.join(tmp.path, name);
    final db = sqlite3.sqlite3.open(path);
    try {
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
      db.execute('PRAGMA user_version = 63');
    } finally {
      db.close();
    }
    return path;
  }

  Future<String> writeProtectedCopy(String name) async {
    final path = writeSubmersionDb(name);
    await DatabaseEncryptionMigrator().encryptInPlace(
      dbPath: path,
      keyHex: _liveKeyHex,
    );
    return path;
  }

  (ProviderContainer, _RecordingBackupService) makeContainer(String? keyHex) {
    final service = _RecordingBackupService(BackupPreferences(prefs), keyHex);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return (container, service);
  }

  test(
    'restoreFromFilePath accepts a SQLCipher copy the live key opens',
    () async {
      final path = await writeProtectedCopy('20261012-081200000-v300-v301.db');
      final (container, service) = makeContainer(_liveKeyHex);

      await container
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(path);

      expect(service.restoredPaths, [path]);
    },
  );

  test(
    'restoreFromFilePath refuses a SQLCipher copy with no live key',
    () async {
      final path = await writeProtectedCopy('20261012-081200000-v300-v301.db');
      final (container, service) = makeContainer(null);

      await container
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(path);

      final state = container.read(backupOperationProvider);
      expect(state.status, BackupOperationStatus.error);
      expect(state.message, BackupService.unreadableCopyNoKeyMessage);
      expect(service.restoredPaths, isEmpty);
    },
  );

  test('restoreFromFilePath still accepts a plain backup', () async {
    final path = writeSubmersionDb('submersion_backup_2026-10-28.db');
    final (container, service) = makeContainer(_liveKeyHex);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(path);

    expect(service.restoredPaths, [path]);
  });
}
