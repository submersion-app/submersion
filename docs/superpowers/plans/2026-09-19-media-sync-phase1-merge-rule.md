# Media Sync Phase 1, Slice 3: Engine Merge Rule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the sync engine losing a peer's update while a local row is pending, make the media tables refuse stale copies, and give media's device-stamped facts their own clocks so an upload stamp can neither beat a user's edit nor resurrect a cleared stamp.

**Architecture:** Three rules, each with its own tasks. (1) Engine-wide: `_mergeEntity` merges a pending row instead of skipping it whenever both the local row and the peer's copy carry a clock, and keeps the pending mark. (2) `media`, `mediaEnrichment`, `mediaSpecies` and `mediaStores` join the stale-copy guard the parent-gated children already use. (3) `media` gains two synced clock columns (schema v223), one per fact group; fact writes stamp their group clock and never the row clock, export and the watermark count fact clocks, and the merge resolves each fact group by its own clock and writes it with a targeted update so explicit nulls land.

**Tech Stack:** Flutter, Drift (SQLite, `NativeDatabase.memory()` in tests), the in-house changeset sync engine (`SyncService`, `SyncDataSerializer`, `SyncRepository`, `SyncClock`/`Hlc`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 5.1 and locked decision 7 (both updated in the same change as this plan).

## Global Constraints

- **Branch:** `ericgriffin/media-sync-s3-merge-rule`. Cut it from `origin/main` if #2140 (slice 1, the harness) has merged; otherwise cut it from `origin/ericgriffin/media-sync-s1-harness` and run `git branch --unset-upstream` at once. Tasks 2 and 7 remove skips from harness scenarios that only exist once slice 1 is in the base. In a fresh worktree run `git submodule update --init --recursive`, `flutter pub get`, the Drift codegen and `flutter gen-l10n` before anything else.
- **Schema rung: v223.** Main is at v221; #1978, #1860 and #2040 and one local worktree all claim v222. Re-scan open PR diffs and every worktree's `currentSchemaVersion` right before pushing; if v223 is taken, renumber every `223` in this plan (rung, ladder, backstop comment, migration test file name and assertions).
- **No em-dashes (U+2014) in any output**: code, comments, commit messages, docs. En-dashes and " - " as prose punctuation are equally forbidden.
- **No emojis** in code, comments, or documentation.
- **TDD**: every behaviour gets a failing test first. Each task names the test run and its expected result.
- **Immutability**: never mutate an existing list or map in place; build a new one (`{...a, ...b}`, spread lists).
- **Never rewrite a user's data in a migration** beyond filling the two new columns; the backstop adds columns only, no backfill.
- File size target 200-400 lines, 800 max. `sync_service.dart` is already far past that; add only what this plan names to it and put new logic in `lib/core/services/sync/sync_fact_groups.dart`.
- Run `dart format .` from the worktree root before every commit, and `flutter analyze` on the whole project (infos are fatal in CI).
- Import grouping: dart, flutter, packages, local.
- Commit messages carry no `Co-Authored-By` line, no tool name and no session URL. The PR body says `Part of #2090` and `Refs #2097`.
- After adding any file under `lib/`, run `flutter test test/architecture/`.

---

## Decisions this plan relies on

- **Fact clocks, not a monotone rule** (spec decision 7, 2026-09-19). Upload stamps are cleared on purpose by `MediaVerifyService` (object missing from the store), the upload pipeline (quality override swaps original and compressed) and `MediaRepairService` (relink). A "non-null always wins" rule would resurrect those stamps. Each fact group merges last-writer-wins by its own clock instead.
- **A pending row still skips a peer copy it cannot order.** When either the local row or the peer's copy has no clock, nothing orders an unpublished local edit against the peer's, so the existing skip stays for that row. Only `diveProfiles`, `tankPressureProfiles` and `equipmentFindings` have no clock column at all; for every other entity this only affects rows written before clocks existed.
- **The pending mark is kept after a merge.** Nothing in this plan touches `sync_records` during a merge. The post-publish clear (`clearPendingRecords(markedBefore:)`) already bounds it.

## File Structure

| Path | Change | Responsibility |
| --- | --- | --- |
| `lib/core/services/sync/sync_service.dart` | Modify `_mergeEntity` (around lines 2669-2900 on main at 1eb59813be4) | Pending rule; stale-copy guard for the media tables; fact-group merge and targeted fact writes. |
| `lib/core/services/sync/sync_data_serializer.dart` | Modify | `clockGuardedEntities`; batched `fetchRecords` case for `media`; `_exportMedia` filter; `_maxHlcInData` counts fact clocks; `writeFactGroup`. |
| `lib/core/services/sync/sync_fact_groups.dart` | Create | `SyncFactGroup`, `SyncFactGroups` registry, and the pure `mergeFactGroups` resolution. |
| `lib/core/data/repositories/sync_repository.dart` | Modify | `markFactsPending`; `markRecordPending(alsoStamp:)`; `_stampHlc(columns:)`; `_maxRowHlc` includes fact clocks. |
| `lib/core/database/database.dart` | Modify | Two `media` columns, v223 rung with backfill, `_assertMediaFactClockColumns` backstop, ladder. |
| `lib/features/media/data/repositories/media_repository.dart` | Modify | Fact writers stamp their group clock; `createMedia` stamps both; mixed writers stamp the verification clock too; `republishForSync` stamps fact clocks only. |
| `test/core/services/sync/pending_merge_test.dart` | Create | Rule 1. |
| `test/core/services/sync/media_clock_guard_test.dart` | Create | Rule 2. |
| `test/core/database/migration_v223_media_fact_clocks_test.dart` | Create | Rung and backstop. |
| `test/core/database/migration_v221_dive_center_gear_notes_test.dart` | Modify | Relax the exact version assertion. |
| `test/core/services/sync/sync_fact_groups_test.dart` | Create | Registry and pure merge. |
| `test/core/data/repositories/sync_repository_fact_clock_test.dart` | Create | `markFactsPending`, `alsoStamp`, clock seeding. |
| `test/core/services/sync/media_fact_export_test.dart` | Create | Export filter and watermark. |
| `test/core/services/sync/media_fact_merge_test.dart` | Create | Fact merge through `debugApplyPayload`. |
| `test/features/media/data/media_repository_fact_clock_test.dart` | Create | Every fact writer stamps the right clock and leaves the row clock alone. |
| `test/features/media/two_device/row_sync_scenarios_test.dart` | Modify | Remove the S1 and S3 skips. |

Shared test helper, defined once here and repeated in each test file that needs it (keep it file-private; it is ten lines):

```dart
SyncPayload payloadWith({
  List<Map<String, dynamic>> dives = const [],
  List<Map<String, dynamic>> media = const [],
}) => SyncPayload(
  version: 1,
  exportedAt: 0,
  deviceId: 'peer',
  checksum: '',
  data: SyncData(dives: dives, media: media),
  deletions: const {},
);
```

`_applyRemotePayload` does not validate the checksum, so an empty string is fine. Apply with `SyncService(syncRepository: SyncRepository(), serializer: SyncDataSerializer()).debugApplyPayload(payload)`.

---

### Task 1: A pending row merges when both sides carry a clock

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (the `if (pendingRecordIds.contains(recordId)) { continue; }` block in `_mergeEntity`; add a private helper after `_parseHlc`)
- Create: `test/core/services/sync/pending_merge_test.dart`

**Interfaces:**
- Produces: `bool _orderable(Map<String, dynamic>? local, Map<String, dynamic> remote)` (private to `SyncService`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/pending_merge_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A locally pending row used to skip the peer's copy outright, and the
/// changeset cursor still advanced, so a newer edit made elsewhere never
/// landed and the peer then refused this device's older copy: the devices
/// diverged for good. Where both sides carry a clock they are now ordered.
void main() {
  late AppDatabase db;

  SyncPayload payloadWith({
    List<Map<String, dynamic>> dives = const [],
  }) => SyncPayload(
    version: 1,
    exportedAt: 0,
    deviceId: 'peer',
    checksum: '',
    data: SyncData(dives: dives),
    deletions: const {},
  );

  SyncService service() =>
      SyncService(syncRepository: SyncRepository(), serializer: SyncDataSerializer());

  Future<String?> notesOf(String id) async => (await db
          .customSelect('SELECT notes FROM dives WHERE id = ?',
              variables: [Variable.withString(id)])
          .getSingle())
      .read<String?>('notes');

  Future<bool> pending(String type, String id) async =>
      (await SyncRepository().getPendingRecords())
          .any((r) => r.entityType == type && r.recordId == id);

  /// A local edit to d1's notes, marked pending as the app's editors do.
  Future<void> editLocally(String notes) async {
    await db.customStatement(
      'UPDATE dives SET notes = ? WHERE id = ?',
      [notes, 'd1'],
    );
    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: 'd1',
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('a pending row takes a strictly newer peer edit and stays pending',
      () async {
    await editLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('dives', 'd1'))!;
    final newer = SyncClock.instance.issue()!;

    await service().debugApplyPayload(
      payloadWith(dives: [{...local, 'notes': 'theirs', 'hlc': newer}]),
    );

    expect(await notesOf('d1'), 'theirs');
    expect(await pending('dives', 'd1'), isTrue,
        reason: 'the mark is kept; the next publish carries what won');
  });

  test('a pending row keeps its edit against an older peer copy', () async {
    final before = (await SyncDataSerializer().fetchRecord('dives', 'd1'))!;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await editLocally('mine');

    await service().debugApplyPayload(
      payloadWith(dives: [{...before, 'notes': 'stale'}]),
    );

    expect(await notesOf('d1'), 'mine');
  });

  test('a pending row still skips a peer copy that carries no clock',
      () async {
    await editLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('dives', 'd1'))!;
    final unclocked = {...local, 'notes': 'unordered'}..remove('hlc');

    await service().debugApplyPayload(payloadWith(dives: [unclocked]));

    expect(await notesOf('d1'), 'mine',
        reason: 'nothing orders an unpublished edit against it');
  });

  test('two devices converge when one edits while the other is pending',
      () async {
    // Two real devices over one fake cloud, the pattern of
    // test/features/dive_log/integration/consolidation_sync_roundtrip_test.dart.
    final cloud = FakeCloudStorageProvider();
    final dbA = db;
    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    void switchTo(AppDatabase d) {
      DatabaseService.instance.setTestDatabase(d);
      SyncClock.instance.reset();
    }

    switchTo(dbA);
    expect((await buildService().performSync()).isSuccess, isTrue);
    final dbB = createTestDatabase();
    addTearDown(dbB.close);
    switchTo(dbB);
    expect((await buildService().performSync()).isSuccess, isTrue);

    // B edits offline first; A edits later, so A's clock is newer.
    db = dbB;
    await editLocally('from B');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    switchTo(dbA);
    db = dbA;
    await editLocally('from A');
    expect((await buildService().performSync()).isSuccess, isTrue);

    switchTo(dbB);
    db = dbB;
    expect((await buildService().performSync()).isSuccess, isTrue);
    expect(await notesOf('d1'), 'from A', reason: 'B took the newer edit');

    switchTo(dbA);
    db = dbA;
    expect((await buildService().performSync()).isSuccess, isTrue);
    expect(await notesOf('d1'), 'from A', reason: 'A kept it');
  });
}
```

`createTestDatabase` (not `setUpTestDatabase`) builds a second in-memory database without installing it; `switchTo` installs whichever device is active.

- [ ] **Step 2: Run to verify the right failures**

Run: `flutter test test/core/services/sync/pending_merge_test.dart`
Expected: "takes a strictly newer peer edit" FAILS (notes stay `mine`); "two devices converge" FAILS at `'from A'` on B (B keeps `from B`). The other two pass already; they pin behaviour that must not change.

- [ ] **Step 3: Implement**

In `_mergeEntity`, replace

```dart
        if (pendingRecordIds.contains(recordId)) {
          continue;
        }
```

with

```dart
        // A locally pending row used to skip the peer's copy outright, and
        // the changeset cursor still advanced past it, so the peer's update
        // was lost for good: a newer edit made elsewhere never landed here,
        // and the peer then refused this device's older copy, leaving the
        // two devices diverged. Where both sides carry a clock the ordinary
        // resolution below orders them, and the pending mark is kept, so
        // this device still publishes whatever wins. Where either clock is
        // missing nothing can order an unpublished local edit against the
        // peer's, so the skip stays. Entities whose local rows are not
        // fetched (the clockless blind upserts) have no local clock here and
        // keep the skip too.
        if (pendingRecordIds.contains(recordId) &&
            !_orderable(localById[recordId], record)) {
          continue;
        }
```

and add, directly after `_parseHlc`:

```dart
  /// Whether a local row and a peer's copy can be ordered: both carry a
  /// clock. A pending local row is protected from the peer's copy only when
  /// they cannot be.
  bool _orderable(Map<String, dynamic>? local, Map<String, dynamic> remote) =>
      _extractHlc(local) != null && _extractHlc(remote) != null;
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/sync/pending_merge_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Audit tests that pinned the skip**

Run: `flutter test test/core/services/sync test/features/dive_log/integration test/features/settings/presentation/providers`
Expected: PASS. If a test fails because it asserted that a pending local row beats a peer copy with a strictly newer clock, it pinned the divergence bug: rewrite its expectation to the peer's value and name the file in the PR body under "Tests that pinned the skip". Any other failure is a real regression; stop and investigate.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync/sync_service.dart test/core/services/sync/pending_merge_test.dart
git commit -m "fix(sync): merge a pending row instead of dropping the peer's update

A locally pending row made the merge skip the peer's copy, and the cursor
still advanced, so a newer edit made on another device never landed and the
peer then refused this device's older copy: the devices diverged for good.
Where both sides carry a clock the ordinary resolution now orders them and
the pending mark is kept. A copy without a clock is still skipped.

Part of #2090, refs #2097"
```

---

### Task 2: The media tables refuse stale copies

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (add `clockGuardedEntities` after `parentGatedChildEntities`; add a batched `case 'media':` in `fetchRecords`)
- Modify: `lib/core/services/sync/sync_service.dart` (`_mergeEntity`: the `childClocked` / `localById` block and the `if (!hasUpdatedAt) { if (childClocked) {` guard)
- Create: `test/core/services/sync/media_clock_guard_test.dart`
- Modify: `test/features/media/two_device/row_sync_scenarios_test.dart` (remove the S3 skip)

**Interfaces:**
- Produces: `static const Set<String> SyncDataSerializer.clockGuardedEntities`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/media_clock_guard_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// The media tables merged as blind upserts: the last copy to arrive owned
/// the whole row, so a peer's older snapshot overwrote a newer local edit.
/// They now refuse a copy strictly older than the local row, as the
/// parent-gated children do; a tie or a missing clock still applies.
void main() {
  late AppDatabase db;
  late String id;

  SyncPayload payloadWith(List<Map<String, dynamic>> media) => SyncPayload(
    version: 1,
    exportedAt: 0,
    deviceId: 'peer',
    checksum: '',
    data: SyncData(media: media),
    deletions: const {},
  );

  Future<void> apply(Map<String, dynamic> row) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
  ).debugApplyPayload(payloadWith([row]));

  Future<String?> captionOf() async => (await db
          .customSelect('SELECT caption FROM media WHERE id = ?',
              variables: [Variable.withString(id)])
          .getSingle())
      .read<String?>('caption');

  Future<void> captionLocally(String caption) async {
    await db.customStatement(
      'UPDATE media SET caption = ? WHERE id = ?', [caption, id]);
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: id,
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    // Publish would clear this; the guard must hold without the pending rule.
    await SyncRepository().clearPendingRecords();
  }

  setUp(() async {
    db = await setUpTestDatabase();
    id = (await MediaRepository().createMedia(MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/nowhere/reef.jpg',
      takenAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    ))).id;
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('every clock-guarded entity is a stamped HLC target', () {
    for (final type in SyncDataSerializer.clockGuardedEntities) {
      expect(SyncRepository.hlcTargets[type], isNotNull, reason: type);
      expect(
        SyncDataSerializer.parentGatedChildEntities,
        isNot(contains(type)),
        reason: '$type exports on its own clock, not through a parent',
      );
    }
    expect(SyncDataSerializer.clockGuardedEntities, {
      'media', 'mediaEnrichment', 'mediaSpecies', 'mediaStores',
      'species', 'importedFiles', 'fieldPresets',
    });
  });

  // The media-only assertions below pin the rule, but the set changes merge
  // behaviour for three more media tables, each with its own fetch and upsert
  // arm. Seed one row per table, stamp its clock the way a local edit would,
  // publish it so the pending rule cannot be what refuses the peer, then
  // assert both directions. Without these, a missing arm on any of the three
  // ships green.
  group('the guard covers every clock-guarded media table', () {
    // Seed 'e1' in media_enrichment, 'ms1' in media_species and 'st1' in
    // media_stores, each with a text column set to 'mine':
    // match_confidence, notes and display_hint respectively.
    // For each table:
    //   test('<table> refuses a strictly older copy'):
    //     stamp the clock, fetchRecord it, stamp again (the local row moves
    //     on after the peer's snapshot), apply the snapshot with the text
    //     column set to 'theirs', expect the column still reads 'mine'.
    //   test('<table> applies a strictly newer copy'):
    //     stamp, fetchRecord, apply with the column set to 'theirs' and
    //     'hlc': SyncClock.instance.issue(), expect 'theirs'.
    // Drive each table through its own SyncData field: SyncData(
    // mediaEnrichment: [row]), SyncData(mediaSpecies: [row]) and
    // SyncData(mediaStores: [row]). media_enrichment needs a dives row and
    // media_species needs a species row; species has no created_at or
    // updated_at column.
  });

  test('a strictly older copy does not overwrite a newer local edit',
      () async {
    final before = (await SyncDataSerializer().fetchRecord('media', id))!;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await captionLocally('mine');

    await apply({...before, 'caption': 'stale'});

    expect(await captionOf(), 'mine');
  });

  test('a newer copy applies', () async {
    await captionLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;
    await apply({...local, 'caption': 'theirs', 'hlc': SyncClock.instance.issue()});
    expect(await captionOf(), 'theirs');
  });

  test('a copy with no clock still applies, as the blind upsert did',
      () async {
    await captionLocally('mine');
    final local = (await SyncDataSerializer().fetchRecord('media', id))!;
    await apply({...local, 'caption': 'legacy peer'}..remove('hlc'));
    expect(await captionOf(), 'legacy peer');
  });

  test('the batched fetch serves media rows', () async {
    final rows = await SyncDataSerializer().fetchRecords('media', [id, 'none']);
    expect(rows.keys, [id]);
    expect(rows[id]!['hlc'], isNotNull);
  });
}
```

If `clearPendingRecords` requires a `markedBefore` argument on this branch, pass `markedBefore: DateTime.now().millisecondsSinceEpoch + 1`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/media_clock_guard_test.dart`
Expected: FAIL to compile (`clockGuardedEntities` undefined). After adding only the set, "a strictly older copy" still FAILS (caption becomes `stale`).

- [ ] **Step 3: Implement**

In `sync_data_serializer.dart`, directly after `parentGatedChildEntities`:

```dart
  /// Rows that export on their own clock but merge as blind upserts (no
  /// conflict cards). Like [parentGatedChildEntities] they carry an hlc, so
  /// the merge refuses a copy strictly older than the local row
  /// (SyncService._mergeEntity); unlike them they are selected for export by
  /// their own clock, so they must not join that set, which also drives the
  /// pending-children export.
  static const Set<String> clockGuardedEntities = {
    'media',
    'mediaEnrichment',
    'mediaSpecies',
    'mediaStores',
  };
```

In `fetchRecords`' switch, next to the existing `case 'mediaStores':`, add:

```dart
      case 'media':
        final rows = await (_db.select(
          _db.media,
        )..where((t) => t.id.isIn(idList))).get();
        return {
          for (final r in rows) r.id: r.toJson(serializer: _syncBlobSerializer),
        };
```

In `_mergeEntity`, after `final childClocked = ...;` add

```dart
    // The media tables join the same stale-copy guard (spec 5.1) through
    // their own set; childClocked alone still selects the tombstone clocks.
    final clockGuarded =
        childClocked ||
        SyncDataSerializer.clockGuardedEntities.contains(entityType);
```

change the fetch condition from `hasUpdatedAt || childClocked` to `hasUpdatedAt || clockGuarded`, and in the blind-upsert branch change `if (childClocked) {` to `if (clockGuarded) {`. Leave the `deleteClock = childClocked ? ... : null` line unchanged.

- [ ] **Step 4: Run the tests, then turn S3 on**

Run: `flutter test test/core/services/sync/media_clock_guard_test.dart`
Expected: PASS, 5 tests.

Delete the `skip:` argument from S3 in `test/features/media/two_device/row_sync_scenarios_test.dart` (after `dart format`, it may sit on the closing `});` line as `}, skip: '...S3...');`; delete only the `, skip: ...` part).

Run: `flutter test test/features/media/two_device/`
Expected: S0, S0b and S3 pass; the other scenarios stay skipped.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync test/core/services/sync/media_clock_guard_test.dart test/features/media/two_device/row_sync_scenarios_test.dart
git commit -m "fix(sync): refuse a stale copy of a media row

Media, its enrichment, species tags and store records merged as blind
upserts, so a peer's older snapshot overwrote a newer local edit. They join
the stale-copy guard the parent-gated children use, through their own set
because they export on their own clock. Media also gains a batched fetch.
Turns scenario S3 green.

Part of #2090, refs #2097"
```

---

### Task 3: Schema v223, two fact clock columns on media

**Files:**
- Modify: `lib/core/database/database.dart` (the `Media` table, `currentSchemaVersion`, `migrationVersions`, the rung after `if (from < 221)`, a backstop method beside `_assertMediaEquipmentIdColumn`, its call in `beforeOpen` beside `await _assertMediaEquipmentIdColumn();`)
- Create: `test/core/database/migration_v223_media_fact_clocks_test.dart`
- Modify: `test/core/database/migration_v221_dive_center_gear_notes_test.dart`

- [ ] **Step 1: Write the failing migration test**

```dart
// test/core/database/migration_v223_media_fact_clocks_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v223: media fact clocks (media sync program, spec 5.1). Upload and
/// verification facts get their own clock columns so a fact write never
/// moves the row clock.
void main() {
  /// A v221 database with a media table and the tables the beforeOpen
  /// backstops touch (copied from the v221 test's fixture).
  NativeDatabase setupDb({int userVersion = 221, bool withFactColumns = false}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE media (id TEXT PRIMARY KEY, hlc TEXT'
          '${withFactColumns ? ', upload_facts_hlc TEXT, verify_facts_hlc TEXT' : ''})',
        );
        rawDb.execute("INSERT INTO media (id, hlc) VALUES ('m1', 'H1')");
        rawDb.execute("INSERT INTO media (id, hlc) VALUES ('m2', NULL)");
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Map<String, (String?, String?)>> clocks(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, upload_facts_hlc, verify_facts_hlc FROM media')
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): (
          r.read<String?>('upload_facts_hlc'),
          r.read<String?>('verify_facts_hlc'),
        ),
    };
  }

  test('v223 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 223);
    expect(AppDatabase.migrationVersions, contains(223));
  });

  test('upgrading from v221 adds both clocks, filled from the row clock',
      () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'media'),
      containsAll(['upload_facts_hlc', 'verify_facts_hlc']),
    );
    final c = await clocks(db);
    expect(c['m1'], ('H1', 'H1'));
    expect(c['m2'], (null, null), reason: 'no row clock, nothing to copy');
  });

  test('the backstop re-adds missing columns without backfilling', () async {
    // A database already at v223 that lost the columns to a version
    // collision on a parallel branch.
    final db = AppDatabase(setupDb(userVersion: 223));
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'media'),
      containsAll(['upload_facts_hlc', 'verify_facts_hlc']),
    );
    expect((await clocks(db))['m1'], (null, null));
  });

  test('a fresh database has both columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'media'),
      containsAll(['upload_facts_hlc', 'verify_facts_hlc']),
    );
  });
}
```

If opening the minimal fixture throws in a backstop that needs a table the v221 fixture lacked, add that table to `setupDb` the way the v221 test does (a `CREATE TABLE <name> (id TEXT PRIMARY KEY)` is enough for backstops that return early on missing columns).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/migration_v223_media_fact_clocks_test.dart`
Expected: FAIL (`currentSchemaVersion` is 221; columns missing).

- [ ] **Step 3: Implement**

In the `Media` table, after `TextColumn get hlc => text().nullable()();`:

```dart
  /// Clock of the upload facts (content identity, the three upload stamps
  /// and the compressed rendition's level and size). Every upload-fact write
  /// stamps this instead of [hlc], so a stamp never makes a stale caption win
  /// the row, and a cleared stamp still orders against a set one. Null falls
  /// back to [hlc] (v223, media sync program spec 5.1).
  TextColumn get uploadFactsHlc => text().nullable()();

  /// Clock of the verification facts (isOrphaned, lastVerifiedAt). Same
  /// contract as [uploadFactsHlc].
  TextColumn get verifyFactsHlc => text().nullable()();
```

Set `static const int currentSchemaVersion = 223;` and append `223` to `migrationVersions`. After the `if (from < 221) await reportProgress();` line:

```dart
        if (from < 223) {
          await _assertMediaFactClockColumns();
          // Existing facts were last written under the row clock, so that is
          // their clock. Rows already stamped (a re-run) are left alone.
          await customStatement(
            'UPDATE media SET upload_facts_hlc = hlc '
            'WHERE upload_facts_hlc IS NULL',
          );
          await customStatement(
            'UPDATE media SET verify_facts_hlc = hlc '
            'WHERE verify_facts_hlc IS NULL',
          );
        }
        if (from < 223) await reportProgress();
```

Beside `_assertMediaEquipmentIdColumn`:

```dart
  Future<void> _assertMediaFactClockColumns() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('upload_facts_hlc')) {
      await customStatement('ALTER TABLE media ADD COLUMN upload_facts_hlc TEXT');
    }
    if (!names.contains('verify_facts_hlc')) {
      await customStatement('ALTER TABLE media ADD COLUMN verify_facts_hlc TEXT');
    }
  }
