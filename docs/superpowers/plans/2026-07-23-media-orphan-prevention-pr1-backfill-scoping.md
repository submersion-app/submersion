# Media Orphan Prevention PR 1: Backfill Scoping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop "Upload library" from uploading media rows that are linked to
neither a dive nor a site, by scoping `getBackfillCandidateIds()` with a
shared linkage predicate.

**Architecture:** PR 1 of 4 from
`docs/superpowers/specs/2026-07-23-media-store-orphan-prevention-design.md`.
One new static predicate on `MediaRepository` (spec section 3: defined once,
reused later by the dive-deletion cascade and backlog sweep in PR 3) ANDed
onto the existing backfill WHERE clause, covering both the photo and video
arms. Plus test updates: existing fixtures create unlinked rows and assert
they ARE candidates, so they must link their rows to a dive.

**Tech Stack:** Flutter/Dart, Drift ORM, flutter_test with in-memory DBs.

## Global Constraints

- Work in a dedicated worktree (branch `worktree-media-orphan-pr1`), per
  CLAUDE.md; after creation run `git submodule update --init --recursive`,
  `flutter pub get`, and `dart run build_runner build --delete-conflicting-outputs`.
- `dart format .` must produce no changes before any commit.
- `flutter analyze` on the whole project must be clean (infos are fatal in
  CI).
- No emojis anywhere. No schema changes in this PR.
- PR description: substantive summary only; never include Claude attribution
  or session links.

---

### Task 1: Shared linkage predicate + scoped backfill query

**Files:**
- Create: `test/features/media/data/media_repository_backfill_scope_test.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart:908-934`
  (`getBackfillCandidateIds` and a new static predicate above it)

**Interfaces:**
- Consumes: `setUpTestDatabase()` from `test/helpers/test_database.dart`
  (returns `AppDatabase`, registers it in `DatabaseService`);
  `MediaRepository()` reads that registered DB.
- Produces: `static Expression<bool> MediaRepository.isLinkedToDiveOrSite($MediaTable m)`
  — PR 3 reuses this exact symbol for the cascade decision and backlog
  sweep. `getBackfillCandidateIds()` keeps its existing signature
  (`Future<List<String>>`).

- [ ] **Step 1: Write the failing regression test**

Create `test/features/media/data/media_repository_backfill_scope_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

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
        DiveSitesCompanion(
          id: Value(id),
          name: const Value('Reef'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(
    String name, {
    String? diveId,
    String? siteId,
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
    sourceType: sourceType,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    siteId: siteId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('unlinked media are never backfill candidates (orphan regression)',
      () async {
    await insertDive('dive-1');
    await insertSite('site-1');
    final linkedToDive = await repo.createMedia(
      item('a.jpg', diveId: 'dive-1'),
    );
    final linkedToSite = await repo.createMedia(
      item('b.jpg', siteId: 'site-1'),
    );
    // The observed bug, miniaturized: an orphan gallery photo (dive was
    // deleted; FK nulled dive_id) must not be uploaded.
    await repo.createMedia(item('orphan.jpg'));
    // The video arm has the same hole and must be scoped too.
    await repo.createMedia(
      item(
        'orphan.mp4',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.serviceConnector,
      ),
    );

    final ids = await repo.getBackfillCandidateIds();
    expect(ids.toSet(), {linkedToDive.id, linkedToSite.id});
  });
}
```

