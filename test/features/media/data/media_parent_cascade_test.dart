import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/features/media/data/repositories/media_parent_cascade.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// A deletion that removes several kinds of parent at once (a diver takes
/// their dives, sites, gear and buddies) has to classify each media row
/// against every dying set together. The single-entity partitions cannot be
/// composed: each keeps a row another dying parent still links.
void main() {
  late AppDatabase db;
  const t = 1000;

  const dying = DyingMediaParents(
    diveIds: {'d-dying'},
    siteIds: {'s-dying'},
    equipmentIds: {'g-dying'},
    buddyIds: {'b-dying'},
  );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['d-dying', 'd-kept']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final id in ['s-dying', 's-kept']) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final id in ['g-dying', 'g-kept']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final id in ['b-dying', 'b-kept']) {
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> photo({
    String? dive,
    String? site,
    String? gear,
    String? signer,
  }) async => (await MediaRepository().createMedia(
    MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: p.join('photos', 'p.jpg'),
      originalFilename: 'p.jpg',
      diveId: dive,
      siteId: site,
      equipmentId: gear,
      signerId: signer,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  )).id;

  Future<void> enrich(String id, String mediaId, String diveId) => db
      .into(db.mediaEnrichment)
      .insert(
        MediaEnrichmentCompanion.insert(
          id: id,
          mediaId: mediaId,
          diveId: diveId,
          createdAt: t,
        ),
      );

  Future<MediaData> row(String id) =>
      (db.select(db.media)..where((m) => m.id.equals(id))).getSingle();

  Future<bool> isPending(String id) async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == 'media' && r.recordId == id,
      );

  group('planMediaCascade', () {
    test('a row whose every link is dying is doomed', () async {
      final onlyDive = await photo(dive: 'd-dying');
      final diveAndSite = await photo(dive: 'd-dying', site: 's-dying');

      final plan = await planMediaCascade(db, dying);

      expect(
        plan.doomed.map((m) => m.id),
        unorderedEquals([onlyDive, diveAndSite]),
        reason: 'both parents of the second row die, so nothing keeps it',
      );
      expect(plan.survivors, isEmpty);
    });

    test(
      'a row a surviving parent links is kept, naming only its dying links',
      () async {
        final keptBySite = await photo(dive: 'd-dying', site: 's-kept');
        final keptByDive = await photo(dive: 'd-kept', gear: 'g-dying');

        final plan = await planMediaCascade(db, dying);

        expect(plan.doomed, isEmpty);
        final byId = {for (final s in plan.survivors) s.id: s};
        expect(byId[keptBySite]!.diveId, 'd-dying');
        expect(byId[keptBySite]!.siteId, isNull, reason: 'the site survives');
        expect(byId[keptByDive]!.equipmentId, 'g-dying');
        expect(byId[keptByDive]!.diveId, isNull, reason: 'the dive survives');
      },
    );

    test('paperwork only dying gear holds is doomed with it', () async {
      final invoice = await photo(gear: 'g-dying');
      final keptByGear = await photo(site: 's-dying', gear: 'g-kept');

      final plan = await planMediaCascade(db, dying);

      expect(plan.doomed.single.id, invoice);
      expect(
        plan.survivors.single.id,
        keptByGear,
        reason: 'surviving gear keeps a row whose site dies',
      );
    });

    test('a dying signer never dooms a row on its own', () async {
      // A signer is not a logbook link: it names who signed, not where the
      // signature belongs.
      final signed = await photo(dive: 'd-kept', signer: 'b-dying');

      final plan = await planMediaCascade(db, dying);

      expect(plan.doomed, isEmpty);
      expect(plan.survivors.single.id, signed);
      expect(plan.survivors.single.signerId, 'b-dying');
    });

    test('a row linked to no dying parent is left out', () async {
      await photo(dive: 'd-kept', site: 's-kept', signer: 'b-kept');

      final plan = await planMediaCascade(db, dying);

      expect(plan.doomed, isEmpty);
      expect(plan.survivors, isEmpty);
    });

    test('names the enrichment of the dying dives only', () async {
      final a = await photo(dive: 'd-dying', site: 's-kept');
      final b = await photo(dive: 'd-kept');
      await enrich('e-dying', a, 'd-dying');
      await enrich('e-kept', b, 'd-kept');

      final plan = await planMediaCascade(db, dying);

      expect(plan.enrichmentIds, ['e-dying']);
    });

    test(
      'a dying set past the bind-variable limit is read in chunks',
      () async {
        // The bundled SQLite binds at most 32766 variables in one statement,
        // and a diver's whole library arrives as one set. Past that limit, one
        // list per query fails before the delete even starts.
        final id = await photo(dive: 'd-dying');
        final many = {'d-dying', for (var i = 0; i < 33000; i++) 'absent-$i'};

        final plan = await planMediaCascade(
          db,
          DyingMediaParents(diveIds: many),
        );

        expect(plan.doomed.single.id, id);
      },
    );

    test('no dying parents plans nothing', () async {
      await photo(dive: 'd-dying');

      final plan = await planMediaCascade(db, const DyingMediaParents());

      expect(plan.doomed, isEmpty);
      expect(plan.survivors, isEmpty);
      expect(plan.enrichmentIds, isEmpty);
    });
  });

  group('recheckDoomed', () {
    // The plan is applied after the delete commits, and a row can be
    // relinked in between (a sync pull, say). Deleting by the planned id
    // alone would destroy it, uploaded copy included.
    test('a doomed row relinked to a surviving parent is spared', () async {
      final id = await photo(dive: 'd-dying');
      final plan = await planMediaCascade(db, dying);
      await db.customStatement(
        "UPDATE media SET dive_id = 'd-kept' WHERE id = ?",
        [id],
      );

      expect(await recheckDoomed(db, plan), isEmpty);
    });

    test('a doomed row the delete detached is still doomed', () async {
      final id = await photo(dive: 'd-dying', site: 's-dying');
      final plan = await planMediaCascade(db, dying);
      // What ON DELETE SET NULL leaves once both parents are gone.
      await db.customStatement(
        'UPDATE media SET dive_id = NULL, site_id = NULL WHERE id = ?',
        [id],
      );

      expect((await recheckDoomed(db, plan)).map((m) => m.id), [id]);
    });

    test(
      'a doomed row still naming its dying parents is still doomed',
      () async {
        final id = await photo(dive: 'd-dying');
        final plan = await planMediaCascade(db, dying);

        expect((await recheckDoomed(db, plan)).map((m) => m.id), [id]);
      },
    );

    test('a doomed row deleted since the plan is dropped', () async {
      final id = await photo(dive: 'd-dying');
      final plan = await planMediaCascade(db, dying);
      await db.customStatement('DELETE FROM media WHERE id = ?', [id]);

      expect(await recheckDoomed(db, plan), isEmpty);
    });
  });

  group('unlinkMediaFromDeletedParents', () {
    test(
      'clears the dying links, keeps the rest, stamps and marks pending',
      () async {
        final id = await photo(
          dive: 'd-dying',
          site: 's-kept',
          signer: 'b-dying',
        );
        await db.customStatement(
          'UPDATE media SET updated_at = 1 WHERE id = ?',
          [id],
        );
        await SyncRepository().clearPendingRecords();

        await unlinkMediaFromDeletedParents(db, SyncRepository(), [
          MediaSurvivor(id, diveId: 'd-dying', signerId: 'b-dying'),
        ]);

        final after = await row(id);
        expect(after.diveId, isNull);
        expect(after.signerId, isNull);
        expect(after.siteId, 's-kept');
        expect(after.updatedAt, greaterThan(1));
        expect(await isPending(id), isTrue);
      },
    );

    test('a link that moved since the plan is kept', () async {
      // The plan is read before the deletion and applied after it, so a row
      // can be relinked in between. Clearing by column would erase the new
      // link.
      final id = await photo(dive: 'd-dying', site: 's-kept');
      await db.customStatement(
        "UPDATE media SET dive_id = 'd-kept' WHERE id = ?",
        [id],
      );

      await unlinkMediaFromDeletedParents(db, SyncRepository(), [
        MediaSurvivor(id, diveId: 'd-dying'),
      ]);

      expect((await row(id)).diveId, 'd-kept');
    });

    test('one survivor failing does not undo the others', () async {
      // Each survivor's unlink is the only thing that publishes it, so one
      // row that cannot be marked must not roll the rest back with it.
      final bad = await photo(dive: 'd-dying', site: 's-kept');
      final good = await photo(dive: 'd-dying', site: 's-kept');
      await SyncRepository().clearPendingRecords();

      await expectLater(
        unlinkMediaFromDeletedParents(db, _PendingFailsFor(bad), [
          MediaSurvivor(bad, diveId: 'd-dying'),
          MediaSurvivor(good, diveId: 'd-dying'),
        ]),
        throwsA(isA<StateError>()),
        reason: 'the caller still hears about the failure',
      );

      expect((await row(good)).diveId, isNull);
      expect(await isPending(good), isTrue);
      expect(
        (await row(bad)).diveId,
        'd-dying',
        reason: 'its own unlink rolled back with its failed mark',
      );
    });

    test('a row deleted since the plan is not marked', () async {
      await unlinkMediaFromDeletedParents(db, SyncRepository(), const [
        MediaSurvivor('gone', diveId: 'd-dying'),
      ]);

      expect(await isPending('gone'), isFalse);
    });
  });
}

/// Fails to mark one record pending, the way a full disk or a locked
/// database would for a single write.
class _PendingFailsFor extends SyncRepository {
  _PendingFailsFor(this.failingId);
  final String failingId;

  @override
  Future<void> markRecordPending({
    required String entityType,
    required String recordId,
    required int localUpdatedAt,
    List<SyncFactGroup> alsoStamp = const [],
    bool stampClock = true,
  }) {
    if (recordId == failingId) {
      return Future<void>.error(StateError('could not mark $recordId'));
    }
    return super.markRecordPending(
      entityType: entityType,
      recordId: recordId,
      localUpdatedAt: localUpdatedAt,
      alsoStamp: alsoStamp,
      stampClock: stampClock,
    );
  }
}
