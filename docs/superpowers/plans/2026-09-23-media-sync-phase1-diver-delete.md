# Media Sync Slice 6: Diver Delete Media Cascade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deleting a diver deletes the media only that diver's rows linked, and unlinks, stamps and publishes the media a surviving row still links, so every device converges and uploaded copies are scheduled for removal.

**Architecture:** A new `media_parent_cascade.dart` plans the cascade inside the diver delete's transaction, after Step 0 reassigns the shared sites and before any delete, while the media links still name the dying parents, and applies it after the transaction commits. Survivors are unlinked first, on their own. Doomed rows are read again (`recheckDoomed`) and go through the existing `MediaDeletionCoordinator` (tombstones plus blob-delete intents) in isolated batches of at most 900, each row judged once more inside the delete's own transaction (`keepIf`), so a relink landing at any point before the delete spares it. Every id list is read in chunks of 900 as well. Survivors get their dying links cleared with `NULLIF`, a fresh `updated_at` and a pending mark, each survivor in its own transaction so one row that cannot be written does not roll the others back; the failures are rethrown together once every survivor has been tried. The media enrichment the dive deletes cascade away is tombstoned inside the transaction from ids read before it.

**Tech Stack:** Flutter, Dart, Drift over SQLite, the in-house changeset sync (`SyncRepository`), `flutter_test` with in-memory databases, the two-device media harness.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 5.4 (and 5.3 for the enrichment tombstones). Sub-issue #2108, closes #1954, part of #2090. Stacked on slice 4 (#2239).

