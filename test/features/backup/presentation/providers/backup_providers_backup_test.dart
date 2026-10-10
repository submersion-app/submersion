import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
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

  @override
  String? get databaseKeyHex => null;
}

/// Returns a canned record, and reports whether the cloud copy was withheld
/// because the device is not unlocked for sync encryption.
class _FakeBackupService extends BackupService {
  bool blockedByEncryptionLock = false;
  bool lockCheckThrows = false;
  BackupLocation location = BackupLocation.local;
  String? lastNote;

  _FakeBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  @override
  Future<BackupRecord> performBackup({
    bool isAutomatic = false,
    String? note,
  }) async {
    lastNote = note;
    return BackupRecord(
      id: 'r1',
      filename: 'submersion_backup_test.db',
      timestamp: DateTime(2026, 10, 9),
      sizeBytes: 2048,
      location: location,
      diveCount: 0,
      siteCount: 0,
      type: BackupType.manual,
    );
  }

  @override
  Future<bool> isCloudBackupBlockedByEncryptionLock() async {
    if (lockCheckThrows) throw StateError('keychain unavailable');
    return blockedByEncryptionLock;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakeBackupService service;
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _FakeBackupService(BackupPreferences(prefs));
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue('en'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('Backup Now hands the note to the service', () async {
    final container = makeContainer();
    await container
        .read(backupOperationProvider.notifier)
        .performBackup(note: 'Before the trip');
    expect(service.lastNote, 'Before the trip');
  });

  group('manual backup message (issue #3089)', () {
    test('says the backup stayed on the device when encryption is '
        'locked', () async {
      service.blockedByEncryptionLock = true;
      final container = makeContainer();

      await container.read(backupOperationProvider.notifier).performBackup();

      final state = container.read(backupOperationProvider);
      expect(state.status, BackupOperationStatus.success);
      expect(
        state.message,
        l10n.backup_operation_createdLocalOnlyLocked('2.0 KB'),
      );
    });

    test('keeps the plain message otherwise', () async {
      final container = makeContainer();

      await container.read(backupOperationProvider.notifier).performBackup();

      expect(
        container.read(backupOperationProvider).message,
        l10n.backup_operation_created('2.0 KB'),
      );
    });

    test('a failing lock check does not fail a backup that was '
        'written', () async {
      service.lockCheckThrows = true;
      final container = makeContainer();

      await container.read(backupOperationProvider.notifier).performBackup();

      final state = container.read(backupOperationProvider);
      expect(state.status, BackupOperationStatus.success);
      expect(state.message, l10n.backup_operation_created('2.0 KB'));
    });

    test('keeps the plain message when the cloud copy was made', () async {
      // A lock that only appeared after the upload finished does not mean
      // the upload was withheld.
      service
        ..blockedByEncryptionLock = true
        ..location = BackupLocation.both;
      final container = makeContainer();

      await container.read(backupOperationProvider.notifier).performBackup();

      expect(
        container.read(backupOperationProvider).message,
        l10n.backup_operation_created('2.0 KB'),
      );
    });
  });
}
