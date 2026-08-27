import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Issue #509 cloud clear: freeing this device's footprint (3a) and the
/// full-backend wipe (3b).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  Uint8List b(String s) => Uint8List.fromList(s.codeUnits);

  test('deleteDeviceSyncFile removes only this device’s files (manifest, base '
      'parts, changesets)', () async {
    // dev1: a manifest, a base part, and a changeset -- all should go.
    cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
    cloud.seedFile(ChangesetLogLayout.basePartName('dev1', 0, 0), b('bp1'));
    cloud.seedFile(ChangesetLogLayout.changesetName('dev1', 5), b('cs1'));
    // dev2: must survive.
    cloud.seedFile(ChangesetLogLayout.manifestName('dev2'), b('m2'));

    await buildService().deleteDeviceSyncFile('dev1');

    expect(cloud.bytesOf(ChangesetLogLayout.manifestName('dev1')), isNull);
    expect(
      cloud.bytesOf(ChangesetLogLayout.basePartName('dev1', 0, 0)),
      isNull,
    );
    expect(cloud.bytesOf(ChangesetLogLayout.changesetName('dev1', 5)), isNull);
    expect(
      cloud.bytesOf(ChangesetLogLayout.manifestName('dev2')),
      isNotNull,
      reason: 'other devices keep syncing',
    );
  });

  test('wipeAllSyncData deletes logs AND the epoch/moved markers', () async {
    cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
    cloud.seedFile(ChangesetLogLayout.basePartName('dev1', 0, 0), b('bp1'));
    cloud.seedFile(libraryEpochFileName, b('epoch'));
    cloud.seedFile(libraryMovedFileName, b('moved'));

    await buildService().wipeAllSyncData(cloud);

    // deleteAllSyncFiles clears the logs...
    expect(cloud.bytesOf(ChangesetLogLayout.manifestName('dev1')), isNull);
    expect(
      cloud.bytesOf(ChangesetLogLayout.basePartName('dev1', 0, 0)),
      isNull,
    );
    // ...and wipeAllSyncData additionally clears the epoch/moved markers that
    // deleteAllSyncFiles deliberately preserves, for a genuine fresh start.
    expect(cloud.bytesOf(libraryEpochFileName), isNull);
    expect(cloud.bytesOf(libraryMovedFileName), isNull);
  });

  test(
    'wipeAllSyncData is best-effort: a delete failure does not throw',
    () async {
      cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
      cloud.seedFile(libraryEpochFileName, b('epoch'));
      cloud.failDeletes = true; // offline/denied provider

      // Every delete throws, but the wipe swallows and logs each one.
      await buildService().wipeAllSyncData(cloud);
    },
  );

  // ---- Issue #1032: a wipe of a large backend runs for minutes with no
  // feedback, and reported success even when it had not finished. The outcome
  // and progress stream are what the UI needs to stop lying to the user.

  group('wipe progress and outcome (issue #1032)', () {
    test('reports monotonic progress against a total fixed up front', () async {
      for (var i = 0; i < 4; i++) {
        cloud.seedFile(ChangesetLogLayout.basePartName('dev1', 0, i), b('p$i'));
      }
      cloud.seedFile(libraryEpochFileName, b('epoch'));

      final seen = <({int done, int total})>[];
      final outcome = await buildService().wipeAllSyncData(
        cloud,
        onProgress: (done, total) => seen.add((done: done, total: total)),
      );

      expect(outcome.deleted, 5);
      expect(outcome.failed, 0);
      expect(seen.first, (
        done: 0,
        total: 5,
      ), reason: 'the bar must start at a known total, not grow as it goes');
      expect(seen.last, (done: 5, total: 5));
      expect(
        seen.map((p) => p.done),
        orderedEquals([0, 1, 2, 3, 4, 5]),
        reason: 'one tick per file so a 400-file wipe visibly advances',
      );
      expect(seen.every((p) => p.total == 5), isTrue);
    });

    test('counts failed deletions instead of reporting a clean wipe', () async {
      cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
      cloud.seedFile(libraryEpochFileName, b('epoch'));
      cloud.failDeletes = true;

      final outcome = await buildService().wipeAllSyncData(cloud);

      expect(outcome.deleted, 0);
      expect(outcome.failed, 2);
      expect(outcome.isComplete, isFalse);
    });

    test(
      'flags an incomplete listing so the UI cannot claim success',
      () async {
        // Mirrors the reported log: "Could not list markers for full sync wipe:
        // TimeoutException" -- markers survived, yet the app said "Wiped all
        // sync data".
        cloud.failLists = true;

        final outcome = await buildService().wipeAllSyncData(cloud);

        expect(outcome.listIncomplete, isTrue);
        expect(outcome.isComplete, isFalse);
      },
    );

    test('a wipe that deletes everything it listed is complete', () async {
      cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));

      final outcome = await buildService().wipeAllSyncData(cloud);

      expect(outcome.deleted, 1);
      expect(outcome.isComplete, isTrue);
    });

    test('deletes the changeset logs before the epoch marker', () async {
      cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
      cloud.seedFile(libraryEpochFileName, b('epoch'));

      await buildService().wipeAllSyncData(cloud);

      final deletes = cloud.operationLog
          .where((op) => op.startsWith('delete:'))
          .toList();
      expect(
        deletes.indexOf('delete:${ChangesetLogLayout.manifestName('dev1')}'),
        lessThan(deletes.indexOf('delete:$libraryEpochFileName')),
        reason:
            'a peer listing mid-wipe must not see orphaned logs whose epoch '
            'marker is already gone',
      );
    });

    test('deleteDeviceSyncFile reports its own outcome', () async {
      cloud.seedFile(ChangesetLogLayout.manifestName('dev1'), b('m1'));
      cloud.seedFile(ChangesetLogLayout.basePartName('dev1', 0, 0), b('bp1'));
      cloud.seedFile(ChangesetLogLayout.manifestName('dev2'), b('m2'));

      final seen = <({int done, int total})>[];
      final outcome = await buildService().deleteDeviceSyncFile(
        'dev1',
        onProgress: (done, total) => seen.add((done: done, total: total)),
      );

      expect(outcome.deleted, 2, reason: 'only dev1’s two files');
      expect(outcome.isComplete, isTrue);
      expect(seen.last, (done: 2, total: 2));
    });
  });
}
