import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Through the real merge: a peer's newer facts land on an older row, a
/// cleared stamp lands as null, and a stamp never carries a stale caption.
void main() {
  late AppDatabase db;

  SyncPayload payloadWith(List<Map<String, dynamic>> media) => SyncPayload(
    version: 1,
    exportedAt: 0,
    deviceId: 'peer',
    checksum: '',
    data: SyncData(media: media),
    deletions: const {},
  );

  Future<void> apply(Map<String, dynamic> row) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
  ).debugApplyPayload(payloadWith([row]));

  Future<Map<String, Object?>> read() async =>
      (await db
              .customSelect(
                'SELECT caption, remote_uploaded_at, content_hash, is_orphaned, '
                'upload_facts_hlc FROM media WHERE id = ?',
                variables: [Variable.withString('m1')],
              )
              .getSingle())
          .data;

  Future<Map<String, dynamic>> local() async =>
      (await SyncDataSerializer().fetchRecord('media', 'm1'))!;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 0,
      alsoStamp: SyncFactGroups.of('media'),
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('newer facts land while an older row keeps the local caption', () async {
    final stale = await local(); // the peer's snapshot of the row
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.customStatement(
      "UPDATE media SET caption = 'mine' WHERE id = 'm1'",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 1,
    );

    await apply({
      ...stale,
      'caption': 'stale',
      'contentHash': 'h',
      'contentSizeBytes': 10,
      'remoteUploadedAt': 99,
      'uploadFactsHlc': SyncClock.instance.issue(),
    });

    final r = await read();
    expect(r['caption'], 'mine');
    expect(r['remote_uploaded_at'], 99);
    expect(r['content_hash'], 'h');
  });

  test(
    'a newer clear lands as null even though the upsert drops nulls',
    () async {
      await db.customStatement(
        "UPDATE media SET content_hash = 'h', remote_uploaded_at = 50 "
        "WHERE id = 'm1'",
      );
      await SyncRepository().markFactsPending(
        entityType: 'media',
        recordId: 'm1',
        localUpdatedAt: 1,
        group: SyncFactGroups.mediaUpload,
      );
      final l = await local();

      await apply({
        ...l,
        'remoteUploadedAt': null,
        'uploadFactsHlc': SyncClock.instance.issue(),
      });

      expect((await read())['remote_uploaded_at'], isNull);
    },
  );

  test('older facts do not overwrite newer local ones', () async {
    final stale = await local();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.customStatement(
      "UPDATE media SET remote_uploaded_at = 50 WHERE id = 'm1'",
    );
    await SyncRepository().markFactsPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload,
    );

    await apply({...stale, 'remoteUploadedAt': null});

    expect((await read())['remote_uploaded_at'], 50);
  });

  test(
    'a newer row keeps local facts that are newer than the peer\'s',
    () async {
      await db.customStatement(
        "UPDATE media SET remote_uploaded_at = 50 WHERE id = 'm1'",
      );
      await SyncRepository().markFactsPending(
        entityType: 'media',
        recordId: 'm1',
        localUpdatedAt: 1,
        group: SyncFactGroups.mediaUpload,
      );
      final l = await local();
      final olderFacts = (await local())['verifyFactsHlc'];

      // The peer edited the caption later, but its upload facts are the old
      // ones from before this device's upload.
      await apply({
        ...l,
        'caption': 'theirs',
        'hlc': SyncClock.instance.issue(),
        'remoteUploadedAt': null,
        'uploadFactsHlc': olderFacts,
      });

      final r = await read();
      expect(r['caption'], 'theirs');
      expect(r['remote_uploaded_at'], 50, reason: 'our upload is newer');
    },
  );
}
