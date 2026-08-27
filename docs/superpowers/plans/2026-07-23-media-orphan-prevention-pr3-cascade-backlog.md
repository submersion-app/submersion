# Media Orphan Prevention PR 3: Dive-Deletion Cascade + Backlog Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dive deletion deletes its dive-only media (rows + cloud blobs via
PR 2's fast path) instead of silently unlinking it, and a one-time startup
sweep clears the existing orphan-row backlog — both honoring the amended
safe predicate (spec section 3, verification gate RESOLVED).

**Architecture:** PR 3 of 4 from
`docs/superpowers/specs/2026-07-23-media-store-orphan-prevention-design.md`
(sections 3, 4.2, 4.3 as amended 2026-07-23). The gate audit found two
protected classes: `networkUrl` / `manifestEntry` rows are legitimate
library-level media (never deleted for being unlinked; cascade reverts them
to library instead), and all other creators always set `diveId`, so a
null/null non-library row can only be past-dive-deletion residue.
`DiveRepositoryImpl` gets an optional injected `MediaDeletionCoordinator`
(PR 2) so cascaded deletions reuse the enqueue-before-delete blob path; the
sweep is a SharedPreferences-flagged one-shot service that feeds the same
coordinator.

**Tech Stack:** Flutter/Dart, Drift, Riverpod, flutter_test.

## Global Constraints

