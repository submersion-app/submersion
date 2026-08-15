import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  group('getPendingCount', () {
    test('counts only rows whose sync_status is pending', () async {
      final db = DatabaseService.instance.database;
      Future<void> seed(String id, String status) => db.customStatement(
        'INSERT INTO sync_records (id, entity_type, record_id, '
        'local_updated_at, sync_status, created_at, updated_at) '
        "VALUES ('$id', 'dives', '$id', 1000, '$status', 1000, 1000)",
      );
      await seed('a', 'pending');
      await seed('b', 'pending');
      await seed('c', 'synced');
      await seed('d', 'conflict');

      expect(await SyncRepository().getPendingCount(), 2);
    });

    test('is zero on an empty log', () async {
      expect(await SyncRepository().getPendingCount(), 0);
    });
  });

  group('getUnpublishedDeletionCount', () {
    // A tombstone is not cleared when it is published -- it lives on until the
    // fleet-acked GC removes it (clearAcknowledgedDeletions). Counting the
    // whole deletion log as "pending" would therefore pin the UI to "unsynced"
    // forever. The publish watermark is what separates the two.
    Future<void> seed(String id, String? hlc) =>
        DatabaseService.instance.database.customStatement(
          'INSERT INTO deletion_log '
          '(id, entity_type, record_id, deleted_at, hlc) '
          "VALUES ('$id', 'dives', '$id', 1000, "
          "${hlc == null ? 'NULL' : "'$hlc'"})",
        );

    test('counts every tombstone when nothing has been published', () async {
      await seed('a', '00000000000010:000000:x');
      await seed('b', '00000000000020:000000:x');

      expect(
        await SyncRepository().getUnpublishedDeletionCount(upToHlc: null),
        2,
      );
    });

    test('counts only tombstones above the publish watermark', () async {
      await seed('published', '00000000000010:000000:x');
      await seed('at-watermark', '00000000000020:000000:x');
      await seed('unpublished', '00000000000030:000000:x');

      expect(
        await SyncRepository().getUnpublishedDeletionCount(
          upToHlc: '00000000000020:000000:x',
        ),
        1,
      );
    });

    test('counts null-hlc tombstones regardless of the watermark', () async {
      // A null hlc cannot be compared, so the serializer includes it in every
      // base; it is genuinely unpublished until a base goes out.
      await seed('published', '00000000000010:000000:x');
      await seed('legacy', null);

      expect(
        await SyncRepository().getUnpublishedDeletionCount(
          upToHlc: '00000000000020:000000:x',
        ),
        1,
      );
    });

    test('is zero when every tombstone is at or below the watermark', () async {
      await seed('a', '00000000000010:000000:x');
      await seed('b', '00000000000020:000000:x');

      expect(
        await SyncRepository().getUnpublishedDeletionCount(
          upToHlc: '00000000000020:000000:x',
        ),
        0,
      );
    });
  });

  group('getUnsyncedChangeCount', () {
    // Through the real API rather than raw SQL: this is the exact call every
    // dive/site/gear write makes, so the count is proven against the shape
    // production actually writes.
    Future<void> seedPending(String id) => SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: 1000,
    );
    Future<void> seedTombstone(String id, String hlc) =>
        DatabaseService.instance.database.customStatement(
          'INSERT INTO deletion_log '
          '(id, entity_type, record_id, deleted_at, hlc) '
          "VALUES ('$id', 'dives', '$id', 1000, '$hlc')",
        );
    Future<void> seedWatermark(String provider, String hlc) =>
        DatabaseService.instance.database.customStatement(
          'INSERT INTO local_publish_states '
          '(provider, head_seq, published_hlc_high, '
          'changeset_bytes_since_base, updated_at) '
          "VALUES ('$provider', 1, '$hlc', 0, 1000)",
        );

    test('sums pending records and unpublished deletions', () async {
      await seedPending('p1');
      await seedPending('p2');
      await seedTombstone('published', '00000000000010:000000:x');
      await seedTombstone('unpublished', '00000000000030:000000:x');
      await seedWatermark('icloud', '00000000000020:000000:x');

      expect(
        await SyncRepository().getUnsyncedChangeCount(providerId: 'icloud'),
        3,
      );
    });

    test('a delete-only change set is not reported as zero', () async {
      // The bug behind #990: deletions never touch sync_records, so a pure
      // delete used to leave the UI claiming "Synced".
      await seedTombstone('gone', '00000000000030:000000:x');
      await seedWatermark('icloud', '00000000000020:000000:x');

      expect(
        await SyncRepository().getUnsyncedChangeCount(providerId: 'icloud'),
        1,
      );
    });

    test('reads the watermark of the named provider only', () async {
      // Per-provider watermarks: a backend switch must not import the old
      // backend's published position.
      await seedTombstone('t', '00000000000030:000000:x');
      await seedWatermark('icloud', '00000000000040:000000:x');
      await seedWatermark('dropbox', '00000000000010:000000:x');

      final repo = SyncRepository();
      expect(await repo.getUnsyncedChangeCount(providerId: 'icloud'), 0);
      expect(await repo.getUnsyncedChangeCount(providerId: 'dropbox'), 1);
    });

    test('is zero with a clean log', () async {
      await seedWatermark('icloud', '00000000000020:000000:x');
      expect(
        await SyncRepository().getUnsyncedChangeCount(providerId: 'icloud'),
        0,
      );
    });
  });
}
