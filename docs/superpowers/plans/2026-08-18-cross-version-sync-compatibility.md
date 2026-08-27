# Cross-Version Sync Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End the review-window sync blackout between App Store and direct-download builds by stamping a compatibility floor into sync manifests, hardening restore against newer-schema backups, and making the held-peer messaging honest.

**Architecture:** The writer stamps `minimumCompatibleSchemaVersion` (the floor) into the manifest field shipped readers already compare, so old devices resume syncing with no update on their side; the gate predicate is untouched. The receiving-side safety this relies on (the #474 overlay merge) is locked in by a characterization test first. Restore gets pre-checks at both entry points plus an automatic post-swap rollback.

**Tech Stack:** Flutter/Dart, Drift ORM, sqlite3, flutter_test, gen_l10n.

**Spec:** `docs/superpowers/specs/2026-08-17-cross-version-sync-compatibility-design.md`

## Global Constraints

- Never use the em-dash character (U+2014) in any output: code, comments, docs, commit messages. No " - " as prose punctuation either. Rewrite with commas, colons, or parentheses.
- No emojis in code, comments, or documentation.
- All new user-facing strings go into ALL 11 locale files under `lib/l10n/arb/` (ar, de, en, es, fr, he, hu, it, nl, pt, zh), then run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart` files.
- Run `dart format .` before every commit; the pre-push hook rejects unformatted code.
- `flutter analyze` must be clean at whole-project scope (infos are fatal in CI).
- Never pipe test runs through `| tail`; it masks the exit code. Never run two `flutter test` invocations concurrently on this machine.
- Work in a dedicated git worktree branched from `origin/main`. After creating it run: `git submodule update --init --recursive`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs` (worktrees do not inherit codegen or submodules).
- Commit messages: no Claude attribution lines, no session URLs.
- The current schema version is `AppDatabase.currentSchemaVersion` (153 at plan time). Never hardcode 153 in tests; always reference the constant. The floor constant is 137.

---

### Task 1: Characterization test locking in the cross-version overlay

The whole design rests on the receiving side preserving columns an old peer omits. This test freezes that behavior before anything else changes. It passes against current code; a future regression in `_overlayOntoLocal`, LWW tie handling, or `upsertRecords` breaks it loudly.

**Files:**

- Create: `test/core/services/sync/cross_version_roundtrip_test.dart`

**Interfaces:**

- Consumes: existing test helpers `setUpTestDatabase`, `createTestDiveWithBottomTime`, `seedPeerBaseFromPayload`, `FakeCloudStorageProvider`; `Hlc` from `lib/core/services/sync/hlc.dart`.
- Produces: the file itself, plus the convention that `postV137DiveKeys` lists dives-table JSON keys added after schema 137. Task 2's floor doc comment references this file by path.

- [ ] **Step 1: Write the test file**

```dart
// Characterization tests for cross-version sync (issue #1089).
//
// A peer on an older schema (the App Store fleet during an Apple review
// window) republishes rows WITHOUT the columns its build does not know.
// These tests freeze the receiving-side behavior that makes that safe:
//  - the #474 overlay refills omitted keys from the local row,
//  - a tied HLC keeps local (an unedited old-peer snapshot applies nothing),
//  - rows created on the old device apply with newer columns as null.
// The compatibility floor (AppDatabase.minimumCompatibleSchemaVersion)
// asserts this safety; when a migration raises the floor, extend
// postV137DiveKeys and add the analogous projection for the new boundary.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// The dives-table JSON keys a schema-137 (v1.7.2) build does not know.
/// From the migration ladder: v144 added dives.visibility_meters; no other
/// dives column landed between 138 and 153. Extend this list when a later
/// migration adds a dives column, so the projection stays a faithful model
/// of what the oldest supported reader republishes.
const postV137DiveKeys = ['visibilityMeters'];

void main() {
  group('v137 peer round-trip through the real merge path (#1089)', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() => DatabaseService.instance.resetForTesting());

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    /// Seeds a synced (non-pending) dive carrying a post-137 column value,
    /// returning its full exported JSON: the row as this newer device would
    /// publish it.
    Future<Map<String, dynamic>> seedModernDive(String id) async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: id).copyWith(name: 'Original Name'),
      );
      final db = DatabaseService.instance.database;
      await db.customStatement(
        'UPDATE dives SET visibility_meters = 12.5 WHERE id = ?',
        [id],
      );
      final row = await SyncDataSerializer().fetchRecord('dives', id);
      expect(row!['visibilityMeters'], 12.5, reason: 'precondition');
      expect(row['hlc'], isNotNull, reason: 'precondition: row is clocked');
      await SyncRepository().resetSyncState();
      return Map<String, dynamic>.from(row);
    }

    /// Projects [row] onto the v137 dives schema: exactly what a 1.7.2 device
    /// ends up storing (fromJson ignores unknown keys) and later re-exporting
    /// (its row genuinely lacks the newer columns, so their keys are absent).
    Map<String, dynamic> asV137Peer(Map<String, dynamic> row) {
      final projected = Map<String, dynamic>.from(row);
      for (final key in postV137DiveKeys) {
        projected.remove(key);
      }
      return projected;
    }

    /// Publishes [diveRow] as peer `peer-137`'s data and pulls it through the
    /// full real pipeline (performSync, _mergeEntity, overlay, upsert).
    Future<void> pullPeerDive(Map<String, dynamic> diveRow) async {
      final data = SyncData(dives: [diveRow]);
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-137',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-137', payload);
      final result = await buildService().performSync();
      // A per-row apply failure flips the whole run to error, so this
      // assertion covers recordsFailed too.
      expect(result.status, isNot(SyncResultStatus.error));
    }

    test('old-peer edit applies AND the post-137 column survives', () async {
      final row = await seedModernDive('dive-xver');

      // The v137 peer edits the dive: its republished row carries only v137
      // keys, the edit, and a strictly-greater HLC minted by its own clock.
      final peerRow = asV137Peer(row)
        ..['name'] = 'Renamed on old device'
        ..['hlc'] = Hlc(
          Hlc.parse(row['hlc'] as String).physicalTime + 60000,
          0,
          'peer-137',
        ).toString()
        ..['updatedAt'] = (row['updatedAt'] as int) + 60000;

      await pullPeerDive(peerRow);

      final after = await SyncDataSerializer().fetchRecord(
        'dives',
        'dive-xver',
      );
      expect(
        after!['name'],
        'Renamed on old device',
        reason: 'the old peer legitimately won LWW; its edit must apply',
      );
      expect(
        after['visibilityMeters'],
        12.5,
        reason: 'THE HAZARD: the column the old peer never knew must survive',
      );
    });

    test(
      'tied-HLC republish (unedited old-peer snapshot) applies nothing',
      () async {
        final row = await seedModernDive('dive-tie');

        // The old peer republishes its full base without editing: same HLC.
        final peerRow = asV137Peer(row)..['name'] = 'Should Not Apply';

        await pullPeerDive(peerRow);

        final after = await SyncDataSerializer().fetchRecord(
          'dives',
          'dive-tie',
        );
        expect(
          after!['name'],
          'Original Name',
          reason: 'a tied HLC keeps local; nothing applies',
        );
        expect(after['visibilityMeters'], 12.5);
      },
    );

    test('row CREATED on the old device applies cleanly', () async {
      final template = await seedModernDive('dive-template');

      // A brand-new dive logged on the v137 device: no post-137 keys at all,
      // an id this device has never seen, the old device's own clock.
      final peerRow = asV137Peer(template)
        ..['id'] = 'dive-born-on-137'
        ..['name'] = 'Logged on old device'
        ..['hlc'] = Hlc(
          Hlc.parse(template['hlc'] as String).physicalTime + 60000,
          0,
          'peer-137',
        ).toString();

      await pullPeerDive(peerRow);

      final after = await SyncDataSerializer().fetchRecord(
        'dives',
        'dive-born-on-137',
      );
      expect(after, isNotNull, reason: 'the new row must apply');
      expect(after!['name'], 'Logged on old device');
      expect(
        after['visibilityMeters'],
        isNull,
        reason: 'nullable post-137 column backfills as null, not garbage',
      );
    });
  });
}
```

- [ ] **Step 2: Run it, expect PASS (characterization of current behavior)**

Run: `flutter test test/core/services/sync/cross_version_roundtrip_test.dart`
Expected: `+3: All tests passed!`

If any test fails, STOP: the design's premise is broken and the spec needs revisiting. Do not weaken the assertions to get green.

- [ ] **Step 3: Format and commit**

```bash
dart format test/core/services/sync/cross_version_roundtrip_test.dart
git add test/core/services/sync/cross_version_roundtrip_test.dart
git commit -m "test(sync): characterize cross-version overlay round-trip (#1089)"
```

---

### Task 2: Compatibility floor constant, manifest field, writer stamp

**Files:**

- Modify: `lib/core/database/database.dart` (after `currentSchemaVersion`, near line 3072)
- Modify: `lib/core/services/sync/changeset_log/sync_manifest.dart` (constructor, fields, `toJson`, `fromJson`)
- Modify: `lib/core/services/sync/changeset_log/changeset_writer.dart` (4 stamp sites, near lines 203, 279, 311, 466)
- Test: `test/core/services/sync/changeset_log/sync_manifest_test.dart`
- Test: `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`

**Interfaces:**

- Consumes: `AppDatabase.currentSchemaVersion` (`static const int`, currently 153).
- Produces: `AppDatabase.minimumCompatibleSchemaVersion` (`static const int` = 137); `SyncManifest.writerSchemaVersion` (`final int?`, JSON key `writerSchemaVersion`). Tasks 3 and the floor doc reference both.

- [ ] **Step 1: Update the writer-stamp expectation in the schema-gate test (it will fail)**

In `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`, find the test `'published manifests are stamped with the schema version'` and change its final assertion block from:

```dart
    expect(manifest.schemaVersion, AppDatabase.currentSchemaVersion);
```

to:

```dart
    expect(
      manifest.schemaVersion,
      AppDatabase.minimumCompatibleSchemaVersion,
      reason: 'the gate field carries the floor so shipped readers '
          'only hold peers across declared breaking changes',
    );
    expect(manifest.writerSchemaVersion, AppDatabase.currentSchemaVersion);
```

Rename the test to `'published manifests are stamped with the floor and writer schema'`.

- [ ] **Step 2: Add a manifest JSON round-trip test (it will fail)**

In `test/core/services/sync/changeset_log/sync_manifest_test.dart`, add (mirror the file's existing round-trip test style for constructing a manifest; reuse its minimal constructor arguments):

```dart
  test('writerSchemaVersion round-trips through JSON and defaults null', () {
    final manifest = SyncManifest.fromJson({
      'deviceId': 'd1',
      'provider': 'fake',
      'headSeq': 0,
      'updatedAt': 0,
      'schemaVersion': 137,
      'writerSchemaVersion': 153,
    });
    expect(manifest.schemaVersion, 137);
    expect(manifest.writerSchemaVersion, 153);
    expect(
      SyncManifest.fromJson(manifest.toJson()).writerSchemaVersion,
      153,
    );

    // A manifest written before the field existed parses as null.
    final legacy = SyncManifest.fromJson({
      'deviceId': 'd1',
      'provider': 'fake',
      'headSeq': 0,
      'updatedAt': 0,
    });
    expect(legacy.writerSchemaVersion, isNull);
  });
```

- [ ] **Step 3: Run both test files to verify they fail**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: FAIL. The manifest test fails compiling (`writerSchemaVersion` undefined); the gate test fails on the floor assertion.

- [ ] **Step 4: Add the floor constant**

In `lib/core/database/database.dart`, directly below `static const int currentSchemaVersion = 153;` (near line 3072), add:

```dart
  /// The oldest schema whose reader can apply this build's sync payloads
  /// without loss or misinterpretation (the compatibility floor).
  ///
  /// Stamped into every published manifest's `schemaVersion` field, which
  /// shipped readers compare against their own schema to decide whether to
  /// hold a peer (changeset_reader.dart). Keeping the floor low lets older
  /// builds keep syncing across additive schema changes; the receiving-side
  /// overlay merge (issue #474) preserves columns an older peer omits, and
  /// test/core/services/sync/cross_version_roundtrip_test.dart locks that in.
  ///
  /// Raise this to the NEW schema version ONLY when a migration:
  ///  - drops, renames, or retypes an existing synced column,
  ///  - changes the meaning or units of an existing column's values,
  ///  - removes or folds a synced entity (the v147 buddyRoles case),
  ///  - tightens a constraint an old writer's payloads would violate.
  /// Do NOT raise it for new tables or synced entities, new nullable or
  /// defaulted columns, new indexes, dedupe passes, or data repairs that
  /// preserve meaning. When raising it, extend the round-trip test's
  /// projection so the new boundary stays covered.
  static const int minimumCompatibleSchemaVersion = 137;
```

- [ ] **Step 5: Add `writerSchemaVersion` to SyncManifest**

In `lib/core/services/sync/changeset_log/sync_manifest.dart`:

1. Constructor: add `this.writerSchemaVersion,` next to `this.schemaVersion,`.
2. Replace the existing `schemaVersion` doc comment ("The database schema version of the publishing device...") with:

```dart
  /// The oldest database schema that can apply this device's payloads
  /// without loss (the compatibility floor,
  /// AppDatabase.minimumCompatibleSchemaVersion). Readers hold a peer when
  /// this exceeds their own schema. Manifests written before 2026-08 carried
  /// the writer's actual schema version here instead, which is strictly
  /// higher, so old manifests are held MORE eagerly, never less safely. The
  /// writer's true version now travels in [writerSchemaVersion]. Null on
  /// manifests written before the field existed.
  final int? schemaVersion;
```

3. Add the new field below it:

```dart
  /// The publishing device's actual database schema version, for
  /// diagnostics and support tooling. Never used for gating; the gate
  /// compares [schemaVersion]. Null on manifests written before the field
  /// existed.
  final int? writerSchemaVersion;
```

4. `toJson`: add `'writerSchemaVersion': writerSchemaVersion,` after the `schemaVersion` entry.
5. `fromJson`: add `writerSchemaVersion: json['writerSchemaVersion'] as int?,` after the `schemaVersion` line.

- [ ] **Step 6: Stamp the floor at all four writer sites**

In `lib/core/services/sync/changeset_log/changeset_writer.dart`, change every one of the four occurrences of:

```dart
          schemaVersion: AppDatabase.currentSchemaVersion,
```

to:

```dart
          schemaVersion: AppDatabase.minimumCompatibleSchemaVersion,
          writerSchemaVersion: AppDatabase.currentSchemaVersion,
```

(Adjust indentation to each site; near lines 203, 279, 311, 466. Verify with `grep -n "schemaVersion:" lib/core/services/sync/changeset_log/changeset_writer.dart` that exactly four pairs exist afterward.)

- [ ] **Step 7: Run the two test files to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/sync_manifest_test.dart test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: PASS, including every pre-existing test in both files (the gate's hold tests use `schemaVersionOverride`, which is independent of the writer stamp).

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -u lib test
git commit -m "feat(sync): stamp compatibility floor into sync manifests (#1089)"
```

---

### Task 3: Reader floor semantics, held-peer names, SyncResult plumbing

**Files:**

- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart` (result class near line 55, gate branch near line 148, result construction near line 230)
- Modify: `lib/core/services/sync/sync_service.dart` (`SyncResult` fields near line 79, both construction sites near lines 726 and 745)
- Test: `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`

**Interfaces:**

- Consumes: `SyncManifest.deviceName` (`String?`), `SyncManifest.writerSchemaVersion` from Task 2.
- Produces: `ChangesetReadResult.newerSchemaPeerNames` (`Map<String, String>`, device id to display name, absent when the peer published no name); `SyncResult.newerSchemaPeerNames` (same shape, default `const {}`). Task 6 consumes both.

- [ ] **Step 1: Extend the schema-gate test harness and add failing tests**

In `test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`:

1. Extend the `publishPeer` helper's manifest-rewrite block to also inject a device name. Change the signature to:

```dart
  Future<void> publishPeer(
    String peerId, {
    String? epochId,
    int? schemaVersionOverride,
    String? deviceNameOverride,
  }) async {
```

and inside the existing `if (schemaVersionOverride != null)` rewrite block, generalize the condition to `if (schemaVersionOverride != null || deviceNameOverride != null)` and add, next to the `manifest['schemaVersion'] = ...` line:

```dart
      if (schemaVersionOverride != null) {
        manifest['schemaVersion'] = schemaVersionOverride;
      }
      if (deviceNameOverride != null) {
        manifest['deviceName'] = deviceNameOverride;
      }
```

2. Extend the `pull` helper to accept a reader schema:

```dart
  Future<ChangesetReadResult> pull({
    String? currentEpochId,
    int? localSchemaVersion,
  }) => reader.pull(
    provider: provider,
    selfDeviceId: 'reader-x',
    folderId: folder,
    apply: spyApply,
    applyBaseFile: spyApplyBaseFile(applied),
    currentEpochId: currentEpochId,
    localSchemaVersion: localSchemaVersion ?? AppDatabase.currentSchemaVersion,
  );
```

3. Add these tests to the group:

```dart
  test('a floor-stamped manifest from a newer writer applies on an old '
      'reader', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    // The writer is at currentSchemaVersion but stamps the floor (Task 2),
    // so a reader at exactly the floor must apply, not hold.
    await publishPeer('peer-new');

    final result = await pull(
      localSchemaVersion: AppDatabase.minimumCompatibleSchemaVersion,
    );

    expect(result.newerSchemaPeerDeviceIds, isEmpty);
    expect(result.peersProcessed, 1);
    expect(applied, isNotEmpty);
  });

  test('a floor above the local schema still holds, and collects the '
      'peer name for the banner', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer(
      'peer-future',
      schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
      deviceNameOverride: 'Future iPhone',
    );

    final result = await pull();

    expect(result.newerSchemaPeerDeviceIds, {'peer-future'});
    expect(result.newerSchemaPeerNames, {'peer-future': 'Future iPhone'});
    expect(applied, isEmpty);
  });
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart`
Expected: FAIL compiling (`newerSchemaPeerNames` undefined on `ChangesetReadResult`).

- [ ] **Step 3: Implement the reader side**

In `lib/core/services/sync/changeset_log/changeset_reader.dart`:

1. In `ChangesetReadResult`, below `newerSchemaPeerDeviceIds`, add the field and mirror it in the constructor exactly the way `skippedPeerNames` is declared and defaulted:

```dart
  /// Display names for the entries in [newerSchemaPeerDeviceIds] that
  /// published one, keyed by device id. Same fallback contract as
  /// [skippedPeerNames]: absent means the UI shows a short id label.
  final Map<String, String> newerSchemaPeerNames;
```

2. In `pull`, next to the local `skippedPeerNames` map declaration, add:

```dart
    final newerSchemaPeerNames = <String, String>{};
```

3. In the newer-schema gate branch, mirror the epoch branch's name collection:

```dart
        final peerSchema = manifest.schemaVersion;
        if (peerSchema != null && peerSchema > localSchemaVersion) {
          newerSchemaPeerDeviceIds.add(peerId);
          final name = manifest.deviceName;
          if (name != null && name.isNotEmpty) {
            newerSchemaPeerNames[peerId] = name;
          }
          continue;
        }
```

4. Pass `newerSchemaPeerNames: newerSchemaPeerNames,` in the `ChangesetReadResult(...)` construction at the end of `pull`.

- [ ] **Step 4: Plumb through SyncResult**

In `lib/core/services/sync/sync_service.dart`:

1. In `SyncResult`, below `newerSchemaPeerDeviceIds` (near line 79), add:

```dart
  /// Display names for [newerSchemaPeerDeviceIds], same contract as
  /// [skippedPeerNames].
  final Map<String, String> newerSchemaPeerNames;
```

and in the constructor, next to `this.newerSchemaPeerDeviceIds = const {},` add `this.newerSchemaPeerNames = const {},`.

2. At BOTH `SyncResult(...)` construction sites that already pass `newerSchemaPeerDeviceIds: pullResult.newerSchemaPeerDeviceIds` (near lines 726 and 745), add `newerSchemaPeerNames: pullResult.newerSchemaPeerNames,`. `pullResult` exposes the `ChangesetReadResult` fields; mirror exactly how `skippedPeerNames` flows at the same sites.

- [ ] **Step 5: Run to verify they pass**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_schema_gate_test.dart test/core/services/sync/changeset_log/changeset_reader_test.dart`
Expected: PASS (the second file guards against a constructor-signature break).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -u lib test
git commit -m "feat(sync): collect held-peer names for the newer-schema banner (#1089)"
```

---

### Task 4: Restore pre-checks for newer-schema backups

**Files:**

- Modify: `lib/features/backup/data/services/backup_service.dart` (exception near line 1450, `validateBackupFile` near line 557, `restoreFromFile` near line 727)
- Test: Create `test/features/backup/data/services/backup_service_newer_schema_test.dart`

**Interfaces:**

- Consumes: `DatabaseService.getStoredSchemaVersion(String dbPath, {String? keyHex})` returning `int?` (exists, `lib/core/services/database_service.dart` near line 391); `AppDatabase.currentSchemaVersion`; `BackupException` (`const BackupException(this.message)`).
- Produces: `BackupNewerSchemaException extends BackupException` with `final int backupSchemaVersion; final int supportedSchemaVersion;`. Existing catch sites that render `BackupException.message` need no changes.

- [ ] **Step 1: Write the failing tests**

Create `test/features/backup/data/services/backup_service_newer_schema_test.dart`. Copy the `setUp` scaffolding (the `_FakeBackupDatabaseAdapter`, preferences setup, and `BackupService` construction) from `test/features/backup/data/services/backup_service_premigration_restore_test.dart` verbatim, then add this helper and these tests:

```dart
  /// Crafts a plaintext SQLite file that passes the deep validation checks
  /// (real SQLite, has dives and dive_sites tables) but claims [userVersion].
  Future<String> craftDbFile(int userVersion) async {
    final dir = await Directory.systemTemp.createTemp('newer-schema-test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'crafted.db');
    final db = sqlite3.sqlite3.open(path);
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    db.execute('PRAGMA user_version = $userVersion');
    db.dispose();
    return path;
  }

  test('validateBackupFile rejects a newer-schema backup', () async {
    final path = await craftDbFile(AppDatabase.currentSchemaVersion + 1);
    final result = await service.validateBackupFile(path);
    expect(result.isValid, isFalse);
    expect(result.error, contains('newer version of Submersion'));
  });

  test('validateBackupFile accepts an equal-schema backup', () async {
    final path = await craftDbFile(AppDatabase.currentSchemaVersion);
    final result = await service.validateBackupFile(path);
    expect(result.isValid, isTrue);
  });

  test('validateBackupFile accepts an older-schema backup (the migration '
      'ladder handles it at restore)', () async {
    final path = await craftDbFile(AppDatabase.currentSchemaVersion - 1);
    final result = await service.validateBackupFile(path);
    expect(result.isValid, isTrue);
  });

  test('restoreFromFile refuses a newer-schema backup before any side '
      'effects', () async {
    final path = await craftDbFile(AppDatabase.currentSchemaVersion + 1);
    await expectLater(
      service.restoreFromFile(path),
      throwsA(isA<BackupNewerSchemaException>()),
    );
    expect(
      adapter.restoreCallCount,
      0,
      reason: 'the database swap must never have started',
    );
  });

  test('restoreFromFile refuses an ENCRYPTED newer-schema backup after '
      'decrypting, before any side effects', () async {
    final plainPath = await craftDbFile(AppDatabase.currentSchemaVersion + 1);
    final encPath = '$plainPath.enc';
    // Encrypt the crafted file exactly the way backup_crypto_test.dart
    // invokes BackupCrypto.encryptFile (copy its call, including the
    // extension constant BackupCrypto.fileExtension if it uses one).
    await BackupCrypto.encryptFile(plainPath, encPath, 'test-passphrase');

    await expectLater(
      service.restoreFromFile(encPath, encryptionSecret: 'test-passphrase'),
      throwsA(isA<BackupNewerSchemaException>()),
    );
    expect(adapter.restoreCallCount, 0);
  });
```

(The equal- and older-schema comparisons share one predicate with the
plaintext tests above, so the encrypted matrix needs only the refusal case.
If `BackupCrypto.encryptFile` has a different signature, mirror the call
from `test/features/backup/data/services/backup_crypto_test.dart`.)

Use the same import style as the premigration test (`sqlite3` as `sqlite3`, `package:path/path.dart` as `p`). Name the service and adapter variables to match whatever the copied `setUp` calls them.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/backup/data/services/backup_service_newer_schema_test.dart`
Expected: FAIL. The first test fails on the assertion (validation currently passes newer schemas); the third fails compiling (`BackupNewerSchemaException` undefined).

- [ ] **Step 3: Implement**

In `lib/features/backup/data/services/backup_service.dart`:

1. Below the `BackupException` class (near line 1457), add:

```dart
/// A backup written by a NEWER schema than this build supports. Restoring
/// it would swap in a database the running app cannot open.
class BackupNewerSchemaException extends BackupException {
  final int backupSchemaVersion;
  final int supportedSchemaVersion;

  BackupNewerSchemaException({
    required this.backupSchemaVersion,
    required this.supportedSchemaVersion,
  }) : super(
         'This backup was created by a newer version of Submersion '
         '(database v$backupSchemaVersion; this app supports up to '
         'v$supportedSchemaVersion). Update Submersion, then restore.',
       );
}
```

2. In `validateBackupFile`, after the existing deep checks succeed and immediately before the final `BackupValidationResult.valid(...)` return, add (the `deepCheckKeyHex` local is already in scope on the plaintext path; it is null for unencrypted files, which is correct):

```dart
    // Reject a backup written by a newer schema BEFORE restore can swap it
    // in; the post-swap open guard would otherwise fire with the file
    // already live (issue #1089).
    final storedSchema = DatabaseService.getStoredSchemaVersion(
      filePath,
      keyHex: deepCheckKeyHex,
    );
    if (storedSchema != null &&
        storedSchema > AppDatabase.currentSchemaVersion) {
      return BackupValidationResult.invalid(
        'This backup was created by a newer version of Submersion '
        '(database v$storedSchema; this app supports up to '
        'v${AppDatabase.currentSchemaVersion}). Update Submersion, then '
        'restore.',
      );
    }
```

Add imports for `DatabaseService` and `AppDatabase` if the file lacks them.

3. In `restoreFromFile`, as the FIRST statement inside the `try` block that follows `_materializePlaintextBackup` (before `performBackup()`), add:

```dart
      // The materialized copy is always plaintext, so no key is needed.
      // This runs before performBackup and before any swap, so a refusal
      // has zero side effects; it also covers encrypted artifacts, which
      // validateBackupFile cannot inspect.
      final restoredSchema = DatabaseService.getStoredSchemaVersion(
        materialized.path,
      );
      if (restoredSchema != null &&
          restoredSchema > AppDatabase.currentSchemaVersion) {
        throw BackupNewerSchemaException(
          backupSchemaVersion: restoredSchema,
          supportedSchemaVersion: AppDatabase.currentSchemaVersion,
        );
      }
```

- [ ] **Step 4: Run to verify pass, plus the neighboring backup suites**

Run: `flutter test test/features/backup/data/services/backup_service_newer_schema_test.dart test/features/backup/data/services/backup_service_premigration_restore_test.dart test/features/backup/data/services/backup_service_replace_test.dart`
Expected: PASS. (Backup suites share a temp dir and are flaky when run concurrently with other local runs; run nothing else in parallel.)

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -u lib test
git commit -m "fix(backup): refuse newer-schema backups before the swap (#1089)"
```

---

### Task 5: Post-swap auto-rollback and exception field rename

**Files:**

- Modify: `lib/core/services/database_service.dart` (the reopen inside `restore`, near line 660)
- Modify: `lib/core/database/database_version_exception.dart` (field rename)
- Modify: every consumer of the renamed fields (find with `grep -rn "DatabaseVersionMismatchException" lib test`; known: the throw site in `database_service.dart` near line 206, the catch in `lib/core/presentation/pages/startup_page.dart` near line 276, `test/core/services/database_service_schema_version_test.dart`)
- Test: Create `test/core/services/database_service_restore_rollback_test.dart`

**Interfaces:**

- Consumes: the swap-and-reopen structure of `DatabaseService.restore` (aside copy at `'$destinationPath.pre-restore'`, reopen at `initialize(onMigrationProgress: ...)`).
- Produces: `DatabaseVersionMismatchException` with fields renamed `databaseVersion` to `storedSchemaVersion` and `appVersion` to `supportedSchemaVersion` (both were always schema numbers). Rollback behavior: a version mismatch at the post-swap reopen restores the pre-restore database and rethrows.

- [ ] **Step 1: Write the failing rollback test**

Create `test/core/services/database_service_restore_rollback_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  test('restoring a newer-schema file rolls back to the pre-restore '
      'database', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'keep-me'),
    );

    // A plaintext SQLite file claiming a future schema, bypassing the
    // backup-layer pre-checks (models a raced or hand-placed file).
    final dir = await Directory.systemTemp.createTemp('rollback-test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'future.db');
    final raw = sqlite3.sqlite3.open(path);
    raw.execute('CREATE TABLE t (id TEXT)');
    raw.execute(
      'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
    );
    raw.dispose();

    await expectLater(
      DatabaseService.instance.restore(path),
      throwsA(isA<DatabaseVersionMismatchException>()),
    );

    // THE FIX: the pre-restore database must be back in place and open.
    final dive = await DiveRepository().getDiveById('keep-me');
    expect(
      dive,
      isNotNull,
      reason: 'the version mismatch surfaced AFTER the swap; without '
          'rollback the app is left with no working database',
    );
  });
}
```

(If `DatabaseService.restore` takes different parameters in the test environment, mirror how `test/features/backup/data/services/backup_service_replace_test.dart` invokes a real restore.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/database_service_restore_rollback_test.dart`
Expected: FAIL on the post-throw `getDiveById` (database closed or opening the wrong file), NOT on the `expectLater`.

- [ ] **Step 3: Implement the rollback**

In `lib/core/services/database_service.dart`, replace the bare reopen (near line 660):

```dart
    await initialize(onMigrationProgress: onMigrationProgress);
```

with:

```dart
    try {
      await initialize(onMigrationProgress: onMigrationProgress);
    } on DatabaseVersionMismatchException {
      // The restored file needs a newer app than this one. The backup-layer
      // pre-checks make this near-unreachable, but a raced or hand-placed
      // file can still hit it, and at this point the newer file is already
      // live. Put the pre-restore database back and reopen so the app keeps
      // a working library, then surface the error.
      await _deleteIfExists(destinationPath);
      await _deleteIfExists('$destinationPath-wal');
      await _deleteIfExists('$destinationPath-shm');
      if (hadDest && await File(asidePath).exists()) {
        await File(asidePath).rename(destinationPath);
      }
      await initialize();
      rethrow;
    }
```

The comment above the block ("Reopen on the swapped-in file BEFORE dropping...") stays; the `asidePath` cleanup after it already only runs on success.

- [ ] **Step 4: Rename the exception fields**

In `lib/core/database/database_version_exception.dart`, rename `databaseVersion` to `storedSchemaVersion` and `appVersion` to `supportedSchemaVersion` (fields, constructor parameters, and the `toString`/message interpolation; both values are Drift schema numbers, and the old names read as app release versions). Then run `flutter analyze` and fix every reference it reports; known consumers are the throw site in `database_service.dart` (near line 206), `startup_page.dart` (reads the fields to pass into `VersionMismatchView`, whose own parameter names do not change), and `test/core/services/database_service_schema_version_test.dart`.

- [ ] **Step 5: Run the affected suites**

Run: `flutter test test/core/services/database_service_restore_rollback_test.dart test/core/services/database_service_schema_version_test.dart test/features/backup/data/services/backup_service_replace_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -u lib test
git commit -m "fix(db): roll back a restore the version guard rejects post-swap (#1089)"
```

---

### Task 6: Held-peer banner naming, channel-aware wording, VersionMismatchView

**Files:**

- Create: `lib/features/settings/presentation/widgets/newer_schema_peer_banner.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (state field near line 508, static helper near line 951, reset near line 1216, set near line 1288)
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (replace the inline count banner near lines 1157-1195)
- Modify: `lib/core/presentation/widgets/version_mismatch_view.dart`
- Modify: all 11 arb files in `lib/l10n/arb/` plus regenerated `app_localizations*.dart`
- Test: Create `test/features/settings/presentation/widgets/newer_schema_peer_banner_test.dart`
- Test: Modify `test/features/settings/presentation/pages/cloud_sync_page_test.dart` (references to `newerSchemaPeerCount`)

**Interfaces:**

- Consumes: `SyncResult.newerSchemaPeerDeviceIds` and `.newerSchemaPeerNames` (Task 3); `UpdateChannel` and `UpdateChannelConfig` from `lib/features/auto_update/domain/entities/update_channel.dart`; existing l10n keys `settings_cloudSync_peerNeedsAdopt_unnamedDevice`, `_listSeparator`, `_listLastSeparator`.
- Produces: state field `newerSchemaPeerLabels` (`List<({String? name, String shortId})>`, replaces `newerSchemaPeerCount`); static `heldPeerLabels(Set<String> ids, Map<String, String> names)` on the sync notifier; widget `NewerSchemaPeerBanner({required peers, UpdateChannel? channelOverride})`; `VersionMismatchView` gains `UpdateChannel? channelOverride`.

- [ ] **Step 1: Add the l10n keys to `lib/l10n/arb/app_en.arb`**

Replace the key `settings_cloudSync_peerRequiresUpdate_banner` (and its `@`-metadata entry if one exists) with these four keys at the same location:

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} syncs from a newer version of Submersion, so its latest changes are held for now.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} sync from a newer version of Submersion, so their latest changes are held for now.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Update this device to receive them.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "They will apply automatically once this device's app store update arrives; the update may still be in review.",
```

And next to `startup_versionMismatch_instructions` add:

```json
  "startup_versionMismatch_storeInstructions": "This app was installed from an app store and is older than the version that created your data. Your data is safe and has not been modified. Update Submersion when the new version appears in the store, then reopen it.",
```

- [ ] **Step 2: Translate the five keys in the other ten arb files**

Remove `settings_cloudSync_peerRequiresUpdate_banner` from each file and add the five keys. Use these translations:

**de:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} synchronisiert von einer neueren Version von Submersion, daher werden die neuesten Änderungen vorerst zurückgehalten.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} synchronisieren von einer neueren Version von Submersion, daher werden ihre neuesten Änderungen vorerst zurückgehalten.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Aktualisieren Sie dieses Gerät, um sie zu erhalten.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Sie werden automatisch übernommen, sobald das App-Store-Update für dieses Gerät verfügbar ist; das Update befindet sich möglicherweise noch in der Prüfung.",
  "startup_versionMismatch_storeInstructions": "Diese App wurde aus einem App Store installiert und ist älter als die Version, die Ihre Daten erstellt hat. Ihre Daten sind sicher und wurden nicht verändert. Aktualisieren Sie Submersion, sobald die neue Version im Store erscheint, und öffnen Sie die App dann erneut."
```

**es:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} sincroniza desde una versión más reciente de Submersion, por lo que sus últimos cambios quedan retenidos por ahora.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} sincronizan desde una versión más reciente de Submersion, por lo que sus últimos cambios quedan retenidos por ahora.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Actualiza este dispositivo para recibirlos.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Se aplicarán automáticamente cuando llegue la actualización de la tienda de aplicaciones de este dispositivo; puede que aún esté en revisión.",
  "startup_versionMismatch_storeInstructions": "Esta app se instaló desde una tienda de aplicaciones y es más antigua que la versión que creó tus datos. Tus datos están a salvo y no se han modificado. Actualiza Submersion cuando la nueva versión aparezca en la tienda y vuelve a abrirla."