```

In `beforeOpen`, after `await _assertMediaEquipmentIdColumn();`:

```dart
        // v223 backstop: re-assert the media fact clock columns (parallel
        // branch version-collision self-heal). Columns only, no backfill: a
        // null clock falls back to the row clock, so nothing is lost.
        await _assertMediaFactClockColumns();
```

In `migration_v221_dive_center_gear_notes_test.dart` change `expect(AppDatabase.currentSchemaVersion, 221);` to `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(221));`.

Regenerate Drift code: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/database/`
Expected: PASS. If a schema-count or table-shape test elsewhere pins the media column list, add the two columns to its expectation.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/database test/core/database
git commit -m "feat(db): give media's upload and verification facts their own clocks (v223)

Two nullable synced columns on media, filled from the row clock for
existing rows so every fact group has an explicit clock, with a backstop
that re-adds the columns without a backfill. A null clock falls back to
the row clock, so older app versions and pre-rung rows order as before.

Part of #2090, refs #2097"
```

---

### Task 4: Fact group registry and fact-clock stamping

**Files:**
- Create: `lib/core/services/sync/sync_fact_groups.dart`
- Modify: `lib/core/data/repositories/sync_repository.dart` (`markRecordPending`, `_stampHlc`, `_maxRowHlc`; add `markFactsPending`)
- Create: `test/core/services/sync/sync_fact_groups_test.dart` (registry half; Task 6 adds the merge half)
- Create: `test/core/data/repositories/sync_repository_fact_clock_test.dart`

**Interfaces:**
- Produces:

```dart
class SyncFactGroup {
  const SyncFactGroup({required this.name, required this.clockKey,
      required this.clockColumn, required this.columns});
  final String name;
  final String clockKey;              // JSON key, e.g. 'uploadFactsHlc'
  final String clockColumn;           // SQL column, e.g. 'upload_facts_hlc'
  final Map<String, String> columns;  // JSON key -> SQL column
}
abstract final class SyncFactGroups {
  static const SyncFactGroup mediaUpload;
  static const SyncFactGroup mediaVerification;
  static const Map<String, List<SyncFactGroup>> byEntity;
  static List<SyncFactGroup> of(String entityType);
}
// SyncRepository
Future<void> markRecordPending({required String entityType,
    required String recordId, required int localUpdatedAt,
    List<SyncFactGroup> alsoStamp = const []});