If `MediaItem`'s constructor rejects a named parameter used above (for
example `localPath`), mirror the constructor call in
`test/features/media_store/media_backfill_service_test.dart:35-58`, which
builds the same entity, and keep the `diveId`/`siteId` arguments.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/media_repository_backfill_scope_test.dart`

Expected: FAIL — the returned set also contains the two orphan ids
(today's query has no linkage filter). If it fails with a compile error
instead, fix the fixture, not the assertion.

- [ ] **Step 3: Implement the predicate and scope the query**

In `lib/features/media/data/repositories/media_repository.dart`, directly
above `getBackfillCandidateIds()` (line ~908), add:

```dart
  /// A media row is linked to the logbook when it references a dive or a
  /// site (orphan-prevention spec section 3). Single definition shared by
  /// backfill scoping, the dive-deletion cascade, and the orphan backlog
  /// sweep so the three predicates cannot drift apart.
  static Expression<bool> isLinkedToDiveOrSite($MediaTable m) =>
      m.diveId.isNotNull() | m.siteId.isNotNull();
```

Then change `getBackfillCandidateIds()`'s `where` to AND the predicate onto
the existing disjunction (both arms scoped at once), and note the scoping
in the doc comment:

```dart
  /// Backfill candidates (design spec section 9): device-resident photos
  /// not yet confirmed in the media store, newest first so recent dives
  /// gain protection soonest. Scoped to rows linked to a dive or site so
  /// orphaned rows are never uploaded (orphan-prevention spec section 4.1).
  Future<List<String>> getBackfillCandidateIds() async {
    final id = _db.media.id;
    final query = _db.selectOnly(_db.media)
      ..addColumns([id])
      ..where(
        isLinkedToDiveOrSite(_db.media) &
            ((_db.media.remoteUploadedAt.isNull() &
                    _db.media.remoteCompressedUploadedAt.isNull() &
                    _db.media.fileType.equals('photo') &
                    _db.media.sourceType.isIn([
                      'platformGallery',
                      'localFile',
                      'serviceConnector',
                    ])) |
                // Connector videos are thumb-only (no original in the store
                // by design), so their backfill signal is the missing thumb
                // stamp.
                (_db.media.remoteThumbUploadedAt.isNull() &
                    _db.media.fileType.equals('video') &
                    _db.media.sourceType.equals('serviceConnector'))),
      )
      ..orderBy([OrderingTerm.desc(_db.media.takenAt)]);
    final rows = await query.get();
    return rows.map((r) => r.read(id)!).toList();
  }
```

`Expression`, `$MediaTable`, and the drift operators are already available
through the file's existing imports (it already builds drift expressions);
if the analyzer reports `$MediaTable` undefined, import
`package:submersion/core/database/database.dart` is already present — do
not add a new import without checking.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/media/data/media_repository_backfill_scope_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/media/data/repositories/media_repository.dart \
  test/features/media/data/media_repository_backfill_scope_test.dart
git commit -m "fix(media): scope backfill candidates to dive- or site-linked media"
```

---

### Task 2: Relink fixtures in the backfill service test

The existing tests in
`test/features/media_store/media_backfill_service_test.dart` create media
with no linkage and assert they ARE candidates — they now fail for the new
(correct) reason. Link every fixture row to one dive; the tests' own
semantics (source/type/stamp filtering, ordering, idempotency) are
unchanged.

**Files:**
- Modify: `test/features/media_store/media_backfill_service_test.dart`

**Interfaces:**
- Consumes: `setUpTestDatabase()` returning `AppDatabase`;
  `MediaRepository.createMedia`.
- Produces: nothing new — keeps existing test names green.

- [ ] **Step 1: Run the file to see the expected failures**

Run: `flutter test test/features/media_store/media_backfill_service_test.dart`

Expected: both tests FAIL — `getBackfillCandidateIds()` now returns `[]`
for unlinked fixtures.

- [ ] **Step 2: Link fixtures to a dive**

In `test/features/media_store/media_backfill_service_test.dart`:

Add imports at the top (keep group order: packages then relative):

```dart
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
```

Capture the DB and insert one dive in `setUp` (replace
`await setUpTestDatabase();`):

```dart
  late AppDatabase db;
```

```dart
  setUp(() async {
    db = await setUpTestDatabase();
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    service = MediaBackfillService(
      mediaRepository: mediaRepository,
      queue: queue,
    );
  });
```

