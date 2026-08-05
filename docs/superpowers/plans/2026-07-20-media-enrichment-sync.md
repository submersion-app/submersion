# Media Enrichment Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a linked photo/video's depth/time association (the `MediaEnrichment` row) replicate through sync so it is no longer lost on a second device or after a restore.

**Architecture:** `MediaEnrichment` is depth/temperature/elapsed data projected onto the dive profile at the media's capture time. Today it is computed once at import and stored only in the local DB — it is not a synced entity (absent from `SyncService.entityHasUpdatedAt`, no serializer case, no `hlc` column), even though `MediaRepository.saveEnrichment` already calls `markRecordPending('mediaEnrichment', …)`. We complete that half-finished wiring: add an `hlc` column (schema v130), register `mediaEnrichment` as a first-class HLC-synced child entity across the sync engine (mirroring `mediaStores`), and run a one-time runtime backfill so pre-v130 rows (which carry `hlc = NULL` and are invisible to the incremental export) get a fresh HLC and heal already-affected peers.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod. HLC (Hybrid Logical Clock) based incremental sync.

## Global Constraints

- **Schema version:** bump `AppDatabase.currentSchemaVersion` from `129` to `130`. Parallel open PRs may also claim v130; on a merge conflict in `database.dart`, keep BOTH idempotent migration blocks inside the single `if (from < 130)` step (precedent: the v103 media-store / dive-roles collision). `currentSchemaVersion` stays `130`.
- **Codegen:** after any change to a Drift `Table` class, run `dart run build_runner build --delete-conflicting-outputs` before compiling/testing.
- **Formatting:** run `dart format .` (whole project) before committing; CI treats `prefer_const`-class infos as fatal, so run `flutter analyze` on the WHOLE project and keep it clean.
- **No new l10n:** this change is engine/schema-only; no user-facing strings.
- **Commits/PR:** no `Co-Authored-By` line, no Claude Code attribution, no session URL in commit messages or the PR body.
- **Entity naming:** the sync entity key is the camelCase string `'mediaEnrichment'`; the SQL table is `media_enrichment`; the Drift getter is `_db.mediaEnrichment`; the generated row class is `MediaEnrichmentData`; the companion is `MediaEnrichmentCompanion`.

---

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `lib/core/database/database.dart` | Schema, migrations, beforeOpen backstops | Add `hlc` column to `MediaEnrichment`; bump version; add v130 migration + backstop helper |
| `lib/core/database/database.g.dart` | Generated Drift code | Regenerated (never hand-edited) |
| `lib/core/services/sync/sync_data_serializer.dart` | `SyncData` model + per-entity (de)serialization, export, upsert, delete | Add `mediaEnrichment` field + all serializer cases + `_exportMediaEnrichment` |
| `lib/core/services/sync/sync_service.dart` | Sync orchestration, entity registry, merge order, FK guards | Register `mediaEnrichment` in `entityHasUpdatedAt`, `mergeOrder`, `parentRefs`; call backfill |
| `lib/core/data/repositories/sync_repository.dart` | HLC stamping, mark-pending, backfill | Add `_hlcTargets` entry; add `backfillMediaEnrichmentHlc()` |
| `test/core/database/migration_v130_media_enrichment_hlc_test.dart` | Migration coverage + version tripwire | Create |
| `test/core/database/migration_v129_quality_findings_test.dart` | Old tripwire | Relax exact `==129` to `>=129` |
| `test/core/services/sync/sync_media_enrichment_test.dart` | End-to-end sync replication for enrichment | Create |
| `test/core/services/sync/sync_parent_refs_completeness_test.dart` | FK-guard completeness | Add `media_enrichment` to `syncedTables`, `media` to `deletableParents` |

---

## Task 1: Schema v130 — add `hlc` column to `media_enrichment`

**Files:**
- Modify: `lib/core/database/database.dart` (table def; `currentSchemaVersion`; `migrationVersions`; new `_assertMediaEnrichmentHlcColumn()` helper; onUpgrade block; beforeOpen call)
- Regenerate: `lib/core/database/database.g.dart`
- Create: `test/core/database/migration_v130_media_enrichment_hlc_test.dart`
- Modify: `test/core/database/migration_v129_quality_findings_test.dart`

