# Media Sync Phase 1, Slice 4: Quiet Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop checking a library from rewriting it: a verification that learns nothing writes nothing, and one that confirms what the row already says publishes nothing. Then close the one real tombstone gap in the media family.

**Architecture:** Three small changes and two corrections. The verifier returns early for every inconclusive outcome instead of stamping a date. The repository's four verification writers publish only when the orphan flag actually moves; the check date is a local observation that rides along on the row's next sync-visible write. The enrichment rows that vanish when a dive is deleted but its media survives gain tombstones. Two spec bullets about `mediaStores` are corrected with tests that pin why they do not apply.

**Tech Stack:** Flutter, Drift (SQLite), the in-house changeset sync engine (`SyncRepository`, fact clocks from slice 3), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, sections 5.2 and 5.3 (both amended in the same change as this plan).

## Global Constraints

- **Branch:** `ericgriffin/media-sync-s4-quiet-verification`, cut from `ericgriffin/media-sync-s3-merge-rule` (slice 4's writers call `markFactsPending`, which slice 3 introduces) and rebased onto main once slices 1 to 3 land. Run `git branch --unset-upstream` right after cutting. In a fresh worktree run `git submodule update --init --recursive`, `flutter pub get`, the Drift codegen and `flutter gen-l10n` first.
- **No schema change.** This slice claims no rung. If you find yourself editing `lib/core/database/database.dart`, stop: you have gone outside the plan.
- **No em-dashes (U+2014) in any output**: code, comments, commit messages, docs. En-dashes and " - " as prose punctuation are equally forbidden.
- **No emojis** in code, comments, or documentation.
- **TDD**: every behaviour gets a failing test first; each task names the run and the expected result.
- **Immutability**: never mutate an existing list or map in place.
- Run `dart format .` before every commit and gate the commit on `flutter analyze` exiting zero (`flutter analyze >/dev/null 2>&1 && git commit ...`); piping it to `tail` hides the exit code.
- File size target 200-400 lines, 800 max.
- Commit messages carry no `Co-Authored-By` line, no tool name and no session URL. The PR body says `Part of #2090` and `Refs #2100`.
- After adding any file under `lib/`, run `flutter test test/architecture/`.

---

## Decisions this plan relies on

- **Only a flag change publishes** (decided 2026-09-19). Spec 5.2 said to mark pending when `isOrphaned` **or** `lastVerifiedAt` changes, but the date is set to "now" on every check, so that guard would never fire. The date is now written locally without a pending mark or a clock stamp, and it reaches peers on the row's next sync-visible write. A peer may therefore show a slightly older "last checked" for a row nothing else has touched; the health report from slice 2 shows this device's own value, which is the one a support thread needs.
- **The `mediaStores` hardening bullets do not apply** (decided 2026-09-19, after reading the schema). `media_stores` declares no foreign keys at all, so a `parentRefs` entry would be inert, and `sync_parent_refs_completeness_test.dart` is schema-driven: it reads `pragma_foreign_key_list` and already fails the moment an FK to a deletable parent appears without an entry. No local code path deletes a `media_stores` row either; `MediaStoreService.disconnect()` deliberately keeps the synced descriptor so other devices still know the store exists. Task 5 pins both facts with tests and amends the spec instead of writing inert code.
- **The real tombstone gap is elsewhere.** `_dropEnrichmentRows` already tombstones every deliberate enrichment deletion. What is missing: when a dive is deleted and its media survives because a site or a piece of gear still references it, the enrichment rows cascade away through `MediaEnrichment.diveId` (`onDelete: cascade`) with nothing logged, so a peer re-adds them on its next publish. Task 4 closes it.

## File Structure

| Path | Change | Responsibility |
| --- | --- | --- |
| `lib/features/media/data/services/media_item_verifier.dart` | Modify | Inconclusive outcomes return without writing; correct the stale doc reference to `reverifyAll`. |
| `lib/features/media/data/repositories/media_repository.dart` | Modify | `stampVerification`, `markOrphaned`, `markAsOrphaned`, `markAsVerified` publish only on a flag change; `unlinkMediaFromDeletedDives` drops enrichment with tombstones. |
| `test/features/media/data/services/media_item_verifier_test.dart` | Modify | Six cases currently assert inconclusive outcomes stamp a date; they pin the behaviour this slice removes. |
| `test/features/media/data/media_repository_stamp_verification_test.dart` | Modify | "the write is sync-visible" pins a date-only write publishing; rewrite it as the flag-change case plus a quiet case. |
| `test/features/media/data/media_repository_quiet_verification_test.dart` | Create | The four writers: what is written, what is published. |
| `test/features/media/data/media_enrichment_tombstone_test.dart` | Create | The dive-delete-with-kept-media gap. |
| `test/core/services/sync/media_stores_no_parent_refs_test.dart` | Create | Pins why `mediaStores` needs no entry and no tombstone. |
| `test/features/media/two_device/row_sync_scenarios_test.dart` | Modify | Remove the S2 skip. |

---

### Task 1: An inconclusive check writes nothing

**Files:**
- Modify: `lib/features/media/data/services/media_item_verifier.dart` (the `try` block that calls `stampVerification`, and the class doc comment)
- Modify: `test/features/media/data/services/media_item_verifier_test.dart`

**Interfaces:**
- Consumes: `MediaRepository.stampVerification(String id, {required DateTime verifiedAt, bool? isOrphaned})`, `VerifyResult` (`lib/features/media/domain/value_objects/verify_result.dart`).
- Produces: no signature change. `MediaItemVerifier.verify` keeps returning the `VerifyResult`; only its write behaviour narrows.

- [ ] **Step 1: Rewrite the tests that pin the old behaviour**

Six cases in `media_item_verifier_test.dart` assert `repository.written.single.verifiedAt` for an inconclusive outcome: `unauthenticated stamps the date but never orphans`, `fromOtherDevice stamps the date but never orphans`, `neither clears an existing orphan flag`, the `volumeOffline` case, `transientError does not clear an existing orphan flag`, `accessDenied stamps the date but never orphans a row`, and `accessDenied does not clear an existing orphan flag either`. Replace each assertion of the form

```dart
    expect(repository.written.single.isOrphaned, isNull);
    expect(repository.written.single.verifiedAt, stamp);
```

with

```dart
    expect(
      repository.written,
      isEmpty,
      reason: 'nothing was learned, so the row is not touched',
    );
```

and rename each test from "stamps the date but never orphans" to "writes nothing" (keep the `expect(result, ...)` line in each). Then add one case that states the rule once:

```dart
  test('every inconclusive outcome leaves the row alone', () async {
    for (final outcome in VerifyResult.values) {
      if (outcome == VerifyResult.available ||
          outcome == VerifyResult.notFound) {
        continue;
      }
      final repository = _CapturingRepository();
      final verifier = MediaItemVerifier(
        registry: _registryReturning(outcome),
        repository: repository,
        now: () => stamp,
      );

      expect(await verifier.verify(_item()), outcome);
      expect(repository.written, isEmpty, reason: outcome.name);
    }
  });
```

`_registryReturning` is whatever the file's existing helper for building a registry around a fixed `VerifyResult` is called; reuse it rather than adding a second one (read the top of the file; the existing tests build one per case).

- [ ] **Step 2: Run to verify the failures**

Run: `flutter test test/features/media/data/services/media_item_verifier_test.dart`
Expected: the rewritten cases FAIL with "Expected: empty, Actual: [...]" because the verifier still stamps. The `available` and `notFound` cases pass untouched.

- [ ] **Step 3: Implement**

In `media_item_verifier.dart`, replace the write block

```dart
      if (result != VerifyResult.available && result != VerifyResult.notFound) {
        await _repository.stampVerification(item.id, verifiedAt: stamp);
        return result;
      }
      await _repository.stampVerification(
        item.id,
        verifiedAt: stamp,
        isOrphaned: result == VerifyResult.notFound,
      );
```

with

```dart
      // An inconclusive outcome writes NOTHING, not even the date. The date
      // is a synced column, so stamping it queued a pending record for every
      // row a Check all pass could not reach, and on a device that holds a
      // peer's library that is every row (media sync program spec 5.2). The
      // check did not learn whether the bytes exist, so there is nothing to
      // record: the resolver verdict in the media health report is where a
      // support thread reads what this device could see.
      if (result != VerifyResult.available && result != VerifyResult.notFound) {
        return result;
      }
      await _repository.stampVerification(
        item.id,
        verifiedAt: stamp,
        isOrphaned: result == VerifyResult.notFound,
      );
```

Keep the surrounding `try`/`catch` and the long comment above it that explains which results may move the flag; extend that comment's last paragraph with the sentence "Inconclusive outcomes now return before any write."

While in the file, fix the stale class doc: it says the persistence contract mirrors `LocalFilesDiagnosticsService.reverifyAll`, but that method no longer exists (`local_files_diagnostics_service.dart` is read-only counts now, and its own doc points at `MediaVerificationSweep`). Replace that paragraph with:

```dart
/// `MediaVerificationSweep` runs this over many rows for the Settings
/// "Check all media" action, so the two must agree about what a result
/// means: the sweep counts a row inconclusive under exactly the predicate
/// this method declines to write under.
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/data/services/media_item_verifier_test.dart test/features/media/data/services/media_verification_sweep_test.dart`
Expected: PASS. The sweep's counts are unchanged: it classifies from the returned `VerifyResult`, not from what was written.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add lib/features/media/data/services/media_item_verifier.dart test/features/media/data/services/media_item_verifier_test.dart && git commit -m "fix(media): a check that learns nothing writes nothing

An unreachable source, a revoked photo permission, an unmounted volume and
a row whose bytes live on another machine all stamped the check date, and
the date is synced, so a Check all pass queued a pending record for every
row it could not reach. On a device holding a peer's library that is every
row. Inconclusive outcomes now return before any write.

Part of #2090, refs #2100"
```

---

### Task 2: Only a flag change publishes

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`stampVerification`, `markOrphaned`, `markAsOrphaned`, `markAsVerified`)
- Modify: `test/features/media/data/media_repository_stamp_verification_test.dart`
- Create: `test/features/media/data/media_repository_quiet_verification_test.dart`

**Interfaces:**
- Consumes: `SyncRepository.markFactsPending({required String entityType, required String recordId, required int localUpdatedAt, required SyncFactGroup group})` and `SyncFactGroups.mediaVerification` (slice 3).
- Produces: no signature changes. `stampVerification`, `markOrphaned`, `markAsOrphaned` and `markAsVerified` keep their parameters; each publishes only when `is_orphaned` actually moves.

`markVerified` already guards its UPDATE on the flag differing and returns before marking pending when nothing was written; leave it alone.

- [ ] **Step 1: Rewrite the test that pins the old behaviour**

In `media_repository_stamp_verification_test.dart`, replace the test `the write is sync-visible` (it calls `stampVerification` with no `isOrphaned` and asserts a pending record) with two:

```dart
  test('a flag change is sync-visible', () async {
    final photo = await stampedPhoto();
    await SyncRepository().clearPendingRecords();

    await repo.stampVerification(
      photo.id,
      verifiedAt: DateTime(2026, 3),
      isOrphaned: true,
    );

    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.map((r) => (r.entityType, r.recordId)),
      contains(('media', photo.id)),
    );
  });

  test('a check that confirms what the row already says publishes nothing',
      () async {
    final photo = await stampedPhoto();
    await SyncRepository().clearPendingRecords();

    // The row is not orphaned and the check agrees.
    await repo.stampVerification(
      photo.id,
      verifiedAt: DateTime(2026, 3),
      isOrphaned: false,
    );

    expect(
      await SyncRepository().getPendingRecords(),
      isEmpty,
      reason: 'a library at rest stays at rest',
    );
    expect(
      (await repo.getMediaById(photo.id))!.lastVerifiedAt,
      DateTime(2026, 3),
      reason: 'the date is still recorded locally',
    );
  });
