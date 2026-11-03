@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
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
  final previousWorkerBase = ComputeWorkerClient.assetBase;
  setUpAll(() {
    BackgroundDatabaseConnection.assetBase = kWebTestAssetBase;
    ComputeWorkerClient.assetBase = kWebTestAssetBase;
    // A test page registers no plugins, and on a browser the version lookup
    // a publish makes for its manifest then never answers.
    PackageInfo.setMockInitialValues(
      appName: 'Submersion',
      packageName: 'app.submersion',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
  });
  tearDownAll(() {
    BackgroundDatabaseConnection.assetBase = previousAssetBase;
    ComputeWorkerClient.assetBase = previousWorkerBase;
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
    // Shown when the test fails, so a timeout names the stage that stalled.
    final clock = Stopwatch()..start();
    void stage(String name) => printOnFailure('[${clock.elapsed}] $name');
    final s3 = S3StorageProvider(store: FixedS3CredentialsStore(config!));

    // This browser.
    await openWebDatabase('/opfs/Submersion/s3-round-trip-a.db');
    stage('database open');
    final pull = await syncWith(s3).performSync();
    stage('first pull done');
    expect(
      pull.isSuccess,
      isTrue,
      reason: 'pull failed: ${pull.status} (${pull.message})',
    );
    final dives = DiveRepository();
    final pulled = await dives.getAllDives();
    expect(pulled.length, 5);
    expect(pulled.map((dive) => dive.id), containsAll(kSeededDiveIds));
    // The list leaves profiles out; a dive read on its own carries one.
    final edited = (await dives.getDiveById(kSeededDiveIds.first))!;
    expect(edited.profile, isNotEmpty);

    final note =
        'Edited in a browser at ${DateTime.now().toUtc().toIso8601String()}';
    await dives.updateDive(edited.copyWith(notes: note));
    stage('edit saved');
    final push = await syncWith(s3).performSync();
    stage('publish done');
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
    // A changeset, or a fresh base where compaction rewrote a small library.
    expect(
      ours.where((name) => name.contains('.cs.') || name.contains('.base.')),
      isNotEmpty,
      reason: 'the edit was published',
    );

    // A second browser database under another name.
    await openWebDatabase('/opfs/Submersion/s3-round-trip-c.db');
    stage('second database open');
    final second = await syncWith(s3).performSync();
    stage('second pull done');
    expect(
      second.isSuccess,
      isTrue,
      reason: 'second pull failed: ${second.status} (${second.message})',
    );
    final arrived = await DiveRepository().getDiveById(kSeededDiveIds.first);
    expect(arrived?.notes, note);
  }, skip: config == null ? minioSkipReason : null);
}