> **Revised in review (PR #2289).** Review moved the plan inside the delete's
> transaction (after Step 0, before any delete) so it is atomic with the
> deletes and needs no prediction of Step 0; added `recheckDoomed` so a row
> relinked between the commit and the apply is spared; and chunked every id
> list at 900, because the bundled SQLite (3.53.3) binds at most 32766
> variables per statement (measured). A later round ran the survivor unlinks
> first and on their own, so a failed deletion batch cannot suppress them, and
> gave `deleteMultipleMedia` a `keepIf` judged inside its own transaction, so
> a relink during the coordinator's queue write still spares the row. The
> tasks below describe the code as it shipped.

## Global Constraints

- Originals are never touched: only media rows and uploaded copies are at stake (spec 5.4, issue #1954).
- `MediaDeletionCoordinator` stays outside the delete's database transaction: its queue lives in another database (spec 5.4).
- Single-enqueuer rule: only user-action deletion flows enqueue blob deletes; sync tombstone application never does (`media_deletion_coordinator.dart`).
- A failure after the diver's transaction commits is logged, not rethrown: the diver is gone and cannot be restored (the site delete's rule, `site_repository_impl.dart` `_deleteSiteRows`).
- No schema change. `minimumCompatibleSchemaVersion` stays 224.
- Scope decisions from the owner (2026-09-23): stack on slice 4; include the buddy signer link (`media.signer_id`); execute in this worktree.
- Repository rules: no em-dashes anywhere; no mention of Claude, Claude Code or Anthropic in commits, PRs or comments; no emojis in code; `dart format .` before every commit.
- Any `lib` query reading `FROM dives` inside `diver_repository.dart` needs a `// stats-scope-exempt: <reason>` marker inside the member (`test/core/database/dive_stats_scope_census_test.dart`).
- Paths are platform-agnostic in tests and code alike: build them with `p.join`, never a literal `/`, and never write a literal `/tmp` (CLAUDE.md, issue #2279). In the shell steps below, `$SCRATCH` is any scratch directory outside the repository.

## Why the existing pieces cannot simply be reused

Two traps shape this plan. An implementer who skips this section will fall into both.

1. **The per-entity partitions do not compose.** `partitionMediaForDiveDeletion` keeps a photo that a site still links; `partitionMediaForSiteDeletion` keeps a photo that a dive still links. A photo on the diver's own dive AND the diver's own private site survives each partition alone, even though both parents die, and would be left detached: the exact #1954 bug in a new place. The cascade has to classify a row against every dying set at once.
2. **After the commit, the links are already gone.** `media.dive_id`, `site_id`, `equipment_id` and `signer_id` are all `ON DELETE SET NULL`. Once the transaction commits, SQLite has cleared them locally, with no stamp and no pending mark. Slice 4's `unlinkMediaFromDeletedDives` scopes its write with `dive_id IN (dying dives)`, which matches nothing at that point and returns early without marking anything. So the plan must be read before the deletes, inside the same transaction so it names exactly what they remove, and the survivor write must not depend on the link still being set.

## File Structure

- Create `lib/features/media/data/repositories/media_parent_cascade.dart`: the value types (`DyingMediaParents`, `MediaSurvivor`, `MediaCascadePlan`) and two top-level functions, `planMediaCascade` and `unlinkMediaFromDeletedParents`. Top-level functions taking the database, like `diver_delete_steps.dart`, so `media_repository.dart` (2,639 lines) does not grow.
- Create `test/features/media/data/media_parent_cascade_test.dart`: unit tests for both functions.
- Modify `lib/features/divers/data/repositories/diver_repository.dart`: inject the coordinator; plan inside the transaction after Step 0, tombstone enrichment inside it, and apply after it, rechecking the doomed rows first.
- Create `test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`: the diver delete end to end on one device.
- Modify `test/helpers/two_device_media_harness.dart`: `deleteDiver` passes this device's queue.
- Modify `test/features/media/two_device/deletion_scenarios_test.dart`: unskip S9.
- Modify `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`: section 5.4 records the signer link and the enrichment tombstones.

---

### Task 1: Plan and apply a media cascade over several dying parent sets

**Files:**
- Create: `lib/features/media/data/repositories/media_parent_cascade.dart`
- Test: `test/features/media/data/media_parent_cascade_test.dart`

**Interfaces:**
- Consumes: `mediaItemFromRow(MediaData row, [MediaEnrichmentData? enrichmentRow])` from `media_row_mapper.dart`; `SyncRepository.markRecordPending({required String entityType, required String recordId, required int localUpdatedAt})`.
- Produces:
  - `const mediaCascadeIdChunk = 900;` the id bound every read and batch uses.
  - `class DyingMediaParents { const DyingMediaParents({Set<String> diveIds, Set<String> siteIds, Set<String> equipmentIds, Set<String> buddyIds}); bool get isEmpty; }`
  - `class MediaSurvivor { const MediaSurvivor(String id, {String? diveId, String? siteId, String? equipmentId, String? signerId}); }` where each named field is the dying parent the row linked, or null.
  - `class MediaCascadePlan { const MediaCascadePlan({DyingMediaParents parents, List<domain.MediaItem> doomed, List<MediaSurvivor> survivors, List<String> enrichmentIds}); static const empty; }`
  - `Future<MediaCascadePlan> planMediaCascade(AppDatabase db, DyingMediaParents parents)`
  - `Future<List<domain.MediaItem>> recheckDoomed(AppDatabase db, MediaCascadePlan plan)`
  - `bool mediaRowLivesOn(MediaData row, DyingMediaParents parents)`: whether a live parent still links the row; Task 2 hands it to the delete as `keepIf`.
  - `Future<void> unlinkMediaFromDeletedParents(AppDatabase db, SyncRepository sync, List<MediaSurvivor> survivors)`

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/media_parent_cascade_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/media/data/media_parent_cascade_test.dart`
Expected: compilation FAIL, `Error: Couldn't resolve the package 'submersion' in 'package:submersion/features/media/data/repositories/media_parent_cascade.dart'` or `Undefined name 'planMediaCascade'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/media/data/repositories/media_parent_cascade.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;

/// The parents a deletion is about to remove, keyed by the media column
/// that references each kind.
///
/// A deletion that takes several kinds at once (a diver takes their dives,
/// private sites, gear and buddies) must classify each media row against all
/// of them together. The single-entity partitions cannot be chained: the
/// dive partition keeps a photo its site still links, the site partition
/// keeps a photo its dive still links, and a photo on both would outlive a
/// deletion that removes both.
class DyingMediaParents {
  const DyingMediaParents({
    this.diveIds = const {},
    this.siteIds = const {},
    this.equipmentIds = const {},
    this.buddyIds = const {},
  });

  final Set<String> diveIds;
  final Set<String> siteIds;
  final Set<String> equipmentIds;

  /// Buddies whose signatures would lose their signer. A signer is not a
  /// logbook link, so it never keeps a row alive or dooms one.
  final Set<String> buddyIds;

  bool get isEmpty =>
      diveIds.isEmpty &&
      siteIds.isEmpty &&
      equipmentIds.isEmpty &&
      buddyIds.isEmpty;
}

/// A media row that outlives the deletion. Each field names the dying parent
/// the row linked through that column, or is null where the link was not
/// dying (absent, or a surviving parent).
class MediaSurvivor {
  const MediaSurvivor(
    this.id, {
    this.diveId,
    this.siteId,
    this.equipmentId,
    this.signerId,
  });

  final String id;
  final String? diveId;
  final String? siteId;
  final String? equipmentId;
  final String? signerId;
}

/// Ids per statement. The bundled SQLite binds at most 32766 variables, and
/// a diver's whole library can pass that in one list; 900 is the bound the
/// rest of the codebase already chunks by. Public so a caller handing the
/// doomed rows onward can bound those calls too.
const mediaCascadeIdChunk = 900;

Iterable<List<T>> _chunks<T>(List<T> items) sync* {
  for (var i = 0; i < items.length; i += mediaCascadeIdChunk) {
    yield items.sublist(
      i,
      i + mediaCascadeIdChunk < items.length
          ? i + mediaCascadeIdChunk
          : items.length,
    );
  }
}

/// What a deletion does to its parents' media, read before it runs.
class MediaCascadePlan {
  const MediaCascadePlan({
    this.parents = const DyingMediaParents(),
    this.doomed = const [],
    this.survivors = const [],
    this.enrichmentIds = const [],
  });

  static const empty = MediaCascadePlan();

  /// The dying parents this plan was read against, kept so the doomed set
  /// can be checked again right before it is deleted ([recheckDoomed]).
  final DyingMediaParents parents;

  /// Rows whose every logbook link is dying. Full items, because the
  /// blob-delete intent needs the content hash, filename and type.
  final List<domain.MediaItem> doomed;

  /// Rows a surviving parent still links, or reached only through a dying
  /// signer.
  final List<MediaSurvivor> survivors;

  /// Enrichment rows of the dying dives. Their foreign key cascades, so the
  /// dive deletes remove them with no tombstone; the caller logs these.
  final List<String> enrichmentIds;
}

String? _dyingOf(String? link, Set<String> dying) =>
    link != null && dying.contains(link) ? link : null;

/// Whether some logbook link on [row] names a parent that is not dying.
/// That link alone keeps the row, whatever else dies around it.
///
/// Public so a caller can hand it to `MediaDeletionCoordinator` as `keepIf`,
/// where it is judged inside the delete's own transaction.
bool mediaRowLivesOn(MediaData row, DyingMediaParents parents) =>
    (row.diveId != null && !parents.diveIds.contains(row.diveId)) ||
    (row.siteId != null && !parents.siteIds.contains(row.siteId)) ||
    (row.equipmentId != null &&
        !parents.equipmentIds.contains(row.equipmentId));

/// Reads what a deletion of [parents] does to media. Call it before the
/// deletion: afterwards ON DELETE SET NULL has already cleared the links
/// this classifies by.
///
/// A row is doomed when it has at least one logbook link (dive, site or
/// equipment) and every one of them is dying: the same "linked to the
/// logbook" definition as `MediaRepository.isLinkedToLogbook`. Anything else
/// the query reaches survives, with its dying links named.
Future<MediaCascadePlan> planMediaCascade(
  AppDatabase db,
  DyingMediaParents parents,
) async {
  if (parents.isEmpty) return MediaCascadePlan.empty;

  // One read per column and chunk, merged by id: a row reached through two
  // dying parents must be classified once.
  final byId = <String, MediaData>{};
  Future<void> reach(
    Set<String> ids,
    Expression<bool> Function($MediaTable m, List<String> chunk) where,
  ) async {
    for (final chunk in _chunks(ids.toList())) {
      for (final row in await (db.select(
        db.media,
      )..where((m) => where(m, chunk))).get()) {
        byId[row.id] = row;
      }
    }
  }

  await reach(parents.diveIds, (m, c) => m.diveId.isIn(c));
  await reach(parents.siteIds, (m, c) => m.siteId.isIn(c));
  await reach(parents.equipmentIds, (m, c) => m.equipmentId.isIn(c));
  await reach(parents.buddyIds, (m, c) => m.signerId.isIn(c));

  final doomed = <domain.MediaItem>[];
  final survivors = <MediaSurvivor>[];
  for (final row in byId.values) {
    final linked =
        row.diveId != null || row.siteId != null || row.equipmentId != null;
    if (linked && !mediaRowLivesOn(row, parents)) {
      doomed.add(mediaItemFromRow(row));
    } else {
      survivors.add(
        MediaSurvivor(
          row.id,
          diveId: _dyingOf(row.diveId, parents.diveIds),
          siteId: _dyingOf(row.siteId, parents.siteIds),
          equipmentId: _dyingOf(row.equipmentId, parents.equipmentIds),
          signerId: _dyingOf(row.signerId, parents.buddyIds),
        ),
      );
    }
  }

  final enrichmentIds = <String>{};
  for (final chunk in _chunks(parents.diveIds.toList())) {
    for (final e in await (db.select(
      db.mediaEnrichment,
    )..where((t) => t.diveId.isIn(chunk))).get()) {
      enrichmentIds.add(e.id);
    }
  }

  return MediaCascadePlan(
    parents: parents,
    doomed: doomed,
    survivors: survivors,
    enrichmentIds: enrichmentIds.toList(),
  );
}

/// The planned doomed rows that are still doomed now, read fresh.
///
/// The plan is applied after the deletion commits, and a row can be
/// relinked to a surviving parent in between (a sync pull, say). A row is
/// kept here while some logbook link names a live parent: links the
/// deletion's SET NULL cleared, and links still naming a dying parent, both
/// leave it doomed. A row already gone is dropped. The items are the fresh
/// reads, so a blob-delete intent is built from the row as it is now.
///
/// A pre-filter, not the guard: the delete that follows awaits a queue write
/// before it runs, and a relink can land in that gap too. The guard is
/// [mediaRowLivesOn] passed to the delete as `keepIf`, which judges each row
/// inside the delete's own transaction. This only spares the rows already
/// relinked the cost of a blob intent.
Future<List<domain.MediaItem>> recheckDoomed(
  AppDatabase db,
  MediaCascadePlan plan,
) async {
  final still = <domain.MediaItem>[];
  for (final chunk in _chunks([for (final m in plan.doomed) m.id])) {
    for (final row in await (db.select(
      db.media,
    )..where((m) => m.id.isIn(chunk))).get()) {
      if (!mediaRowLivesOn(row, plan.parents)) {
        still.add(mediaItemFromRow(row));
      }
    }
  }
  return still;
}

/// Clears each survivor's links to the parents a deletion removed, stamps
/// the row and marks it pending, so peers take the unlink rather than each
/// nulling the link silently on its own schedule (issue #1954).
///
/// Runs after the deletion commits, when ON DELETE SET NULL has already
/// cleared those links locally with no stamp. So the write cannot be scoped
/// on the link still naming the parent. `NULLIF(column, dying)` clears a
/// link only while it still names the parent the plan saw dying (or is
/// already null): a row relinked since the plan keeps its new link. A null
/// argument leaves the column unchanged, because `x = NULL` is never true.
///
/// Sends no local-change notice: the caller announces the whole deletion.
///
/// One transaction per survivor, so a row's unlink and its pending mark land
/// together or not at all, and one row that cannot be written does not roll
/// the others back: each survivor's unlink is the only thing that publishes
/// it. A failure is rethrown after the rest have been tried, so the caller
/// still hears about it. A survivor left unpublished this way is not lost:
/// its dying link is gone locally, and every peer clears the same link
/// itself when it applies the parent's tombstone.
Future<void> unlinkMediaFromDeletedParents(
  AppDatabase db,
  SyncRepository sync,
  List<MediaSurvivor> survivors,
) async {
  if (survivors.isEmpty) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  Object? firstError;
  StackTrace? firstStack;
  var failed = 0;
  for (final s in survivors) {
    try {
      await db.transaction(() async {
        final written = await db.customUpdate(
          'UPDATE media SET '
          'dive_id = NULLIF(dive_id, ?), '
          'site_id = NULLIF(site_id, ?), '
          'equipment_id = NULLIF(equipment_id, ?), '
          'signer_id = NULLIF(signer_id, ?), '
          'updated_at = ? '
          'WHERE id = ?',
          variables: [
            Variable<String>(s.diveId),
            Variable<String>(s.siteId),
            Variable<String>(s.equipmentId),
            Variable<String>(s.signerId),
            Variable<int>(now),
            Variable<String>(s.id),
          ],
          updates: {db.media},
          updateKind: UpdateKind.update,
        );
        // Deleted since the plan: nothing survived to publish.
        if (written == 0) return;
        await sync.markRecordPending(
          entityType: 'media',
          recordId: s.id,
          localUpdatedAt: now,
        );
      });
    } on Object catch (e, stackTrace) {
      failed++;
      firstError ??= e;
      firstStack ??= stackTrace;
    }
  }
  if (firstError != null) {
    Error.throwWithStackTrace(
      StateError(
        '$failed of ${survivors.length} surviving media rows could not be '
        'unlinked: $firstError',
      ),
      firstStack!,
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart format lib test && flutter test test/features/media/data/media_parent_cascade_test.dart`
Expected: `All tests passed!` (16 tests).

- [ ] **Step 5: Mutation-check the rules that matter**

Back up the file first; never `git checkout` it (a checkout during a red check destroys the fix).

```bash
cp lib/features/media/data/repositories/media_parent_cascade.dart "$SCRATCH/media_parent_cascade.dart.bak"
```

(a) Replace the body of `mediaRowLivesOn` with the dive partition's rule, `row.siteId != null || row.equipmentId != null`. Run the test file. Expected: `a row whose every link is dying is doomed` FAILS (the dive-and-site row survives). Restore from the backup.

(b) Replace `'dive_id = NULLIF(dive_id, ?), '` with `'dive_id = CASE WHEN ? IS NULL THEN dive_id ELSE NULL END, '`. Run the test file. Expected: `a link that moved since the plan is kept` FAILS. Restore from the backup.

(c) In `planMediaCascade`, read the enrichment in one list: replace `for (final chunk in _chunks(parents.diveIds.toList()))` with `for (final chunk in [parents.diveIds.toList()])`. Expected: `a dying set past the bind-variable limit is read in chunks` FAILS with `too many SQL variables`. Restore from the backup.

(d) In `recheckDoomed`, drop the liveness check (`still.add(mediaItemFromRow(row))` unconditionally). Expected: `a doomed row relinked to a surviving parent is spared` FAILS. Restore from the backup.

(e) In `unlinkMediaFromDeletedParents`, stop at the first failure: `rethrow;` as the catch's first statement after `failed++;`. Expected: `one survivor failing does not undo the others` FAILS (the good row is never reached). Restore from the backup.

(f) Swallow the failures: `if (firstError != null && failed < 0) {`. Expected: the same test FAILS (the caller no longer hears). Restore from the backup and rerun: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/media/data/repositories/media_parent_cascade.dart test/features/media/data/media_parent_cascade_test.dart
git commit -m "feat(media): plan a cascade over several dying parent sets at once"
```

---

### Task 2: The diver delete cascades its media

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (constructor near line 45; `deleteDiverWithReassignment` near line 330)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`deleteMultipleMedia`)
- Modify: `lib/features/media_store/data/media_deletion_coordinator.dart` (`deleteMediaItems`, `_delete`)
- Modify: `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` (section 5.4)
- Test: `test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`

**Interfaces:**
- Consumes (Task 1): `DyingMediaParents`, `MediaCascadePlan`, `planMediaCascade(AppDatabase, DyingMediaParents)`, `unlinkMediaFromDeletedParents(AppDatabase, SyncRepository, List<MediaSurvivor>)`. Also `recheckDoomed`, `mediaRowLivesOn` and `SyncRepository.logDeletions({required String entityType, required Iterable<String> recordIds})`.
- Produces: `DiverRepository({ImportedFileReclaimer? importedFileReclaimer, MediaDeletionCoordinator? mediaDeletionCoordinator})` (Task 3 passes the coordinator); `MediaRepository.deleteMultipleMedia(List<String> ids, {bool Function(MediaData row)? keepIf})`; `MediaDeletionCoordinator.deleteMediaItems(List<MediaItem> items, {bool Function(MediaData row)? keepIf})`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a diver cascades their media the way the single-entity deletes
/// do (issue #1954, media sync program spec 5.4). Media linked only to the
/// diver's dives, sites and gear is deleted, tombstoned, and its uploaded
/// copy queued for removal; media a surviving row still links is unlinked,
/// stamped and marked pending. Without this, the foreign keys' SET NULL
/// left every such row detached, unstamped and unsynced on every device.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late DiverRepository repository;
  const t = 1000;

  Future<void> insertDiver(String id, {bool isDefault = false}) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          isDefault: Value(isDefault),
          createdAt: const Value(t),
          updatedAt: const Value(t),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    repository = DiverRepository(
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => queue,
      ),
    );
    await insertDiver('diver-a', isDefault: true);
    // A survivor, so Step 0 reassigns the shared sites instead of deleting.
    await insertDiver('diver-b');
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id, String diverId) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diverId),
          diveDateTime: t,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> insertSite(String id, String diverId, {bool isShared = false}) =>
      db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              diverId: Value(diverId),
              isShared: Value(isShared),
              createdAt: t,
              updatedAt: t,
            ),
          );

  Future<void> insertGear(String id, String diverId) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          diverId: Value(diverId),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> insertBuddy(String id, String diverId) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: id,
          diverId: Value(diverId),
          createdAt: t,
          updatedAt: t,
        ),
      );

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

  /// Marks [id] as uploaded to a media store, so its deletion owes a
  /// blob-delete intent.
  Future<void> uploaded(String id) => db.customStatement(
    'UPDATE media SET content_hash = ?, remote_uploaded_at = 1 WHERE id = ?',
    ['hash-$id', id],
  );

  Future<MediaData?> row(String id) =>
      (db.select(db.media)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> tombstonesFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                'WHERE entity_type = ? AND record_id = ?',
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<bool> isPending(String id) async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == 'media' && r.recordId == id,
      );

  Future<List<String>> blobDeletes() async => [
    for (final e in await queue.allForTesting())
      if (e.direction == 'delete') e.mediaId,
  ];

  test("a photo only the diver's dive shows is deleted everywhere", () async {
    await insertDive('d1', 'diver-a');
    final id = await photo(dive: 'd1');
    await uploaded(id);
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await row(id), isNull);
    expect(await tombstonesFor('media', id), 1);
    expect(await blobDeletes(), [
      id,
    ], reason: 'the uploaded copy must be scheduled for removal');
  });

  test("a photo on the diver's dive and private site goes with both", () async {
    await insertDive('d1', 'diver-a');
    await insertSite('s1', 'diver-a');
    final id = await photo(dive: 'd1', site: 's1');

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await row(id), isNull, reason: 'neither parent survives');
  });

  test(
    'a photo on a shared site the survivor inherits outlives the delete',
    () async {
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      final id = await photo(dive: 'd1', site: 's1');
      await SyncRepository().clearPendingRecords();

      await repository.deleteDiverWithReassignment('diver-a');

      final kept = await row(id);
      expect(kept, isNotNull);
      expect(kept!.diveId, isNull);
      expect(kept.siteId, 's1');
      expect(await isPending(id), isTrue, reason: 'peers must take the unlink');
      expect(await tombstonesFor('media', id), 0);
    },
  );

  test(
    'with no surviving diver the shared site goes too, and its photo',
    () async {
      await db.customStatement("DELETE FROM divers WHERE id = 'diver-b'");
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      final id = await photo(dive: 'd1', site: 's1');

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await row(id), isNull);
    },
  );

  test(
    "gear paperwork another diver's dive uses loses only the gear link",
    () async {
      await insertDive('d-b', 'diver-b');
      await insertGear('g1', 'diver-a');
      final id = await photo(dive: 'd-b', gear: 'g1');
      await SyncRepository().clearPendingRecords();

      await repository.deleteDiverWithReassignment('diver-a');

      final kept = await row(id);
      expect(kept!.equipmentId, isNull);
      expect(kept.diveId, 'd-b');
      expect(await isPending(id), isTrue);
    },
  );

  test("a signature by the diver's buddy on another diver's dive loses only "
      'the signer', () async {
    await insertDive('d-b', 'diver-b');
    await insertBuddy('b1', 'diver-a');
    final id = await photo(dive: 'd-b', signer: 'b1');
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    final kept = await row(id);
    expect(kept!.signerId, isNull);
    expect(kept.diveId, 'd-b');
    expect(await isPending(id), isTrue);
  });

  test(
    "the enrichment the diver's dives take with them is tombstoned",
    () async {
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      final id = await photo(dive: 'd1', site: 's1');
      await db
          .into(db.mediaEnrichment)
          .insert(
            MediaEnrichmentCompanion.insert(
              id: 'e1',
              mediaId: id,
              diveId: 'd1',
              createdAt: t,
            ),
          );

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await tombstonesFor('mediaEnrichment', 'e1'), 1);
    },
  );

  test("another diver's media is not touched", () async {
    await insertDive('d-b', 'diver-b');
    final id = await photo(dive: 'd-b');
    await db.customStatement('UPDATE media SET updated_at = 1 WHERE id = ?', [
      id,
    ]);
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    expect((await row(id))!.updatedAt, 1);
    expect(await isPending(id), isFalse);
  });

  test('a cleanup failure after the commit is logged, not rethrown', () async {
    // The diver is gone by then and cannot be restored, so reporting the
    // delete as failed would be a lie. What is left is recoverable: the row
    // stays, unlinked, for the orphan sweep.
    await insertDive('d1', 'diver-a');
    final id = await photo(dive: 'd1');

    await DiverRepository(
      mediaDeletionCoordinator: _FailingCoordinator(),
    ).deleteDiverWithReassignment('diver-a');

    final diver = await (db.select(
      db.divers,
    )..where((d) => d.id.equals('diver-a'))).getSingleOrNull();
    expect(diver, isNull);
    expect(await row(id), isNotNull, reason: 'left for the orphan sweep');
  });

  test(
    'without an injected coordinator the default one does the cascade',
    () async {
      // Most callers build a DiverRepository only to read the active diver,
      // so the default coordinator is built on first use. An uploaded row
      // makes it reach for its queue too.
      await insertDive('d1', 'diver-a');
      final id = await photo(dive: 'd1');
      await uploaded(id);

      await DiverRepository().deleteDiverWithReassignment('diver-a');

      expect(await row(id), isNull);
    },
  );

  test(
    'a failed deletion still publishes the unlinks of surviving media',
    () async {
      // The commit already cleared the survivor's dying link with SET NULL
      // and no stamp, and its live link keeps it out of every sweep. If this
      // write is lost, its peers keep the stale link for good.
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      await photo(dive: 'd1');
      final survivor = await photo(dive: 'd1', site: 's1');
      await SyncRepository().clearPendingRecords();

      await DiverRepository(
        mediaDeletionCoordinator: _FailingCoordinator(),
      ).deleteDiverWithReassignment('diver-a');

      final kept = await row(survivor);
      expect(kept!.diveId, isNull);
      expect(kept.siteId, 's1');
      expect(await isPending(survivor), isTrue);
    },
  );

  test('a photo relinked while its deletion is under way is kept', () async {
    // The row is read again before deletion, but the coordinator awaits its
    // queue write before deleting by id, and a relink can land in between.
    // The liveness check has to travel with the delete itself.
    await insertDive('d1', 'diver-a');
    await insertDive('d-b', 'diver-b');
    final id = await photo(dive: 'd1');
    // Uploaded, so the coordinator writes to the queue: the relink lands
    // inside that write.
    await uploaded(id);
    final relinking = _RelinkingQueue(
      cacheDb,
      () => db.customStatement(
        "UPDATE media SET dive_id = 'd-b' WHERE id = ?",
        [id],
      ),
    );

    await DiverRepository(
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => relinking,
      ),
    ).deleteDiverWithReassignment('diver-a');

    final kept = await row(id);
    expect(kept, isNotNull, reason: 'a surviving dive shows it now');
    expect(kept!.diveId, 'd-b');
    expect(await tombstonesFor('media', id), 0);
  });

  test('a delete that fails changes no media', () async {
    await insertDive('d1', 'diver-a');
    final id = await photo(dive: 'd1');
    await uploaded(id);
    await SyncRepository().clearPendingRecords();
    await db.customStatement(
      'CREATE TRIGGER fail_diver_delete BEFORE DELETE ON divers '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );

    await expectLater(
      repository.deleteDiverWithReassignment('diver-a'),
      throwsA(anything),
    );

    expect((await row(id))!.diveId, 'd1');
    expect(await isPending(id), isFalse);
    expect(await blobDeletes(), isEmpty);
  });
}

