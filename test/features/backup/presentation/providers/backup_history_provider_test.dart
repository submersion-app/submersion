import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

void main() {
  test('history includes cloud backups the local history has lost '
      '(issue #3214)', () async {
    // A fresh install: SharedPreferences is empty, but the connected cloud
    // folder still holds the backups the previous install made.
    SharedPreferences.setMockInitialValues({});
    final preferences = BackupPreferences(
      await SharedPreferences.getInstance(),
    );
    final cloud = FakeCloudStorageProvider()
      ..seedFile(
        'submersion_backup_2026-03-14_093015.db',
        Uint8List.fromList(List.filled(64, 1)),
      )
      ..seedFile('submersion_sync_device.json', Uint8List(4));
    final service = BackupService(
      dbAdapter: UnusedBackupDatabaseAdapter(),
      preferences: preferences,
      cloudProvider: cloud,
    );
    final container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final history = await container.read(backupHistoryProvider.future);

    expect(history, hasLength(1));
    expect(history.single.filename, 'submersion_backup_2026-03-14_093015.db');
    expect(history.single.location, BackupLocation.cloud);
    expect(
      history.single.cloudFileId,
      'submersion_backup_2026-03-14_093015.db',
    );
    // Display-only: nothing is written back, so retention never prunes it.
    expect(preferences.getHistory(), isEmpty);
  });

  test('signing in after a signed-out visit lists the cloud backups on the '
      'next visit', () async {
    // Cloud Sync selects the provider before authenticate() runs, and a
    // re-sign-in to an already selected provider changes no provider state,
    // so the history must not keep the empty listing from a signed-out visit.
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeCloudStorageProvider()
      ..authenticated = false
      ..seedFile(
        'submersion_backup_2026-03-14_093015.db',
        Uint8List.fromList(List.filled(64, 1)),
      );
    final service = BackupService(
      dbAdapter: UnusedBackupDatabaseAdapter(),
      preferences: BackupPreferences(await SharedPreferences.getInstance()),
      cloudProvider: cloud,
    );
    final container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final firstVisit = container.listen(
      backupHistoryProvider.future,
      (_, _) {},
    );
    expect(await firstVisit.read(), isEmpty);
    firstVisit.close();
    await container.pump();

    cloud.authenticated = true;
    final secondVisit = container.listen(
      backupHistoryProvider.future,
      (_, _) {},
    );
    addTearDown(secondVisit.close);
    expect(await secondVisit.read(), hasLength(1));
  });

  test('a history failure surfaces its own error, not a wrapper', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FailingHistoryService(
      BackupPreferences(await SharedPreferences.getInstance()),
    );
    final container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(backupHistoryProvider.future),
      throwsA(isA<StateError>()),
    );
  });
}

class _FailingHistoryService extends BackupService {
  _FailingHistoryService(BackupPreferences preferences)
    : super(dbAdapter: UnusedBackupDatabaseAdapter(), preferences: preferences);

  @override
  Future<List<BackupRecord>> getValidatedBackupHistory() async =>
      throw StateError('history unreadable');
}