Future<void> markFactsPending({required String entityType,
    required String recordId, required int localUpdatedAt,
    required SyncFactGroup group});
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/sync_fact_groups_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('registry', () {
    test('media declares an upload and a verification group', () {
      expect(SyncFactGroups.of('media').map((g) => g.name),
          ['upload', 'verification']);
      expect(SyncFactGroups.of('dives'), isEmpty);
    });

    test('every declared column and clock exists on the table', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      final media = db.allTables.firstWhere((t) => t.actualTableName == 'media');
      final sqlNames = media.$columns.map((c) => c.name).toSet();
      for (final g in SyncFactGroups.of('media')) {
        expect(sqlNames, contains(g.clockColumn), reason: g.name);
        expect(sqlNames, containsAll(g.columns.values), reason: g.name);
      }
    });

    test('the JSON keys match the synced row', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await db.customStatement(
        "INSERT INTO media (id, file_path, created_at, updated_at) "
        "VALUES ('m1', '/x.jpg', 0, 0)",
      );
      final row = (await db.select(db.media).getSingle()).toJson();
      for (final g in SyncFactGroups.of('media')) {
        expect(row.keys, contains(g.clockKey), reason: g.name);
        expect(row.keys, containsAll(g.columns.keys), reason: g.name);
      }
    });

    test('no column belongs to two groups', () {
      final all = [
        for (final g in SyncFactGroups.of('media')) ...g.columns.keys,
      ];
      expect(all.toSet().length, all.length);
    });
  });
}
```

If the `INSERT` needs more NOT NULL columns on this schema, add them with defaults as the error names them.

```dart
// test/core/data/repositories/sync_repository_fact_clock_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  Future<Map<String, String?>> clocksOf(String id) async {
    final r = await db
        .customSelect(
          'SELECT hlc, upload_facts_hlc, verify_facts_hlc FROM media WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return {
      'hlc': r.read<String?>('hlc'),
      'upload': r.read<String?>('upload_facts_hlc'),
      'verify': r.read<String?>('verify_facts_hlc'),
    };
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 0);
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('markFactsPending stamps only its group clock and marks pending',
      () async {
    final before = await clocksOf('m1');
    await SyncRepository().markFactsPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload);
    final after = await clocksOf('m1');
    expect(after['hlc'], before['hlc'], reason: 'the row clock never moves');
    expect(after['upload'], isNotNull);
    expect(after['upload']!.compareTo(before['hlc']!), greaterThan(0));
    expect(after['verify'], before['verify']);
    final pending = await SyncRepository().getPendingRecords();
    expect(pending.any((r) => r.entityType == 'media' && r.recordId == 'm1'),
        isTrue);
  });

  test('markRecordPending can stamp fact clocks with the row clock', () async {
    await SyncRepository().markRecordPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 2,
      alsoStamp: SyncFactGroups.of('media'));
    final c = await clocksOf('m1');
    expect(c['upload'], c['hlc']);
    expect(c['verify'], c['hlc']);
  });

  test('the clock seed counts fact clocks', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 3,
      group: SyncFactGroups.mediaVerification);
    final verify = (await clocksOf('m1'))['verify']!;
    expect(await SyncRepository().maxRowHlc(), verify);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/sync_fact_groups_test.dart test/core/data/repositories/sync_repository_fact_clock_test.dart`
Expected: FAIL to compile (`sync_fact_groups.dart` missing, `markFactsPending` and `alsoStamp` undefined).

- [ ] **Step 3: Implement the registry**

```dart
// lib/core/services/sync/sync_fact_groups.dart

