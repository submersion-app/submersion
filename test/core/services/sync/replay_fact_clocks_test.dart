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
  /// letter stand-in would compare the wrong way round.
  late String earlier;
  late String later;

  setUp(() {
    earlier = SyncClock.instance.issue()!;
    later = SyncClock.instance.issue()!;
    expect(later.compareTo(earlier), greaterThan(0));
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

  test('a fact-only pending row keeps its row clock', () {
    final row = mediaRow(hlc: earlier, upload: later);
    final out = SyncService.restampRowForReplay('media', row);

    expect(
      out['hlc'],
      earlier,
      reason: 'the last local write was a fact write',
    );
    expect(
      (out['uploadFactsHlc'] as String).compareTo(later),
      greaterThan(0),
      reason: 'the facts must still republish',
    );
    expect(out['verifyFactsHlc'], isNull, reason: 'absent stays absent');
  });

  test('a row whose last write was a user edit is restamped alone', () {
    final row = mediaRow(hlc: later, upload: earlier);
    final out = SyncService.restampRowForReplay('media', row);

    expect((out['hlc'] as String).compareTo(later), greaterThan(0));
    expect(
      out['uploadFactsHlc'],
      earlier,
      reason:
          'an older fact keeps its clock, or it would fabricate freshness '
          'and beat a peer that really did write it',
    );
  });

  test('only the fact group that is newer than the row is restamped', () {
    final row = mediaRow(hlc: earlier, upload: later, verify: earlier);
    final out = SyncService.restampRowForReplay('media', row);

    expect(out['hlc'], earlier, reason: 'the row clock is not the newest');
    expect((out['uploadFactsHlc'] as String).compareTo(later), greaterThan(0));
    expect(
      out['verifyFactsHlc'],
      earlier,
      reason: 'this device wrote no verification fact to republish',
    );
  });

  test('an entity with no fact groups is restamped as before', () {
    final out = SyncService.restampRowForReplay('dives', {
      'id': 'd1',
      'hlc': earlier,
    });

    expect((out['hlc'] as String).compareTo(earlier), greaterThan(0));
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
}