```

Keep `a reachability outcome stamps the date and leaves the flag` as it is: it calls `stampVerification` directly with no `isOrphaned` and asserts the row's date and flag, which stays true.

- [ ] **Step 2: Write the new writer tests**

```dart
// test/features/media/data/media_repository_quiet_verification_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Checking a library must not rewrite it: the four verification writers
/// publish only when the orphan flag actually moves (media sync program
/// spec 5.2). The check date is a local observation and rides along on the
/// row's next sync-visible write.
void main() {
  late AppDatabase db;
  late String id;
  final repo = MediaRepository();

  Future<bool> isPending() async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == 'media' && r.recordId == id,
      );

  Future<String?> verifyClock() async =>
      (await db
              .customSelect(
                'SELECT verify_facts_hlc FROM media WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .getSingle())
          .read<String?>('verify_facts_hlc');

  Future<bool> orphaned() async =>
      (await repo.getMediaById(id))!.isOrphaned;

  setUp(() async {
    db = await setUpTestDatabase();
    id = (await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        localPath: '/nowhere/reef.jpg',
        takenAt: DateTime(2026, 7, 1),
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
    )).id;
    await SyncRepository().clearPendingRecords();
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  group('stampVerification', () {
    test('publishes when the flag moves', () async {
      final before = await verifyClock();
      await repo.stampVerification(
        id,
        verifiedAt: DateTime(2026, 8),
        isOrphaned: true,
      );
      expect(await orphaned(), isTrue);
      expect(await isPending(), isTrue);
      expect(await verifyClock(), isNot(before));
    });

    test('a date-only check records the date and publishes nothing',
        () async {
      final before = await verifyClock();
      await repo.stampVerification(id, verifiedAt: DateTime(2026, 8));
      expect(
        (await repo.getMediaById(id))!.lastVerifiedAt,
        DateTime(2026, 8),
      );
      expect(await isPending(), isFalse);
      expect(await verifyClock(), before, reason: 'no clock was spent');
    });

    test('confirming the current flag publishes nothing', () async {
      await repo.stampVerification(
        id,
        verifiedAt: DateTime(2026, 8),
        isOrphaned: false,
      );
      expect(await isPending(), isFalse);
    });

    test('a row that is gone publishes nothing', () async {
      await repo.stampVerification(
        'no-such-row',
        verifiedAt: DateTime(2026, 8),
        isOrphaned: true,
      );
      expect(await SyncRepository().getPendingRecords(), isEmpty);
    });
  });

  group('the other flag writers', () {
    test('markOrphaned publishes once, then stays quiet', () async {
      await repo.markOrphaned(id, true);
      expect(await isPending(), isTrue);

      await SyncRepository().clearPendingRecords();
      await repo.markOrphaned(id, true);
      expect(await isPending(), isFalse, reason: 'the row already agrees');
    });

    test('markAsOrphaned publishes once, then stays quiet', () async {
      await repo.markAsOrphaned(id);
      expect(await isPending(), isTrue);

      await SyncRepository().clearPendingRecords();
      await repo.markAsOrphaned(id);
      expect(await isPending(), isFalse);
    });

    test('markAsVerified on an already-verified row publishes nothing',
        () async {
      // The row starts not orphaned, so this only restates the flag.
      await repo.markAsVerified(id);
      expect(await isPending(), isFalse);
      expect(
        (await repo.getMediaById(id))!.lastVerifiedAt,
        isNotNull,
        reason: 'the date is still recorded locally',
      );
    });

    test('markAsVerified publishes when it clears the flag', () async {
      await repo.markOrphaned(id, true);
      await SyncRepository().clearPendingRecords();

      await repo.markAsVerified(id);

      expect(await orphaned(), isFalse);
      expect(await isPending(), isTrue);
    });
  });
}
```

- [ ] **Step 3: Run to verify the failures**

Run: `flutter test test/features/media/data/media_repository_quiet_verification_test.dart test/features/media/data/media_repository_stamp_verification_test.dart`
Expected: FAIL on `a date-only check ...`, `confirming the current flag ...`, `markOrphaned ... then stays quiet`, `markAsOrphaned ... then stays quiet`, `markAsVerified on an already-verified row ...` and the new `a check that confirms ...`; the "publishes when the flag moves" cases pass already.

- [ ] **Step 4: Implement**

`stampVerification`: split the write so the flag change is guarded and the date is not.

```dart
  Future<void> stampVerification(
    String id, {
    required DateTime verifiedAt,
    bool? isOrphaned,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Two writes, because they mean different things (media sync program
      // spec 5.2). The flag is a synced fact and is guarded on actually
      // moving: a Check all pass over a healthy library would otherwise
      // publish every row it confirmed. The date is this device's own
      // observation of when it last looked, so it is recorded without a
      // clock and rides along on the row's next sync-visible write.
      var flagMoved = false;
      if (isOrphaned != null) {
        flagMoved =
            await (_db.update(_db.media)..where(
                  (t) => t.id.equals(id) & t.isOrphaned.equals(!isOrphaned),
                ))
                .write(
                  MediaCompanion(
                    isOrphaned: Value(isOrphaned),
                    lastVerifiedAt: Value(verifiedAt.millisecondsSinceEpoch),
                    updatedAt: Value(now),
                  ),
                ) >
            0;
      }
      if (!flagMoved) {
        final rowsWritten =
            await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
              MediaCompanion(
                lastVerifiedAt: Value(verifiedAt.millisecondsSinceEpoch),
                updatedAt: Value(now),
              ),
            );
        // A row deleted while a Check all pass was running gets nothing.
        if (rowsWritten > 0) SyncEventBus.notifyLocalChange();
        return;
      }
      await _syncRepository.markFactsPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
        group: SyncFactGroups.mediaVerification,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to stamp verification: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Replace its doc paragraph "Unlike [markVerified] this always writes: the user asked for a check and the date of that check is the answer, whether or not the flag moved." with:

```dart
  /// Always records the date, but publishes only when the flag moves: the
  /// date is this device's own observation and reaches peers on the row's
  /// next sync-visible write (spec 5.2).
```

`markOrphaned`: guard the UPDATE the way `markVerified` does.

```dart
      final rowsWritten =
          await (_db.update(_db.media)..where(
                // Matching on the OPPOSITE flag makes this a no-op when the
                // row already agrees, so a poller that re-reports the same
                // state publishes nothing.
                (t) => t.id.equals(id) & t.isOrphaned.equals(!isOrphaned),
              ))
              .write(
                MediaCompanion(
                  isOrphaned: Value(isOrphaned),
                  updatedAt: Value(now),
                ),
              );
      if (rowsWritten == 0) return;
```

then the existing `markFactsPending` call and `SyncEventBus.notifyLocalChange()`.

`markAsOrphaned`: same guard with the constant flag.

```dart
      final rowsWritten =
          await (_db.update(_db.media)..where(
                (t) => t.id.equals(id) & t.isOrphaned.equals(false),
              ))
              .write(
                MediaCompanion(
                  isOrphaned: const Value(true),
                  updatedAt: Value(now),
                ),
              );
      if (rowsWritten == 0) return;
```

`markAsVerified`: the flag write is guarded; the date is not, mirroring `stampVerification`.

```dart
      final flagMoved =
          await (_db.update(_db.media)..where(
                (t) => t.id.equals(id) & t.isOrphaned.equals(true),
              ))
              .write(
                MediaCompanion(
                  isOrphaned: const Value(false),
                  lastVerifiedAt: Value(now),
                  updatedAt: Value(now),
                ),
              ) >
          0;
      if (!flagMoved) {
        final rowsWritten =
            await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
              MediaCompanion(
                lastVerifiedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        if (rowsWritten > 0) SyncEventBus.notifyLocalChange();
        return;
      }
```

then its existing `markFactsPending` call and `SyncEventBus.notifyLocalChange()`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/media/data/ test/features/media/data/services/`
Expected: PASS. If `media_repository_fact_clock_test.dart` (slice 3) fails on a verification writer, check which: its cases call `markOrphaned(id, true)`, `markVerified(..., isOrphaned: true)`, `markAsOrphaned` and `stampVerification(..., isOrphaned: true)` against a row that starts not orphaned, so every one of them still moves the flag and still stamps. `markAsVerified` in that file runs against a not-orphaned row and no longer stamps the clock: change that case to orphan the row first (`await repo.markOrphaned(id, true);` then clear pending) so it still exercises a flag change.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add lib/features/media/data/repositories/media_repository.dart test/features/media/data && git commit -m "fix(media): publish a verification only when the orphan flag moves

Check all over a healthy library stamped the check date on every row, and
the date is synced, so the whole library queued for publish. The four flag
writers now guard on the flag actually moving; the date is recorded
locally and reaches peers on the row's next sync-visible write.

Part of #2090, refs #2100"
```

---

### Task 3: Turn S2 on

**Files:**
- Modify: `test/features/media/two_device/row_sync_scenarios_test.dart` (remove the S2 skip)

- [ ] **Step 1: Remove the skip**

Delete the `skip: 'Media sync program S2: turns green in slice 4 (quiet verification)',` argument from the S2 test. After `dart format` it may sit on the closing line as `}, skip: '...');`; in that case delete only the `, skip: ...` part.

- [ ] **Step 2: Run the scenarios**

Run: `flutter test test/features/media/two_device/`
Expected: S0, S0b, S1, S2 and S3 pass; S4 to S10 stay skipped. S2 asserts that a Check all on device B, which holds device A's library and can read none of its files, reports one inconclusive row and leaves nothing pending.

- [ ] **Step 3: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add test/features/media/two_device/row_sync_scenarios_test.dart && git commit -m "test(media): turn scenario S2 on

A Check all on a device holding a peer's library now reports the rows as
inconclusive and writes nothing.

Part of #2090, refs #2100"
```

---

### Task 4: Tombstone the enrichment a dive deletion takes with it

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`unlinkMediaFromDeletedDives`)
- Create: `test/features/media/data/media_enrichment_tombstone_test.dart`

**Interfaces:**
- Consumes: the private `_dropEnrichmentRows(List<String> mediaIds)` already in the file, which deletes each enrichment row and logs a `mediaEnrichment` tombstone.
- Produces: no signature change. `unlinkMediaFromDeletedDives(List<String> mediaIds)` keeps its parameter and now drops the enrichment of those rows inside the same transaction.

**Why here:** `MediaEnrichment.diveId` is `NOT NULL` with `onDelete: cascade`, so when the dive rows are deleted the enrichment of a surviving (unlinked) media row is destroyed by SQLite with nothing logged, and a peer re-adds it on its next publish. `_cascadeMediaForDiveDeletion` runs before `_deleteDiveRows`, so the unlink path is the last moment those rows can be tombstoned. The enrichment is dive-scoped (depth and elapsed time at the photo's moment on that dive's profile), so it is correct for it to go with the dive; only the silence is wrong.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/media/data/media_enrichment_tombstone_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
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
          "SELECT record_id FROM deletion_log WHERE entity_type = 'mediaEnrichment'",
        )
        .get();
    return [for (final r in rows) r.read<String>('record_id')];
  }

  Future<int> enrichmentRows() async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM media_enrichment').getSingle())
          .read<int>('c');

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Reef', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO media (id, file_path, dive_id, site_id, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 'd1', 's1', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, "
      "match_confidence, created_at) VALUES ('e1', 'm1', 'd1', 12.5, 'exact', 0)",
    );
    await SyncRepository().clearPendingRecords();
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('unlinking media from a deleted dive tombstones its enrichment',
      () async {
    await repo.unlinkMediaFromDeletedDives(['m1']);

    expect(await enrichmentRows(), 0, reason: 'the dive gave it its meaning');
    expect(await tombstonedEnrichment(), ['e1']);
  });

  test('the media row itself survives, unlinked and published', () async {
    await repo.unlinkMediaFromDeletedDives(['m1']);

    final row = (await repo.getMediaById('m1'))!;
    expect(row.diveId, isNull);
    expect(row.siteId, 's1');
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.map((r) => (r.entityType, r.recordId)),
      contains(('media', 'm1')),
    );
  });

  test('a media row with no enrichment is unaffected', () async {
    await db.customStatement(
      "INSERT INTO media (id, file_path, dive_id, site_id, created_at, updated_at) "
      "VALUES ('m2', '/y.jpg', 'd1', 's1', 0, 0)",
    );

    await repo.unlinkMediaFromDeletedDives(['m1', 'm2']);

    expect(await tombstonedEnrichment(), ['e1']);
  });
}
```

If an `INSERT` misses a NOT NULL column on this schema, the error names it; add it with a plausible value rather than changing the test's intent.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/media_enrichment_tombstone_test.dart`
Expected: the first test FAILS (`enrichmentRows` is 1 and the tombstone list is empty: today the rows die later, by cascade, unlogged). The other two pass.

- [ ] **Step 3: Implement**

In `unlinkMediaFromDeletedDives`, inside the existing transaction and before the `media` UPDATE:

```dart
    await _db.transaction(() async {
      // The enrichment is dive-scoped (depth and elapsed time on THAT dive's
      // profile) and its FK is NOT NULL with a cascade, so the dive rows
      // about to be deleted would take it with them silently. Drop it here
      // instead, with tombstones, or a peer re-adds it on its next publish
      // (media sync program spec 5.3).
      await _dropEnrichmentRows(mediaIds);
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
```

leaving the rest of the method as it is.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/media/data/ test/features/dive_log/data/repositories/ test/features/media/data/media_repository_cascade_test.dart`
Expected: PASS. A cascade test that asserted a surviving row keeps its enrichment would be pinning the bug; if one fails, read it: the row survives, its dive-scoped enrichment does not.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add lib/features/media/data/repositories/media_repository.dart test/features/media/data/media_enrichment_tombstone_test.dart && git commit -m "fix(media): tombstone the enrichment a dive deletion takes with it

A photo that survives a dive deletion because a site still shows it lost
its enrichment to the FK cascade, which logs nothing, so a peer re-added
the rows on its next publish. The unlink path now drops them explicitly,
with tombstones, before the dive rows go.

Part of #2090, refs #2100"
```

---

### Task 5: Pin why mediaStores needs neither an entry nor a tombstone

**Files:**
- Create: `test/core/services/sync/media_stores_no_parent_refs_test.dart`

(Sections 5.2 and 5.3 of the spec were amended in the commit that added this
plan; this task only adds the tests that pin them.)

**Why:** spec 5.3 asked for a `parentRefs` entry and a tombstone for `mediaStores`. Neither applies: the table declares no foreign keys, and no local path deletes a row (Disconnect deliberately keeps the descriptor so other devices still know the store exists). Rather than write inert code, pin both facts so the next person who changes them is told what to do.

- [ ] **Step 1: Write the test**

```dart
// test/core/services/sync/media_stores_no_parent_refs_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Spec 5.3 asked for a parentRefs entry and a tombstone for mediaStores.
/// Neither applies today, and these tests say why, so the next change to
/// either fact fails here with the reason rather than silently diverging.
void main() {
  test('media_stores declares no foreign keys, so it needs no parentRefs '
      'entry', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    final fks = await db
        .customSelect("PRAGMA foreign_key_list('media_stores')")
        .get();

    expect(
      fks,
      isEmpty,
      reason:
          'add an FK here and sync_parent_refs_completeness_test will demand '
          'a parentRefs entry for mediaStores; add it there, not here',
    );
    expect(SyncService.parentRefs.containsKey('mediaStores'), isFalse);
  });

  test('disconnecting keeps the synced descriptor', () async {
    // Disconnect clears credentials and attach state and deliberately keeps
    // the row, so other devices still learn the store exists. That is why
    // there is no local delete, and so nothing to tombstone. A delete path
    // added later must call SyncRepository.logDeletion, or peers re-add the
    // row on their next publish.
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final stores = MediaStoresRepository();
    await stores.upsertActive(
      storeId: 'store-1',
      providerType: 's3',
      displayHint: 'dive-media @ minio',
    );
    // Construction mirrors test/features/media_store/media_store_service_test.dart.
    final service = MediaStoreService(
      credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
      attachState: MediaStoreAttachState(),
      storesRepository: stores,
      accountsRepository: ConnectedAccountsRepository(),
      accountCredentials: AccountCredentialsStore(storage: InMemoryKeychain()),
    );

    await service.disconnect();

    expect((await stores.getActive())?.id, 'store-1');
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'mediaStores'",
        )
        .get();
    expect(tombstones, isEmpty);
  });
}
```

Copy the imports and the `InMemoryKeychain` helper import from `test/features/media_store/media_store_service_test.dart`; `SharedPreferences.setMockInitialValues({})` is needed before `MediaStoreAttachState()` reads preferences.


- [ ] **Step 2: Run the test**

Run: `flutter test test/core/services/sync/media_stores_no_parent_refs_test.dart`
Expected: PASS immediately. These are tripwires, not a change in behaviour.

- [ ] **Step 3: Confirm the spec already says this**

Sections 5.2 and 5.3 were amended when this plan was written (same commit),
so there is nothing to edit. Read them once and check they match what you
built; if they do not, the code is wrong or the spec drifted, and either way
stop and say so.

- [ ] **Step 4: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add test/core/services/sync/media_stores_no_parent_refs_test.dart && git commit -m "test(sync): pin why a media store descriptor needs no parent ref or tombstone

The table declares no foreign keys, so the schema-driven completeness test
already covers it, and no local path deletes a descriptor: Disconnect keeps
it so other devices still learn the store exists. Two tripwires say so, and
the spec records the correction.

Part of #2090, refs #2100"
```

---

### Task 6: Verify and open the PR

- [ ] **Step 1: Full affected run**

Run: `flutter test test/core test/features/media test/features/media_store test/features/dive_log test/features/settings test/architecture`
Expected: PASS, with S4 to S10 still skipped and S2 now green.

- [ ] **Step 2: Check the info panel still reports the date**

Run: `flutter test test/features/media/presentation/widgets/media_info_panel_test.dart`
Expected: PASS. The panel reads `lastVerifiedAt` from the row, which is still written on every check; only the publishing changed.

- [ ] **Step 3: Push and open the PR**

Base `ericgriffin/media-sync-s3-merge-rule` while the stack is open, or `main` once slices 1 to 3 have merged. Body: the three behaviour changes, the two spec corrections with their evidence, the list of tests that pinned the old behaviour and were rewritten, and `Part of #2090` / `Refs #2100`.

---

## Known limits (not in this slice)

- **The tile reconcile still writes from any device.** Spec 5.2's third bullet (reconcile only on the origin device) belongs to slice 7, which makes the resolvers origin-aware; until then a peer can still write `isOrphaned` when its own resolver says `notFound`. Slice 4 only stops the writes that learn nothing.
- **Enrichment lost to a merge-applied parent deletion stays silent.** When a peer's dive tombstone is applied here, the local enrichment cascades without a local tombstone. That is by design: the peer ships its own enrichment tombstones.
- **The check date can lag on peers.** By the decision above, a row whose only change is a confirmed check publishes nothing, so another device may show an older "last checked" until something else about the row changes.

## Self-review against the spec

- **5.2 inconclusive outcomes never write:** Task 1.
- **5.2 publish only on a real change:** Task 2, with the `lastVerifiedAt` wrinkle resolved and the spec amended in Task 5.
- **5.2 reconcile only on the origin device:** explicitly deferred to slice 7 (Known limits), as the bullet itself says.
- **5.3 mediaStores:** corrected with evidence and pinned by tests (Task 5).
- **5.3 mediaEnrichment tombstones:** the real gap closed (Task 4).
- **5.3 Google Drive error message:** slice 5, not this slice.
- **Turns S2 green:** Task 3.
- **Placeholders:** none. Two spots tell the executor to confirm an existing helper's name (`_registryReturning` in the verifier test) or to add a missing NOT NULL column named by a SQL error; neither changes the design.
- **Type consistency:** `stampVerification`, `markOrphaned`, `markAsOrphaned`, `markAsVerified`, `markVerified`, `_dropEnrichmentRows`, `unlinkMediaFromDeletedDives`, `SyncFactGroups.mediaVerification` are spelled the same in every task.