```

**fr:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} se synchronise depuis une version plus récente de Submersion, ses derniers changements sont donc retenus pour le moment.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} se synchronisent depuis une version plus récente de Submersion, leurs derniers changements sont donc retenus pour le moment.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Mettez à jour cet appareil pour les recevoir.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Ils seront appliqués automatiquement dès que la mise à jour arrivera sur la boutique d'applications de cet appareil ; elle est peut-être encore en cours d'examen.",
  "startup_versionMismatch_storeInstructions": "Cette application a été installée depuis une boutique d'applications et est plus ancienne que la version qui a créé vos données. Vos données sont en sécurité et n'ont pas été modifiées. Mettez à jour Submersion dès que la nouvelle version apparaît dans la boutique, puis rouvrez l'application."
```

**it:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} si sincronizza da una versione più recente di Submersion, quindi le sue ultime modifiche sono per ora trattenute.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} si sincronizzano da una versione più recente di Submersion, quindi le loro ultime modifiche sono per ora trattenute.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Aggiorna questo dispositivo per riceverle.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Verranno applicate automaticamente quando arriverà l'aggiornamento dell'app store per questo dispositivo; l'aggiornamento potrebbe essere ancora in revisione.",
  "startup_versionMismatch_storeInstructions": "Questa app è stata installata da un app store ed è più vecchia della versione che ha creato i tuoi dati. I tuoi dati sono al sicuro e non sono stati modificati. Aggiorna Submersion quando la nuova versione appare nello store, poi riaprila."