/// A set of device-stamped columns that travel under their own clock rather
/// than the row's (media sync program spec 5.1). A fact is an observation a
/// device makes (an upload finished, a file was found missing), not a user
/// edit, so it must neither win the row for a stale user field nor lose to
/// one. Each group merges last-writer-wins by its own clock, and a missing
/// clock falls back to the row clock.
class SyncFactGroup {
  const SyncFactGroup({
    required this.name,
    required this.clockKey,
    required this.clockColumn,
    required this.columns,
  });

  final String name;

  /// JSON key of the clock in a synced row, e.g. `uploadFactsHlc`.
  final String clockKey;

  /// SQL column of the clock, e.g. `upload_facts_hlc`.
  final String clockColumn;

  /// The group's fact columns, JSON key to SQL column.
  final Map<String, String> columns;
}

/// Which entities carry fact groups. Only media does today; an entity with
/// none merges exactly as before.
abstract final class SyncFactGroups {
  static const SyncFactGroup mediaUpload = SyncFactGroup(
    name: 'upload',
    clockKey: 'uploadFactsHlc',
    clockColumn: 'upload_facts_hlc',
    columns: {
      'contentHash': 'content_hash',
      'contentSizeBytes': 'content_size_bytes',
      'remoteUploadedAt': 'remote_uploaded_at',
      'remoteThumbUploadedAt': 'remote_thumb_uploaded_at',
      'remoteCompressedUploadedAt': 'remote_compressed_uploaded_at',
      'compressedLevel': 'compressed_level',
      'compressedSizeBytes': 'compressed_size_bytes',
    },
  );

  static const SyncFactGroup mediaVerification = SyncFactGroup(
    name: 'verification',
    clockKey: 'verifyFactsHlc',
    clockColumn: 'verify_facts_hlc',
    columns: {
      'isOrphaned': 'is_orphaned',
      'lastVerifiedAt': 'last_verified_at',
    },
  );

  static const Map<String, List<SyncFactGroup>> byEntity = {
    'media': [mediaUpload, mediaVerification],
  };

