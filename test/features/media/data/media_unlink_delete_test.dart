import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    hide MediaEnrichment;
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain
    show MediaEnrichment;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Unlinking media from a dive removes it from the library entirely: the row,
/// the cloud proxies and the thumbnails all go, and a sync tombstone carries
/// the removal to the user's other devices. The ORIGINAL source file is never
/// touched -- only artifacts Submersion derived from it.
///
/// The one exception is media that is also attached to a dive site. That keeps
/// today's behaviour (clear the dive link, stay in the library), matching the
/// dive-deletion cascade, so a dive-scoped action can never destroy a site's
/// only photo as a side effect.
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  final epoch = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

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

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: 'Blue Hole',
          createdAt: epoch,
          updatedAt: epoch,
        ),
      );

  MediaItem item(
    String id, {
    String? diveId,
    String? siteId,
    String? caption,
    bool isFavorite = false,
  }) => MediaItem(
    id: id,
    diveId: diveId,
    siteId: siteId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/photos/$id.jpg',
    localPath: '/photos/$id.jpg',
    caption: caption,
    isFavorite: isFavorite,
    takenAt: DateTime.utc(2026, 6, 1, 12),
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
  );

  /// The service under test, with the destructive call recorded rather than
  /// performed: the real one routes to MediaDeletionCoordinator, whose queue
  /// lives in a separate cache database that this suite does not stand up.
  ({MediaUnlinkService service, List<String> deleted}) buildService() {
    final deleted = <String>[];
    return (
      service: MediaUnlinkService(
        repository: repo,
        deleteMedia: (ids) async {
          deleted.addAll(ids);
          // Mirror what the coordinator ultimately does to the rows, so the
          // assertions below see the same end state production reaches.
          await repo.deleteMultipleMedia(ids);
        },
      ),
      deleted: deleted,
    );
  }

  test('a dive-only photo is deleted from the library', () async {
    await insertDive('d1');
    final m = await repo.createMedia(item('m1', diveId: 'd1'));
    final built = buildService();

    final outcome = await built.service.unlinkFromDive([m.id]);

    expect(built.deleted, [m.id]);
    expect(await repo.getMediaById(m.id), isNull);
    expect(outcome.deleted, 1);
    expect(outcome.keptAsSiteMedia, 0);
  });

  test(
    'a site-linked photo survives with only the dive link cleared',
    () async {
      await insertDive('d1');
      await insertSite('s1');
      final m = await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));
      final built = buildService();

      final outcome = await built.service.unlinkFromDive([m.id]);

      expect(built.deleted, isEmpty, reason: 'a site still needs this photo');
      final kept = await repo.getMediaById(m.id);
      expect(kept, isNotNull);
      expect(kept!.diveId, isNull);
      expect(kept.siteId, 's1');
      expect(outcome.deleted, 0);
      expect(outcome.keptAsSiteMedia, 1);
    },
  );

  test('a mixed selection deletes only the media no site needs', () async {
    await insertDive('d1');
    await insertSite('s1');
    final plain = await repo.createMedia(item('m1', diveId: 'd1'));
    final onSite = await repo.createMedia(
      item('m2', diveId: 'd1', siteId: 's1'),
    );
    final built = buildService();

    final outcome = await built.service.unlinkFromDive([plain.id, onSite.id]);

    expect(built.deleted, [plain.id]);
    expect(await repo.getMediaById(plain.id), isNull);
    expect((await repo.getMediaById(onSite.id))!.siteId, 's1');
    expect(outcome.deleted, 1);
    expect(outcome.keptAsSiteMedia, 1);
  });

  // An enrichment is the join product of the media and ONE dive's profile.
  // Clearing the dive link without dropping it left the photo showing depth
  // and elapsed time from a dive it is no longer part of.
  test(
    'the kept photo loses the enrichment computed against the old dive',
    () async {
      await insertDive('d1');
      await insertSite('s1');
      final m = await repo.createMedia(item('m1', diveId: 'd1', siteId: 's1'));
      await repo.saveEnrichment(
        domain.MediaEnrichment(
          id: 'e1',
          mediaId: m.id,
          diveId: 'd1',
          elapsedSeconds: 2520,
          depthMeters: 20,
          matchConfidence: MatchConfidence.exact,
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      );
      final built = buildService();

      await built.service.unlinkFromDive([m.id]);

      expect((await repo.getMediaById(m.id))!.enrichment, isNull);

      final tombstones = await db
          .customSelect(
            "SELECT record_id FROM deletion_log "
            "WHERE entity_type = 'mediaEnrichment'",
          )
          .get();
      expect(
        tombstones.map((r) => r.read<String>('record_id')),
        contains('e1'),
        reason: 'mediaEnrichment is HLC-synced, so the drop must travel',
      );
    },
  );

  // Every other path that invalidates an enrichment tombstones it. Deletion
  // left that to the FK cascade, which removes the row but logs nothing, so
  // the one case that destroys the most data was the one case that told peers
  // the least. A peer's live child is already skipped on merge (the
  // mediaEnrichment parentRefs are nullable: false), so this is about not
  // depending on that interplay, and on the cascade being enabled at all.
  test(
    'deleting media tombstones its enrichment, not just the media',
    () async {
      await insertDive('d1');
      final m = await repo.createMedia(item('m1', diveId: 'd1'));
      await repo.saveEnrichment(
        domain.MediaEnrichment(
          id: 'e1',
          mediaId: m.id,
          diveId: 'd1',
          elapsedSeconds: 2520,
          depthMeters: 20,
          matchConfidence: MatchConfidence.exact,
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      );

      await repo.deleteMultipleMedia([m.id]);

      final tombstoned = await db
          .customSelect(
            "SELECT entity_type, record_id FROM deletion_log "
            "WHERE record_id IN ('m1', 'e1')",
          )
          .get();
      final pairs = {
        for (final r in tombstoned)
          '${r.read<String>('entity_type')}:${r.read<String>('record_id')}',
      };
      expect(pairs, containsAll(<String>['media:m1', 'mediaEnrichment:e1']));
    },
  );

  test('an empty selection is a no-op', () async {
    final built = buildService();
    final outcome = await built.service.unlinkFromDive(const []);
    expect(built.deleted, isEmpty);
    expect(outcome.deleted, 0);
    expect(outcome.keptAsSiteMedia, 0);
  });

  group('user metadata probe', () {
    test('reports only the rows carrying a caption or a favorite', () async {
      await insertDive('d1');
      final plain = await repo.createMedia(item('m1', diveId: 'd1'));
      final captioned = await repo.createMedia(
        item('m2', diveId: 'd1', caption: 'Grey reef shark on the wall'),
      );
      final favorite = await repo.createMedia(
        item('m3', diveId: 'd1', isFavorite: true),
      );

      final withData = await repo.idsWithUserMetadata([
        plain.id,
        captioned.id,
        favorite.id,
      ]);

      expect(withData, {captioned.id, favorite.id});
    });

    test('treats an empty caption as nothing to lose', () async {
      await insertDive('d1');
      final blank = await repo.createMedia(
        item('m1', diveId: 'd1', caption: ''),
      );

      expect(await repo.idsWithUserMetadata([blank.id]), isEmpty);
    });

    test('an empty id list asks the database nothing', () async {
      expect(await repo.idsWithUserMetadata(const []), isEmpty);
    });

    // Warning about a caption on media the unlink is going to KEEP would be
    // a lie: a site-linked row survives, so its caption survives with it.
    test('ignores metadata on media the unlink would keep', () async {
      await insertDive('d1');
      await insertSite('s1');
      final kept = await repo.createMedia(
        item('m1', diveId: 'd1', siteId: 's1', caption: 'Stays put'),
      );
      final built = buildService();

      expect(await built.service.idsWithUserMetadataAtRisk([kept.id]), isEmpty);
    });

    test('reports metadata on media the unlink would delete', () async {
      await insertDive('d1');
      final doomed = await repo.createMedia(
        item('m1', diveId: 'd1', caption: 'Goes away'),
      );
      final built = buildService();

      expect(await built.service.idsWithUserMetadataAtRisk([doomed.id]), {
        doomed.id,
      });
    });
  });

  group('unlinkFromSite', () {
    test('a site-only photo is deleted from the library', () async {
      await insertSite('s1');
      final m = await repo.createMedia(item('m1', siteId: 's1'));
      final built = buildService();

      final outcome = await built.service.unlinkFromSite([m.id]);

      expect(built.deleted, [m.id]);
      expect(await repo.getMediaById(m.id), isNull);
      expect(outcome.deleted, 1);
      expect(outcome.keptAsDiveMedia, 0);
    });

    test(
      'a dive-linked photo survives with only the site link cleared',
      () async {
        await insertDive('d1');
        await insertSite('s1');
        final m = await repo.createMedia(
          item('m1', diveId: 'd1', siteId: 's1'),
        );
        final built = buildService();

        final outcome = await built.service.unlinkFromSite([m.id]);

        expect(built.deleted, isEmpty, reason: 'a dive still needs this photo');
        final kept = await repo.getMediaById(m.id);
        expect(kept!.siteId, isNull);
        expect(kept.diveId, 'd1');
        expect(outcome.deleted, 0);
        expect(outcome.keptAsDiveMedia, 1);
        expect(outcome.total, 1);
      },
    );

    test(
      'metadata at risk is scoped to the rows the site unlink deletes',
      () async {
        await insertDive('d1');
        await insertSite('s1');
        final kept = await repo.createMedia(
          item('kept', diveId: 'd1', siteId: 's1', caption: 'stays'),
        );
        final gone = await repo.createMedia(
          item('gone', siteId: 's1', isFavorite: true),
        );
        final built = buildService();

        final atRisk = await built.service.idsWithUserMetadataAtRiskForSite([
          kept.id,
          gone.id,
        ]);

        expect(atRisk, {gone.id});
      },
    );

    test('an empty list is a no-op', () async {
      final built = buildService();
      final outcome = await built.service.unlinkFromSite(const []);
      expect(outcome.deleted, 0);
      expect(outcome.keptAsDiveMedia, 0);
      expect(built.deleted, isEmpty);
    });
  });
}