/// Runs [relink] inside the coordinator's queue write, which is exactly the
/// window between its liveness recheck and its delete.
class _RelinkingQueue extends MediaTransferQueueRepository {
  _RelinkingQueue(LocalCacheDatabase database, this.relink)
    : super(database: database);

  final Future<void> Function() relink;

  @override
  Future<int> enqueueDelete({
    required String mediaId,
    required String contentHash,
    required String originalExt,
    required String renditionExt,
  }) async {
    await relink();
    return super.enqueueDelete(
      mediaId: mediaId,
      contentHash: contentHash,
      originalExt: originalExt,
      renditionExt: renditionExt,
    );
  }
}

/// Fails the way a media store problem after the commit would.
class _FailingCoordinator extends MediaDeletionCoordinator {
  _FailingCoordinator()
    : super(
        mediaRepository: MediaRepository(),
        queue: () => MediaTransferQueueRepository(),
      );

  @override
  Future<void> deleteMediaItems(
    List<MediaItem> items, {
    bool Function(MediaData row)? keepIf,
  }) async => throw StateError('media store unavailable');
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`
Expected: compilation FAIL, `No named parameter with the name 'mediaDeletionCoordinator'`.

- [ ] **Step 3: Inject the coordinator**

In `diver_repository.dart`, add the imports (keep the existing grouping, alphabetical within the local block):

```dart
import 'package:submersion/features/media/data/repositories/media_parent_cascade.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
```

Replace the constructor and its field:

```dart
class DiverRepository {
  DiverRepository({
    ImportedFileReclaimer? importedFileReclaimer,
    MediaDeletionCoordinator? mediaDeletionCoordinator,
  }) : _importedFileReclaimer = importedFileReclaimer ?? ImportedFileReclaimer(),
       _injectedMediaDeletionCoordinator = mediaDeletionCoordinator;