  static List<SyncFactGroup> of(String entityType) =>
      byEntity[entityType] ?? const [];
}
```

- [ ] **Step 4: Implement the stamping in `SyncRepository`**

Change `_stampHlc` to stamp a list of columns with one issued clock:

```dart
  Future<void> _stampHlc(
    String entityType,
    String recordId, {
    List<String> columns = const ['hlc'],
  }) async {
    final target = hlcTargets[entityType];
    if (target == null || columns.isEmpty) return;
    await ensureSyncClockConfigured();
    final hlc = SyncClock.instance.issue();
    if (hlc == null) return;
    final set = columns.map((c) => '"$c" = ?').join(', ');
    final values = [for (final _ in columns) hlc];
    final second = compositeHlcKeys[entityType];
    if (second != null) {
      final parts = recordId.split('|');
      if (parts.length != 2) return;
      await _db.customStatement(
        'UPDATE "${target.table}" SET $set '
        'WHERE "${target.pk}" = ? AND "$second" = ?',
        [...values, parts[0], parts[1]],
      );
      return;
    }
    await _db.customStatement(
      'UPDATE "${target.table}" SET $set WHERE "${target.pk}" = ?',
      [...values, recordId],
    );
  }
```

Extract the `sync_records` upsert inside `markRecordPending`'s transaction into `Future<void> _upsertPendingRecord(String entityType, String recordId, int localUpdatedAt)`, keep the transaction, and give `markRecordPending` the new parameter:

```dart
    List<SyncFactGroup> alsoStamp = const [],
  }) async {
    ...
      await _db.transaction(() async {
        await _upsertPendingRecord(entityType, recordId, localUpdatedAt);
        await _stampHlc(
          entityType,
          recordId,
          columns: ['hlc', for (final g in alsoStamp) g.clockColumn],
        );
      });
```

Add:

```dart
  /// Marks a row pending for a FACT write: stamps [group]'s clock and never
  /// the row clock, so the write orders only against other writes of the
  /// same facts (media sync program spec 5.1). Same transaction shape as
  /// [markRecordPending].
  Future<void> markFactsPending({
    required String entityType,
    required String recordId,
    required int localUpdatedAt,
    required SyncFactGroup group,
  }) async {
    try {
      await _db.transaction(() async {
        await _upsertPendingRecord(entityType, recordId, localUpdatedAt);
        await _stampHlc(entityType, recordId, columns: [group.clockColumn]);
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark facts pending: $entityType/$recordId (${group.name})',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

In `_maxRowHlc`, build the union from the row clocks plus every fact clock:

```dart
    final selects = [
      for (final t in hlcTargets.values)
        if (present.contains(t.table)) 'SELECT MAX(hlc) AS h FROM "${t.table}"',
      for (final e in SyncFactGroups.byEntity.entries)
        if (present.contains(hlcTargets[e.key]?.table))
          for (final g in e.value)
            'SELECT MAX("${g.clockColumn}") AS h '
                'FROM "${hlcTargets[e.key]!.table}"',
    ];
    if (selects.isEmpty) return null;
    final union = selects.join(' UNION ALL ');
```

(replacing the `tables` list, its empty check and the old `union`; keep the final query unchanged). Import `sync_fact_groups.dart`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/sync/sync_fact_groups_test.dart test/core/data/repositories/ test/core/services/sync/child_hlc_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
flutter test test/architecture/
git add lib/core/services/sync/sync_fact_groups.dart lib/core/data/repositories/sync_repository.dart test/core/services/sync/sync_fact_groups_test.dart test/core/data/repositories/sync_repository_fact_clock_test.dart
git commit -m "feat(sync): declare fact groups and stamp their clocks

SyncFactGroups names media's upload and verification facts with their
clock columns. markFactsPending marks a row pending and stamps only the
group's clock; markRecordPending can stamp fact clocks alongside the row
clock for writes that create or restate facts. The clock seed counts fact
clocks.

Part of #2090, refs #2097"
```

---

### Task 5: Export a fact-only change once

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`_exportMedia`, `_maxHlcInData`)
- Create: `test/core/services/sync/media_fact_export_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/services/sync/media_fact_export_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

void main() {
  late String rowHlc;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 0);
    rowHlc = (await SyncDataSerializer().fetchRecord('media', 'm1'))!['hlc']
        as String;
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('a fact-only change past the watermark is exported', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload);
    final payload = await SyncDataSerializer().exportData(
      deviceId: 'me', deletions: const {}, sinceHlc: rowHlc);
    expect(payload.data.media.map((r) => r['id']), ['m1']);
  });

  test('the watermark rises to the fact clock', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 1,
      group: SyncFactGroups.mediaVerification);
    final verify = (await SyncDataSerializer().fetchRecord('media', 'm1'))![
        'verifyFactsHlc'] as String;
    final payload = await SyncDataSerializer().exportData(
      deviceId: 'me', deletions: const {}, sinceHlc: rowHlc);
    expect(payload.toHlc, verify,
        reason: 'else the row is re-exported on every publish');
  });

  test('a row with no change past the watermark is not exported', () async {
    final payload = await SyncDataSerializer().exportData(
      deviceId: 'me', deletions: const {}, sinceHlc: rowHlc);
    expect(payload.data.media, isEmpty);
  });
}
```

`exportData`'s incremental parameter may carry a different name on main (read its signature; the watermark field on the payload is `toHlc`). Use whatever the incremental changeset export entry point takes; the assertions are the contract.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/media_fact_export_test.dart`
Expected: the first two FAIL (the row is filtered on `hlc` only; the watermark ignores fact clocks).

- [ ] **Step 3: Implement**

`_exportMedia`:

```dart
    if (hlcSince != null) {
      // A fact write stamps its group clock, not the row clock (spec 5.1),
      // so a row is due when either has moved past the watermark.
      query.where(
        (t) =>
            t.hlc.isBiggerThanValue(hlcSince) |
            t.uploadFactsHlc.isBiggerThanValue(hlcSince) |
            t.verifyFactsHlc.isBiggerThanValue(hlcSince),
      );
    }
```

`_maxHlcInData`: iterate the map's entries so each list knows its entity key, and count fact clocks:

```dart
  String? _maxHlcInData(SyncData data) {
    String? maxHlc;
    void consider(Object? h) {
      if (h is String && (maxHlc == null || h.compareTo(maxHlc!) > 0)) {
        maxHlc = h;
      }
    }

    for (final entry in data.toJson().entries) {
      final list = entry.value;
      if (list is! List) continue;
      final groups = SyncFactGroups.of(entry.key);
      for (final row in list) {
        if (row is! Map) continue;
        consider(row['hlc']);
        for (final g in groups) {
          consider(row[g.clockKey]);
        }
      }
    }
    return maxHlc;
  }
```

`SyncData.toJson()` keys are the entity type names (`media`, `dives`, ...); if a key differs from the entity type for media, map it the way `_baseTables` does. Import `sync_fact_groups.dart`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/sync/media_fact_export_test.dart test/core/services/sync/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync/sync_data_serializer.dart test/core/services/sync/media_fact_export_test.dart
git commit -m "feat(sync): export a media row when its facts change, and only once

A fact write stamps its group clock rather than the row clock, so the
incremental media export selects a row when either clock is past the
watermark, and the published watermark counts fact clocks so the row is
not re-sent on every publish.

Part of #2090, refs #2097"
```

---

### Task 6: Merge each fact group by its own clock

**Files:**
- Modify: `lib/core/services/sync/sync_fact_groups.dart` (add `mergeFactGroups`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (add `writeFactGroup`)
- Modify: `lib/core/services/sync/sync_service.dart` (`_mergeEntity`)
- Modify: `test/core/services/sync/sync_fact_groups_test.dart` (merge half)
- Create: `test/core/services/sync/media_fact_merge_test.dart`

**Interfaces:**
- Produces:

```dart
/// The winning side's values for every fact group of [entityType].
typedef FactResolution = ({
  Map<String, dynamic> row,              // base row with every group's winner applied
  List<SyncFactGroup> fromRemote,         // groups the peer won
});
FactResolution mergeFactGroups({
  required String entityType,
  required Map<String, dynamic> base,
  required Map<String, dynamic>? local,
  required Map<String, dynamic> remote,
});
// SyncDataSerializer
Future<void> writeFactGroup(String entityType, String recordId,
    SyncFactGroup group, Map<String, dynamic> values);