In the `mediaRow` helper, add `diveId: 'dive-1'` to the `domain.MediaItem`
constructor call (next to `id: ''`):

```dart
      domain.MediaItem(
        id: '',
        diveId: 'dive-1',
        mediaType: mediaType,
```

- [ ] **Step 3: Run the file to verify it passes**

Run: `flutter test test/features/media_store/media_backfill_service_test.dart`

Expected: PASS (both tests).

- [ ] **Step 4: Commit**

```bash
git add test/features/media_store/media_backfill_service_test.dart
git commit -m "test(media): link backfill service fixtures to a dive"
```

---

### Task 3: Strengthen the compressed-stamp backfill test

`test/features/media/data/media_repository_compressed_test.dart` has a test
"compressed-only photo is NOT a backfill candidate" whose fixture is
unlinked — it still passes after Task 1, but for the wrong reason (excluded
by linkage, not by the compressed stamp). Link it to a dive so it keeps
testing what it names.

**Files:**
- Modify: `test/features/media/data/media_repository_compressed_test.dart`

**Interfaces:**
- Consumes: `MediaRepository.getBackfillCandidateIds()`; the file's local
  `photo(String id, {String? hash})` helper.
- Produces: nothing new.

- [ ] **Step 1: Extend the fixture helper and test**

Add imports at the top:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
```

Change `setUp` to capture the DB (`late AppDatabase db;` beside
`late MediaRepository repo;`):

```dart
  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
```

Add a `diveId` parameter to the `photo` helper:

```dart
  MediaItem photo(String id, {String? hash, String? diveId}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    diveId: diveId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    contentHash: hash,
  );
```

Update the backfill test to insert a dive and link the row:

```dart
  test('compressed-only photo is NOT a backfill candidate', () async {
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    await repo.createMedia(
      photo(
        'd',
        hash: 'h3',
        diveId: 'dive-1',
      ).copyWith(remoteCompressedUploadedAt: DateTime(2026, 1, 3)),
    );
    expect(await repo.getBackfillCandidateIds(), isNot(contains('d')));
  });
```

- [ ] **Step 2: Run the file to verify it passes**

Run: `flutter test test/features/media/data/media_repository_compressed_test.dart`

Expected: PASS (all tests in the file).

- [ ] **Step 3: Commit**

```bash
git add test/features/media/data/media_repository_compressed_test.dart
git commit -m "test(media): compressed backfill exclusion tests the stamp, not linkage"
```

---

### Task 4: Project-wide verification

**Files:** none new — verification only.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: no files changed. If files changed, inspect, keep, and amend the
relevant commit.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` — never pipe through `tail`/`grep` (masks
failures), and treat infos as fatal (CI does).

- [ ] **Step 3: Run the media test suites**

Run: `flutter test test/features/media test/features/media_store`
Expected: all pass. Mock files
(`*_test.mocks.dart`) need no regeneration — `getBackfillCandidateIds`'s
signature did not change.

- [ ] **Step 4: Full suite (pre-push gate)**

Run: `flutter test`
Expected: all pass. Known order-dependent flakes in the backup-service
family pass in isolation; if one fails, re-run that file alone to confirm
before considering `--no-verify` on push.

- [ ] **Step 5: Push and open PR**

Push the branch and open a PR against `main` titled
"fix(media): scope backfill candidates to linked media". Body: summary of
the orphan-upload bug (dive deletion nulls `dive_id`; unscoped backfill
uploaded non-logbook bytes and HLC-stamped rows into sync), the shared
predicate, and the fixture updates. Reference the design spec path. No
attribution or session links.

---

## Not in this PR

- Dive-deletion cascade, backlog sweep (PR 3 — gated on the spec section 3
  verification of the orphan predicate).
- Remote blob deletion, transfer-queue `delete` operation, multipart abort
  (PR 2).
- Verify Library sweep, `media_stores.last_sweep_at` / schema v136 (PR 4).