- Branch `worktree-media-orphan-pr3`, created FROM `worktree-media-orphan-pr2`
  with `worktree-media-orphan-pr1` merged in (PR 3 consumes PR 1's
  `isLinkedToDiveOrSite` and PR 2's coordinator). PR base =
  `worktree-media-orphan-pr2`; merge bottom-up (#697, #702, then this).
  After worktree creation: `git submodule update --init --recursive`,
  `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`,
  and verify `git ls-tree HEAD packages/libdivecomputer_plugin/third_party/libdivecomputer`
  matches origin/main after the PR 1 merge (submodule merge trap).
- `dart format .` clean; `flutter analyze` clean (infos fatal). No emojis.
- No main-DB schema change (sweep flag lives in SharedPreferences; v136
  remains reserved for PR 4).
- Single-enqueuer rule: sync tombstone application stays untouched.
- The protected source types are exactly `'networkUrl'` and
  `'manifestEntry'` (`MediaSourceType.name` strings).
- PR description: substantive summary only; no attribution/session links.

---

### Task 1: MediaRepository — cascade partition, unlink, and sweepable query

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
  (beside `isLinkedToDiveOrSite`, ~line 909)
- Test: `test/features/media/data/media_repository_cascade_test.dart` (new)

**Interfaces:**
- Produces (consumed by Tasks 2-3):
  - `static const List<String> libraryLevelSourceTypes = ['networkUrl', 'manifestEntry'];`
  - `Future<({List<domain.MediaItem> doomed, List<String> unlinkIds})> partitionMediaForDiveDeletion(List<String> diveIds)`
    — rows with `diveId IN diveIds` split: `doomed` = `siteId IS NULL AND
    sourceType NOT IN libraryLevelSourceTypes` (full items, the coordinator
    needs hashes); `unlinkIds` = the rest (site-linked or library-level).
  - `Future<void> unlinkMediaFromDeletedDives(List<String> mediaIds)` —
    sets `diveId = NULL`, bumps `updatedAt`, calls
    `markRecordPending(entityType: 'media', ...)` per row (the unlink must
    sync; today's silent FK SET NULL never did), fires
    `SyncEventBus.notifyLocalChange()` once.
  - `Future<List<String>> getSweepableOrphanIds({required DateTime olderThan})`
    — ids where NOT `isLinkedToDiveOrSite` AND
    `sourceType NOT IN libraryLevelSourceTypes` AND
    `createdAt < olderThan.millisecondsSinceEpoch`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/data/media_repository_cascade_test.dart`.
Reuse the fixture idiom from
`test/features/media/data/media_repository_backfill_scope_test.dart`
(same `insertDive`/`insertSite`/`item(...)` helpers — copy them; the item
helper additionally needs a `sourceType` parameter and `contentHash`).
Test cases (full assertions, ids via the returned `MediaItem.id`):

```dart
  test('partitionMediaForDiveDeletion splits doomed from unlink', () async {
    await insertDive('d1');
    await insertSite('s1');
    final doomed = await repo.createMedia(
      item('a.jpg', diveId: 'd1'), // dive-only gallery photo
    );
    final siteLinked = await repo.createMedia(
      item('b.jpg', diveId: 'd1', siteId: 's1'),
    );
    final library = await repo.createMedia(
      item('c.jpg', diveId: 'd1', sourceType: MediaSourceType.networkUrl),
    );
    await repo.createMedia(item('other.jpg')); // unrelated row

    final split = await repo.partitionMediaForDiveDeletion(['d1']);
    expect(split.doomed.map((m) => m.id), [doomed.id]);
    expect(split.unlinkIds.toSet(), {siteLinked.id, library.id});
  });

  test('unlinkMediaFromDeletedDives nulls diveId and stamps sync', () async {
    await insertDive('d1');
    final m = await repo.createMedia(item('a.jpg', diveId: 'd1'));
    await repo.unlinkMediaFromDeletedDives([m.id]);
    final got = await repo.getMediaById(m.id);
    expect(got!.diveId, isNull);
  });

  test('getSweepableOrphanIds honours linkage, source type, and age',
      () async {
    await insertDive('d1');
    final oldOrphan = await repo.createMedia(item('old.jpg'));
    final libraryOrphan = await repo.createMedia(
      item('lib.jpg', sourceType: MediaSourceType.manifestEntry),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    // Age guard: only rows older than the cutoff qualify. Fixture rows are
    // created "now", so a future cutoff includes them and a past cutoff
    // excludes them.
    final future = DateTime.now().add(const Duration(days: 1));
    final past = DateTime.now().subtract(const Duration(days: 1));
    expect(await repo.getSweepableOrphanIds(olderThan: future), [oldOrphan.id]);
    expect(await repo.getSweepableOrphanIds(olderThan: past), isEmpty);
    expect(
      await repo.getSweepableOrphanIds(olderThan: future),
      isNot(contains(libraryOrphan.id)),
    );
    expect(
      await repo.getSweepableOrphanIds(olderThan: future),
      isNot(contains(linked.id)),
    );
  });
```

NOTE: `createMedia` stamps `createdAt` itself; if it preserves the passed
`item.createdAt`, prefer creating the old orphan with
`createdAt: DateTime(2025)` and using a fixed `olderThan: DateTime(2026)`
cutoff instead of now-relative times — read `createMedia` first and pick
whichever the implementation supports deterministically.

- [ ] **Step 2: Run — expect FAIL (methods undefined)**

Run: `flutter test test/features/media/data/media_repository_cascade_test.dart`

- [ ] **Step 3: Implement the four members**

In `media_repository.dart`, next to `isLinkedToDiveOrSite`:

```dart
  /// Source types whose rows are legitimate as library-level media with no
  /// dive/site linkage (orphan-prevention spec section 3, gate audit
  /// 2026-07-23): URL-tab and manifest-subscription imports. Auto-match is
  /// additive for them, so unlinkedness is a normal permanent state - the
  /// cascade unlinks instead of deleting, and the sweep never touches them.
  static const List<String> libraryLevelSourceTypes = [
    'networkUrl',
    'manifestEntry',
  ];

  /// Splits a dying dive's media (orphan-prevention spec 4.2): [doomed]
  /// rows die with the dive (dive-only, non-library - full items because
  /// the blob-delete intent needs contentHash/filename/type); [unlinkIds]
  /// survive as site-linked or library-level rows with diveId nulled.
  Future<({List<domain.MediaItem> doomed, List<String> unlinkIds})>
  partitionMediaForDiveDeletion(List<String> diveIds) async {
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    final doomed = <domain.MediaItem>[];
    final unlinkIds = <String>[];
    for (final row in rows) {
      final keep =
          row.siteId != null ||
          libraryLevelSourceTypes.contains(row.sourceType);
      if (keep) {
        unlinkIds.add(row.id);
      } else {
        doomed.add(_mapRowToMediaItem(row));
      }
    }
    return (doomed: doomed, unlinkIds: unlinkIds);
  }

  /// Explicitly unlinks surviving media from deleted dives, with the HLC
  /// stamp the old silent FK SET NULL never produced - so the unlink
  /// propagates to other devices instead of diverging.
  Future<void> unlinkMediaFromDeletedDives(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        MediaCompanion(diveId: const Value(null), updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Backlog-sweep candidates (orphan-prevention spec 4.3): unlinked,
  /// non-library, and older than [olderThan] (the 24h age guard protects
  /// any future add-then-link creator the gate audit could not foresee).
  Future<List<String>> getSweepableOrphanIds({
    required DateTime olderThan,
  }) async {
    final id = _db.media.id;
    final query = _db.selectOnly(_db.media)
      ..addColumns([id])
      ..where(
        isLinkedToDiveOrSite(_db.media).not() &
            _db.media.sourceType.isNotIn(libraryLevelSourceTypes) &
            _db.media.createdAt.isSmallerThanValue(
              olderThan.millisecondsSinceEpoch,
            ),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(id)!).toList();
  }
```

Adapt to the file's actual idioms after reading it: `_mapRowToMediaItem`
may require an enrichment row parameter (pass none/null the way
`getMediaById` does), `createdAt` may be a different column accessor, and
`markRecordPending`'s exact signature is visible in `stampRemoteUploaded`
(~line 895).

- [ ] **Step 4: Run — expect PASS. Also run the existing media data suites:**

Run: `flutter test test/features/media/data/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_repository_cascade_test.dart
git commit -m "feat(media): cascade partition, synced unlink, and sweepable-orphan query"
```

---

### Task 2: Dive-deletion cascade in DiveRepositoryImpl

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
  (`deleteDive` ~line 1473, `bulkDeleteDives` ~line 1491; constructor)
- Modify: `lib/features/dive_log/presentation/providers/dive_repository_provider.dart`
  (wire the coordinator + MediaRepository in)
- Test: `test/features/dive_log/data/dive_deletion_cascade_test.dart` (new)

**Interfaces:**
- Consumes: Task 1's `partitionMediaForDiveDeletion` / `unlinkMediaFromDeletedDives`;
  PR 2's `MediaDeletionCoordinator.deleteMultipleMedia` (enqueue-before-delete,
  tombstones, worker kick, failure isolation — all reused).
- Produces: `DiveRepositoryImpl` gains optional constructor params
  `MediaRepository? mediaRepository` and
  `MediaDeletionCoordinator? mediaDeletionCoordinator` (both nullable so
  existing direct constructions/tests compile unchanged; null coordinator
  degrades to `MediaRepository.deleteMultipleMedia` — rows + tombstones,
  no blob intents).

- [ ] **Step 1: Read the current wiring**

Read `dive_repository_impl.dart`'s constructor/fields and
`dive_repository_provider.dart` (it is a dependency-only module created to
avoid import cycles — note what it may import). Confirm:
- how `_db` / `_syncRepository` are obtained;
- that importing `media_deletion_coordinator.dart` +
  `media_transfer_queue_repository.dart` (data-layer) plus
  `media_repository.dart` does not create a NEW import cycle at the
  provider level. If the provider file cannot see
  `mediaDeletionCoordinatorProvider` without a cycle, construct the
  coordinator inline from data classes:
  `MediaDeletionCoordinator(mediaRepository: MediaRepository(), queue: () => MediaTransferQueueRepository())`
  (no kickWorker — a queued intent drains on the next connectivity event,
  app start, or any enqueueAndKick; the PR 4 sweep is the backstop).

- [ ] **Step 2: Write the failing tests**

Create `test/features/dive_log/data/dive_deletion_cascade_test.dart` with
an in-memory app DB (`setUpTestDatabase`), a real `MediaRepository`, a real
`MediaTransferQueueRepository` over an in-memory `LocalCacheDatabase`, and
a real `MediaDeletionCoordinator` wired to them. Construct
`DiveRepositoryImpl` the way its existing tests do (find one under
`test/features/dive_log/` and mirror), passing the new params. Cases:

```dart
  test('deleteDive deletes dive-only media with tombstone and blob intent',
      () async {
    // dive d1 with an uploaded gallery photo (contentHash + remote stamp)
    // -> after deleteDive('d1'): media row gone, deletion_log has a media
    // tombstone for it, queue has one direction='delete' entry with the
    // photo's hash.
  });

  test('site-linked media survives with diveId nulled and syncs', () async {
    // d1 + photo linked to d1 AND site s1 -> after deleteDive: row exists,
    // diveId null, siteId 's1'.
  });

  test('library-level media reverts to library instead of dying', () async {
    // d1 + networkUrl row auto-matched to d1 -> after deleteDive: row
    // exists, diveId null; queue empty.
  });

  test('bulkDeleteDives cascades across all deleted dives', () async {
    // d1, d2 each with one dive-only photo -> both rows gone, two
    // tombstones, two delete intents (distinct hashes).
  });

  test('never-uploaded dive-only media dies without a blob intent',
      () async {
    // d1 + photo with no contentHash/stamps -> row gone, tombstone
    // written, queue empty.
  });
```

Write these as real tests (the deletion-log assertion can query
`db.select(db.deletionLog)` filtered on entityType 'media' — check the
table/DAO name in `database.dart`; mirror how existing sync tests assert
tombstones, e.g. grep `logDeletion` in `test/`).

- [ ] **Step 3: Run — expect FAIL** (constructor params / cascade absent)

- [ ] **Step 4: Implement**

In `deleteDive`, before the existing dive-row delete (and mirrored in
`bulkDeleteDives` with the ids list):

```dart
      final mediaRepo = _mediaRepository;
      if (mediaRepo != null) {
        final split = await mediaRepo.partitionMediaForDiveDeletion([id]);
        if (split.doomed.isNotEmpty) {
          final doomedIds = split.doomed.map((m) => m.id).toList();
          final coordinator = _mediaDeletionCoordinator;
          if (coordinator != null) {
            // Enqueue-before-delete blob intents + rows + tombstones.
            await coordinator.deleteMultipleMedia(doomedIds);
          } else {
            await mediaRepo.deleteMultipleMedia(doomedIds);
          }
        }
        if (split.unlinkIds.isNotEmpty) {
          await mediaRepo.unlinkMediaFromDeletedDives(split.unlinkIds);
        }
      }
```

Keep the cascade OUTSIDE any new transaction wrapping the dive delete: the
coordinator's queue writes live in another database, and every step is
individually idempotent/tombstoned — a crash between cascade and dive
delete leaves a re-deletable dive, never an orphan. Wire the two new
params in `dive_repository_provider.dart` per Step 1's findings.

- [ ] **Step 5: Run the new test file, then the dive_log + consolidation/merge suites**

Run: `flutter test test/features/dive_log test/features/universal_import test/features/import_wizard`
Expected: all pass. The merge/consolidation services reassign media to the
surviving dive BEFORE `bulkDeleteDives`, so the cascade must see no doomed
media for merged-away dives — if any consolidation/merge test fails on
missing media, STOP and re-read the reassignment ordering rather than
weakening the cascade.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive): dive deletion cascades to dive-only media"
```

---

### Task 3: One-time backlog sweep

**Files:**
- Create: `lib/features/media_store/data/media_orphan_backlog_sweep.dart`
- Modify: the app-startup hook point (found in Step 1) + provider file
- Test: `test/features/media_store/media_orphan_backlog_sweep_test.dart` (new)

**Interfaces:**
- Consumes: Task 1's `getSweepableOrphanIds`, PR 2's coordinator.
- Produces:

```dart
class MediaOrphanBacklogSweep {
  MediaOrphanBacklogSweep({
    required MediaRepository mediaRepository,
    required MediaDeletionCoordinator coordinator,
    required Future<SharedPreferences> Function() prefs,
  });

  static const flagKey = 'media_orphan_backlog_swept_v1';

  /// Runs at most once per device (persisted flag, set only on success).
  /// Returns the number of rows swept (0 on skip).
  Future<int> runIfNeeded({DateTime? now});
}
```

- [ ] **Step 1: Find the startup hook**

The sweep must run regardless of media-store attachment (orphan rows leak
into sync and backfill even with no store connected), so
`mediaStoreRuntimeProvider` is the WRONG host. Grep for existing
post-startup one-shots (`grep -rn "addPostFrameCallback\|FutureProvider" lib/app lib/main.dart lib/core/app` and how
`mediaTransferQueueReclaimProvider` gets awaited) and pick the app-shell
init point where other once-per-launch work runs; expose the sweep as a
`FutureProvider<int>` read (not watched) there, after the database is
open. It must never block first frame — fire-and-forget with logging.

- [ ] **Step 2: Failing tests**

`media_orphan_backlog_sweep_test.dart`, with `SharedPreferences.setMockInitialValues({})`:

```dart
  test('sweeps old unlinked non-library rows once', () async {
    // one old orphan gallery row (createdAt 2025, uploaded w/ hash),
    // one networkUrl orphan, one dive-linked row.
    final swept = await sweep.runIfNeeded(now: DateTime(2026, 7, 23));
    expect(swept, 1);
    // orphan gone + tombstoned + delete intent enqueued;
    // networkUrl + linked rows untouched.
    expect(await sweep.runIfNeeded(now: DateTime(2026, 7, 23)), 0,
        reason: 'flag persists');
  });

  test('flag is not set when the coordinator throws', () async {
    // coordinator wired to a queue factory that throws is FINE (it
    // swallows); instead force MediaRepository failure by closing the DB
    // -> runIfNeeded rethrows, flag unset, next run retries.
  });
```

- [ ] **Step 3: Implement**

```dart
  Future<int> runIfNeeded({DateTime? now}) async {
    final p = await _prefs();
    if (p.getBool(flagKey) ?? false) return 0;
    final cutoff = (now ?? DateTime.now()).subtract(
      const Duration(hours: 24),
    );
    final ids = await _mediaRepository.getSweepableOrphanIds(
      olderThan: cutoff,
    );
    if (ids.isNotEmpty) {
      await _coordinator.deleteMultipleMedia(ids);
    }
    await p.setBool(flagKey, true);
    return ids.length;
  }
```

- [ ] **Step 4: Run — expect PASS.** Then wire the startup hook (Step 1's
  location), run `flutter analyze`, and the media suites.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media_store lib/core lib/app test/features/media_store
git commit -m "feat(media-store): one-time backlog sweep for orphaned media rows"
```

---

### Task 4: Project-wide verification + PR

- [ ] `dart format .` — no changes.
- [ ] `flutter analyze` — clean.
- [ ] `flutter test test/features/media test/features/media_store test/features/dive_log test/core` — pass.
- [ ] `flutter test` (full suite) — pass; isolate-verify any backup-family
  flake before `--no-verify`.
- [ ] Push `worktree-media-orphan-pr3`; open PR with base
  `worktree-media-orphan-pr2` titled
  "feat(dive): dive deletion cascades to media + orphan backlog sweep".
  Body covers: the amended predicate (gate findings: library-level
  networkUrl/manifestEntry protected; signatures die with their dive), the
  cascade partition, the synced unlink (fixes the silent FK SET NULL sync
  divergence), the flagged one-shot sweep, and the merge/consolidation
  ordering regression coverage. Note merge order: #697, #702, then this
  (GitHub auto-retargets). No attribution/session links.

---

## Not in this PR

- Verify Library sweep, multipart reaping, `media_stores.last_sweep_at`
  (schema v136) — PR 4.
- Any UI for browsing library-level (unlinked) media — existing surfaces
  already list networkUrl/manifestEntry rows by source/subscription.