```

**Resolution rule** (implement exactly; the tests pin each line):
1. A side's effective group clock is its `clockKey` value when it is a non-empty string, else that side's `hlc`.
2. With no local row, every group comes from the peer.
3. The peer wins a group when its effective clock is non-null and either the local effective clock is null or the peer's is strictly greater (canonical HLC strings compare with `String.compareTo`, as `_maxHlc` does). A tie or an older peer clock keeps local.
4. Both effective clocks null: the group follows `base` (the side that won the row), which is today's behaviour.
5. The winner supplies every column of the group its row actually carries, explicit nulls included, and its effective clock is written into `clockKey`, so a legacy peer's row clock becomes the local fact clock.
6. An omitted key is not a clear. A peer that predates a column sends no key for it, so the merge keeps the local value for any group column the winner's row does not contain, and writes a clear only for a key that is present with a null value. Without this, a legacy peer winning the group on its row clock would blank every column it has never heard of.

- [ ] **Step 1: Write the failing tests**

Append to `sync_fact_groups_test.dart`:

```dart
  group('mergeFactGroups', () {
    Map<String, dynamic> row({
      String hlc = 'H0',
      String? upload,
      String? verify,
      int? uploadedAt,
      String? hash,
      bool orphaned = false,
    }) => {
      'id': 'm1',
      'caption': 'c-$hlc',
      'hlc': hlc,
      'uploadFactsHlc': upload,
      'verifyFactsHlc': verify,
      'contentHash': hash,
      'contentSizeBytes': hash == null ? null : 10,
      'remoteUploadedAt': uploadedAt,
      'remoteThumbUploadedAt': null,
      'remoteCompressedUploadedAt': null,
      'compressedLevel': null,
      'compressedSizeBytes': null,
      'isOrphaned': orphaned,
      'lastVerifiedAt': null,
    };

    test('the peer wins a group only with a strictly newer clock', () {
      final local = row(hlc: 'H5', upload: 'H3', uploadedAt: null);
      final remote = row(hlc: 'H1', upload: 'H4', uploadedAt: 99, hash: 'h');
      final r = mergeFactGroups(
          entityType: 'media', base: local, local: local, remote: remote);
      expect(r.row['caption'], 'c-H5', reason: 'the row stays local');
      expect(r.row['remoteUploadedAt'], 99);
      expect(r.row['contentHash'], 'h');
      expect(r.row['uploadFactsHlc'], 'H4');
      expect(r.fromRemote.map((g) => g.name), ['upload']);
    });

    test('a newer clear lands as null', () {
      final local = row(upload: 'H2', uploadedAt: 50, hash: 'h');
      final remote = row(upload: 'H3', uploadedAt: null, hash: 'h');
      final r = mergeFactGroups(
          entityType: 'media', base: local, local: local, remote: remote);
      expect(r.row.containsKey('remoteUploadedAt'), isTrue);
      expect(r.row['remoteUploadedAt'], isNull);
    });

    test('an older or tied peer clock keeps local', () {
      final local = row(upload: 'H3', uploadedAt: 50);
      for (final clock in ['H2', 'H3']) {
        final r = mergeFactGroups(
          entityType: 'media',
          base: local,
          local: local,
          remote: row(upload: clock, uploadedAt: 1),
        );
        expect(r.row['remoteUploadedAt'], 50, reason: clock);
        expect(r.fromRemote, isEmpty);
      }
    });

    test('a legacy peer without fact clocks orders by its row clock', () {
      final local = row(hlc: 'H2', upload: 'H2', uploadedAt: null);
      final remote = row(hlc: 'H6', uploadedAt: 7)
        ..remove('uploadFactsHlc')
        ..remove('verifyFactsHlc');
      final r = mergeFactGroups(
          entityType: 'media', base: remote, local: local, remote: remote);
      expect(r.row['remoteUploadedAt'], 7);
      expect(r.row['uploadFactsHlc'], 'H6');
    });

    test('groups resolve independently', () {
      final local = row(upload: 'H5', verify: 'H1', uploadedAt: 5);
      final remote = row(upload: 'H1', verify: 'H5', uploadedAt: 1, orphaned: true);
      final r = mergeFactGroups(
          entityType: 'media', base: local, local: local, remote: remote);
      expect(r.row['remoteUploadedAt'], 5);
      expect(r.row['isOrphaned'], isTrue);
    });

    test('an entity without groups returns base untouched', () {
      final base = {'id': 'd1', 'hlc': 'H1'};
      final r = mergeFactGroups(
          entityType: 'dives', base: base, local: base, remote: base);
      expect(identical(r.row, base) || r.row == base, isTrue);
      expect(r.fromRemote, isEmpty);
    });

    test('no local row takes every group from the peer', () {
      final remote = row(upload: 'H1', uploadedAt: 3);
      final r = mergeFactGroups(
          entityType: 'media', base: remote, local: null, remote: remote);
      expect(r.row['remoteUploadedAt'], 3);
    });
  });