```

**nl:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} synchroniseert vanaf een nieuwere versie van Submersion, dus de nieuwste wijzigingen worden voorlopig vastgehouden.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} synchroniseren vanaf een nieuwere versie van Submersion, dus hun nieuwste wijzigingen worden voorlopig vastgehouden.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Werk dit apparaat bij om ze te ontvangen.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Ze worden automatisch toegepast zodra de appstore-update voor dit apparaat beschikbaar is; de update is mogelijk nog in beoordeling.",
  "startup_versionMismatch_storeInstructions": "Deze app is geïnstalleerd vanuit een appstore en is ouder dan de versie die uw gegevens heeft gemaakt. Uw gegevens zijn veilig en niet gewijzigd. Werk Submersion bij zodra de nieuwe versie in de store verschijnt en open de app daarna opnieuw."
```

**pt:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} sincroniza a partir de uma versão mais recente do Submersion, por isso as suas alterações mais recentes ficam retidas por agora.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} sincronizam a partir de uma versão mais recente do Submersion, por isso as suas alterações mais recentes ficam retidas por agora.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Atualize este dispositivo para as receber.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Serão aplicadas automaticamente quando a atualização da loja de aplicações deste dispositivo chegar; a atualização pode ainda estar em revisão.",
  "startup_versionMismatch_storeInstructions": "Esta app foi instalada a partir de uma loja de aplicações e é mais antiga do que a versão que criou os seus dados. Os seus dados estão seguros e não foram modificados. Atualize o Submersion quando a nova versão aparecer na loja e volte a abri-lo."
