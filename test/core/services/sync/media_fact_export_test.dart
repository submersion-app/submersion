import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

/// A fact write stamps its group clock and leaves the row clock alone, so
/// the incremental export must select on fact clocks too, and the watermark
/// must rise past them or the row would be re-sent on every publish.
void main() {
  late String rowHlc;

  Future<SyncPayload> changesetSince(String watermark) =>
      SyncDataSerializer().exportChangeset(
        deviceId: 'me',
        hlcWatermark: watermark,
        deletions: const [],
      );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 0,
    );
    rowHlc =
        (await SyncDataSerializer().fetchRecord('media', 'm1'))!['hlc']
            as String;
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('a fact-only change past the watermark is exported', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload,
    );
    final payload = await changesetSince(rowHlc);
    expect(payload.data.media.map((r) => r['id']), ['m1']);
  });

  test('the watermark rises to the fact clock', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 1,
      group: SyncFactGroups.mediaVerification,
    );
    final verify =
        (await SyncDataSerializer().fetchRecord(
              'media',
              'm1',
            ))!['verifyFactsHlc']
            as String;
    final payload = await changesetSince(rowHlc);
    expect(
      payload.toHlc,
      verify,
      reason: 'else the row is re-exported on every publish',
    );
  });

  test('a row with no change past the watermark is not exported', () async {
    final payload = await changesetSince(rowHlc);
    expect(payload.data.media, isEmpty);
  });
}
