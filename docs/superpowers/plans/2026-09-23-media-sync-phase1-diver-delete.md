# Media Sync Slice 6: Diver Delete Media Cascade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deleting a diver deletes the media only that diver's rows linked, and unlinks, stamps and publishes the media a surviving row still links, so every device converges and uploaded copies are scheduled for removal.

**Architecture:** A new `media_parent_cascade.dart` plans the cascade before the diver delete's transaction, while the media links still name the dying parents, and applies it after the transaction commits. Doomed rows go through the existing `MediaDeletionCoordinator` (tombstones plus blob-delete intents). Survivors get their dying links cleared with `NULLIF`, a fresh `updated_at` and a pending mark. The media enrichment the dive deletes cascade away is tombstoned inside the transaction from ids read before it.

**Tech Stack:** Flutter, Dart, Drift over SQLite, the in-house changeset sync (`SyncRepository`), `flutter_test` with in-memory databases, the two-device media harness.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 5.4 (and 5.3 for the enrichment tombstones). Sub-issue #2108, closes #1954, part of #2090. Stacked on slice 4 (#2239).

> **Revised in review (PR #2289).** Two changes to what the tasks below
> describe. The plan is read inside the delete's transaction, after Step 0
> reassigns the shared sites and before any delete, not before the
> transaction; so `_dyingMediaParents` takes no `hasSurvivor` and no longer
> predicts Step 0 with `is_shared = 0`. And `recheckDoomed` reads each doomed
> row again before it is deleted, sparing one relinked between the commit
> and the apply. Every id list is read in chunks of `mediaCascadeIdChunk`
> (900): the bundled SQLite (3.53.3) binds at most 32766 variables per
> statement, measured.

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
2. **After the commit, the links are already gone.** `media.dive_id`, `site_id`, `equipment_id` and `signer_id` are all `ON DELETE SET NULL`. Once the transaction commits, SQLite has cleared them locally, with no stamp and no pending mark. Slice 4's `unlinkMediaFromDeletedDives` scopes its write with `dive_id IN (dying dives)`, which matches nothing at that point and returns early without marking anything. So the plan must be read before the transaction, and the survivor write must not depend on the link still being set.

## File Structure

- Create `lib/features/media/data/repositories/media_parent_cascade.dart`: the value types (`DyingMediaParents`, `MediaSurvivor`, `MediaCascadePlan`) and two top-level functions, `planMediaCascade` and `unlinkMediaFromDeletedParents`. Top-level functions taking the database, like `diver_delete_steps.dart`, so `media_repository.dart` (2,639 lines) does not grow.
- Create `test/features/media/data/media_parent_cascade_test.dart`: unit tests for both functions.
- Modify `lib/features/divers/data/repositories/diver_repository.dart`: inject the coordinator, plan before the transaction, tombstone enrichment inside it, apply after it.
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
  - `class DyingMediaParents { const DyingMediaParents({Set<String> diveIds, Set<String> siteIds, Set<String> equipmentIds, Set<String> buddyIds}); bool get isEmpty; }`
  - `class MediaSurvivor { const MediaSurvivor(String id, {String? diveId, String? siteId, String? equipmentId, String? signerId}); }` where each named field is the dying parent the row linked, or null.
  - `class MediaCascadePlan { const MediaCascadePlan({List<domain.MediaItem> doomed, List<MediaSurvivor> survivors, List<String> enrichmentIds}); static const empty; }`
  - `Future<MediaCascadePlan> planMediaCascade(AppDatabase db, DyingMediaParents parents)`
  - `Future<void> unlinkMediaFromDeletedParents(AppDatabase db, SyncRepository sync, List<MediaSurvivor> survivors)`

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/media_parent_cascade_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
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

    test('a row a surviving parent links is kept, naming only its dying '
        'links', () async {
      final keptBySite = await photo(dive: 'd-dying', site: 's-kept');
      final keptByDive = await photo(dive: 'd-kept', gear: 'g-dying');

      final plan = await planMediaCascade(db, dying);

      expect(plan.doomed, isEmpty);
      final byId = {for (final s in plan.survivors) s.id: s};
      expect(byId[keptBySite]!.diveId, 'd-dying');
      expect(byId[keptBySite]!.siteId, isNull, reason: 'the site survives');
      expect(byId[keptByDive]!.equipmentId, 'g-dying');
      expect(byId[keptByDive]!.diveId, isNull, reason: 'the dive survives');
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

    test('no dying parents plans nothing', () async {
      await photo(dive: 'd-dying');

      final plan = await planMediaCascade(db, const DyingMediaParents());

      expect(plan.doomed, isEmpty);
      expect(plan.survivors, isEmpty);
      expect(plan.enrichmentIds, isEmpty);
    });
  });

  group('unlinkMediaFromDeletedParents', () {
    test('clears the dying links, keeps the rest, stamps and marks pending',
        () async {
      final id = await photo(dive: 'd-dying', site: 's-kept', signer: 'b-dying');
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
    });

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

    test('a row deleted since the plan is not marked', () async {
      await unlinkMediaFromDeletedParents(db, SyncRepository(), const [
        MediaSurvivor('gone', diveId: 'd-dying'),
      ]);

      expect(await isPending('gone'), isFalse);
    });
  });
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

/// What a deletion does to its parents' media, read before it runs.
class MediaCascadePlan {
  const MediaCascadePlan({
    this.doomed = const [],
    this.survivors = const [],
    this.enrichmentIds = const [],
  });

  static const empty = MediaCascadePlan();

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

  final rows = await (db.select(db.media)..where((m) {
        final reaches = <Expression<bool>>[
          if (parents.diveIds.isNotEmpty) m.diveId.isIn(parents.diveIds),
          if (parents.siteIds.isNotEmpty) m.siteId.isIn(parents.siteIds),
          if (parents.equipmentIds.isNotEmpty)
            m.equipmentId.isIn(parents.equipmentIds),
          if (parents.buddyIds.isNotEmpty) m.signerId.isIn(parents.buddyIds),
        ];
        return reaches.reduce((a, b) => a | b);
      }))
      .get();

  String? dyingOf(String? link, Set<String> dying) =>
      link != null && dying.contains(link) ? link : null;

  final doomed = <domain.MediaItem>[];
  final survivors = <MediaSurvivor>[];
  for (final row in rows) {
    final dive = dyingOf(row.diveId, parents.diveIds);
    final site = dyingOf(row.siteId, parents.siteIds);
    final gear = dyingOf(row.equipmentId, parents.equipmentIds);
    final linked =
        row.diveId != null || row.siteId != null || row.equipmentId != null;
    final kept =
        (row.diveId != null && dive == null) ||
        (row.siteId != null && site == null) ||
        (row.equipmentId != null && gear == null);
    if (linked && !kept) {
      doomed.add(mediaItemFromRow(row));
    } else {
      survivors.add(
        MediaSurvivor(
          row.id,
          diveId: dive,
          siteId: site,
          equipmentId: gear,
          signerId: dyingOf(row.signerId, parents.buddyIds),
        ),
      );
    }
  }

  final enrichmentIds = parents.diveIds.isEmpty
      ? const <String>[]
      : [
          for (final e in await (db.select(
            db.mediaEnrichment,
          )..where((t) => t.diveId.isIn(parents.diveIds))).get())
            e.id,
        ];

  return MediaCascadePlan(
    doomed: doomed,
    survivors: survivors,
    enrichmentIds: enrichmentIds,
  );
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
Future<void> unlinkMediaFromDeletedParents(
  AppDatabase db,
  SyncRepository sync,
  List<MediaSurvivor> survivors,
) async {
  if (survivors.isEmpty) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.transaction(() async {
    for (final s in survivors) {
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
      if (written == 0) continue;
      await sync.markRecordPending(
        entityType: 'media',
        recordId: s.id,
        localUpdatedAt: now,
      );
    }
  });
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart format lib test && flutter test test/features/media/data/media_parent_cascade_test.dart`
Expected: `All tests passed!` (9 tests).

- [ ] **Step 5: Mutation-check the two rules that matter**

Back up the file first; never `git checkout` it (a checkout during a red check destroys the fix).

```bash
cp lib/features/media/data/repositories/media_parent_cascade.dart "$SCRATCH/media_parent_cascade.dart.bak"
```

(a) Replace `final kept =` expression with the dive partition's rule, `row.siteId != null || row.equipmentId != null;`. Run the test file. Expected: `a row whose every link is dying is doomed` FAILS (the dive-and-site row survives). Restore from the backup.

(b) Replace `'dive_id = NULLIF(dive_id, ?), '` with `'dive_id = CASE WHEN ? IS NULL THEN dive_id ELSE NULL END, '`. Run the test file. Expected: `a link that moved since the plan is kept` FAILS. Restore from the backup and rerun: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/media/data/repositories/media_parent_cascade.dart test/features/media/data/media_parent_cascade_test.dart
git commit -m "feat(media): plan a cascade over several dying parent sets at once"
```

---

### Task 2: The diver delete cascades its media

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (constructor near line 45; `deleteDiverWithReassignment` near line 330)
- Modify: `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` (section 5.4)
- Test: `test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`

**Interfaces:**
- Consumes (Task 1): `DyingMediaParents`, `MediaCascadePlan`, `planMediaCascade(AppDatabase, DyingMediaParents)`, `unlinkMediaFromDeletedParents(AppDatabase, SyncRepository, List<MediaSurvivor>)`. Also `MediaDeletionCoordinator.deleteMediaItems(List<MediaItem>)` and `SyncRepository.logDeletions({required String entityType, required Iterable<String> recordIds})`.
- Produces: `DiverRepository({ImportedFileReclaimer? importedFileReclaimer, MediaDeletionCoordinator? mediaDeletionCoordinator})`. Task 3 passes the coordinator.

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
    expect(
      await blobDeletes(),
      [id],
      reason: 'the uploaded copy must be scheduled for removal',
    );
  });

  test("a photo on the diver's dive and private site goes with both", () async {
    await insertDive('d1', 'diver-a');
    await insertSite('s1', 'diver-a');
    final id = await photo(dive: 'd1', site: 's1');

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await row(id), isNull, reason: 'neither parent survives');
  });

  test('a photo on a shared site the survivor inherits outlives the delete',
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
  });

  test('with no surviving diver the shared site goes too, and its photo',
      () async {
    await db.customStatement("DELETE FROM divers WHERE id = 'diver-b'");
    await insertDive('d1', 'diver-a');
    await insertSite('s1', 'diver-a', isShared: true);
    final id = await photo(dive: 'd1', site: 's1');

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await row(id), isNull);
  });

  test("gear paperwork another diver's dive uses loses only the gear link",
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
  });

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

  test("the enrichment the diver's dives take with them is tombstoned",
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
  });

  test("another diver's media is not touched", () async {
    await insertDive('d-b', 'diver-b');
    final id = await photo(dive: 'd-b');
    await db.customStatement(
      'UPDATE media SET updated_at = 1 WHERE id = ?',
      [id],
    );
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    expect((await row(id))!.updatedAt, 1);
    expect(await isPending(id), isFalse);
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/divers/data/repositories/diver_delete_media_cascade_test.dart`
Expected: compilation FAIL, `No named parameter with the name 'mediaDeletionCoordinator'`.

- [ ] **Step 3: Inject the coordinator**

In `diver_repository.dart`, add the imports (keep the existing grouping, alphabetical within the local block):

```dart
import 'package:submersion/features/media/data/repositories/media_parent_cascade.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
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

- [ ] **Step 4: Plan before the transaction, tombstone inside it, apply after it**

Add these two members to `DiverRepository`, directly above the doc comment of `deleteDiverWithReassignment` (anchor on the doc comment's first line, `/// Delete a diver, reassigning shared trips/sites to a surviving diver first.`, not on the signature, or the doc comment splits):

```dart
  /// The parents of media that [deleteDiverWithReassignment] removes,
  /// mirroring its step lists (`diver_delete_steps.dart`): every dive, piece
  /// of gear and buddy of the diver, and the sites Step 0 does not hand to a
  /// survivor. Read before the transaction, so it has to predict Step 0:
  /// with a survivor the shared sites are reassigned and live on.
  Future<DyingMediaParents> _dyingMediaParents(
    String id, {
    required bool hasSurvivor,
  }) async => DyingMediaParents(
    // stats-scope-exempt: a deletion cascade, not a statistic.
    diveIds: (await _idsOf('SELECT id FROM dives WHERE diver_id = ?', [
      id,
    ])).toSet(),
    siteIds: (await _idsOf(
      hasSurvivor
          ? 'SELECT id FROM dive_sites WHERE diver_id = ? AND is_shared = 0'
          : 'SELECT id FROM dive_sites WHERE diver_id = ?',
      [id],
    )).toSet(),
    equipmentIds: (await _idsOf('SELECT id FROM equipment WHERE diver_id = ?', [
      id,
    ])).toSet(),
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
  /// cannot be restored, and what is left is recoverable (unlinked rows for
  /// the orphan sweep, a missed blob intent for the Verify Library sweep).
  Future<void> _applyMediaCascade(
    String diverId,
    MediaCascadePlan plan,
  ) async {
    try {
      if (plan.doomed.isNotEmpty) {
        await _mediaDeletionCoordinator.deleteMediaItems(plan.doomed);
      }
      await unlinkMediaFromDeletedParents(_db, _syncRepository, plan.survivors);
    } catch (e, stackTrace) {
      _log.error(
        'Deleted diver $diverId, but could not clean up their media',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

```

In `deleteDiverWithReassignment`, directly after the block that sets `targetId` and `targetName` and before `await _db.transaction(() async {`, add:

```dart
      // Read before the transaction, while the links still name the
      // parents: the deletes below fire ON DELETE SET NULL on media, which
      // clears them locally with no stamp (issue #1954).
      final mediaPlan = await planMediaCascade(
        _db,
        await _dyingMediaParents(id, hasSurvivor: targetId != null),
      );
```

Inside the transaction, directly after `await deleteDiverRows(_db, _syncRepository, id, diverDiveSteps);`, add:

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
Expected: `All tests passed!` (9 tests).

- [ ] **Step 6: Mutation-check the diver-specific rules**

```bash
cp lib/features/divers/data/repositories/diver_repository.dart "$SCRATCH/diver_repository.dart.bak"
```

(a) Delete ` AND is_shared = 0` from the `hasSurvivor` query. Expected: `a photo on a shared site the survivor inherits outlives the delete` FAILS (the shared site is planned as dying and the photo is doomed). Restore.

(b) Comment out the `logDeletions(entityType: 'mediaEnrichment', ...)` call. Expected: `the enrichment the diver's dives take with them is tombstoned` FAILS. Restore.

(c) Comment out `await _applyMediaCascade(id, mediaPlan);`. Expected: the dive-only, shared-site, gear and signature tests FAIL. Restore and rerun: all pass.

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
git add lib/features/divers/data/repositories/diver_repository.dart test/features/divers/data/repositories/diver_delete_media_cascade_test.dart docs/superpowers/specs/2026-09-18-media-sync-program-design.md
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