**Interfaces:**
- Produces: `media_enrichment.hlc` column (nullable TEXT); `AppDatabase.currentSchemaVersion == 130`; `_assertMediaEnrichmentHlcColumn()` idempotent helper. Task 2/3 rely on the `hlc` column existing.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v130_media_enrichment_hlc_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  test('media_enrichment has an hlc column', () async {
    final rows = await db
        .customSelect("PRAGMA table_info('media_enrichment')")
        .get();
    final cols = [for (final r in rows) r.read<String>('name')];
    expect(
      cols,
      containsAll([
        'id',
        'media_id',
        'dive_id',
        'depth_meters',
        'temperature_celsius',
        'elapsed_seconds',
        'match_confidence',
        'timestamp_offset_seconds',
        'created_at',
        'hlc',
      ]),
    );
  });

  test('v130 is the current schema version (exact-latest tripwire)', () {
    expect(AppDatabase.currentSchemaVersion, 130);
    expect(AppDatabase.migrationVersions, contains(130));
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/database/migration_v130_media_enrichment_hlc_test.dart`
Expected: FAIL — `hlc` not in columns and `currentSchemaVersion` is 129.

- [ ] **Step 3: Add the `hlc` column to the table**

In `lib/core/database/database.dart`, in `class MediaEnrichment extends Table`, after the `createdAt` getter and before `@override Set<Column> get primaryKey`, add:

```dart
  IntColumn get createdAt => integer()();
  // v130: sync replication. media_enrichment is the depth/time association
  // for a linked photo; without an hlc it never travelled through sync and
  // was lost on other devices / after restore.
  TextColumn get hlc => text().nullable()();
```

- [ ] **Step 4: Bump the schema version and register the migration version**

Change `static const int currentSchemaVersion = 129;` to `= 130;`.

In the `static const List<int> migrationVersions = [ … ]` list, append `130,` after the existing final `129,` entry.

- [ ] **Step 5: Add the idempotent backstop helper**

In `lib/core/database/database.dart`, next to the other `_assert…` helpers (e.g. beside `_assertMediaStoreSchema`), add:

```dart
  /// v130: media_enrichment.hlc column. Self-guarding when the table is
  /// absent (partial-schema migration tests) and PRAGMA-guarded so it is safe
  /// to call from both onUpgrade and the beforeOpen backstop (parallel-branch
  /// collision self-heal).
  Future<void> _assertMediaEnrichmentHlcColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('media_enrichment')",
    ).get();
    final hasColumn = cols.any((c) => c.read<String>('name') == 'hlc');
    if (cols.isNotEmpty && !hasColumn) {
      await customStatement(
        'ALTER TABLE media_enrichment ADD COLUMN hlc TEXT',
      );
    }
  }
```

- [ ] **Step 6: Wire the onUpgrade step**

In the `onUpgrade` chain, after the `if (from < 129) await reportProgress();` line, add:

```dart
      // v130: media_enrichment.hlc so the depth/time association syncs.
      if (from < 130) {
        await _assertMediaEnrichmentHlcColumn();
      }
      if (from < 130) await reportProgress();
```

- [ ] **Step 7: Wire the beforeOpen backstop**

In the `beforeOpen` block, next to the `await _assertMediaStoreSchema();` call, add:

```dart
        await _assertMediaEnrichmentHlcColumn();
```

- [ ] **Step 8: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `MediaEnrichmentData` gains an `hlc` field; its `fromJson`/`toJson`/`toCompanion` include `hlc`.

- [ ] **Step 9: Relax the old tripwire**

In `test/core/database/migration_v129_quality_findings_test.dart`, change:

```dart
    expect(AppDatabase.currentSchemaVersion, 129);
    expect(AppDatabase.migrationVersions, contains(129));
```

to:

```dart
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(129));
    expect(AppDatabase.migrationVersions, contains(129));