```

Real HLC strings are longer; the tests use short strings because only their order matters and the rule compares strings.

```dart
// test/core/services/sync/media_fact_merge_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Through the real merge: a peer's newer facts land on an older row, a
/// cleared stamp lands as null, and a stamp never carries a stale caption.
void main() {
  late AppDatabase db;

  SyncPayload payloadWith(List<Map<String, dynamic>> media) => SyncPayload(
    version: 1, exportedAt: 0, deviceId: 'peer', checksum: '',
    data: SyncData(media: media), deletions: const {});

  Future<void> apply(Map<String, dynamic> row) => SyncService(
    syncRepository: SyncRepository(), serializer: SyncDataSerializer(),
  ).debugApplyPayload(payloadWith([row]));

  Future<Map<String, Object?>> read() async => (await db
          .customSelect(
            'SELECT caption, remote_uploaded_at, content_hash, '
            'upload_facts_hlc FROM media WHERE id = ?',
            variables: [Variable.withString('m1')])
          .getSingle())
      .data;

  Future<Map<String, dynamic>> local() async =>
      (await SyncDataSerializer().fetchRecord('media', 'm1'))!;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 0,
      alsoStamp: SyncFactGroups.of('media'));
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('newer facts land while an older row keeps the local caption',
      () async {
    final stale = await local(); // the peer's snapshot of the row
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.customStatement(
        "UPDATE media SET caption = 'mine' WHERE id = 'm1'");
    await SyncRepository().markRecordPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 1);

    await apply({
      ...stale,
      'caption': 'stale',
      'contentHash': 'h',
      'contentSizeBytes': 10,
      'remoteUploadedAt': 99,
      'uploadFactsHlc': SyncClock.instance.issue(),
    });

    final r = await read();
    expect(r['caption'], 'mine');
    expect(r['remote_uploaded_at'], 99);
    expect(r['content_hash'], 'h');
  });

  test('a newer clear lands as null even though the upsert drops nulls',
      () async {
    await db.customStatement(
      "UPDATE media SET content_hash = 'h', remote_uploaded_at = 50 "
      "WHERE id = 'm1'");
    await SyncRepository().markFactsPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload);
    final l = await local();

    await apply({
      ...l,
      'remoteUploadedAt': null,
      'uploadFactsHlc': SyncClock.instance.issue(),
    });

    expect((await read())['remote_uploaded_at'], isNull);
  });

  test('older facts do not overwrite newer local ones', () async {
    final stale = await local();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.customStatement(
        "UPDATE media SET remote_uploaded_at = 50 WHERE id = 'm1'");
    await SyncRepository().markFactsPending(
      entityType: 'media', recordId: 'm1', localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload);

    await apply({...stale, 'remoteUploadedAt': null});

    expect((await read())['remote_uploaded_at'], 50);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/services/sync/sync_fact_groups_test.dart test/core/services/sync/media_fact_merge_test.dart`
Expected: FAIL to compile (`mergeFactGroups` missing); once it compiles, the three merge tests FAIL (older row's facts are refused with the row; the clear is dropped by the upsert).

- [ ] **Step 3: Implement the pure merge**

Append to `sync_fact_groups.dart`:

```dart
/// The resolved row and the groups the peer won.
typedef FactResolution = ({
  Map<String, dynamic> row,
  List<SyncFactGroup> fromRemote,
});

String? _effectiveClock(Map<String, dynamic>? side, SyncFactGroup g) {
  if (side == null) return null;
  final own = side[g.clockKey];
  if (own is String && own.isNotEmpty) return own;
  final row = side['hlc'];
  return row is String && row.isNotEmpty ? row : null;
}

/// Applies each fact group's winner onto [base], the row that won the user
/// fields (spec 5.1). See the resolution rule in the Phase 1 plan: a group
/// is the peer's only on a strictly newer effective clock; the winner
/// supplies every column of the group, explicit nulls included, and its
/// effective clock becomes the group clock.
FactResolution mergeFactGroups({
  required String entityType,
  required Map<String, dynamic> base,
  required Map<String, dynamic>? local,
  required Map<String, dynamic> remote,
}) {
  final groups = SyncFactGroups.of(entityType);
  if (groups.isEmpty) return (row: base, fromRemote: const []);
  var row = base;
  final fromRemote = <SyncFactGroup>[];
  for (final g in groups) {
    final localClock = _effectiveClock(local, g);
    final remoteClock = _effectiveClock(remote, g);
    final Map<String, dynamic> winner;
    final String? clock;
    if (local == null ||
        (remoteClock != null &&
            (localClock == null || remoteClock.compareTo(localClock) > 0))) {
      winner = remote;
      clock = remoteClock;
      fromRemote.add(g);
    } else if (localClock == null && remoteClock == null) {
      winner = base;
      clock = null;
    } else {
      winner = local;
      clock = localClock;
    }
    row = {
      ...row,
      for (final key in g.columns.keys) key: winner[key],
      g.clockKey: clock,
    };
  }
  return (row: row, fromRemote: fromRemote);
}
```

`writeFactGroup` in `SyncDataSerializer` (media is the only entity with groups; keep the table lookup generic through `SyncRepository.hlcTargets`):

```dart
  /// Writes one fact group's columns and clock with explicit values, nulls
  /// included. The media upsert builds its insert with nullToAbsent, so a
  /// cleared stamp would never land through it (spec 5.1).
  Future<void> writeFactGroup(
    String entityType,
    String recordId,
    SyncFactGroup group,
    Map<String, dynamic> values,
  ) async {
    final target = SyncRepository.hlcTargets[entityType];
    if (target == null) return;
    final assignments = {
      ...group.columns,
      group.clockKey: group.clockColumn,
    };
    final set = assignments.values.map((c) => '"$c" = ?').join(', ');
    final args = [
      for (final key in assignments.keys)
        switch (values[key]) {
          final bool b => b ? 1 : 0,
          final Object? v => v,
        },
    ];
    await _db.customStatement(
      'UPDATE "${target.table}" SET $set WHERE "${target.pk}" = ?',
      [...args, recordId],
    );
  }
```

Import `sync_repository.dart` if the serializer does not already.

- [ ] **Step 4: Wire it into `_mergeEntity`**

Before the loop, next to `toUpsert`:

```dart
    final factGroups = SyncFactGroups.of(entityType);
    // Fact groups written after the batched upsert, so explicit nulls land.
    final factWrites = <({String id, Map<String, dynamic> row, List<SyncFactGroup> groups})>[];
```

and extend the fetch condition to `hasUpdatedAt || clockGuarded || factGroups.isNotEmpty`.

In the blind-upsert branch, restructure the guard so a stale row still hands over its newer facts:

```dart
        if (!hasUpdatedAt) {
          final local = localById[recordId];
          var rowFromRemote = true;
          if (clockGuarded) {
            final remoteHlc = _extractHlc(record);
            if (remoteHlc != null) SyncClock.instance.receive(remoteHlc);
            for (final g in factGroups) {
              final c = _parseHlc(record[g.clockKey]);
              if (c != null) SyncClock.instance.receive(c);
            }
            final localHlc = _extractHlc(local);
            // (existing comment about the stale-copy guard stays here)
            if (localHlc != null &&
                remoteHlc != null &&
                remoteHlc.compareTo(localHlc) < 0) {
              rowFromRemote = false;
            }
          }
          if (factGroups.isEmpty) {
            if (!rowFromRemote) continue;
            toUpsert.add(recordToApply);
            applied += 1;
            continue;
          }
          final resolved = mergeFactGroups(
            entityType: entityType,
            base: rowFromRemote ? recordToApply : local!,
            local: local,
            remote: recordToApply,
          );
          if (rowFromRemote) {
            toUpsert.add(resolved.row);
            factWrites.add((id: recordId, row: resolved.row, groups: factGroups));
            applied += 1;
          } else if (resolved.fromRemote.isNotEmpty) {
            factWrites.add(
              (id: recordId, row: resolved.row, groups: resolved.fromRemote),
            );
            applied += 1;
          }
          continue;
        }
```

After the `upsertRecords` flush (inside the method, before `return`):

```dart
    for (final w in factWrites) {
      try {
        for (final g in w.groups) {
          await _serializer.writeFactGroup(entityType, w.id, g, w.row);
        }
      } catch (e, stackTrace) {
        _log.error('Failed to write facts for $entityType ${w.id}',
            error: e, stackTrace: stackTrace);
        failed += 1;
        applied -= 1;
      }
    }
```

When the row came from the peer every group is rewritten explicitly, so a peer's null in a group it won lands even though the upsert dropped it. Import `sync_fact_groups.dart`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/services/sync/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/core/services/sync test/core/services/sync
git commit -m "feat(sync): merge media's facts by their own clocks

After the row is resolved, each fact group takes the side with the newer
group clock, so a peer's newer upload stamp lands on an otherwise older
row and a newer clear lands as null through a targeted write (the media
upsert drops nulls). A missing group clock falls back to the row clock.

Part of #2090, refs #2097"
```

---

### Task 7: Fact writers stamp their group clock

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`
- Create: `test/features/media/data/media_repository_fact_clock_test.dart`
- Modify: `test/features/media/two_device/row_sync_scenarios_test.dart` (remove the S1 skip)

The writers and the call each gets (method names from main at 1eb59813be4; line numbers drift):

| Method | Writes | Call |
| --- | --- | --- |
| `stampContentIdentity` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `stampRemoteUploaded` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `stampRemoteThumbUploaded` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `stampRemoteCompressedUploaded` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `clearRemoteUploaded` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `clearRemoteThumbUploaded` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `clearRemoteCompressed` | upload | `markFactsPending(group: SyncFactGroups.mediaUpload)` |
| `markAsOrphaned` | verification | `markFactsPending(group: SyncFactGroups.mediaVerification)` |
| `markAsVerified` | verification | `markFactsPending(group: SyncFactGroups.mediaVerification)` |
| `markOrphaned` | verification | `markFactsPending(group: SyncFactGroups.mediaVerification)` |
| `markVerified` | verification | `markFactsPending(group: SyncFactGroups.mediaVerification)` |
| `stampVerification` | verification | `markFactsPending(group: SyncFactGroups.mediaVerification)` |
| `applyRepairWrites` | pointer + verification | `markRecordPending(alsoStamp: [SyncFactGroups.mediaVerification])` |
| `convertToCloudBacked` | pointer + verification | `markRecordPending(alsoStamp: [SyncFactGroups.mediaVerification])` |
| `createMedia` | whole new row | `markRecordPending(alsoStamp: SyncFactGroups.of('media'))` |
| `republishForSync` | no column change; re-sends stamps | `markFactsPending` for both groups, in its existing transaction |

| `updateMedia` | whole row, fact columns included | `markRecordPending(alsoStamp: _changedFactGroups(previous, item))` |

`setManualElapsedSeconds` and every unlink or link write stay on plain
`markRecordPending`: they are user edits that touch no fact column.

`updateMedia` cannot, because it writes the whole row and callers use it to
set `contentHash`, `contentSizeBytes`, the three `remoteUploadedAt` stamps,
`compressedLevel`, `compressedSizeBytes`, `isOrphaned` and `lastVerifiedAt`.
Left on a bare `markRecordPending` it would move those columns while their
fact clocks stayed behind, and the next merge would resurrect the old stamps
over them. It reads the row first and stamps only the groups whose columns
actually changed, so a caption edit still moves nothing but the row clock:

```dart
List<SyncFactGroup> _changedFactGroups(
  domain.MediaItem? previous,
  domain.MediaItem next,
) {
  if (previous == null) return SyncFactGroups.of('media');
  final groups = <SyncFactGroup>[];
  if (previous.contentHash != next.contentHash ||
      previous.contentSizeBytes != next.contentSizeBytes ||
      previous.remoteUploadedAt != next.remoteUploadedAt ||
      previous.remoteThumbUploadedAt != next.remoteThumbUploadedAt ||
      previous.remoteCompressedUploadedAt != next.remoteCompressedUploadedAt ||
      previous.compressedLevel != next.compressedLevel ||
      previous.compressedSizeBytes != next.compressedSizeBytes) {
    groups.add(SyncFactGroups.mediaUpload);
  }
  if (previous.isOrphaned != next.isOrphaned ||
      previous.lastVerifiedAt != next.lastVerifiedAt) {
    groups.add(SyncFactGroups.mediaVerification);
  }
  return groups;
}
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/media/data/media_repository_fact_clock_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Every fact write stamps its own group's clock and leaves the row clock
/// alone, so a stamp can never make a stale caption win the row.
void main() {
  late AppDatabase db;
  late String id;
  final repo = MediaRepository();

  Future<Map<String, String?>> clocks() async {
    final r = await db
        .customSelect(
          'SELECT hlc, upload_facts_hlc, verify_facts_hlc FROM media WHERE id = ?',
          variables: [Variable.withString(id)])
        .getSingle();
    return {
      'row': r.read<String?>('hlc'),
      'upload': r.read<String?>('upload_facts_hlc'),
      'verify': r.read<String?>('verify_facts_hlc'),
    };
  }

  setUp(() async {
    db = await setUpTestDatabase();
    id = (await repo.createMedia(MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: '/nowhere/reef.jpg',
      takenAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    ))).id;
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('createMedia stamps both fact clocks with the row clock', () async {
    final c = await clocks();
    expect(c['row'], isNotNull);
    expect(c['upload'], c['row']);
    expect(c['verify'], c['row']);
  });

  final uploadWriters = <String, Future<void> Function(String)>{
    'stampContentIdentity': (i) =>
        repo.stampContentIdentity(i, contentHash: 'h', sizeBytes: 1),
    'stampRemoteUploaded': (i) =>
        repo.stampRemoteUploaded(i, uploadedAt: DateTime(2026)),
    'stampRemoteThumbUploaded': (i) =>
        repo.stampRemoteThumbUploaded(i, uploadedAt: DateTime(2026)),
    'clearRemoteUploaded': repo.clearRemoteUploaded,
    'clearRemoteThumbUploaded': repo.clearRemoteThumbUploaded,
    'clearRemoteCompressed': repo.clearRemoteCompressed,
  };
  final verifyWriters = <String, Future<void> Function(String)>{
    'markAsOrphaned': repo.markAsOrphaned,
    'markAsVerified': repo.markAsVerified,
    'markOrphaned': (i) => repo.markOrphaned(i, true),
    'markVerified': (i) =>
        repo.markVerified(i, isOrphaned: true, verifiedAt: DateTime(2026)),
  };

  for (final e in uploadWriters.entries) {
    test('${e.key} stamps the upload clock only', () async {
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await e.value(id);
      final after = await clocks();
      expect(after['row'], before['row'], reason: 'row clock unchanged');
      expect(after['verify'], before['verify']);
      expect(after['upload']!.compareTo(before['upload']!), greaterThan(0));
    });
  }

  for (final e in verifyWriters.entries) {
    test('${e.key} stamps the verification clock only', () async {
      final before = await clocks();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await e.value(id);
      final after = await clocks();
      expect(after['row'], before['row'], reason: 'row clock unchanged');
      expect(after['upload'], before['upload']);
      expect(after['verify']!.compareTo(before['verify']!), greaterThan(0));
    });
  }

  test('republishForSync moves only the fact clocks', () async {
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.republishForSync([id]);
    final after = await clocks();
    expect(after['row'], before['row']);
    expect(after['upload']!.compareTo(before['upload']!), greaterThan(0));
    expect(after['verify']!.compareTo(before['verify']!), greaterThan(0));
  });

  test('a user edit moves only the row clock', () async {
    final before = await clocks();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.setManualElapsedSeconds(id, 30);
    final after = await clocks();
    expect(after['row']!.compareTo(before['row']!), greaterThan(0));
    expect(after['upload'], before['upload']);
    expect(after['verify'], before['verify']);
  });
}
```

Adjust each writer's call to its real signature on main (read the method; for example `stampRemoteCompressedUploaded` takes the level and size, `stampVerification` takes a verdict). Add `stampRemoteCompressedUploaded` and `stampVerification` to the maps once their arguments are known; both belong in the table above. `applyRepairWrites` and `convertToCloudBacked` get one test each: the row clock and the verification clock both advance and are equal; the upload clock does not move (`convertToCloudBacked` needs `content_hash` and `remote_uploaded_at` set first, or it refuses the row).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/media/data/media_repository_fact_clock_test.dart`
Expected: "createMedia stamps both" FAILS (clocks null); every writer test FAILS at "row clock unchanged".

- [ ] **Step 3: Implement**

Apply the table: in each fact writer replace

```dart
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
```

with

```dart
    await _syncRepository.markFactsPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
      group: SyncFactGroups.mediaUpload, // or mediaVerification per the table
    );
```

keeping each method's own id variable name. In `createMedia`, `applyRepairWrites` and `convertToCloudBacked` add the `alsoStamp:` argument from the table. In `republishForSync`, replace its per-id `markRecordPending` with two `markFactsPending` calls (upload, then verification) inside the existing transaction, and update its doc comment: it re-sends the facts without claiming a user edit. Import `package:submersion/core/services/sync/sync_fact_groups.dart`.

Then find fact writes outside the repository:

```bash
git grep -n -E "(contentHash|remoteUploadedAt|remoteThumbUploadedAt|remoteCompressedUploadedAt|compressedLevel|compressedSizeBytes|isOrphaned|lastVerifiedAt|contentSizeBytes):\s*(const )?Value" -- lib ':!lib/features/media/data/repositories/media_repository.dart' ':!lib/core/database'
```

Each hit that writes the media table and then marks it pending gets the same treatment; list them in the PR body.

- [ ] **Step 4: Run the tests and turn S1 on**

Run: `flutter test test/features/media/data/media_repository_fact_clock_test.dart`
Expected: PASS.

Delete the `skip:` argument from S1 in `test/features/media/two_device/row_sync_scenarios_test.dart`.

Run: `flutter test test/features/media/two_device/`
Expected: S0, S0b, S1 and S3 pass; S2 and the rest stay skipped.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/features/media test/features/media
git commit -m "fix(media): stamp upload and verification facts on their own clocks

Every upload and verification write now stamps its group's clock and
leaves the row clock alone, so a stamp written after a caption edit can no
longer make the stale caption win. New rows stamp both fact clocks, repair
and cloud conversion stamp the verification clock with the pointer edit,
and the origin republish re-sends facts without claiming a user edit.
Turns scenario S1 green.

Part of #2090, refs #2097"
```

---

### Task 8: Verify and open the PR

- [ ] **Step 1: Re-scan the schema rung**

```bash
gh pr list --repo submersion-app/submersion --state open --limit 60 --json number --jq '.[].number' | while read n; do gh pr diff $n --repo submersion-app/submersion | grep -E "^\+.*currentSchemaVersion = [0-9]+" | sed "s/^/#$n: /"; done
```

and check every local worktree's `lib/core/database/database.dart`. If 223 is claimed, renumber per Global Constraints.

- [ ] **Step 2: Full affected run**

Run: `flutter test test/core test/features/media test/features/media_store test/features/dive_log/integration test/features/settings test/architecture`
Expected: PASS, with S2 and S4 to S10 still skipped.

- [ ] **Step 3: Push and open the PR**

Base `main` if #2140 has merged, else `ericgriffin/media-sync-s1-harness` (then retarget after it merges; a branch-based PR gets no CI). Body: what the three rules do, the schema rung, "Tests that pinned the skip" from Task 1 Step 5, fact writers found outside the repository in Task 7 Step 3, and `Part of #2090` / `Refs #2097`.

---

## Known limits (not in this slice)

- **Media user-field clears.** The media upsert drops explicit nulls for every column, so a peer clearing a caption does not land either. Fact groups get a targeted write here; user fields are a separate fix.
- **Clockless rows stay skipped while pending.** Rows with no clock on either side keep today's skip, and the cursor still advances past them.
- **Quiet verification is slice 4.** Verification writes now stamp their own clock, but a Check all still writes every row; slice 4 makes inconclusive outcomes write nothing.

## Self-review against the spec

- **5.1 pending rule:** Task 1, narrowed to rows both sides can order (spec updated to say so).
- **5.1 media tables join the stale-copy guard through their own set:** Task 2.
- **5.1 fact groups with clock columns, fallback to row clock, v223 backfill, create stamps both, targeted write for nulls, export and watermark:** Tasks 3 to 7.
- **Slice 3 turns S1 and S3 green:** S3 in Task 2, S1 in Task 7.
- **Placeholders:** none. Three spots tell the executor to confirm an existing signature (`exportData`'s incremental parameter, the compressed-upload and verification writers' arguments, `clearPendingRecords`' parameter); the design does not depend on their spelling.
- **Type consistency:** `SyncFactGroup`, `SyncFactGroups.mediaUpload` / `.mediaVerification` / `.of`, `markFactsPending(group:)`, `markRecordPending(alsoStamp:)`, `mergeFactGroups` returning `FactResolution`, `writeFactGroup`, `clockGuardedEntities` are spelled the same in every task.
