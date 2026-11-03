@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/core/platform/cross_tab_lock.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

import '../web_test_assets.dart';

const _livePath = '/opfs/Submersion/submersion.db';

class _NoFileAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) =>
      throw UnsupportedError('a browser restore takes no file backup');

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) => throw UnsupportedError('a browser restore swaps no file');

  @override
  Future<String> get databasePath async => _livePath;

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _QuietSyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'browser-device';

  @override
  Future<String?> getLastAcceptedEpochId() async => null;

  @override
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {}
}

/// A browser restore (issue #4121) takes the sync lock every tab's sync
/// runs under, and keeps it from the swap until the other tabs are told,
/// so no tab syncs on the library while it is replaced and re-baselined.
void main() {
  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  test('a restore waits for a sync another tab holds the lock for, then '
      'holds it from the safety copy until the other tabs are told', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final events = <String>[];
    Future<String> lock() async =>
        await withCrossTabLockIfAvailable(kSyncCrossTabLock, () async {})
        ? 'lock free'
        : 'lock held';
    final service = BackupService(
      dbAdapter: _NoFileAdapter(),
      preferences: BackupPreferences(prefs),
      syncRepository: _QuietSyncRepository(),
      restoreImage: (bytes, {onMigrationProgress}) async {
        events.add('swap, ${await lock()}');
        return _livePath;
      },
      retireLibrary: (_) async => events.add('retire, ${await lock()}'),
    );
    final backup = await withScratchDatabase((db) async {
      db.execute('CREATE TABLE dives (id TEXT)');
      db.execute('PRAGMA user_version = 300');
    });

    final release = Completer<void>();
    final held = withCrossTabLock(kSyncCrossTabLock, () => release.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final restore = service.restoreFromImage(
      backup,
      safetyCopy: () async => events.add('safety copy, ${await lock()}'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(events, isEmpty, reason: 'the other tab\'s sync still runs');

    release.complete();
    await held;
    await restore;
    expect(events, [
      'safety copy, lock held',
      'swap, lock held',
      'retire, lock held',
    ]);
  });
}