  final ImportedFileReclaimer _importedFileReclaimer;
  final MediaDeletionCoordinator? _injectedMediaDeletionCoordinator;

  /// Built on first use: most callers construct a DiverRepository only to
  /// read the active diver, and never delete one. No worker kick from the
  /// data layer (provider cycles), the rule SiteRepository follows: queued
  /// intents drain on the next kick, and the Verify Library sweep is the
  /// backstop.
  late final MediaDeletionCoordinator _mediaDeletionCoordinator =
      _injectedMediaDeletionCoordinator ??
      MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => MediaTransferQueueRepository(),
      );
```

(Leave the other existing fields, `_settingsRepository` and `_syncRepository`, where they are.)

- [ ] **Step 3b: Let the delete itself judge whether a row still dies**

A liveness check made before the delete can be overtaken: the coordinator awaits its queue write and then deletes by id, and a relink can land in between. The check has to run inside the delete's own transaction. In `lib/features/media/data/repositories/media_repository.dart`, replace `deleteMultipleMedia` with:

```dart
  /// Delete multiple media items in a single transaction.
  /// Logs each deletion for sync tracking.
  ///
  /// [keepIf], when given, is asked about each row as it stands inside the
  /// same transaction, and a row it keeps is neither deleted nor
  /// tombstoned. That makes a caller's "is this row still doomed?" check
  /// atomic with the delete: one made earlier, outside the transaction, can
  /// be overtaken by a relink before the delete runs.
  Future<void> deleteMultipleMedia(
    List<String> ids, {
    bool Function(MediaData row)? keepIf,
  }) async {
    if (ids.isEmpty) return;
    try {
      _log.info('Deleting ${ids.length} media items');
      await _db.transaction(() async {
        var targets = ids;
        if (keepIf != null) {
          final rows = await (_db.select(
            _db.media,
          )..where((t) => t.id.isIn(ids))).get();
          targets = [
            for (final row in rows)
              if (!keepIf(row)) row.id,
          ];
          if (targets.isEmpty) return;
        }
        // Before the parents: the enrichment rows would otherwise vanish on
        // the FK cascade, which removes them without logging anything. See
        // [_dropEnrichmentRows] for why the tombstone matters.
        await _dropEnrichmentRows(targets);
        for (final id in targets) {
          await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
          await _syncRepository.logDeletion(entityType: 'media', recordId: id);
        }
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted ${ids.length} media items');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete multiple media',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `lib/features/media_store/data/media_deletion_coordinator.dart`, add `import 'package:submersion/core/database/database.dart';` and replace `deleteMediaItems` and `_delete` with:

```dart
  /// [deleteMultipleMedia] for callers that already hold the rows. The
  /// dive-deletion cascade partitions its doomed set out of a single
  /// select, so re-reading each row by id here would be duplicate work
  /// proportional to the number of photos on the dives being deleted.
  ///
  /// [keepIf] spares any row it answers true for, judged inside the delete's
  /// own transaction (see [MediaRepository.deleteMultipleMedia]). A caller
  /// whose items were chosen earlier passes the rule that chose them, so a
  /// row relinked in the meantime, even during the queue write below,
  /// survives. Its intent was already enqueued; that is harmless by the
  /// same refcount that covers a crash between enqueue and delete.
  Future<void> deleteMediaItems(
    List<MediaItem> items, {
    bool Function(MediaData row)? keepIf,
  }) => _delete(
    [for (final item in items) item.id],
    {for (final item in items) item.id: item},
    keepIf: keepIf,
  );

  /// [known] short-circuits the per-id read for callers that already hold
  /// the row; ids absent from it are read back as before.
  Future<void> _delete(
    List<String> ids,
    Map<String, MediaItem> known, {
    bool Function(MediaData row)? keepIf,
  }) async {
    var enqueued = false;
    for (final id in ids) {
      // Untyped catch on purpose: an uninitialized
      // LocalCacheDatabaseService throws StateError (an Error, not an
      // Exception), and no media-store problem may ever block the user's
      // deletion.
      try {
        if (await _enqueueIntent(id, known[id])) enqueued = true;
      } catch (e, stackTrace) {
        _log.warning(
          'Could not enqueue remote delete for media $id '
          '(sweep will reconcile)',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    if (keepIf != null) {
      await _mediaRepository.deleteMultipleMedia(ids, keepIf: keepIf);
    } else if (ids.length == 1) {
      await _mediaRepository.deleteMedia(ids.single);
    } else {
      await _mediaRepository.deleteMultipleMedia(ids);
    }
    if (enqueued && _kickWorker != null) {
      try {
        await _kickWorker();
      } catch (e) {
        _log.warning('Worker kick after media delete failed', error: e);
      }
    }
  }
```

- [ ] **Step 4: Plan inside the transaction, tombstone inside it, apply after it**

Add these two members to `DiverRepository`, directly above the doc comment of `deleteDiverWithReassignment` (anchor on the doc comment's first line, `/// Delete a diver, reassigning shared trips/sites to a surviving diver first.`, not on the signature, or the doc comment splits):

```dart
  /// The parents of media that [deleteDiverWithReassignment] removes,
  /// mirroring its step lists (`diver_delete_steps.dart`): every dive, site,
  /// piece of gear and buddy the diver still owns. Read inside the delete's
  /// transaction after Step 0, when the shared sites already belong to the
  /// survivor, so what remains is exactly what the transaction deletes.
  Future<DyingMediaParents> _dyingMediaParents(String id) async =>
      DyingMediaParents(
        // stats-scope-exempt: a deletion cascade, not a statistic.
        diveIds: (await _idsOf('SELECT id FROM dives WHERE diver_id = ?', [
          id,
        ])).toSet(),
        siteIds: (await _idsOf('SELECT id FROM dive_sites WHERE diver_id = ?', [
          id,
        ])).toSet(),
        equipmentIds: (await _idsOf(
          'SELECT id FROM equipment WHERE diver_id = ?',
          [id],
        )).toSet(),
        buddyIds: (await _idsOf('SELECT id FROM buddies WHERE diver_id = ?', [
          id,
        ])).toSet(),
      );

  /// Deletes the media only this diver's rows linked, with tombstones and
  /// blob-delete intents, and unlinks, stamps and marks pending the media a
  /// surviving row still links (issue #1954, spec 5.4).
  ///
  /// After the delete commits, never inside it: the coordinator's queue
  /// lives in another database, and a failed delete must leave the media as
  /// it was. A failure here is logged, not rethrown: the diver is gone and
  /// cannot be restored.
  ///
  /// The survivors go first and on their own. The commit already cleared
  /// their dying links with SET NULL and no stamp, and their live links keep
  /// them out of every sweep, so a lost unlink would leave peers with the
  /// stale link for good. A doomed row the deletion misses is recoverable
  /// (the orphan sweep collects it, and the Verify Library sweep a missed
  /// blob intent), so each deletion batch is isolated and a failed one does
  /// not stop the rest.
  ///
  /// Each doomed row is judged again inside the delete's own transaction
  /// ([mediaRowLivesOn] as `keepIf`), so one relinked to a surviving parent
  /// since the plan survives, even if the relink lands during the
  /// coordinator's queue write. [recheckDoomed] only drops the rows already
  /// relinked beforehand. Batches are bounded: the coordinator tombstones
  /// their enrichment with one list per call, and a whole library can pass
  /// what one statement binds.
  Future<void> _applyMediaCascade(String diverId, MediaCascadePlan plan) async {
    try {
      await unlinkMediaFromDeletedParents(_db, _syncRepository, plan.survivors);
    } catch (e, stackTrace) {
      _log.error(
        'Deleted diver $diverId, but could not publish the unlinks of the '
        'media that outlived it',
        error: e,
        stackTrace: stackTrace,
      );
    }

    final List<MediaItem> doomed;
    try {
      doomed = await recheckDoomed(_db, plan);
    } catch (e, stackTrace) {
      _log.error(
        'Deleted diver $diverId, but could not read the media only it linked',
        error: e,
        stackTrace: stackTrace,
      );
      return;
    }
    for (var i = 0; i < doomed.length; i += mediaCascadeIdChunk) {
      final batch = doomed.sublist(
        i,
        i + mediaCascadeIdChunk < doomed.length
            ? i + mediaCascadeIdChunk
            : doomed.length,
      );
      try {
        await _mediaDeletionCoordinator.deleteMediaItems(
          batch,
          keepIf: (row) => mediaRowLivesOn(row, plan.parents),
        );
      } catch (e, stackTrace) {
        _log.error(
          'Deleted diver $diverId, but could not delete ${batch.length} of '
          'the media only it linked',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
```

In `deleteDiverWithReassignment`, directly before `await _db.transaction(() async {`, add:

```dart
      // Set inside the transaction, applied after it commits.
      late final MediaCascadePlan mediaPlan;
```

Inside the transaction, after the Step 0 block (the `if (targetId != null) { ... }` that reassigns the shared trips and sites) and directly before `// Step 1: Null out cross-diver FK references to this diver's`, add the plan. Here, and not before the transaction: in one transaction the plan names exactly what the deletes remove, and after Step 0 the shared sites already belong to the survivor, so nothing has to be predicted.

```dart
        // Step 0b: Plan the media cascade (issue #1954). Here, after the
        // shared sites have gone to the survivor and before any delete: the
        // links still name the parents, which the deletes below clear with
        // ON DELETE SET NULL and no stamp, and in one transaction the plan
        // names exactly the rows this delete removes.
        mediaPlan = await planMediaCascade(_db, await _dyingMediaParents(id));
```

Directly after `await deleteDiverRows(_db, _syncRepository, id, diverDiveSteps);`, add:

```dart
        // Those dive deletes cascaded their media enrichment away, and a
        // cascade logs nothing. Tombstone it here, from ids read before the
        // transaction, so it rolls back with the delete (spec 5.3, 5.4).
        await _syncRepository.logDeletions(
          entityType: 'mediaEnrichment',
          recordIds: mediaPlan.enrichmentIds,
        );
```

After the transaction, directly after its closing `});` and before the comment that begins `// The cascade above took dive_data_sources rows`, add:

```dart
      await _applyMediaCascade(id, mediaPlan);
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `dart format lib test && flutter test test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`
Expected: `All tests passed!` (13 tests).

- [ ] **Step 6: Mutation-check the diver-specific rules**

```bash
cp lib/features/divers/data/repositories/diver_repository.dart "$SCRATCH/diver_repository.dart.bak"
```

(a) Move the `mediaPlan = await planMediaCascade(...)` line above the Step 0 block. Expected: `a photo on a shared site the survivor inherits outlives the delete` FAILS (the shared site is still the diver's when planned, so the photo is doomed). Restore.

(b) Comment out the `logDeletions(entityType: 'mediaEnrichment', ...)` call. Expected: `the enrichment the diver's dives take with them is tombstoned` FAILS. Restore.

(c) Comment out `await _applyMediaCascade(id, mediaPlan);`. Expected: the dive-only, shared-site, gear and signature tests FAIL. Restore.

(d) Add `rethrow;` at the end of the catch around a deletion batch in `_applyMediaCascade`. Expected: `a cleanup failure after the commit is logged, not rethrown` FAILS. Restore.

(e) Drop the `keepIf:` argument from the coordinator call in `_applyMediaCascade`. Expected: `a photo relinked while its deletion is under way is kept` FAILS. Restore.

(f) Move the survivors' `try` block below the deletion loop and add `return;` to a failed batch's catch. Expected: `a failed deletion still publishes the unlinks of surviving media` FAILS. Restore and rerun: all pass.

- [ ] **Step 7: Run the existing diver and census suites**

Run: `flutter test test/features/divers test/core/database/dive_stats_scope_census_test.dart`
Expected: all pass. The census splits `diver_repository.dart` into one chunk per member and needs the marker inside `_dyingMediaParents`'s chunk, which is why it sits in the body rather than above the signature.

- [ ] **Step 8: Record the scope in the spec**

In `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 5.4, after the sentence ending `Originals are never touched.`, insert:

```markdown
The diver's buddies go too, and `media.signer_id` is also `ON DELETE SET
NULL`, so a surviving signature whose signer was one of them has
`signer_id` cleared, stamped and marked pending with the other unlinks. A
signer is not a logbook link: it never keeps a row alive or dooms one. The
media enrichment the diver's dives cascade away is tombstoned inside the
transaction, from ids read before it. The per-entity partitions cannot be
chained here, because each keeps a row another dying parent still links, so
the plan classifies every row against all the dying sets at once.
```

- [ ] **Step 9: Commit**

```bash
git add lib/features/divers/data/repositories/diver_repository.dart lib/features/media/data/repositories/media_repository.dart lib/features/media_store/data/media_deletion_coordinator.dart test/features/divers/data/repositories/diver_delete_media_cascade_test.dart docs/superpowers/specs/2026-09-18-media-sync-program-design.md
git commit -m "fix(divers): a diver delete cascades their media like the single-entity deletes"
```

---

### Task 3: Scenario S9 goes green

**Files:**
- Modify: `test/helpers/two_device_media_harness.dart` (`deleteDiver`, near line 459)
- Modify: `test/features/media/two_device/deletion_scenarios_test.dart` (S9's `skip:`)

**Interfaces:**
- Consumes (Task 2): `DiverRepository({MediaDeletionCoordinator? mediaDeletionCoordinator})`.
- Produces: nothing new.

- [ ] **Step 1: Unskip S9**

In `deletion_scenarios_test.dart`, delete these two lines from the end of the S9 test (grep for `skip:` if the formatter has joined them onto the `},` line):

```dart
    skip:
        'Media sync program S9: turns green in slice 6 (diver delete cascade)',
```

- [ ] **Step 2: Run S9 to see which assertion stops it**

Run: `flutter test test/features/media/two_device/deletion_scenarios_test.dart`
Expected: FAIL at the `hasLength(1)` expectation whose reason is `the uploaded copy must be scheduled for removal`: this device's queue holds no delete intent. The row itself is gone, so Task 2 works; the harness builds `DiverRepository()`, whose default coordinator writes to the global cache database instead of this device's. The harness never points that at a device, so the intent lands elsewhere or the enqueue throws and is logged.

- [ ] **Step 3: Give the harness delete this device's queue**

In `two_device_media_harness.dart`, replace `deleteDiver`:

```dart
  Future<void> deleteDiver(String id) async {
    await activate();
    // This device's queue: a default coordinator writes to the global cache
    // database, which the harness never points at a device.
    await DiverRepository(
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => queue,
      ),
    ).deleteDiverWithReassignment(id);
  }
```

Add `import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';` to the harness if it is not already imported.

- [ ] **Step 4: Run the two-device suite**

Run: `flutter test test/features/media/two_device`
Expected: all pass, S9 included; the remaining skips are the scenarios later slices own (S4 to S8, S10).

- [ ] **Step 5: Commit**

```bash
git add test/helpers/two_device_media_harness.dart test/features/media/two_device/deletion_scenarios_test.dart
git commit -m "test(media): S9 turns green, the diver delete reaches the peer"
```

---

### Task 4: Branch verification and the pull request

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run every affected suite**

Run: `flutter test test/features/divers test/features/media test/features/media_store test/core/services/sync test/core/database test/core/data test/architecture > "$SCRATCH/s6_tests.log" 2>&1; echo "exit=$?"; tail -3 "$SCRATCH/s6_tests.log"`
Expected: `exit=0`, `All tests passed!`. Capture to a file, never pipe `flutter test` into `grep` or `tail`: the pipe hides the exit status.

- [ ] **Step 3: Push and open the PR (ask the owner first)**

Push with `git push -u origin ericgriffin/media-sync-s6-diver-delete`. Open against `main`. The body must carry, one keyword per issue:

```markdown
Closes #2108
Closes #1954
Part of #2090
```

and say it is stacked on #2239 (slice 4) and carries its commits until that merges.