```

- [ ] **Step 10: Run both migration tests**

Run: `flutter test test/core/database/migration_v130_media_enrichment_hlc_test.dart test/core/database/migration_v129_quality_findings_test.dart`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart \
  test/core/database/migration_v130_media_enrichment_hlc_test.dart \
  test/core/database/migration_v129_quality_findings_test.dart
git commit -m "feat(sync): add hlc column to media_enrichment (schema v130)"
```

---

## Task 2: Register `mediaEnrichment` as a synced entity

Drive this task with the end-to-end sync test; it exercises export, upsert, batch, `deleteAllRecords`, `recordIdsFor`, `SyncData.fromJson`, and `performSync`, plus the two parity/completeness tests fail until every site is wired. Land all sites together (the parity tests require the `SyncData` field and the `entityHasUpdatedAt` key to move as a pair).

**Files:**
- Create: `test/core/services/sync/sync_media_enrichment_test.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart`
- Modify: `lib/core/services/sync/sync_service.dart`
- Modify: `lib/core/data/repositories/sync_repository.dart`
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart`

**Interfaces:**
- Consumes: `media_enrichment.hlc` column (Task 1).
- Produces: `SyncData.mediaEnrichment` (`List<Map<String, dynamic>>`); serializer handling for the `'mediaEnrichment'` entity key; `_hlcTargets['mediaEnrichment']` (Task 3 relies on this so `markRecordPending` stamps the HLC).

- [ ] **Step 1: Write the failing sync test**

Create `test/core/services/sync/sync_media_enrichment_test.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Sync replication for `media_enrichment` (the depth/time association for a
/// linked photo). Like `media_stores`/`buddy_roles`, this table carries its
/// own `hlc` column, so its export uses the simple hlc-filter pattern. Unlike
/// them it is a child of both `media` and `dives`, so each fixture seeds those
/// parent rows first.
void main() {
  group('media_enrichment sync', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    Map<String, dynamic> diveRow(String id) => {
      'id': id,
      'diveNumber': 1,
      'diveDateTime': 1000,
      'createdAt': 1000,
      'updatedAt': 1000,
    };

    Map<String, dynamic> mediaRow(String id, String diveId) => {
      'id': id,
      'diveId': diveId,
      'filePath': '/photos/$id.jpg',
      'fileType': 'photo',
      'sourceType': 'platformGallery',
      'isFavorite': false,
      'isOrphaned': false,
      'createdAt': 1000,
      'updatedAt': 1000,
    };

    Map<String, dynamic> enrichmentRow(
      String id, {
      required String mediaId,
      required String diveId,
      required String hlc,
    }) => {
      'id': id,
      'mediaId': mediaId,
      'diveId': diveId,
      'depthMeters': 18.3,
      'temperatureCelsius': 21.0,
      'elapsedSeconds': 600,
      'matchConfidence': 'exact',
      'timestampOffsetSeconds': 0,
      'createdAt': 1000,
      'hlc': hlc,
    };

    Future<void> seedParents(
      SyncDataSerializer s, {
      required String diveId,
      required String mediaId,
    }) async {
      await s.upsertRecord('dives', diveRow(diveId));
      await s.upsertRecord('media', mediaRow(mediaId, diveId));
    }

    test('full export includes a media_enrichment row', () async {
      final s = SyncDataSerializer();
      await seedParents(s, diveId: 'd1', mediaId: 'm1');
      await s.upsertRecord(
        'mediaEnrichment',
        enrichmentRow('e1', mediaId: 'm1', diveId: 'd1',
            hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await s.exportData(deviceId: 'dev-a', deletions: const []);

      expect(
        payload.data.mediaEnrichment.map((r) => r['id']).toSet(),
        contains('e1'),
      );
    });

    test('round trip: wipe and re-import restores depth and confidence',
        () async {
      final s = SyncDataSerializer();
      await seedParents(s, diveId: 'd1', mediaId: 'm1');
      await s.upsertRecord(
        'mediaEnrichment',
        enrichmentRow('e1', mediaId: 'm1', diveId: 'd1',
            hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await s.exportData(deviceId: 'dev-a', deletions: const []);
      final exported =
          payload.data.mediaEnrichment.singleWhere((r) => r['id'] == 'e1');

      final db = DatabaseService.instance.database;
      await s.deleteAllRecords('mediaEnrichment');
      expect(
        await (db.select(db.mediaEnrichment)
              ..where((t) => t.id.equals('e1')))
            .getSingleOrNull(),
        isNull,
        reason: 'sanity: the wipe actually removed the row',
      );

      await s.upsertRecord('mediaEnrichment', exported);

      final restored = await (db.select(db.mediaEnrichment)
            ..where((t) => t.id.equals('e1')))
          .getSingle();
      expect(restored.depthMeters, 18.3);
      expect(restored.matchConfidence, 'exact');
      expect(restored.diveId, 'd1');
    });

    test('incremental export: only rows with hlc > watermark are included',
        () async {
      final s = SyncDataSerializer();
      await seedParents(s, diveId: 'd1', mediaId: 'm1');
      await s.upsertRecord('media', mediaRow('m2', 'd1'));
      await s.upsertRecord(
        'mediaEnrichment',
        enrichmentRow('e-old', mediaId: 'm1', diveId: 'd1',
            hlc: hlcAt(1000, 'dev-a')),
      );
      await s.upsertRecord(
        'mediaEnrichment',
        enrichmentRow('e-new', mediaId: 'm2', diveId: 'd1',
            hlc: hlcAt(9000, 'dev-a')),
      );

      final changeset = await s.exportChangeset(
        deviceId: 'dev-a',
        hlcWatermark: hlcAt(5000, 'dev-a'),
        deletions: const [],
      );

      final ids = changeset.data.mediaEnrichment.map((r) => r['id']).toSet();
      expect(ids, contains('e-new'));
      expect(ids, isNot(contains('e-old')));
    });

    test('per-record plumbing: recordIdsFor, deleteRecord, SyncData.fromJson',
        () async {
      final s = SyncDataSerializer();
      await seedParents(s, diveId: 'd1', mediaId: 'm1');
      await s.upsertRecord(
        'mediaEnrichment',
        enrichmentRow('e1', mediaId: 'm1', diveId: 'd1',
            hlc: hlcAt(1000, 'dev-a')),
      );

      expect(await s.recordIdsFor('mediaEnrichment'), {'e1'});

      final payload = await s.exportData(deviceId: 'dev-a', deletions: const []);
      final rehydrated = SyncData.fromJson(payload.data.toJson());
      expect(
        rehydrated.mediaEnrichment.map((r) => r['id']),
        contains('e1'),
      );

      await s.deleteRecord('mediaEnrichment', 'e1');
      expect(await s.recordIdsFor('mediaEnrichment'), isEmpty);
    });

    test('end to end: a peer-published enrichment replicates via performSync',
        () async {
      final cloud = FakeCloudStorageProvider();
      final data = SyncData(
        dives: [diveRow('d1')],
        media: [mediaRow('m1', 'd1')],
        mediaEnrichment: [
          enrichmentRow('e1', mediaId: 'm1', diveId: 'd1',
              hlc: hlcAt(1000, 'peer-dev')),
        ],
      );
      final payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-dev',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: const {},
      );
      await seedPeerBaseFromPayload(cloud, 'peer-dev', payload);

      final result = await SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      ).performSync();
      expect(result.status, isNot(SyncResultStatus.error));

      final db = DatabaseService.instance.database;
      final restored = await (db.select(db.mediaEnrichment)
            ..where((t) => t.id.equals('e1')))
          .getSingleOrNull();
      expect(restored, isNotNull);
      expect(restored!.depthMeters, 18.3);
    });
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/services/sync/sync_media_enrichment_test.dart`
Expected: FAIL to COMPILE — `SyncData` has no `mediaEnrichment` member.

> NOTE on the fixtures: the `diveRow`/`mediaRow` maps use the JSON keys Drift's `fromJson` expects (camelCase getter names). If a required non-null column is missing for your generated schema, the `upsertRecord` insert will throw — add the missing key using the column's Drift getter name. Keep the enrichment JSON keys exactly as the generated `MediaEnrichmentData.toJson()` emits them (verify by printing `payload.data.mediaEnrichment.first` once).

- [ ] **Step 3: Add the `SyncData` field, ctor param, toJson, fromJson**

In `lib/core/services/sync/sync_data_serializer.dart`, in `class SyncData`:
- After the field `final List<Map<String, dynamic>> mediaStores;` add:
  ```dart
  final List<Map<String, dynamic>> mediaEnrichment;
  ```
- In the constructor, after `this.mediaStores = const [],` add:
  ```dart
  this.mediaEnrichment = const [],
  ```
- In `toJson()`, after `'mediaStores': mediaStores,` add:
  ```dart
  'mediaEnrichment': mediaEnrichment,
  ```
- In `fromJson()`, after `mediaStores: _parseList(json['mediaStores']),` add:
  ```dart
  mediaEnrichment: _parseList(json['mediaEnrichment']),
  ```

- [ ] **Step 4: Add the base-snapshot table entry and the export call**

In `_baseTables`, after `(key: 'media', table: _db.media, blob: true, full: null),` add:

```dart
    (
      key: 'mediaEnrichment',
      table: _db.mediaEnrichment,
      blob: false,
      full: null,
    ),
```

In `_buildSyncData(String? hlcSince)`, after the `media: await _safeExport('media', () => _exportMedia(hlcSince)),` line add:

```dart
      mediaEnrichment: await _safeExport(
        'mediaEnrichment',
        () => _exportMediaEnrichment(hlcSince),
      ),
```

- [ ] **Step 5: Add the `_exportMediaEnrichment` method**

Next to `_exportMediaStores`, add:

```dart
  Future<List<Map<String, dynamic>>> _exportMediaEnrichment(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.mediaEnrichment);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

- [ ] **Step 6: Add the per-entity switch cases**

Mirror the adjacent `case 'mediaStores':` in each switch, swapping table/class. Add to each:

`fetchRecord`:
```dart
      case 'mediaEnrichment':
        final row = await (_db.select(_db.mediaEnrichment)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        return row?.toJson();
```

`fetchRecords` (use whatever the local id-list param is named — it is the same one the `'mediaStores'` case uses):
```dart
      case 'mediaEnrichment':
        final rows = await (_db.select(_db.mediaEnrichment)
              ..where((t) => t.id.isIn(idList)))
            .get();
        return {for (final r in rows) r.id: r.toJson()};
```

`upsertRecord`:
```dart
      case 'mediaEnrichment':
        await _db
            .into(_db.mediaEnrichment)
            .insertOnConflictUpdate(
              MediaEnrichmentData.fromJson(data).toCompanion(false),
            );
        return;
```

`upsertRecords`:
```dart
      case 'mediaEnrichment':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.mediaEnrichment,
            records
                .map((r) => MediaEnrichmentData.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```

`recordIdsFor`:
```dart
      case 'mediaEnrichment':
        return plain(_db.mediaEnrichment, _db.mediaEnrichment.id);
```

`_syncTableFor`:
```dart
      case 'mediaEnrichment':
        return _db.mediaEnrichment;
```

`deleteRecord`:
```dart
      case 'mediaEnrichment':
        await (_db.delete(_db.mediaEnrichment)
              ..where((t) => t.id.equals(recordId)))
            .go();
        return;
```

- [ ] **Step 7: Register in `sync_service.dart`**

In `entityHasUpdatedAt`, after `'media': false,` add:
```dart
    'mediaEnrichment': false,
```

In `mergeOrder`, after `(type: 'media', records: data.media, hasUpdatedAt: false),` add:
```dart
          (
            type: 'mediaEnrichment',
            records: data.mediaEnrichment,
            hasUpdatedAt: false,
          ),
```

In `parentRefs`, add a new entry (place it near the other dive-child entries):
```dart
    'mediaEnrichment': [
      (field: 'mediaId', parent: 'media', nullable: false),
      (field: 'diveId', parent: 'dives', nullable: false),
    ],
```

- [ ] **Step 8: Register the HLC target in `sync_repository.dart`**

In `_hlcTargets`, after `'media': (table: 'media', pk: 'id'),` add:
```dart
    'mediaEnrichment': (table: 'media_enrichment', pk: 'id'),
```

- [ ] **Step 9: Update the parent-refs completeness test**

In `test/core/services/sync/sync_parent_refs_completeness_test.dart`:
- In the `syncedTables` map, after `'media': 'media',` add:
  ```dart
    'media_enrichment': 'mediaEnrichment',
  ```
- In the `deletableParents` map, add (so the test verifies the `mediaId` guard too):
  ```dart
    'media': 'media',
  ```

- [ ] **Step 10: Run the new test + the parity/completeness guards**

Run:
```bash
flutter test \
  test/core/services/sync/sync_media_enrichment_test.dart \
  test/core/services/sync/sync_parent_refs_completeness_test.dart \
  test/core/services/sync/sync_data_serializer_record_ids_test.dart
```
Expected: PASS. (The record-ids guard and the `entityHasUpdatedAt covers exactly the SyncData entities` parity test now include `mediaEnrichment` automatically.)

- [ ] **Step 11: Commit**

```bash
git add lib/core/services/sync/sync_data_serializer.dart \
  lib/core/services/sync/sync_service.dart \
  lib/core/data/repositories/sync_repository.dart \
  test/core/services/sync/sync_media_enrichment_test.dart \
  test/core/services/sync/sync_parent_refs_completeness_test.dart
git commit -m "feat(sync): replicate media_enrichment as a first-class HLC entity"
```

---

## Task 3: One-time self-heal backfill for pre-v130 rows

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (add `backfillMediaEnrichmentHlc()`)
- Modify: `lib/core/services/sync/sync_service.dart` (call it in `performSync`)
- Create: `test/core/services/sync/sync_enrichment_backfill_test.dart`

**Interfaces:**
- Consumes: `_hlcTargets['mediaEnrichment']` (Task 2) so `markRecordPending` stamps the HLC; `media_enrichment.hlc` column (Task 1).
- Produces: `SyncRepository.backfillMediaEnrichmentHlc()`.

- [ ] **Step 1: Write the failing backfill test**

Create `test/core/services/sync/sync_enrichment_backfill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// Pre-v130 media_enrichment rows have hlc = NULL and are invisible to the
/// incremental export. The backfill stamps a fresh HLC so they replicate.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('stamps hlc + a pending sync record on null-hlc enrichment rows',
      () async {
    final db = DatabaseService.instance.database;
    // A parent dive + media (FK) and an enrichment row with NO hlc, as written
    // by a pre-v130 build.
    await db.customStatement(
      "INSERT INTO dives (id, dive_number, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', 1, 1000, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO media (id, dive_id, file_path, file_type, source_type, "
      "is_favorite, is_orphaned, created_at, updated_at) "
      "VALUES ('m1', 'd1', '/p.jpg', 'photo', 'platformGallery', 0, 0, "
      "1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO media_enrichment (id, media_id, dive_id, depth_meters, "
      "match_confidence, created_at) "
      "VALUES ('e1', 'm1', 'd1', 12.5, 'exact', 1000)",
    );

    await SyncRepository().backfillMediaEnrichmentHlc();

    final row = await (db.select(db.mediaEnrichment)
          ..where((t) => t.id.equals('e1')))
        .getSingle();
    expect(row.hlc, isNotNull);

    final pending = await (db.select(db.syncRecords)
          ..where((t) => t.entityType.equals('mediaEnrichment')))
        .get();
    expect(pending.map((r) => r.recordId), contains('e1'));
  });

  test('is a no-op the second time (self-limiting)', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dives (id, dive_number, dive_date_time, created_at, "
      "updated_at) VALUES ('d1', 1, 1000, 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO media (id, dive_id, file_path, file_type, source_type, "
      "is_favorite, is_orphaned, created_at, updated_at) "
      "VALUES ('m1', 'd1', '/p.jpg', 'photo', 'platformGallery', 0, 0, "
      "1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO media_enrichment (id, media_id, dive_id, match_confidence, "
      "created_at) VALUES ('e1', 'm1', 'd1', 'exact', 1000)",
    );

    await SyncRepository().backfillMediaEnrichmentHlc();
    final first = (await (db.select(db.mediaEnrichment)
              ..where((t) => t.id.equals('e1')))
            .getSingle())
        .hlc;
    await SyncRepository().backfillMediaEnrichmentHlc();
    final second = (await (db.select(db.mediaEnrichment)
              ..where((t) => t.id.equals('e1')))
            .getSingle())
        .hlc;

    expect(second, first, reason: 'row already had an hlc; not re-stamped');
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/core/services/sync/sync_enrichment_backfill_test.dart`
Expected: FAIL — `backfillMediaEnrichmentHlc` is undefined.

- [ ] **Step 3: Implement the backfill in `sync_repository.dart`**

Add to `class SyncRepository`:

```dart
  /// One-time self-heal for enrichment rows written before schema v130, when
  /// media_enrichment had no `hlc` column and never synced. Such rows carry
  /// `hlc IS NULL` and are invisible to the incremental export (which filters
  /// `hlc > watermark`; SQL `NULL > x` is false). markRecordPending stamps a
  /// fresh HLC (above every peer watermark) so they replicate on the next
  /// sync and heal peers that lost the depth/time association.
  ///
  /// Self-limiting: rows written by saveEnrichment always get an HLC, so once
  /// every legacy row is stamped this finds nothing.
  Future<void> backfillMediaEnrichmentHlc() async {
    final rows = await _db
        .customSelect(
          'SELECT id, created_at FROM media_enrichment WHERE hlc IS NULL',
        )
        .get();
    for (final row in rows) {
      await markRecordPending(
        entityType: 'mediaEnrichment',
        recordId: row.read<String>('id'),
        localUpdatedAt: row.read<int>('created_at'),
      );
    }
  }
```

- [ ] **Step 4: Call it from `performSync`**

In `lib/core/services/sync/sync_service.dart`, in `performSync`, immediately after `await _syncRepository.ensureSyncClockConfigured();`, add:

```dart
      // Self-heal: stamp an HLC on pre-v130 enrichment rows so the depth/time
      // association replicates and repairs peers that lost it.
      await _syncRepository.backfillMediaEnrichmentHlc();
```

- [ ] **Step 5: Run the backfill test**

Run: `flutter test test/core/services/sync/sync_enrichment_backfill_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/data/repositories/sync_repository.dart \
  lib/core/services/sync/sync_service.dart \
  test/core/services/sync/sync_enrichment_backfill_test.dart
git commit -m "feat(sync): backfill hlc on legacy media_enrichment rows (self-heal)"
```

---

## Task 4: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Run the whole sync + database + media test suites**

Run:
```bash
flutter test test/core/services/sync/ test/core/database/ test/features/media/
```
Expected: PASS (no regressions). Investigate any failure before proceeding.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: no errors, no new infos (CI treats infos as fatal).

- [ ] **Step 3: Format the whole project**

Run: `dart format .`
Expected: no files changed (if any change, re-stage and amend the relevant commit).

- [ ] **Step 4: Run the full test suite once**

Run: `flutter test`
Expected: PASS.

---

## Self-Review Notes

- **Spec coverage:** depth/time now (a) travels in base + incremental payloads (`_baseTables`, `_exportMediaEnrichment`), (b) applies on peers (`upsertRecord`/`upsertRecords`, `mergeOrder`), (c) survives Replace-adopt (re-inserted from the cloud union like any synced entity), (d) heals already-broken libraries (`backfillMediaEnrichmentHlc`), and (e) is FK-safe under deferred-FK COMMIT (`parentRefs`).
- **Deletion:** enrichment needs no tombstones — it cascade-deletes with its parent `media`/`dive` locally, and applying the parent's synced deletion cascades on peers too.
- **Type consistency:** entity key `'mediaEnrichment'`, table `media_enrichment`, getter `_db.mediaEnrichment`, row class `MediaEnrichmentData`, companion `MediaEnrichmentCompanion` are used identically everywhere above.
- **Placeholder scan:** none — every step carries concrete code or an exact command.