```

**he:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} מסתנכרן מגרסה חדשה יותר של Submersion, ולכן השינויים האחרונים שלו מוחזקים בינתיים.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} מסתנכרנים מגרסה חדשה יותר של Submersion, ולכן השינויים האחרונים שלהם מוחזקים בינתיים.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "עדכן מכשיר זה כדי לקבל אותם.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "הם יוחלו אוטומטית ברגע שעדכון חנות האפליקציות של מכשיר זה יגיע; ייתכן שהעדכון עדיין בבדיקה.",
  "startup_versionMismatch_storeInstructions": "אפליקציה זו הותקנה מחנות אפליקציות והיא ישנה יותר מהגרסה שיצרה את הנתונים שלך. הנתונים שלך בטוחים ולא שונו. עדכן את Submersion כשהגרסה החדשה תופיע בחנות, ואז פתח את האפליקציה מחדש."
```

**hu:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} a Submersion újabb verziójából szinkronizál, ezért a legújabb változtatásai egyelőre visszatartva maradnak.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} a Submersion újabb verziójából szinkronizálnak, ezért a legújabb változtatásaik egyelőre visszatartva maradnak.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "Frissítsd ezt az eszközt, hogy megkapd őket.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "Automatikusan érvénybe lépnek, amint megérkezik az eszköz alkalmazásbolti frissítése; a frissítés még ellenőrzés alatt állhat.",
  "startup_versionMismatch_storeInstructions": "Ezt az alkalmazást alkalmazásboltból telepítetted, és régebbi, mint az adataidat létrehozó verzió. Az adataid biztonságban vannak, nem módosultak. Frissítsd a Submersiont, amint az új verzió megjelenik a boltban, majd nyisd meg újra."
