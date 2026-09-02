import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
// Shares the `domain` prefix with the media entity below: Drift generates its
// own `Dive` into database.dart, so the entity has to be qualified.
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/dive_media_enricher.dart';
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

  MediaItem item(String id, {String? diveId, DateTime? takenAt}) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$id',
    localPath: '/tmp/$id',
    takenAt: takenAt ?? DateTime(2026, 6, 1),
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

  // The deletion above is only half of reassignMediaToDive's contract: its doc
  // comment promises the rows are "recomputed lazily by DiveMediaEnricher the
  // next time the new dive's media renders". Nothing pinned that half, and the
  // recompute had exactly one trigger (the dive detail page) -- so a photo
  // re-linked from the Media section stayed stripped of its depth, elapsed
  // time and profile marker for as long as the user never opened the new
  // dive's detail page.
  test(
    'the enrichment a reassign deletes is recomputed against the new dive',
    () async {
      await insertDive('d1');
      await insertDive('d2');
      // Both timestamps are wall-clock-as-UTC, the convention taken_at and
      // entry_time are stored and hydrated under. Building either as a local
      // DateTime here would encode the offset into elapsedSeconds and make
      // the assertion pass or fail with the host timezone.
      // Shutter at 12:08, 42 minutes after the d2 entry time below.
      final m = await repo.createMedia(
        item('m1', diveId: 'd1', takenAt: DateTime.utc(2026, 6, 1, 12, 8)),
      );
      await repo.saveEnrichment(
        domain.MediaEnrichment(
          id: 'e1',
          mediaId: m.id,
          diveId: 'd1',
          elapsedSeconds: 999,
          depthMeters: 10,
          matchConfidence: MatchConfidence.exact,
          createdAt: DateTime(2026, 6, 1),
        ),
      );

      await repo.reassignMediaToDive([m.id], 'd2');
      expect((await repo.getMediaById(m.id))!.enrichment, isNull);

      final enricher = DiveMediaEnricher(
        loadDive: (id) async => domain.Dive(
          id: id,
          dateTime: DateTime.utc(2026, 6, 1, 11, 26),
          entryTime: DateTime.utc(2026, 6, 1, 11, 26),
          profile: const [
            domain.DiveProfilePoint(timestamp: 0, depth: 0),
            domain.DiveProfilePoint(timestamp: 2520, depth: 20),
            domain.DiveProfilePoint(timestamp: 2580, depth: 5),
          ],
        ),
        loadMediaForDive: repo.getMediaForDive,
        saveEnrichments: repo.saveEnrichments,
      );

      expect(await enricher.enrichMissingForDive('d2'), 1);

      final restored = (await repo.getMediaById(m.id))!.enrichment;
      expect(restored, isNotNull);
      expect(restored!.diveId, 'd2', reason: 'recomputed against the new dive');
      expect(restored.elapsedSeconds, 2520);
      expect(restored.depthMeters, 20.0);
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
