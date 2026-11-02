@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../web_test_assets.dart';
import 'minio_round_trip_support.dart';

/// The browser against a real S3-compatible store (issue #4121): it pulls
/// the library tool/seed_sync_library_test.dart published, edits a dive,
/// publishes, and a second browser database pulls the edit back.
///
/// Needs the four MINIO_* `--dart-define`s and a store whose CORS rule
/// admits the test page's origin (MinIO: `MINIO_API_CORS_ALLOW_ORIGIN=*`);
/// without an endpoint it skips, saying so.
void main() {
  final config = minioConfigFromEnvironment();

  final previousAssetBase = BackgroundDatabaseConnection.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
  });

  Future<AppDatabase> openWebDatabase(String path) async {
    final connection = await BackgroundDatabaseConnection.open(path);
    final db = AppDatabase(connection.connection);
    DatabaseService.instance.setTestDatabase(db);
    addTearDown(db.close);
    return db;
  }

  SyncService syncWith(S3StorageProvider s3) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: s3,
  );

  test('pulls the seeded library, publishes an edit, and a second database '
      'receives it', () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(DatabaseService.instance.resetForTesting);
    final s3 = S3StorageProvider(store: FixedS3CredentialsStore(config!));

    // This browser.
    await openWebDatabase('/opfs/Submersion/s3-round-trip-a.db');
    final pull = await syncWith(s3).performSync();
    expect(
      pull.isSuccess,
      isTrue,
      reason: 'pull failed: ${pull.status} (${pull.message})',
    );
    final dives = DiveRepository();
    final pulled = await dives.getAllDives();
    expect(pulled.length, 5);
    expect(pulled.map((dive) => dive.id), containsAll(kSeededDiveIds));
    expect(
      pulled.firstWhere((dive) => dive.id == kSeededDiveIds.first).profile,
      isNotEmpty,
    );

    final note =
        'Edited in a browser at ${DateTime.now().toUtc().toIso8601String()}';
    final edited = pulled.firstWhere((dive) => dive.id == kSeededDiveIds.first);
    await dives.updateDive(edited.copyWith(notes: note));
    final push = await syncWith(s3).performSync();
    expect(
      push.isSuccess,
      isTrue,
      reason: 'publish failed: ${push.status} (${push.message})',
    );

    final deviceA = await SyncRepository().getDeviceId();
    final ours = [
      for (final file in await s3.listFiles(
        folderId: await s3.getOrCreateSyncFolder(),
        namePattern: ChangesetLogLayout.listPattern,
      ))
        if (file.name.startsWith('${ChangesetLogLayout.prefix}$deviceA.'))
          file.name,
    ];
    expect(ours, contains(ChangesetLogLayout.manifestName(deviceA)));
    expect(ours, anyElement(contains('.cs.')), reason: 'a changeset object');

    // A second browser database under another name.
    await openWebDatabase('/opfs/Submersion/s3-round-trip-c.db');
    final second = await syncWith(s3).performSync();
    expect(
      second.isSuccess,
      isTrue,
      reason: 'second pull failed: ${second.status} (${second.message})',
    );
    final arrived = await DiveRepository().getDiveById(kSeededDiveIds.first);
    expect(arrived?.notes, note);
  }, skip: config == null ? minioSkipReason : null);
}
