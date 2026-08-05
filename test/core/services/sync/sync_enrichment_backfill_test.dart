import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Pre-v130 media_enrichment rows have hlc = NULL and are invisible to the
/// incremental export. The backfill stamps a fresh HLC so they replicate.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  // A dive + media so the enrichment row's FKs resolve, then an enrichment row
  // with NO hlc, exactly as a pre-v130 build wrote it.
  Future<void> seedLegacyEnrichment(String enrichmentId) async {
    final db = DatabaseService.instance.database;
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await SyncDataSerializer().upsertRecord('media', {
      'id': 'm1',
      'diveId': 'd1',
      'filePath': '/p.jpg',
      'fileType': 'photo',
      'sourceType': 'platformGallery',
      'isFavorite': false,
      'isOrphaned': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await db.customStatement(
      "INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, "
      "match_confidence, created_at) "
      "VALUES ('$enrichmentId', 'm1', 'd1', 12.5, 'exact', 1000)",
    );
  }

  test(
    'stamps hlc + a pending sync record on null-hlc enrichment rows',
    () async {
      final db = DatabaseService.instance.database;
      await seedLegacyEnrichment('e1');

      await SyncRepository().backfillMediaEnrichmentHlc();

      final row = await (db.select(
        db.mediaEnrichment,
      )..where((t) => t.id.equals('e1'))).getSingle();
      expect(row.hlc, isNotNull);

      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.entityType.equals('mediaEnrichment'))).get();
      expect(pending.map((r) => r.recordId), contains('e1'));
    },
  );

  test('is a no-op the second time (self-limiting)', () async {
    final db = DatabaseService.instance.database;
    await seedLegacyEnrichment('e1');

    await SyncRepository().backfillMediaEnrichmentHlc();
    final first = (await (db.select(
      db.mediaEnrichment,
    )..where((t) => t.id.equals('e1'))).getSingle()).hlc;
    await SyncRepository().backfillMediaEnrichmentHlc();
    final second = (await (db.select(
      db.mediaEnrichment,
    )..where((t) => t.id.equals('e1'))).getSingle()).hlc;

    expect(second, first, reason: 'row already had an hlc; not re-stamped');
  });
}
