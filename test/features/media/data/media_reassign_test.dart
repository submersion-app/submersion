import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    hide MediaEnrichment;
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain
    show MediaEnrichment;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(String id, {String? diveId}) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  test(
    'reassign moves the FK and deletes stale enrichment with a tombstone',
    () async {
      await insertDive('d1');
      await insertDive('d2');
      final m = await repo.createMedia(item('m1', diveId: 'd1'));
      await repo.saveEnrichment(
        domain.MediaEnrichment(
          id: 'e1',
          mediaId: m.id,
          diveId: 'd1',
          depthMeters: 10,
          matchConfidence: MatchConfidence.exact,
          createdAt: DateTime(2026, 6, 1),
        ),
      );

      await repo.reassignMediaToDive([m.id], 'd2');

      final moved = await repo.getMediaById(m.id);
      expect(moved!.diveId, 'd2');
      expect(moved.enrichment, isNull);

      final tombstones = await db
          .customSelect(
            "SELECT record_id FROM deletion_log "
            "WHERE entity_type = 'mediaEnrichment'",
          )
          .get();
      expect(
        tombstones.map((r) => r.read<String>('record_id')),
        contains('e1'),
      );
    },
  );

  test('reassign of an unlinked row is a plain link', () async {
    await insertDive('d2');
    final m = await repo.createMedia(item('m1'));
    await repo.reassignMediaToDive([m.id], 'd2');
    expect((await repo.getMediaById(m.id))!.diveId, 'd2');
  });

  test('empty id list is a no-op', () async {
    await repo.reassignMediaToDive(const [], 'd2');
  });
}
