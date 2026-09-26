import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// A retirement rejoin replays the pending snapshot with fresh clocks so the
/// rows sort above the adopted watermark. A media row pending only because
/// of a fact write must not get a fresh ROW clock: that would republish this
/// device's whole snapshot of it and let a stale caption beat a peer's newer
/// edit (media sync program spec 5.1).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await SyncRepository().ensureSyncClockConfigured();
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  /// Real clocks: an issued HLC is a canonical zero-padded string, so a
  /// letter stand-in would compare the wrong way round. [watermark] is the
  /// publish watermark the snapshot was exported above, so [oldest] and
  /// [older] are published and [newer] and [newest] are not.
  late String oldest;
  late String older;
  late String watermark;
  late String newer;
  late String newest;

  setUp(() {
    oldest = SyncClock.instance.issue()!;
    older = SyncClock.instance.issue()!;
    watermark = SyncClock.instance.issue()!;
    newer = SyncClock.instance.issue()!;
    newest = SyncClock.instance.issue()!;
    expect([
      oldest,
      older,
      watermark,
      newer,
      newest,
    ], orderedEquals([oldest, older, watermark, newer, newest]..sort()));
  });

  Map<String, dynamic> mediaRow({
    required String hlc,
    String? upload,
    String? verify,
  }) => {
    'id': 'm1',
    'caption': 'mine',
    'hlc': hlc,
    'uploadFactsHlc': upload,
    'verifyFactsHlc': verify,
  };

  Map<String, dynamic> restamp(Map<String, dynamic> row) =>
      SyncService.restampRowForReplay(
        'media',
        row,
        publishedThrough: watermark,
      );

  test('a fact-only pending row keeps its row clock', () {
    final out = restamp(mediaRow(hlc: older, upload: newest));

    expect(out['hlc'], older, reason: 'the row clock was already published');
    expect(
      (out['uploadFactsHlc'] as String).compareTo(newest),
      greaterThan(0),
      reason: 'the unsent facts must still republish',
    );
    expect(out['verifyFactsHlc'], isNull, reason: 'absent stays absent');
  });

  test('a row whose only unsent write is a user edit is restamped alone', () {
    final out = restamp(mediaRow(hlc: newest, upload: older));

    expect((out['hlc'] as String).compareTo(newest), greaterThan(0));
    expect(
      out['uploadFactsHlc'],
      older,
      reason:
          'a published fact keeps its clock, or it would fabricate freshness '
          'and beat a peer that really did write it',
    );
  });

  test('a published fact above the row clock keeps its clock', () {
    // The snapshot selects the row on ANY clock above the watermark, so a
    // row can arrive with a published upload fact that is newer than its
    // published row clock and only the verification unsent. Choosing by
    // "newer than the row" restamped that upload fact too, republishing a
    // fact the cloud has already resolved with a brand-new clock.
    final out = restamp(mediaRow(hlc: oldest, upload: older, verify: newest));

    expect(out['hlc'], oldest);
    expect(
      out['uploadFactsHlc'],
      older,
      reason: 'published, however it sorts against the row clock',
    );
    expect((out['verifyFactsHlc'] as String).compareTo(newest), greaterThan(0));
  });

  test('only the unpublished fact group is restamped', () {
    final out = restamp(mediaRow(hlc: older, upload: newest, verify: oldest));

    expect(out['hlc'], older);
    expect((out['uploadFactsHlc'] as String).compareTo(newest), greaterThan(0));
    expect(
      out['verifyFactsHlc'],
      oldest,
      reason: 'this device has no unsent verification fact to republish',
    );
  });

  test('a row with nothing unsent still republishes', () {
    // The export cannot select such a row, but a row that restamped no
    // clock at all would sort below the adopted watermark and be lost, so
    // the row clock is refreshed as a floor.
    final out = restamp(mediaRow(hlc: oldest, upload: older, verify: older));

    expect((out['hlc'] as String).compareTo(watermark), greaterThan(0));
    expect(out['uploadFactsHlc'], older);
    expect(out['verifyFactsHlc'], older);
  });

  test('an entity with no fact groups is restamped as before', () {
    final out = SyncService.restampRowForReplay('dives', {
      'id': 'd1',
      'hlc': older,
    }, publishedThrough: watermark);

    expect((out['hlc'] as String).compareTo(older), greaterThan(0));
  });

  test('a never-published device restamps everything', () {
    final out = SyncService.restampRowForReplay(
      'media',
      mediaRow(hlc: oldest, upload: older),
      publishedThrough: null,
    );

    expect((out['hlc'] as String).compareTo(newest), greaterThan(0));
    expect(
      (out['uploadFactsHlc'] as String).compareTo(newest),
      greaterThan(0),
      reason: 'with no watermark nothing was ever published',
    );
  });

  test('the replay does not re-stamp a fact-only row on the way out', () async {
    // restampRowForReplay chooses the clocks, but the replay then re-marks
    // every restored row pending to reopen the publish gate. A stamp there
    // put the row clock back up for a fact-only row and undid the choice.
    final cloud = FakeCloudStorageProvider();
    final folder = await cloud.getOrCreateSyncFolder();
    // A peer library must exist, or the fence re-establishes from local and
    // never reaches the rebuild-and-replay path this test is about.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'keep-1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1'); // resets the local DB afterwards
    final repo = MediaRepository();
    final db = DatabaseService.instance.database;

    final id = (await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: '/nowhere/reef.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    )).id;

    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);

    // The only local write since publishing is a fact write, so the row is
    // pending on its upload clock alone.
    await repo.stampRemoteUploaded(id, uploadedAt: DateTime(2026, 8, 1));
    Future<String?> rowClock() async =>
        (await db
                .customSelect(
                  'SELECT hlc FROM media WHERE id = ?',
                  variables: [Variable.withString(id)],
                )
                .getSingle())
            .read<String?>('hlc');
    final before = await rowClock();

    final deviceId = await SyncRepository().getDeviceId();
    await svc.deleteDeviceSyncFile(deviceId);
    await cloud.uploadFile(
      RetirementMarker(
        deviceId: deviceId,
        retiredAt: DateTime.now().millisecondsSinceEpoch,
      ).toBytes(),
      ChangesetLogLayout.retiredMarkerName(deviceId),
      folderId: folder,
    );

    expect((await svc.performSync()).status, SyncResultStatus.success);

    expect(
      await rowClock(),
      before,
      reason: 'a fact-only row must come through the replay unre-stamped',
    );
  });

  // A legacy row has no row clock, and a fact write leaves it that way, so
  // the replayed copy cannot be ordered against the adopted one. The merge
  // treats a copy with a missing clock as applicable, which let this
  // device's stale snapshot fields (the caption) overwrite the newer ones a
  // peer published, while only the fact was this device's to send.
  // The merge reads a blank clock as missing too, so both shapes of a
  // legacy row must take the same path.
  for (final (label, sqlClock) in [('no', 'NULL'), ('a blank', "''")]) {
    test('a legacy row with $label row clock replays only its facts over a '
        'newer caption', () async {
      final cloud = FakeCloudStorageProvider();
      final folder = await cloud.getOrCreateSyncFolder();
      final repo = MediaRepository();

      MediaItem photo(String caption) => MediaItem(
        id: 'm1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: '/nowhere/reef.jpg',
        caption: caption,
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

      // The peer's copy, with the newer caption.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'keep-1', diveNumber: 1),
      );
      await repo.createMedia(photo('new'));
      await seedPeerLog(cloud, 'peer-1'); // resets the local DB afterwards

      // This device's copy of the same row: legacy, so no row clock.
      await repo.createMedia(photo('old'));
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "UPDATE media SET hlc = $sqlClock WHERE id = 'm1'",
      );

      final svc = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);

      // The only local write since publishing is a fact write.
      await db.customStatement(
        "UPDATE media SET hlc = $sqlClock WHERE id = 'm1'",
      );
      await repo.stampRemoteUploaded('m1', uploadedAt: DateTime(2026, 8, 1));

      final deviceId = await SyncRepository().getDeviceId();
      await svc.deleteDeviceSyncFile(deviceId);
      await cloud.uploadFile(
        RetirementMarker(
          deviceId: deviceId,
          retiredAt: DateTime.now().millisecondsSinceEpoch,
        ).toBytes(),
        ChangesetLogLayout.retiredMarkerName(deviceId),
        folderId: folder,
      );

      expect((await svc.performSync()).status, SyncResultStatus.success);

      final after = (await repo.getMediaById('m1'))!;
      expect(after.caption, 'new', reason: 'the adopted caption stands');
      expect(
        after.remoteUploadedAt,
        isNotNull,
        reason: 'this device\'s unsent fact still lands',
      );
    });
  }
}