```

**zh:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} 正在从更新版本的 Submersion 同步，因此其最新更改暂时被保留。",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} 正在从更新版本的 Submersion 同步，因此它们的最新更改暂时被保留。",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "更新此设备即可接收这些更改。",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "此设备的应用商店更新到达后，这些更改将自动应用；该更新可能仍在审核中。",
  "startup_versionMismatch_storeInstructions": "此应用安装自应用商店，版本低于创建您数据的版本。您的数据是安全的，未被修改。当新版本在商店上架后，请更新 Submersion 并重新打开。"
```

**ar:**

```json
  "settings_cloudSync_peerRequiresUpdate_bannerNamed": "{deviceList} يزامن من إصدار أحدث من Submersion، لذا يتم تعليق أحدث تغييراته مؤقتًا.",
  "settings_cloudSync_peerRequiresUpdate_bannerNamedPlural": "{deviceList} تزامن من إصدار أحدث من Submersion، لذا يتم تعليق أحدث تغييراتها مؤقتًا.",
  "settings_cloudSync_peerRequiresUpdate_updateAction": "حدّث هذا الجهاز لاستلامها.",
  "settings_cloudSync_peerRequiresUpdate_storeAction": "سيتم تطبيقها تلقائيًا فور وصول تحديث متجر التطبيقات لهذا الجهاز؛ وقد يكون التحديث لا يزال قيد المراجعة.",
  "startup_versionMismatch_storeInstructions": "تم تثبيت هذا التطبيق من متجر تطبيقات وهو أقدم من الإصدار الذي أنشأ بياناتك. بياناتك آمنة ولم يتم تعديلها. حدّث Submersion عندما يظهر الإصدار الجديد في المتجر، ثم أعد فتحه."
```

