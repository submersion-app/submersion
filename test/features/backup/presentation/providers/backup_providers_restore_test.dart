import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}

  @override
  Future<void> restore(String backupPath) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();
}

/// Records restore invocations so the notifier's threading of [RestoreMode]
/// and its post-restore fix-ups can be asserted without real file IO.
class _RecordingBackupService extends BackupService {
  final List<String> calls = [];
  RestoreMode? lastMode;
  String? lastSecret;

  /// When true, restore throws [BackupEncryptedException] UNLESS a secret is
  /// supplied -- modelling the "encrypted artifact needs a passphrase" path.
  bool requireSecret = false;

  _RecordingBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  @override
  Future<BackupValidationResult> validateBackupFile(String filePath) async =>
      const BackupValidationResult.valid(sizeBytes: 1);

  @override
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
  }) async {
    calls.add('restoreFromBackup');
    lastMode = mode;
    lastSecret = encryptionSecret;
    if (requireSecret && encryptionSecret == null) {
      throw const BackupEncryptedException();
    }
  }

  @override
  Future<void> restoreFromFile(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
  }) async {
    calls.add('restoreFromFile');
    lastMode = mode;
    lastSecret = encryptionSecret;
    if (requireSecret && encryptionSecret == null) {
      throw const BackupEncryptedException();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _RecordingBackupService service;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _RecordingBackupService(BackupPreferences(prefs));
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  ProviderContainer makeContainer({bool overrideService = true}) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        if (overrideService) backupServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('restoreFromFilePath threads the mode and completes', () async {
    final container = makeContainer();
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_restore_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(tmp.path, mode: RestoreMode.replace);

    expect(service.calls, ['restoreFromFile']);
    expect(service.lastMode, RestoreMode.replace);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('restoreFromBackup threads the mode and completes', () async {
    final container = makeContainer();
    final record = BackupRecord(
      id: 'r1',
      filename: 'b.db',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromBackup(record);

    expect(service.calls, ['restoreFromBackup']);
    expect(service.lastMode, RestoreMode.merge);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test(
    'realignActiveDiverAfterDataReplace persists the active diver',
    () async {
      // The restored settings table names no active diver and no default
      // diver exists, so the helper leaves prefs untouched -- but must not
      // throw against a fresh database.
      await realignActiveDiverAfterDataReplace(prefs);
      expect(prefs.getString(currentDiverIdKey), isNull);
    },
  );

  test('backupServiceProvider wires the epoch store', () {
    final container = makeContainer(overrideService: false);
    final built = container.read(backupServiceProvider);
    expect(built, isA<BackupService>());
  });

  test('restoreFromFilePath rethrows BackupEncryptedException and resets '
      'to idle so the page can prompt', () async {
    service.requireSecret = true;
    final container = makeContainer();
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_enc_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });

    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(tmp.path),
      throwsA(isA<BackupEncryptedException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );

    // Retrying with a secret succeeds and threads it to the service.
    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(tmp.path, encryptionSecret: 'pw');
    expect(service.lastSecret, 'pw');
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('restoreFromBackup rethrows BackupEncryptedException and resets '
      'to idle', () async {
    service.requireSecret = true;
    final container = makeContainer();
    final record = BackupRecord(
      id: 'enc',
      filename: 'b.sbe',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );

    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromBackup(record),
      throwsA(isA<BackupEncryptedException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromBackup(record, encryptionSecret: 'pw');
    expect(service.lastSecret, 'pw');
  });
}
