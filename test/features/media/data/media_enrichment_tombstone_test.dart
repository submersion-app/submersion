import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

import '../../../helpers/test_database.dart';

/// A dive deletion destroys the enrichment of every photo on that dive,
/// including photos that survive because a site still shows them. The FK
/// cascade logs nothing, so peers used to re-add those rows on their next
/// publish (media sync program spec 5.3).
void main() {
  late AppDatabase db;
  final repo = MediaRepository();

  Future<List<String>> tombstonedEnrichment() async {
    final rows = await db
        .customSelect(
          'SELECT record_id FROM deletion_log '
          "WHERE entity_type = 'mediaEnrichment'",
        )
        .get();
    return [for (final r in rows) r.read<String>('record_id')];
  }

  Future<int> enrichmentRows() async =>
      (await db
              .customSelect('SELECT COUNT(*) AS c FROM media_enrichment')
              .getSingle())
          .read<int>('c');

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Reef', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO media (id, file_path, dive_id, site_id, created_at, '
      "updated_at) VALUES ('m1', '/x.jpg', 'd1', 's1', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, '
      "match_confidence, created_at) "
      "VALUES ('e1', 'm1', 'd1', 12.5, 'exact', 0)",
    );
    await SyncRepository().clearPendingRecords();
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test(
    'unlinking media from a deleted dive tombstones its enrichment',
    () async {
      await repo.unlinkMediaFromDeletedDives(['m1'], ['d1']);

      expect(await enrichmentRows(), 0, reason: 'the dive gave it its meaning');
      expect(await tombstonedEnrichment(), ['e1']);
    },
  );

  test('the media row itself survives, unlinked and published', () async {
    await repo.unlinkMediaFromDeletedDives(['m1'], ['d1']);

    final row = (await repo.getMediaById('m1'))!;
    expect(row.diveId, isNull);
    expect(row.siteId, 's1');
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.map((r) => (r.entityType, r.recordId)),
      contains(('media', 'm1')),
    );
  });

  test('a row relinked to a surviving dive is left alone', () async {
    // The partition chose m1 before the caller did its other deletion work,
    // and the row moved to another dive in between. Keyed on the media id
    // alone this cleared that new link and deleted the enrichment the row
    // gained with it.
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d2', 0, 0, 0)",
    );
    await db.customStatement("UPDATE media SET dive_id = 'd2' WHERE id = 'm1'");
    await db.customStatement(
      "UPDATE media_enrichment SET dive_id = 'd2' WHERE id = 'e1'",
    );

    await repo.unlinkMediaFromDeletedDives(['m1'], ['d1']);

    expect((await repo.getMediaById('m1'))!.diveId, 'd2');
    expect(await enrichmentRows(), 1, reason: 'it belongs to the new dive');
    expect(await tombstonedEnrichment(), isEmpty);
  });

  test('a media row with no enrichment is unaffected', () async {
    await db.customStatement(
      'INSERT INTO media (id, file_path, dive_id, site_id, created_at, '
      "updated_at) VALUES ('m2', '/y.jpg', 'd1', 's1', 0, 0)",
    );

    await repo.unlinkMediaFromDeletedDives(['m1', 'm2'], ['d1']);

    expect(await tombstonedEnrichment(), ['e1']);
  });
}