Then run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations*.dart` regenerate with the new methods and without `settings_cloudSync_peerRequiresUpdate_banner`.

- [ ] **Step 3: Write the failing banner widget test**

Create `test/features/settings/presentation/widgets/newer_schema_peer_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/settings/presentation/widgets/newer_schema_peer_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders nothing when no peer is held', (tester) async {
    await tester.pumpWidget(
      host(const NewerSchemaPeerBanner(peers: [])),
    );
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('names the held peer and, on the github channel, asks for an '
      'update', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: 'Living Room Mac', shortId: 'abc12345')],
          channelOverride: UpdateChannel.github,
        ),
      ),
    );
    expect(
      find.textContaining('Living Room Mac'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Update this device'),
      findsOneWidget,
    );
  });

  testWidgets('on a store channel it acknowledges the pending store update '
      'instead of demanding an impossible action', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: null, shortId: 'abc12345')],
          channelOverride: UpdateChannel.appstore,
        ),
      ),
    );
    expect(find.textContaining('abc12345'), findsOneWidget);
    expect(find.textContaining('Update this device'), findsNothing);
    expect(find.textContaining('app store update'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/settings/presentation/widgets/newer_schema_peer_banner_test.dart`
Expected: FAIL compiling (widget does not exist).

- [ ] **Step 4: Implement the banner widget**

Create `lib/features/settings/presentation/widgets/newer_schema_peer_banner.dart`, mirroring `skipped_peer_banner.dart`'s structure and its Card styling comment:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Names the devices held back because they publish from a newer database
/// schema (a newer app) than this build understands.
///
/// Mirrors SkippedPeerBanner: zero-noise resting state, appears only when a
/// peer is actually held. On store-channel builds the call to action
/// acknowledges the store update may still be in review rather than telling
/// the user to do something their channel does not offer yet (issue #1089).
class NewerSchemaPeerBanner extends StatelessWidget {
  const NewerSchemaPeerBanner({
    super.key,
    required this.peers,
    this.channelOverride,
  });

  /// A null name means the peer published none; the UI falls back to a
  /// short id label.
  final List<({String? name, String shortId})> peers;

  /// Test seam: UpdateChannelConfig.current is a compile-time constant and
  /// cannot be varied inside a test binary.
  final UpdateChannel? channelOverride;

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final channel = channelOverride ?? UpdateChannelConfig.current;

    final labels = peers
        .map(
          (p) =>
              p.name ??
              l10n.settings_cloudSync_peerNeedsAdopt_unnamedDevice(p.shortId),
        )
        .toList();
    final list = labels.length == 1
        ? labels.single
        : labels
                  .sublist(0, labels.length - 1)
                  .join(l10n.settings_cloudSync_peerNeedsAdopt_listSeparator) +
              l10n.settings_cloudSync_peerNeedsAdopt_listLastSeparator +
              labels.last;
    final headline = labels.length == 1
        ? l10n.settings_cloudSync_peerRequiresUpdate_bannerNamed(list)
        : l10n.settings_cloudSync_peerRequiresUpdate_bannerNamedPlural(list);
    final action = UpdateChannelConfig.isStoreChannel(channel)
        ? l10n.settings_cloudSync_peerRequiresUpdate_storeAction
        : l10n.settings_cloudSync_peerRequiresUpdate_updateAction;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.system_update_alt,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$headline $action',
                  // Card is secondaryContainer, and Material does not
                  // re-derive text colour from its background, so bodyMedium
                  // would keep onSurface. Pair it with the container
                  // explicitly, as the icon already is.
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Run the widget test again. Expected: PASS.

- [ ] **Step 5: Swap the state field and wire the page**

In `lib/features/settings/presentation/providers/sync_providers.dart`:

1. Replace the `final int newerSchemaPeerCount;` field (near line 508), its constructor default (`this.newerSchemaPeerCount = 0,` near line 557), and its `copyWith` parameter and assignment (near lines 576 and 596) with:

```dart
  final List<({String? name, String shortId})> newerSchemaPeerLabels;
```

constructor: `this.newerSchemaPeerLabels = const [],`
copyWith parameter: `List<({String? name, String shortId})>? newerSchemaPeerLabels,`
copyWith assignment: `newerSchemaPeerLabels: newerSchemaPeerLabels ?? this.newerSchemaPeerLabels,`

2. Generalize the label builder (near line 951). Above the existing `skippedPeerLabels`, add the shared helper, and rewrite `skippedPeerLabels` to delegate:

```dart
  /// (name, shortId) per held peer, shared by the epoch-fence and
  /// newer-schema banners. Sorted so banner text is stable across syncs.
  @visibleForTesting
  static List<({String? name, String shortId})> heldPeerLabels(
    Set<String> ids,
    Map<String, String> names,
  ) {
    final entries =
        ids.map((id) {
          final name = names[id];
          final shortId = id.length > 8 ? id.substring(0, 8) : id;
          return (
            name: (name != null && name.isNotEmpty) ? name : null,
            shortId: shortId,
          );
        }).toList()..sort(
          (a, b) => (a.name ?? a.shortId).compareTo(b.name ?? b.shortId),
        );
    return entries;
  }

  @visibleForTesting
  static List<({String? name, String shortId})> skippedPeerLabels(
    SyncResult result,
  ) => heldPeerLabels(result.skippedPeerDeviceIds, result.skippedPeerNames);
```

(Keep the original doc comment on `skippedPeerLabels`.)

3. At the reset site (near line 1216) change `newerSchemaPeerCount: 0,` to `newerSchemaPeerLabels: const [],`.

4. At the set site (near line 1288) change `newerSchemaPeerCount: result.newerSchemaPeerDeviceIds.length,` to:

```dart
            newerSchemaPeerLabels: heldPeerLabels(
              result.newerSchemaPeerDeviceIds,
              result.newerSchemaPeerNames,
            ),
```

5. In `lib/features/settings/presentation/pages/cloud_sync_page.dart`, delete the whole inline banner block, from `if (syncState.newerSchemaPeerCount > 0)` through its closing parenthesis (the `Padding` containing the `Card` with `Icons.system_update_alt`, near lines 1157-1195), and replace it with:

```dart
          NewerSchemaPeerBanner(peers: syncState.newerSchemaPeerLabels),
```

Add the import for `newer_schema_peer_banner.dart` next to the `skipped_peer_banner.dart` import.

6. Run `flutter analyze` and fix every remaining reference to `newerSchemaPeerCount` (known: `test/features/settings/presentation/pages/cloud_sync_page_test.dart`; update its assertions to build `newerSchemaPeerLabels` lists instead of counts).

- [ ] **Step 6: Make VersionMismatchView channel-aware**

In `lib/core/presentation/widgets/version_mismatch_view.dart`:

1. Add a field and constructor parameter:

```dart
  /// Test seam: UpdateChannelConfig.current is a compile-time constant and
  /// cannot be varied inside a test binary.
  final UpdateChannel? channelOverride;
```

(`this.channelOverride,` in the constructor; import `update_channel.dart`.)

2. In `build`, before the returned widget tree:

```dart
    final channel = channelOverride ?? UpdateChannelConfig.current;
    final isStore = UpdateChannelConfig.isStoreChannel(channel);
```

3. Swap the instructions text:

```dart
          Text(
            isStore
                ? context.l10n.startup_versionMismatch_storeInstructions
                : context.l10n.startup_versionMismatch_instructions,
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
```

4. Wrap the download affordances (the `FilledButton`, the `manualLink` `Text`, the `SelectableText(latestReleaseUrl)`, and their two `SizedBox` spacers) in `if (!isStore) ...[ ... ],` so store builds show neither a GitHub button nor a GitHub URL.

5. Add a widget test to a new file `test/core/presentation/widgets/version_mismatch_view_test.dart` (reuse the `host` helper shape from Step 3's test file):

```dart
  testWidgets('store channel hides the GitHub download affordances', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        VersionMismatchView(
          databaseVersion: 154,
          appVersion: 153,
          textColor: Colors.black,
          subtitleColor: Colors.black54,
          onDownloadLatest: () {},
          onClose: () {},
          channelOverride: UpdateChannel.appstore,
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(
      find.textContaining('github.com'),
      findsNothing,
    );
  });

  testWidgets('github channel keeps the download button', (tester) async {
    await tester.pumpWidget(
      host(
        VersionMismatchView(
          databaseVersion: 154,
          appVersion: 153,
          textColor: Colors.black,
          subtitleColor: Colors.black54,
          onDownloadLatest: () {},
          onClose: () {},
          channelOverride: UpdateChannel.github,
        ),
      ),
    );
    expect(find.byType(FilledButton), findsOneWidget);
  });
```

- [ ] **Step 7: Run the affected suites**

Run: `flutter test test/features/settings/presentation/widgets/newer_schema_peer_banner_test.dart test/core/presentation/widgets/version_mismatch_view_test.dart test/features/settings/presentation/pages/cloud_sync_page_test.dart`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A lib test
git commit -m "feat(sync): name held peers and make update messaging channel-aware (#1089)"
```

---

### Task 7: Whole-project verification

**Files:** none new.

- [ ] **Step 1: Format check**

Run: `dart format .`
Expected: `0 changed` (or commit any stragglers as part of Step 4).

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: `No issues found!` (do not pipe through anything).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all pass. Ensure no other local `flutter test` run is active. Known pre-existing flakes unrelated to this diff: two recovery-code `split('-')` tests and a security-settings recovery dialog test; if exactly those fail, re-run the failing files in isolation before investigating this branch's diff.

- [ ] **Step 4: Commit any verification fallout, then finish**

```bash
git add -u
git commit -m "chore: verification fixes for cross-version sync compatibility (#1089)"
```

(Skip the commit if the tree is clean.) Then use the superpowers:finishing-a-development-branch skill to integrate the branch.
