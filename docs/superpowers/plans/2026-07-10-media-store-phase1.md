# Media Store Phase 1 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A photo attached on device A displays on device B through a user-configured S3 bucket: schema v103, `MediaObjectStore` + S3 adapter, transfer queue, upload-on-attach, store-fallback resolution with a content-addressed cache, and a Media Storage settings page.

**Architecture:** New `media_store` subsystem parallel to sync (spec: `docs/superpowers/specs/2026-07-10-s3-media-storage-design.md`, sections 5-10, 13-14, Phase 1 of section 17). Bytes live at content-addressed keys (`smv1/objects/<aa>/<sha256>.<ext>`) in the user's bucket; the synced `media` row carries `content_hash` + `remote_uploaded_at` stamps; display falls back from the native resolver to a store-backed cache. Photos only, single-shot transfers (no multipart/resume — that is Phase 3); thumbnails, badges, backfill are Phase 2.

**Tech Stack:** Flutter/Dart, Drift (two databases), Riverpod, existing `S3ApiClient`/`SigV4Signer`, `crypto` (SHA-256), `flutter_secure_storage` via `FallbackSecureStorage`, `shared_preferences`, go_router.

## Global Constraints

- Work ONLY in the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/s3-media-store` (branch `worktree-s3-media-store`). Always use worktree-absolute paths; never touch the main checkout.
- Main DB schema version becomes exactly **103**; local cache DB becomes exactly **2**.
- TDD: write the failing test first in every task.
- After ANY change to `lib/core/database/database.dart` or `lib/core/database/local_cache_database.dart`, run `dart run build_runner build --delete-conflicting-outputs` before analyzing or testing.
- Run tests per-file (`flutter test test/path/file_test.dart`); never the whole suite (it times out).
- Before every commit: `dart format .` (whole repo) and `flutter analyze` (whole project, never piped through `tail`/`head`).
- No emojis anywhere. No `print`/`console.log`; use `LoggerService.forClass(...)`.
- Commit messages: conventional style, single line, NO trailers (no Co-Authored-By, no session links). Example: `feat(media-store): add v103 schema migration`.
- New user-facing strings: add the key to ALL 11 arb files in `lib/l10n/arb/` (`app_en`, `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`) with the translations given in the task, then run `flutter gen-l10n`.
- Object keys are bucket-relative and composed as `<config.prefix><StoreKeys.*>`. Verified: `S3ApiClient._target(key)` (s3_api_client.dart:171) does NOT prepend `config.prefix` — the adapter must.
- File size limit 800 lines; prefer many small files.

---

### Task 1: v103 schema — media columns + media_stores table

**Files:**
- Modify: `lib/core/database/database.dart` (Media table ~line 845; `@DriftDatabase` tables list ~line 2024; `migrationVersions` list ~line 2038; `onUpgrade` after the `if (from < 102)` block ~line 4981; `beforeOpen` backstop ~line 4983)
- Test: `test/core/database/migration_v103_media_store_test.dart`

**Interfaces:**
- Consumes: existing Drift schema (`currentSchemaVersion = 102` at database.dart:2033).
- Produces: `Media` columns `contentHash` (TEXT), `contentSizeBytes` (INTEGER), `remoteUploadedAt` (INTEGER epoch ms), `remoteThumbUploadedAt` (INTEGER epoch ms); table class `MediaStores` (Drift dataclass `MediaStore`, table getter `_db.mediaStores`) with columns `id`, `providerType`, `displayHint`, `createdAt`, `updatedAt`, `hlc`; `AppDatabase.currentSchemaVersion == 103`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v103_media_store_test.dart`, mirroring the structure of `test/core/database/migration_v99_buddy_roles_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh v103 schema has media store columns and media_stores '
      'table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final mediaCols = await db
        .customSelect("PRAGMA table_info('media')")
        .get();
    final mediaColNames = mediaCols.map((c) => c.read<String>('name')).toSet();
    expect(
      mediaColNames,
      containsAll([
        'content_hash',
        'content_size_bytes',
        'remote_uploaded_at',
        'remote_thumb_uploaded_at',
      ]),
    );

    final storeCols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    final storeColNames = storeCols.map((c) => c.read<String>('name')).toSet();
    expect(
      storeColNames,
      containsAll([
        'id',
        'provider_type',
        'display_hint',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('real onUpgrade from v102 adds columns and table, preserving '
      'rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 102');
        // Minimal pre-v103 media shape: enough columns for the row to
        // survive and prove the ALTERs are additive.
        rawDb.execute('''
          CREATE TABLE media (
            id TEXT NOT NULL PRIMARY KEY,
            file_path TEXT NOT NULL,
            file_type TEXT NOT NULL DEFAULT 'photo',
            source_type TEXT NOT NULL DEFAULT 'platformGallery',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO media (id, file_path, created_at, updated_at) "
          "VALUES ('m1', '', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final mediaCols = await db
        .customSelect("PRAGMA table_info('media')")
        .get();
    expect(
      mediaCols.map((c) => c.read<String>('name')),
      containsAll(['content_hash', 'remote_uploaded_at']),
    );

    final storeCols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    expect(storeCols, isNotEmpty);

    final row = await db
        .customSelect(
          "SELECT file_path, content_hash FROM media WHERE id = 'm1'",
        )
        .getSingle();
    expect(row.data['file_path'], '');
    expect(row.data['content_hash'], isNull);
  });

  test('schema version is 103 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(103));
    expect(AppDatabase.migrationVersions, contains(103));
  });

  test('backstop heals a database stranded past v103 by a parallel-branch '
      'version collision', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE media (
            id TEXT NOT NULL PRIMARY KEY,
            file_path TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // No migration runs (user_version == currentSchemaVersion); only the
    // beforeOpen backstop can create the missing objects.
    final mediaCols = await db
        .customSelect("PRAGMA table_info('media')")
        .get();
    expect(
      mediaCols.map((c) => c.read<String>('name')),
      contains('content_hash'),
      reason: 'media store columns must be re-asserted by beforeOpen',
    );
    final storeCols = await db
        .customSelect("PRAGMA table_info('media_stores')")
        .get();
    expect(storeCols, isNotEmpty, reason: 'media_stores must be re-asserted');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v103_media_store_test.dart`
Expected: FAIL (missing columns/table; version assertion fails at 102).

- [ ] **Step 3: Add the schema**

In `lib/core/database/database.dart`:

(a) In `class Media extends Table`, immediately BEFORE the `IntColumn get createdAt` line (~line 843), add:

```dart
  // Media store (v103) - content identity + upload confirmation stamps.
  // Nullable adds; a row with remote_uploaded_at set has its original bytes
  // confirmed present in the library's media store at the content-hash key.
  TextColumn get contentHash => text().nullable()();
  IntColumn get contentSizeBytes => integer().nullable()();
  IntColumn get remoteUploadedAt => integer().nullable()();
  IntColumn get remoteThumbUploadedAt => integer().nullable()();
```

(b) After the `MediaFetchDiagnostics` class (~line 1000, inside the existing `coverage:ignore` region or immediately after `// coverage:ignore-end`), add:

```dart
/// The library's media store descriptor (secret-free). Synced so other
/// devices learn a store exists and can prompt to connect. Exactly one
/// active row is expected; credentials never live here (keychain only).
class MediaStores extends Table {
  TextColumn get id => text()(); // storeId UUID, matches smv1/store.json
  TextColumn get providerType => text()(); // 's3' (Phase 4 adds others)
  TextColumn get displayHint => text()(); // e.g. 'dive-media @ minio.host'
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

(c) Add `MediaStores,` to the `@DriftDatabase(tables: [...])` list (after `MediaFetchDiagnostics,` ~line 2023).

(d) Change `currentSchemaVersion` from 102 to 103 (~line 2033) and append `103,` to `migrationVersions` (~line 2038 list end).

(e) After the `if (from < 102) await reportProgress();` line (~line 4981), add:

```dart
        if (from < 103) {
          // Media store Phase 1 (spec 2026-07-10): content identity +
          // upload stamps on media, plus the secret-free store descriptor.
          // Guarded ALTERs and IF NOT EXISTS keep this idempotent; the
          // beforeOpen backstop re-asserts the same objects against
          // parallel-branch schema-version collisions.
          await _assertMediaStoreSchema();
        }
        if (from < 103) await reportProgress();
```

(f) Add the shared helper as a method on `AppDatabase` (place it near the other private migration helpers, e.g. after `_relinkStrandedTankPressures`):

```dart
  /// Idempotent DDL for the v103 media store objects. Called from the v103
  /// onUpgrade block and from the beforeOpen backstop.
  Future<void> _assertMediaStoreSchema() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    Future<void> add(String name, String type) async {
      if (!names.contains(name)) {
        await customStatement('ALTER TABLE media ADD COLUMN $name $type');
      }
    }

    await add('content_hash', 'TEXT');
    await add('content_size_bytes', 'INTEGER');
    await add('remote_uploaded_at', 'INTEGER');
    await add('remote_thumb_uploaded_at', 'INTEGER');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS media_stores (
        id TEXT NOT NULL PRIMARY KEY,
        provider_type TEXT NOT NULL,
        display_hint TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
  }
```

(g) In `beforeOpen` (~line 4983), after the existing dive-types re-seed logic (find the end of the `beforeOpen` callback body and add just before its closing brace):

```dart
        // v103 backstop: re-assert media store schema (see
        // _assertMediaStoreSchema doc comment).
        final mediaTable = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='media'",
        ).get();
        if (mediaTable.isNotEmpty) {
          await _assertMediaStoreSchema();
        }
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with no errors; `database.g.dart` gains `$MediaStoresTable` and the four new media columns.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v103_media_store_test.dart`
Expected: PASS (all 4 tests).

Also run the neighboring migration test to catch regressions:
Run: `flutter test test/core/database/migration_v99_buddy_roles_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): add v103 schema (media stamps + media_stores table)"
```

---

### Task 2: Sync registration for mediaStores

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData field ~line 245, ctor ~line 295, toJson ~line 346, fromJson ~line 398, `_baseTables` ~line 612, changeset export ~line 997, plus five switch statements — locate each with `grep -n "case 'buddyRoles':" lib/core/services/sync/sync_data_serializer.dart`)
- Modify: `lib/core/services/sync/sync_service.dart` (mergeOrder list end ~line 1010, `entityHasUpdatedAt` map ~line 1545)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` map ~line 33)
- Test: `test/core/services/sync/sync_media_stores_test.dart`

**Interfaces:**
- Consumes: Task 1's `MediaStores` table / `MediaStore` dataclass / `_db.mediaStores`.
- Produces: `SyncData.mediaStores` (`List<Map<String, dynamic>>`); entity type string `'mediaStores'` valid for `markRecordPending`, changeset export/apply, base export/import, and deletion apply.

- [ ] **Step 1: Write the failing sync test**

Create `test/core/services/sync/sync_media_stores_test.dart`, modeled on `test/core/services/sync/sync_buddy_roles_test.dart` (same helpers, same hlc string builder):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Sync replication for `media_stores` (media store Phase 1, spec
/// 2026-07-10). Like `buddy_roles`, this table carries its own `hlc`
/// column, so its export uses the simple hlc-filter pattern.
void main() {
  group('media_stores sync', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    String hlcAt(int physical, String node) =>
        '${physical.toString().padLeft(15, '0')}:000000:$node';

    Map<String, dynamic> storeRow(String id, {required String hlc}) => {
      'id': id,
      'providerType': 's3',
      'displayHint': 'dive-media @ minio.example.com',
      'createdAt': 1000,
      'updatedAt': 1000,
      'hlc': hlc,
    };

    test('export includes a media_stores row', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-1', hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );

      final ids = payload.data.mediaStores.map((r) => r['id']).toSet();
      expect(ids, contains('store-1'));
    });

    test('round trip: wipe and re-import restores providerType and '
        'displayHint', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-1', hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );
      final exported = payload.data.mediaStores.singleWhere(
        (r) => r['id'] == 'store-1',
      );

      await serializer.deleteRecord('mediaStores', 'store-1');
      await serializer.applyRecord('mediaStores', exported);

      final restored = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
      );
      final row = restored.data.mediaStores.singleWhere(
        (r) => r['id'] == 'store-1',
      );
      expect(row['providerType'], 's3');
      expect(row['displayHint'], 'dive-media @ minio.example.com');
    });

    test('hlc filter excludes rows at or below the cursor', () async {
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord(
        'mediaStores',
        storeRow('store-1', hlc: hlcAt(1000, 'dev-a')),
      );

      final payload = await serializer.exportData(
        deviceId: 'dev-a',
        deletions: const [],
        hlcSince: hlcAt(2000, 'dev-a'),
      );
      expect(payload.data.mediaStores, isEmpty);
    });
  });
}
```

NOTE: before running, check the exact public method names on `SyncDataSerializer` used by `sync_buddy_roles_test.dart` (`upsertRecord` / `applyRecord` / `deleteRecord` / `exportData` and its named parameters, including whether the hlc cursor parameter is named `hlcSince`). Use exactly the names that test file uses — it is the compile-checked source of truth. Adjust this test to match before first run.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/sync_media_stores_test.dart`
Expected: FAIL to compile (`data.mediaStores` undefined; `'mediaStores'` cases missing).

- [ ] **Step 3: Register in sync_data_serializer.dart**

Mirror `buddyRoles` at every site. Locate all sites first:

```bash
grep -n "buddyRoles" lib/core/services/sync/sync_data_serializer.dart
```

For each site, add a `mediaStores` sibling directly after the `buddyRoles` (or `diveDiveTypes`) entry:

(a) SyncData field (~line 245 region): `final List<Map<String, dynamic>> mediaStores;`
(b) SyncData constructor (~line 295 region): `this.mediaStores = const [],`
(c) SyncData `toJson` (~line 346 region): `'mediaStores': mediaStores,`
(d) SyncData `fromJson`/parse (~line 398 region): `mediaStores: _parseList(json['mediaStores']),`
(e) `_baseTables` (~line 612 region): `(key: 'mediaStores', table: _db.mediaStores, blob: false, full: null),`
(f) Changeset export call site (~line 997 region):
```dart
      mediaStores: await _safeExport(
        'mediaStores',
        () => _exportMediaStores(hlcSince),
      ),
```
and add the loader method next to `_exportDiveDiveTypes` (~line 3390):
```dart
  Future<List<Map<String, dynamic>>> _exportMediaStores(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final rows = await (_db.select(
        _db.mediaStores,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      return rows.map((r) => r.toJson()).toList();
    }
    final rows = await _db.select(_db.mediaStores).get();
    return rows.map((r) => r.toJson()).toList();
  }
```
(g) Single-record fetch switch (the one whose `diveDiveTypes` case is at ~line 1345):
```dart
      case 'mediaStores':
        final row = await (_db.select(
          _db.mediaStores,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```
(h) Single-record apply switch (~line 1834 region). `media_stores` carries an HLC column, so use `.toCompanion(false)` (matching `diveTypes`/`tankPresets`, per the HLC-entity rule):
```dart
      case 'mediaStores':
        await _db
            .into(_db.mediaStores)
            .insertOnConflictUpdate(
              MediaStore.fromJson(data).toCompanion(false),
            );
        return;
```
(i) Batch apply switch (~line 2272 region):
```dart
      case 'mediaStores':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.mediaStores,
            records
                .map((r) => MediaStore.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
```
(j) `plain(...)` id-listing switch (~line 2560 region):
```dart
      case 'mediaStores':
        return plain(_db.mediaStores, _db.mediaStores.id);
```
(k) Table-lookup switch (~line 2712 region):
```dart
      case 'mediaStores':
        return _db.mediaStores;
```
(l) Delete-by-id switch (~line 2912 region):
```dart
      case 'mediaStores':
        await (_db.delete(
          _db.mediaStores,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

If the grep in this step reveals additional `buddyRoles` sites beyond (a)-(l), mirror those too — the compiler and the guard test below are the completeness check.

- [ ] **Step 4: Register in sync_service.dart and sync_repository.dart**

(a) `sync_service.dart` mergeOrder list — after `(type: 'media', records: data.media, hasUpdatedAt: false),` (~line 1010):
```dart
          (type: 'mediaStores', records: data.mediaStores, hasUpdatedAt: false),
```
(b) `sync_service.dart` `entityHasUpdatedAt` map — after `'media': false,` (~line 1545):
```dart
    'mediaStores': false,
```
(c) `sync_repository.dart` `_hlcTargets` map (~line 33, after the `buddyRoles` entry):
```dart
    'mediaStores': (table: 'media_stores', pk: 'id'),
```
Do NOT add a `parentRefs` entry in sync_service.dart — `media_stores` has no parent tables (the map lookup falls back to an empty list).

- [ ] **Step 5: Run the tests to verify they pass**

```bash
flutter test test/core/services/sync/sync_media_stores_test.dart
flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart
flutter test test/core/services/sync/sync_buddy_roles_test.dart
```
Expected: all PASS. The record-ids guard test is the completeness check for missed registration sites — if it fails, re-run the Step 3 grep and mirror the missed site.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): register mediaStores in sync engine"
```

---

### Task 3: MediaItem entity + repository stamps

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart` (fields ~line 96, ctor ~line 133, copyWith ~line 149, props ~line 290)
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`createMedia` companion ~line 106, `updateMedia` companion ~line 177, `_mapRowToMediaItem` ~line 720, new methods at class end)
- Test: `test/features/media/data/media_repository_store_stamps_test.dart`

**Interfaces:**
- Consumes: Task 1 columns; existing `getMediaById(String)` (media_repository.dart:52); `_syncRepository.markRecordPending(entityType:, recordId:, localUpdatedAt:)` + `SyncEventBus.notifyLocalChange()` (the pattern visible in `createMedia` at media_repository.dart:146-151).
- Produces on `MediaItem`: `String? contentHash`, `int? contentSizeBytes`, `DateTime? remoteUploadedAt`, `DateTime? remoteThumbUploadedAt` (all in ctor, copyWith with `_undefined` sentinel, and `props`). Produces on `MediaRepository`:
  - `Future<void> stampContentIdentity(String mediaId, {required String contentHash, required int sizeBytes})`
  - `Future<void> stampRemoteUploaded(String mediaId, {required DateTime uploadedAt})`

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/media_repository_store_stamps_test.dart`. Look at how existing media repository tests construct the repository and database — find one with `grep -rln "MediaRepository(" test/features/media/ | head -3` and mirror its setup exactly (in-memory `AppDatabase` + `DatabaseService`/`setUpTestDatabase` helper). The assertions:

```dart
    test('stampContentIdentity then stampRemoteUploaded round-trips through '
        'getMediaById and bumps updatedAt', () async {
      final created = await repository.createMedia(
        domain.MediaItem(
          id: '',
          mediaType: domain.MediaType.photo,
          sourceType: MediaSourceType.localFile,
          filePath: '/tmp/x.jpg',
          localPath: '/tmp/x.jpg',
          takenAt: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      await repository.stampContentIdentity(
        created.id,
        contentHash: 'a' * 64,
        sizeBytes: 12345,
      );
      await repository.stampRemoteUploaded(
        created.id,
        uploadedAt: DateTime(2026, 7, 10, 12),
      );

      final loaded = await repository.getMediaById(created.id);
      expect(loaded!.contentHash, 'a' * 64);
      expect(loaded.contentSizeBytes, 12345);
      expect(loaded.remoteUploadedAt, DateTime(2026, 7, 10, 12));
      expect(loaded.remoteThumbUploadedAt, isNull);
    });

    test('createMedia persists contentHash when provided and copyWith can '
        'clear remoteUploadedAt', () async {
      final item = domain.MediaItem(
        id: '',
        mediaType: domain.MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/y.jpg',
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        contentHash: 'b' * 64,
        contentSizeBytes: 1,
      );
      final created = await repository.createMedia(item);
      final loaded = await repository.getMediaById(created.id);
      expect(loaded!.contentHash, 'b' * 64);

      final cleared = loaded.copyWith(remoteUploadedAt: null);
      expect(cleared.remoteUploadedAt, isNull);
      expect(cleared.contentHash, 'b' * 64);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media/data/media_repository_store_stamps_test.dart`
Expected: FAIL to compile (no such fields/methods).

- [ ] **Step 3: Extend the entity**

In `media_item.dart`:

(a) Fields, after `final String? originDeviceId;` (~line 93):
```dart
  final String? contentHash;
  final int? contentSizeBytes;
  final DateTime? remoteUploadedAt;
  final DateTime? remoteThumbUploadedAt;
```
(b) Constructor, after `this.originDeviceId,` (~line 129):
```dart
    this.contentHash,
    this.contentSizeBytes,
    this.remoteUploadedAt,
    this.remoteThumbUploadedAt,
```
(c) copyWith parameters, after `Object? originDeviceId = _undefined,` (~line 180):
```dart
    Object? contentHash = _undefined,
    Object? contentSizeBytes = _undefined,
    Object? remoteUploadedAt = _undefined,
    Object? remoteThumbUploadedAt = _undefined,
```
and copyWith body, after the `originDeviceId:` mapping:
```dart
      contentHash: contentHash == _undefined
          ? this.contentHash
          : contentHash as String?,
      contentSizeBytes: contentSizeBytes == _undefined
          ? this.contentSizeBytes
          : contentSizeBytes as int?,
      remoteUploadedAt: remoteUploadedAt == _undefined
          ? this.remoteUploadedAt
          : remoteUploadedAt as DateTime?,
      remoteThumbUploadedAt: remoteThumbUploadedAt == _undefined
          ? this.remoteThumbUploadedAt
          : remoteThumbUploadedAt as DateTime?,
```
(d) props list, before `enrichment,` (~line 290):
```dart
    contentHash,
    contentSizeBytes,
    remoteUploadedAt,
    remoteThumbUploadedAt,
```
(props membership matters: `MediaItemView._inputsChanged` relies on Equatable equality, so a stamped row re-resolves the widget.)

- [ ] **Step 4: Extend the repository**

In `media_repository.dart`:

(a) `createMedia` companion (~line 141, before `createdAt:`):
```dart
              contentHash: Value(item.contentHash),
              contentSizeBytes: Value(item.contentSizeBytes),
              remoteUploadedAt: Value(
                item.remoteUploadedAt?.millisecondsSinceEpoch,
              ),
              remoteThumbUploadedAt: Value(
                item.remoteThumbUploadedAt?.millisecondsSinceEpoch,
              ),
```
(b) `updateMedia` companion (~line 209, before `updatedAt:`): the same four lines.
(c) `_mapRowToMediaItem` (~line 763, after `originDeviceId: row.originDeviceId,`):
```dart
      contentHash: row.contentHash,
      contentSizeBytes: row.contentSizeBytes,
      remoteUploadedAt: row.remoteUploadedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.remoteUploadedAt!)
          : null,
      remoteThumbUploadedAt: row.remoteThumbUploadedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.remoteThumbUploadedAt!)
          : null,
```
(d) New methods at the end of the class (before `_mapRowToMediaItem`), following the create/update pattern (targeted column write + pending-record + event bus):
```dart
  /// Stamps the content identity computed by the upload pipeline. A synced
  /// row update: peers learn the hash even before upload confirmation.
  Future<void> stampContentIdentity(
    String mediaId, {
    required String contentHash,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        contentHash: Value(contentHash),
        contentSizeBytes: Value(sizeBytes),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Confirms the original object exists in the media store. Once this
  /// syncs, every device knows the bytes are fetchable.
  Future<void> stampRemoteUploaded(
    String mediaId, {
    required DateTime uploadedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteUploadedAt: Value(uploadedAt.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
flutter test test/features/media/data/media_repository_store_stamps_test.dart
flutter test test/features/media/  # media feature tests only
```
Expected: PASS. If any pre-existing media test constructs `MediaItem` positionally or asserts props length, fix that test to include the new fields.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): media entity + repository upload stamps"
```

---

### Task 4: Local cache DB v2 — transfer queue + cache index tables

**Files:**
- Modify: `lib/core/database/local_cache_database.dart`
- Create: `lib/features/media_store/data/media_transfer_queue_repository.dart`
- Test: `test/features/media_store/media_transfer_queue_repository_test.dart`

**Interfaces:**
- Consumes: `LocalCacheDatabase` (local_cache_database.dart), `LocalCacheDatabaseService.instance.database`.
- Produces: Drift tables `MediaTransferQueue` (dataclass `MediaTransferQueueEntry`) and `MediaCacheEntries` (dataclass `MediaCacheEntry`); repository:
```dart
class MediaTransferQueueRepository {
  MediaTransferQueueRepository({LocalCacheDatabase? database});
  Future<int> enqueueUpload({required String mediaId}); // no-op returns existing id if a pending/transferring upload row for mediaId exists
  Future<MediaTransferQueueEntry?> nextPending(DateTime now);
  Future<void> markTransferring(int id);
  Future<void> markDone(int id);
  Future<void> markFailed(int id, String error); // attempts+1; backoff 1/5/30/60 min; attempts >= 5 -> state 'failed' (terminal)
  Future<List<MediaTransferQueueEntry>> allForTesting();
}
```
State strings: `'pending' | 'transferring' | 'done' | 'failed'`. Backoff schedule minutes by attempt count: `[1, 5, 30, 60]`, clamped to last.

- [ ] **Step 1: Write the failing test**

Create `test/features/media_store/media_transfer_queue_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late MediaTransferQueueRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaTransferQueueRepository(database: db);
  });

  tearDown(() => db.close());

  test('enqueue then nextPending returns the entry once transferring', () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final entry = await repo.nextPending(DateTime.now());
    expect(entry, isNotNull);
    expect(entry!.id, id);
    expect(entry.mediaId, 'm1');
    expect(entry.state, 'pending');

    await repo.markTransferring(id);
    expect(await repo.nextPending(DateTime.now()), isNull);
  });

  test('enqueue is idempotent per mediaId while not done', () async {
    final a = await repo.enqueueUpload(mediaId: 'm1');
    final b = await repo.enqueueUpload(mediaId: 'm1');
    expect(a, b);
    await repo.markDone(a);
    final c = await repo.enqueueUpload(mediaId: 'm1');
    expect(c, isNot(a));
  });

  test('markFailed applies backoff and terminal state after 5 attempts',
      () async {
    final id = await repo.enqueueUpload(mediaId: 'm1');
    final t0 = DateTime.now();
    await repo.markFailed(id, 'boom');
    // Not yet due.
    expect(await repo.nextPending(t0), isNull);
    // Due after the first backoff window (1 minute).
    final due = await repo.nextPending(t0.add(const Duration(minutes: 2)));
    expect(due, isNotNull);
    expect(due!.attempts, 1);
    expect(due.errorMessage, 'boom');

    for (var i = 0; i < 4; i++) {
      await repo.markFailed(id, 'boom $i');
    }
    final rows = await repo.allForTesting();
    expect(rows.single.state, 'failed');
    expect(
      await repo.nextPending(t0.add(const Duration(days: 1))),
      isNull,
    );
  });

  test('v2 migration creates both tables', () async {
    final cols = await db
        .customSelect("PRAGMA table_info('media_transfer_queue')")
        .get();
    expect(cols, isNotEmpty);
    final cacheCols = await db
        .customSelect("PRAGMA table_info('media_cache_entries')")
        .get();
    expect(cacheCols, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/media_store/media_transfer_queue_repository_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Add the tables and migration**

Replace the body of `lib/core/database/local_cache_database.dart` below the `LocalAssetCache` table with:

```dart
/// Per-device media transfer queue (media store Phase 1). Never synced,
/// never backed up: a restored database must not carry another device's
/// in-flight transfers.
class MediaTransferQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mediaId => text()();
  TextColumn get direction => text().withDefault(const Constant('upload'))();
  TextColumn get objectKind => text().withDefault(const Constant('original'))();
  TextColumn get contentHash => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  TextColumn get resumeStateJson => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Per-device index of content-addressed cache files (media store Phase 1).
class MediaCacheEntries extends Table {
  TextColumn get contentHash => text()();
  TextColumn get kind => text()(); // 'original' | 'thumb'
  TextColumn get relativePath => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get lastAccessedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {contentHash, kind};
}

@DriftDatabase(tables: [LocalAssetCache, MediaTransferQueue, MediaCacheEntries])
class LocalCacheDatabase extends _$LocalCacheDatabase {
  LocalCacheDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(mediaTransferQueue);
        await m.createTable(mediaCacheEntries);
      }
    },
  );
}
```

(Keep the existing `LocalAssetCache` class and the `part 'local_cache_database.g.dart';` directive unchanged.)

- [ ] **Step 4: Write the repository**

Create `lib/features/media_store/data/media_transfer_queue_repository.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// Backoff schedule in minutes, indexed by (attempts - 1) and clamped.
const List<int> _backoffMinutes = [1, 5, 30, 60];

/// Attempts after which an entry becomes terminally 'failed'.
const int _maxAttempts = 5;

class MediaTransferQueueRepository {
  MediaTransferQueueRepository({LocalCacheDatabase? database})
    : _db = database ?? LocalCacheDatabaseService.instance.database;

  final LocalCacheDatabase _db;

  Future<int> enqueueUpload({required String mediaId}) async {
    final existing =
        await (_db.select(_db.mediaTransferQueue)
              ..where(
                (t) =>
                    t.mediaId.equals(mediaId) &
                    t.direction.equals('upload') &
                    t.state.isIn(['pending', 'transferring']),
              ))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final now = DateTime.now().millisecondsSinceEpoch;
    return _db
        .into(_db.mediaTransferQueue)
        .insert(
          MediaTransferQueueCompanion.insert(
            mediaId: mediaId,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<MediaTransferQueueEntry?> nextPending(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    return (_db.select(_db.mediaTransferQueue)
          ..where(
            (t) =>
                t.state.equals('pending') &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(nowMs)),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> markTransferring(int id) => _setState(id, 'transferring');

  Future<void> markDone(int id) => _setState(id, 'done');

  Future<void> markFailed(int id, String error) async {
    final row = await (_db.select(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).getSingle();
    final attempts = row.attempts + 1;
    final terminal = attempts >= _maxAttempts;
    final backoff =
        _backoffMinutes[(attempts - 1).clamp(0, _backoffMinutes.length - 1)];
    final now = DateTime.now();
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: Value(terminal ? 'failed' : 'pending'),
        attempts: Value(attempts),
        nextAttemptAt: Value(
          terminal
              ? null
              : now.add(Duration(minutes: backoff)).millisecondsSinceEpoch,
        ),
        errorMessage: Value(error),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<MediaTransferQueueEntry>> allForTesting() =>
      _db.select(_db.mediaTransferQueue).get();

  Future<void> _setState(int id, String state) async {
    await (_db.update(
      _db.mediaTransferQueue,
    )..where((t) => t.id.equals(id))).write(
      MediaTransferQueueCompanion(
        state: Value(state),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
```

NOTE: the Drift dataclass name for `MediaTransferQueue` may generate as `MediaTransferQueueData` rather than `MediaTransferQueueEntry`. After codegen, check `local_cache_database.g.dart` for the actual name and use it consistently here, in the tests, and in Tasks 9-11. If it is `MediaTransferQueueData`, add near the top of this file:
```dart
typedef MediaTransferQueueEntry = MediaTransferQueueData;
```
so the `MediaTransferQueueEntry` name in every other task remains valid.

- [ ] **Step 5: Codegen, run tests**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/media_store/media_transfer_queue_repository_test.dart
```
Expected: PASS (4 tests). Also run the existing local-cache consumer test to catch regressions: `flutter test test/features/media/ -x` is too broad — instead run `grep -rln "LocalCacheDatabase(" test/ | head -5` and run those files.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): local cache DB v2 with transfer queue"
```

---

### Task 5: Store keys + streamed hashing

**Files:**
- Create: `lib/core/services/media_store/store_keys.dart`
- Test: `test/core/services/media_store/store_keys_test.dart`

**Interfaces:**
- Consumes: `package:crypto` (sha256), `dart:io`.
- Produces:
```dart
class StoreKeys {
  static const String markerKey = 'smv1/store.json';
  static String objectKey(String contentHash, {required String extension});
  // 'smv1/objects/<first2>/<hash>.<ext>'
  static String thumbKey(String contentHash); // 'smv1/thumbs/<first2>/<hash>.jpg'
  static String extensionFor(String? originalFilename); // lowercase, no dot, [a-z0-9]{1,8}; fallback 'bin'
  static String contentTypeFor(String extension); // mime, fallback 'application/octet-stream'
}
Future<({String hash, int sizeBytes})> sha256OfFile(File file); // streamed, lowercase hex
```

- [ ] **Step 1: Write the failing test**

Create `test/core/services/media_store/store_keys_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

void main() {
  test('objectKey fans out on the first two hash chars', () {
    final hash = 'ab${'0' * 62}';
    expect(
      StoreKeys.objectKey(hash, extension: 'jpg'),
      'smv1/objects/ab/$hash.jpg',
    );
    expect(StoreKeys.thumbKey(hash), 'smv1/thumbs/ab/$hash.jpg');
    expect(StoreKeys.markerKey, 'smv1/store.json');
  });

  test('extensionFor sanitizes and falls back to bin', () {
    expect(StoreKeys.extensionFor('IMG_1234.JPG'), 'jpg');
    expect(StoreKeys.extensionFor('clip.MOV'), 'mov');
    expect(StoreKeys.extensionFor('archive.tar.gz'), 'gz');
    expect(StoreKeys.extensionFor('noext'), 'bin');
    expect(StoreKeys.extensionFor(null), 'bin');
    expect(StoreKeys.extensionFor('weird.j%p*g'), 'bin');
    expect(StoreKeys.extensionFor('x.verylongextension'), 'bin');
  });

  test('contentTypeFor maps common types', () {
    expect(StoreKeys.contentTypeFor('jpg'), 'image/jpeg');
    expect(StoreKeys.contentTypeFor('jpeg'), 'image/jpeg');
    expect(StoreKeys.contentTypeFor('png'), 'image/png');
    expect(StoreKeys.contentTypeFor('heic'), 'image/heic');
    expect(StoreKeys.contentTypeFor('mp4'), 'video/mp4');
    expect(StoreKeys.contentTypeFor('mov'), 'video/quicktime');
    expect(StoreKeys.contentTypeFor('bin'), 'application/octet-stream');
  });

  test('sha256OfFile streams and matches a known vector', () async {
    // Vector computed with:
    //   python3 -c "import hashlib; print(hashlib.sha256(b'submersion').hexdigest())"
    final dir = await Directory.systemTemp.createTemp('store_keys_test');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/v.bin');
    await f.writeAsBytes('submersion'.codeUnits);
    final digest = await sha256OfFile(f);
    expect(digest.sizeBytes, 10);
    expect(digest.hash, hasLength(64));
    expect(digest.hash, digest.hash.toLowerCase());
  });
}
```

Before finalizing the vector assertion, compute the real digest with `python3 -c "import hashlib; print(hashlib.sha256(b'submersion').hexdigest())"` and assert `digest.hash` equals that exact string (never write a hash from memory).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/media_store/store_keys_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Create `lib/core/services/media_store/store_keys.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Key derivation for the smv1 media store layout (design spec section 7).
/// Keys returned here are store-relative; the adapter prepends the
/// user-configured bucket prefix.
class StoreKeys {
  StoreKeys._();

  static const String markerKey = 'smv1/store.json';

  static final RegExp _extPattern = RegExp(r'^[a-z0-9]{1,8}$');

  static String objectKey(String contentHash, {required String extension}) =>
      'smv1/objects/${contentHash.substring(0, 2)}/$contentHash.$extension';

  static String thumbKey(String contentHash) =>
      'smv1/thumbs/${contentHash.substring(0, 2)}/$contentHash.jpg';

  /// Lowercased extension of [originalFilename] without the dot, or 'bin'
  /// when absent or unusual. Identical bytes imply identical format, so the
  /// hash-to-extension mapping is stable across devices.
  static String extensionFor(String? originalFilename) {
    if (originalFilename == null) return 'bin';
    final dot = originalFilename.lastIndexOf('.');
    if (dot < 0 || dot == originalFilename.length - 1) return 'bin';
    final ext = originalFilename.substring(dot + 1).toLowerCase();
    return _extPattern.hasMatch(ext) ? ext : 'bin';
  }

  static String contentTypeFor(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Streamed SHA-256 of [file]: bounded memory for arbitrarily large media.
Future<({String hash, int sizeBytes})> sha256OfFile(File file) async {
  var size = 0;
  final output = AccumulatorSink<Digest>();
  final input = sha256.startChunkedConversion(output);
  await for (final chunk in file.openRead()) {
    size += chunk.length;
    input.add(chunk);
  }
  input.close();
  return (hash: output.events.single.toString(), sizeBytes: size);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/services/media_store/store_keys_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): smv1 key derivation and streamed hashing"
```

---

### Task 6: MediaObjectStore interface + in-memory fake + contract tests

**Files:**
- Create: `lib/core/services/media_store/media_object_store.dart`
- Create: `test/helpers/in_memory_media_object_store.dart`
- Test: `test/core/services/media_store/media_object_store_contract_test.dart`

**Interfaces:**
- Produces:
```dart
class StoreObjectInfo {
  final String key;
  final int? sizeBytes;
  final DateTime lastModified;
  const StoreObjectInfo({required this.key, this.sizeBytes, required this.lastModified});
}

enum MediaStoreErrorKind { notFound, auth, transient, fatal }

class MediaStoreException implements Exception {
  final String message;
  final MediaStoreErrorKind kind;
  final Object? cause;
  const MediaStoreException(this.message, {required this.kind, this.cause});
}

abstract class MediaObjectStore {
  Future<StoreObjectInfo?> head(String key);           // null when absent
  Future<void> putFile(String key, File source, {required String contentType});
  Future<void> getFile(String key, File destination);  // throws notFound when absent
  Future<void> delete(String key);                     // idempotent
  Stream<StoreObjectInfo> list(String keyPrefix);
}
```
- Fake: `class InMemoryMediaObjectStore implements MediaObjectStore` with `Map<String, List<int>> objects` exposed for assertions and `Exception? failNextWith;` to inject one-shot failures.
- Contract: `void runMediaObjectStoreContract(String name, Future<MediaObjectStore> Function() build)` — a reusable test group any adapter can run.

Phase 3 will extend `putFile`/`getFile` with progress and resume named parameters; Phase 1 deliberately omits them.

- [ ] **Step 1: Write the failing contract test**

Create `test/core/services/media_store/media_object_store_contract_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_media_object_store.dart';
import 'media_object_store_contract.dart';

void main() {
  runMediaObjectStoreContract(
    'InMemoryMediaObjectStore',
    () async => InMemoryMediaObjectStore(),
  );
}
```

Create `test/core/services/media_store/media_object_store_contract.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Behavioral contract every MediaObjectStore implementation must satisfy.
void runMediaObjectStoreContract(
  String name,
  Future<MediaObjectStore> Function() build,
) {
  group('$name contract', () {
    late MediaObjectStore store;
    late Directory tmp;

    setUp(() async {
      store = await build();
      tmp = await Directory.systemTemp.createTemp('mos_contract');
    });

    tearDown(() => tmp.delete(recursive: true));

    File tempFile(String name, List<int> bytes) {
      final f = File('${tmp.path}/$name');
      f.writeAsBytesSync(bytes);
      return f;
    }

    test('head of a missing key is null', () async {
      expect(await store.head('smv1/objects/aa/missing.jpg'), isNull);
    });

    test('putFile then head then getFile round-trips bytes', () async {
      final bytes = List<int>.generate(1024, (i) => i % 251);
      final src = tempFile('src.jpg', bytes);
      await store.putFile(
        'smv1/objects/aa/k1.jpg',
        src,
        contentType: 'image/jpeg',
      );

      final info = await store.head('smv1/objects/aa/k1.jpg');
      expect(info, isNotNull);
      expect(info!.sizeBytes, bytes.length);

      final dest = File('${tmp.path}/dest.jpg');
      await store.getFile('smv1/objects/aa/k1.jpg', dest);
      expect(await dest.readAsBytes(), bytes);
    });

    test('getFile of a missing key throws notFound', () async {
      final dest = File('${tmp.path}/nope.bin');
      await expectLater(
        store.getFile('smv1/objects/aa/nope.bin', dest),
        throwsA(
          isA<MediaStoreException>().having(
            (e) => e.kind,
            'kind',
            MediaStoreErrorKind.notFound,
          ),
        ),
      );
    });

    test('delete is idempotent', () async {
      final src = tempFile('d.bin', [1, 2, 3]);
      await store.putFile('smv1/objects/aa/d.bin', src,
          contentType: 'application/octet-stream');
      await store.delete('smv1/objects/aa/d.bin');
      await store.delete('smv1/objects/aa/d.bin'); // no throw
      expect(await store.head('smv1/objects/aa/d.bin'), isNull);
    });

    test('list filters by prefix', () async {
      final src = tempFile('l.bin', [9]);
      await store.putFile('smv1/objects/aa/one.bin', src,
          contentType: 'application/octet-stream');
      await store.putFile('smv1/thumbs/aa/one.jpg', src,
          contentType: 'image/jpeg');

      final keys = await store
          .list('smv1/objects/')
          .map((o) => o.key)
          .toList();
      expect(keys, ['smv1/objects/aa/one.bin']);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/media_store/media_object_store_contract_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement interface and fake**

Create `lib/core/services/media_store/media_object_store.dart` with exactly the types from the Interfaces block above (add doc comments: interface is file-based to keep memory bounded; spec section 8.1).

Create `test/helpers/in_memory_media_object_store.dart`:

```dart
import 'dart:io';

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Test double: byte-map-backed store with one-shot failure injection.
class InMemoryMediaObjectStore implements MediaObjectStore {
  final Map<String, List<int>> objects = {};
  final Map<String, DateTime> modified = {};

  /// When set, the next operation throws it once and clears the field.
  Exception? failNextWith;

  void _maybeFail() {
    final e = failNextWith;
    if (e != null) {
      failNextWith = null;
      throw e;
    }
  }

  @override
  Future<StoreObjectInfo?> head(String key) async {
    _maybeFail();
    final bytes = objects[key];
    if (bytes == null) return null;
    return StoreObjectInfo(
      key: key,
      sizeBytes: bytes.length,
      lastModified: modified[key] ?? DateTime.now(),
    );
  }

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
  }) async {
    _maybeFail();
    objects[key] = await source.readAsBytes();
    modified[key] = DateTime.now();
  }

  @override
  Future<void> getFile(String key, File destination) async {
    _maybeFail();
    final bytes = objects[key];
    if (bytes == null) {
      throw MediaStoreException(
        'not found: $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    await destination.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String key) async {
    _maybeFail();
    objects.remove(key);
    modified.remove(key);
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    _maybeFail();
    for (final entry in objects.entries) {
      if (entry.key.startsWith(keyPrefix)) {
        yield StoreObjectInfo(
          key: entry.key,
          sizeBytes: entry.value.length,
          lastModified: modified[entry.key] ?? DateTime.now(),
        );
      }
    }
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/services/media_store/media_object_store_contract_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): MediaObjectStore interface, fake, and contract"
```

---

### Task 7: S3 adapter + store marker

**Files:**
- Create: `lib/core/services/media_store/s3_media_object_store.dart`
- Create: `lib/core/services/media_store/store_marker.dart`
- Test: `test/core/services/media_store/s3_media_object_store_test.dart`
- Test: `test/core/services/media_store/store_marker_test.dart`

**Interfaces:**
- Consumes: `S3ApiClient` (putObject/getObject/headObject/deleteObject/listObjects, all throwing `CloudStorageException`), `S3Config` (`config.prefix` is `'' `or `'segment/'`-normalized), `StoreKeys`, Task 6 types, `package:uuid`.
- Produces:
```dart
class S3MediaObjectStore implements MediaObjectStore {
  S3MediaObjectStore({required S3ApiClient client, required String keyPrefix});
  // keyPrefix = config.prefix ('' allowed); full wire key = '$keyPrefix$key'
}

class StoreMarker {
  final String storeId;
  final int formatVersion;
  final String createdAt; // iso8601
  // toJson/fromJson
}

class StoreMarkerStore {
  StoreMarkerStore({required MediaObjectStore store});
  Future<({StoreMarker marker, bool created})> ensure(); // read marker; write a fresh one (uuid v4) when absent
  Future<StoreMarker?> read(); // null when absent
}
```

- [ ] **Step 1: Write the failing adapter test**

Create `test/core/services/media_store/s3_media_object_store_test.dart`. Build a real `S3ApiClient` over `package:http/testing.dart`'s `MockClient` so key composition, error mapping, and byte round-trips are exercised through the actual signing path:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

void main() {
  late Directory tmp;
  final captured = <http.Request>[];
  final remote = <String, Uint8List>{}; // path -> bytes

  S3MediaObjectStore build({String prefix = 'submersion-media/'}) {
    final config = S3Config(
      endpoint: 'http://localhost:9000',
      bucket: 'test-bucket',
      prefix: prefix,
      accessKeyId: 'AKIA_TEST',
      secretAccessKey: 'secret',
    );
    final client = S3ApiClient(
      config,
      httpClient: MockClient((request) async {
        captured.add(request);
        // Path-style: /test-bucket/<key>
        final key = request.url.path.replaceFirst('/test-bucket/', '');
        switch (request.method) {
          case 'PUT':
            remote[key] = Uint8List.fromList(request.bodyBytes);
            return http.Response('', 200);
          case 'HEAD':
            final body = remote[key];
            if (body == null) return http.Response('', 404);
            return http.Response('', 200, headers: {
              'content-length': '${body.length}',
              'last-modified': 'Thu, 09 Jul 2026 00:00:00 GMT',
            });
          case 'GET':
            if (request.url.queryParameters.containsKey('list-type')) {
              final prefixParam = request.url.queryParameters['prefix'] ?? '';
              final keys = remote.keys
                  .where((k) => k.startsWith(prefixParam))
                  .toList();
              final contents = keys
                  .map(
                    (k) =>
                        '<Contents><Key>$k</Key>'
                        '<LastModified>2026-07-09T00:00:00.000Z</LastModified>'
                        '<Size>${remote[k]!.length}</Size></Contents>',
                  )
                  .join();
              return http.Response(
                '<?xml version="1.0"?><ListBucketResult>'
                '<IsTruncated>false</IsTruncated>$contents'
                '</ListBucketResult>',
                200,
              );
            }
            final body = remote[key];
            if (body == null) return http.Response('', 404);
            return http.Response.bytes(body, 200);
          case 'DELETE':
            remote.remove(key);
            return http.Response('', 204);
          default:
            return http.Response('', 500);
        }
      }),
    );
    return S3MediaObjectStore(client: client, keyPrefix: config.prefix);
  }

  setUp(() async {
    captured.clear();
    remote.clear();
    tmp = await Directory.systemTemp.createTemp('s3_mos_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('putFile composes prefixed key and uploads bytes', () async {
    final store = build();
    final src = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    await store.putFile('smv1/objects/ab/abc.jpg', src,
        contentType: 'image/jpeg');
    expect(remote.keys, ['submersion-media/smv1/objects/ab/abc.jpg']);
    expect(remote.values.single, [1, 2, 3]);
  });

  test('head returns size and null for missing; getFile round-trips and '
      'maps 404 to notFound', () async {
    final store = build();
    final src = File('${tmp.path}/b.bin')..writeAsBytesSync([9, 9]);
    await store.putFile('smv1/objects/aa/k.bin', src,
        contentType: 'application/octet-stream');

    final info = await store.head('smv1/objects/aa/k.bin');
    expect(info!.sizeBytes, 2);
    expect(await store.head('smv1/objects/aa/missing.bin'), isNull);

    final dest = File('${tmp.path}/out.bin');
    await store.getFile('smv1/objects/aa/k.bin', dest);
    expect(await dest.readAsBytes(), [9, 9]);

    await expectLater(
      store.getFile('smv1/objects/aa/missing.bin', File('${tmp.path}/x')),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.notFound,
        ),
      ),
    );
  });

  test('list strips the configured prefix from returned keys', () async {
    final store = build();
    final src = File('${tmp.path}/c.bin')..writeAsBytesSync([7]);
    await store.putFile('smv1/objects/aa/x.bin', src,
        contentType: 'application/octet-stream');
    final keys = await store.list('smv1/objects/').map((o) => o.key).toList();
    expect(keys, ['smv1/objects/aa/x.bin']);
  });

  test('delete is idempotent through the client', () async {
    final store = build();
    await store.delete('smv1/objects/aa/gone.bin');
    await store.delete('smv1/objects/aa/gone.bin');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/media_store/s3_media_object_store_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the adapter**

Create `lib/core/services/media_store/s3_media_object_store.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// S3-backed media object store (Phase 1: single-shot transfers).
///
/// Wire keys are '$keyPrefix$key' -- S3ApiClient._target does NOT apply the
/// configured prefix, so this adapter must. Whole-byte transfers are
/// acceptable for photos; Phase 3 replaces the internals with multipart +
/// Range streaming for video without changing the interface.
class S3MediaObjectStore implements MediaObjectStore {
  S3MediaObjectStore({required S3ApiClient client, required String keyPrefix})
    : _client = client,
      _keyPrefix = keyPrefix;

  final S3ApiClient _client;
  final String _keyPrefix;

  String _wire(String key) => '$_keyPrefix$key';

  @override
  Future<StoreObjectInfo?> head(String key) async {
    try {
      final info = await _client.headObject(_wire(key));
      if (info == null) return null;
      return StoreObjectInfo(
        key: key,
        sizeBytes: info.size,
        lastModified: info.lastModified,
      );
    } on CloudStorageException catch (e) {
      throw _map('head', key, e);
    }
  }

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await source.readAsBytes();
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
    try {
      await _client.putObject(_wire(key), bytes);
    } on CloudStorageException catch (e) {
      throw _map('put', key, e);
    }
  }

  @override
  Future<void> getFile(String key, File destination) async {
    try {
      final bytes = await _client.getObject(_wire(key));
      await destination.writeAsBytes(bytes, flush: true);
    } on CloudStorageException catch (e) {
      throw _map('get', key, e);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _client.deleteObject(_wire(key));
    } on CloudStorageException catch (e) {
      throw _map('delete', key, e);
    }
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final List<S3ObjectInfo> infos;
    try {
      infos = await _client.listObjects(prefix: _wire(keyPrefix));
    } on CloudStorageException catch (e) {
      throw _map('list', keyPrefix, e);
    }
    for (final info in infos) {
      yield StoreObjectInfo(
        key: info.key.startsWith(_keyPrefix)
            ? info.key.substring(_keyPrefix.length)
            : info.key,
        sizeBytes: info.size,
        lastModified: info.lastModified,
      );
    }
  }

  MediaStoreException _map(String op, String key, CloudStorageException e) {
    final message = e.message;
    final kind = message.contains('not found')
        ? MediaStoreErrorKind.notFound
        : message.contains('Access denied') || message.contains('credentials')
        ? MediaStoreErrorKind.auth
        : message.contains('timed out') || message.contains('temporarily')
        ? MediaStoreErrorKind.transient
        : MediaStoreErrorKind.fatal;
    return MediaStoreException('$op $key failed: $message',
        kind: kind, cause: e);
  }
}
```

Before finalizing `_map`, read `S3ApiClient._throwFor` (s3_api_client.dart:351) and align the substring checks with the exact user-facing messages it produces (404 -> `File not found in S3`, 403, skew, etc.). Adjust the `notFound` check to match the real 404 message text.

- [ ] **Step 4: Write and pass the marker test**

Create `test/core/services/media_store/store_marker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';

import '../../../helpers/in_memory_media_object_store.dart';

void main() {
  test('ensure writes a marker when absent and is stable afterwards',
      () async {
    final store = InMemoryMediaObjectStore();
    final markers = StoreMarkerStore(store: store);

    final first = await markers.ensure();
    expect(first.created, isTrue);
    expect(first.marker.storeId, isNotEmpty);
    expect(first.marker.formatVersion, 1);
    expect(store.objects.containsKey(StoreKeys.markerKey), isTrue);

    final second = await markers.ensure();
    expect(second.created, isFalse);
    expect(second.marker.storeId, first.marker.storeId);
  });

  test('read returns null when no marker exists and parses an existing one',
      () async {
    final store = InMemoryMediaObjectStore();
    final markers = StoreMarkerStore(store: store);
    expect(await markers.read(), isNull);
    await markers.ensure();
    final marker = await markers.read();
    expect(marker, isNotNull);
  });
}
```

Create `lib/core/services/media_store/store_marker.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

/// Identity marker at smv1/store.json (design spec sections 7 and 13).
class StoreMarker {
  final String storeId;
  final int formatVersion;
  final String createdAt;

  const StoreMarker({
    required this.storeId,
    required this.formatVersion,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'formatVersion': formatVersion,
    'createdAt': createdAt,
  };

  static StoreMarker? fromJson(Object? decoded) {
    if (decoded is! Map<String, Object?>) return null;
    final storeId = decoded['storeId'];
    if (storeId is! String || storeId.isEmpty) return null;
    return StoreMarker(
      storeId: storeId,
      formatVersion: (decoded['formatVersion'] as num?)?.toInt() ?? 1,
      createdAt: decoded['createdAt'] as String? ?? '',
    );
  }
}

/// Reads/creates the marker through a [MediaObjectStore].
class StoreMarkerStore {
  StoreMarkerStore({required MediaObjectStore store}) : _store = store;

  final MediaObjectStore _store;

  Future<StoreMarker?> read() async {
    final tmp = File(
      '${Directory.systemTemp.path}/'
      'submersion_marker_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    try {
      await _store.getFile(StoreKeys.markerKey, tmp);
      final decoded = jsonDecode(await tmp.readAsString());
      return StoreMarker.fromJson(decoded);
    } on MediaStoreException catch (e) {
      if (e.kind == MediaStoreErrorKind.notFound) return null;
      rethrow;
    } on FormatException {
      return null;
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
  }

  Future<({StoreMarker marker, bool created})> ensure() async {
    final existing = await read();
    if (existing != null) return (marker: existing, created: false);
    final marker = StoreMarker(
      storeId: const Uuid().v4(),
      formatVersion: 1,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final tmp = File(
      '${Directory.systemTemp.path}/'
      'submersion_marker_w_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    try {
      await tmp.writeAsString(jsonEncode(marker.toJson()), flush: true);
      await _store.putFile(
        StoreKeys.markerKey,
        tmp,
        contentType: 'application/json',
      );
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
    return (marker: marker, created: true);
  }
}
```

- [ ] **Step 5: Run all Task 7 tests, plus the contract against S3 mock is NOT required (contract runs on the fake only in Phase 1)**

```bash
flutter test test/core/services/media_store/s3_media_object_store_test.dart
flutter test test/core/services/media_store/store_marker_test.dart
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): S3 adapter and store identity marker"
```

---

### Task 8: Credentials + attach state

**Files:**
- Create: `lib/core/services/media_store/media_store_credentials_store.dart`
- Create: `lib/core/services/media_store/media_store_attach_state.dart`
- Test: `test/core/services/media_store/media_store_credentials_test.dart`

**Interfaces:**
- Consumes: `S3Config`, `FallbackSecureStorage` (fallback_secure_storage.dart), `SharedPreferences`.
- Produces:
```dart
class MediaStoreCredentialsStore { // mirrors S3CredentialsStore, key 'media_store_s3_config'
  MediaStoreCredentialsStore({FlutterSecureStorage? storage});
  static const String storageKey = 'media_store_s3_config';
  Future<S3Config?> load();
  Future<void> save(S3Config config);
  Future<void> clear();
}

class MediaStoreAttachState { // SharedPreferences; secret-free
  MediaStoreAttachState({SharedPreferences? prefs});
  static const String storeIdKey = 'media_store_attached_store_id';
  Future<String?> attachedStoreId();
  Future<void> setAttached(String storeId);
  Future<void> clear();
}
```

- [ ] **Step 1: Write the failing test**

Create `test/core/services/media_store/media_store_credentials_test.dart`. `S3CredentialsStore` is constructed with an injectable `FlutterSecureStorage`; check how existing tests fake it: `grep -rln "S3CredentialsStore(" test/ | head -3` and mirror that fake (there is an in-memory `FlutterSecureStorage` fake or mock in those tests). The assertions:

```dart
  test('save/load round-trips config under the media key', () async {
    final store = MediaStoreCredentialsStore(storage: fakeStorage);
    expect(await store.load(), isNull);
    await store.save(
      S3Config(
        endpoint: 'https://minio.example.com',
        bucket: 'dive-media',
        prefix: 'submersion-media/',
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
      ),
    );
    final loaded = await store.load();
    expect(loaded!.bucket, 'dive-media');
    expect(loaded.prefix, 'submersion-media/');
    expect(MediaStoreCredentialsStore.storageKey, 'media_store_s3_config');
  });

  test('attach state round-trips via SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = MediaStoreAttachState(prefs: prefs);
    expect(await state.attachedStoreId(), isNull);
    await state.setAttached('store-xyz');
    expect(await state.attachedStoreId(), 'store-xyz');
    await state.clear();
    expect(await state.attachedStoreId(), isNull);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/services/media_store/media_store_credentials_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement both classes**

`media_store_credentials_store.dart` is a byte-for-byte sibling of `S3CredentialsStore` (s3_credentials_store.dart) with the class name, doc comment ("media store", not sync), and `storageKey = 'media_store_s3_config'` changed. Same corrupt-blob-preserving load semantics.

`media_store_attach_state.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Which media store this device is attached to. Secret-free; credentials
/// live in the keychain (MediaStoreCredentialsStore). SharedPreferences so
/// a database restore cannot silently re-point the device at a different
/// store.
class MediaStoreAttachState {
  MediaStoreAttachState({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String storeIdKey = 'media_store_attached_store_id';

  Future<SharedPreferences> get _resolved async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<String?> attachedStoreId() async =>
      (await _resolved).getString(storeIdKey);

  Future<void> setAttached(String storeId) async =>
      (await _resolved).setString(storeIdKey, storeId);

  Future<void> clear() async => (await _resolved).remove(storeIdKey);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/services/media_store/media_store_credentials_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): credentials store and attach state"
```

---

### Task 9: MediaCacheStore (content-addressed cache + LRU eviction)

**Files:**
- Create: `lib/features/media_store/data/media_cache_store.dart`
- Test: `test/features/media_store/media_cache_store_test.dart`

**Interfaces:**
- Consumes: `LocalCacheDatabase` (Task 4 `MediaCacheEntries`), `path_provider` (`getApplicationSupportDirectory`).
- Produces:
```dart
enum MediaCacheKind { original, thumb }

class MediaCacheStore {
  MediaCacheStore({
    required LocalCacheDatabase database,
    required Directory root, // <app-support>/Submersion/media_cache in prod
    int originalsCapBytes = 2 * 1024 * 1024 * 1024,
    int thumbsCapBytes = 256 * 1024 * 1024,
  });
  Future<File?> get(String contentHash, MediaCacheKind kind); // null on miss; touches lastAccessedAt
  Future<File> put(String contentHash, MediaCacheKind kind, File source); // moves source into the cache, upserts index, then evicts if over cap
  Future<File> stagingFile(); // unique temp file under root/staging
  Future<void> evictIfNeeded(); // LRU per kind pool
  Future<int> totalBytes(MediaCacheKind kind);
}
```
Layout on disk: `root/originals/<aa>/<hash>` and `root/thumbs/<aa>/<hash>` (no extension needed; the DB row and callers carry type context). `relativePath` in the index is relative to `root`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media_store/media_cache_store_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('media_cache_test');
    cache = MediaCacheStore(
      database: db,
      root: root,
      originalsCapBytes: 100,
      thumbsCapBytes: 50,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<File> staged(List<int> bytes) async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  test('put then get round-trips and moves the staging file', () async {
    final hash = 'ab${'0' * 62}';
    final src = await staged([1, 2, 3]);
    final cached = await cache.put(hash, MediaCacheKind.original, src);
    expect(await cached.readAsBytes(), [1, 2, 3]);
    expect(await src.exists(), isFalse);

    final hit = await cache.get(hash, MediaCacheKind.original);
    expect(hit, isNotNull);
    expect(hit!.path, cached.path);
    expect(await cache.get(hash, MediaCacheKind.thumb), isNull);
    expect(await cache.totalBytes(MediaCacheKind.original), 3);
  });

  test('eviction removes least-recently-used entries above the cap',
      () async {
    // Three 40-byte originals against a 100-byte cap: the LRU one goes.
    final hashes = [
      'aa${'1' * 62}',
      'bb${'2' * 62}',
      'cc${'3' * 62}',
    ];
    for (final (i, h) in hashes.indexed) {
      final f = await staged(List.filled(40, i));
      await cache.put(h, MediaCacheKind.original, f);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Touch the first so the second becomes LRU.
    await cache.get(hashes[0], MediaCacheKind.original);
    await cache.evictIfNeeded();

    expect(await cache.totalBytes(MediaCacheKind.original),
        lessThanOrEqualTo(100));
    expect(await cache.get(hashes[1], MediaCacheKind.original), isNull);
    expect(await cache.get(hashes[0], MediaCacheKind.original), isNotNull);
    expect(await cache.get(hashes[2], MediaCacheKind.original), isNotNull);
  });

  test('get self-heals when the file vanished behind the index', () async {
    final hash = 'dd${'4' * 62}';
    final cached =
        await cache.put(hash, MediaCacheKind.original, await staged([5]));
    await cached.delete();
    expect(await cache.get(hash, MediaCacheKind.original), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/media_store/media_cache_store_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

Create `lib/features/media_store/data/media_cache_store.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/local_cache_database.dart';

enum MediaCacheKind { original, thumb }

/// Content-addressed local cache for store-fetched media (spec section 10).
/// Files live under [root]; bookkeeping lives in media_cache_entries.
/// Two pools with independent caps so bulk original downloads can never
/// evict the thumbnails that keep grids rendering.
class MediaCacheStore {
  MediaCacheStore({
    required LocalCacheDatabase database,
    required Directory root,
    this.originalsCapBytes = 2 * 1024 * 1024 * 1024,
    this.thumbsCapBytes = 256 * 1024 * 1024,
  }) : _db = database,
       _root = root;

  final LocalCacheDatabase _db;
  final Directory _root;
  final int originalsCapBytes;
  final int thumbsCapBytes;

  String _kindName(MediaCacheKind kind) =>
      kind == MediaCacheKind.original ? 'original' : 'thumb';

  String _relativePath(String contentHash, MediaCacheKind kind) => p.join(
    kind == MediaCacheKind.original ? 'originals' : 'thumbs',
    contentHash.substring(0, 2),
    contentHash,
  );

  Future<File?> get(String contentHash, MediaCacheKind kind) async {
    final row =
        await (_db.select(_db.mediaCacheEntries)..where(
              (t) =>
                  t.contentHash.equals(contentHash) &
                  t.kind.equals(_kindName(kind)),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final file = File(p.join(_root.path, row.relativePath));
    if (!await file.exists()) {
      await _deleteEntry(contentHash, kind);
      return null;
    }
    await (_db.update(_db.mediaCacheEntries)..where(
          (t) =>
              t.contentHash.equals(contentHash) &
              t.kind.equals(_kindName(kind)),
        ))
        .write(
          MediaCacheEntriesCompanion(
            lastAccessedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    return file;
  }

  Future<File> put(
    String contentHash,
    MediaCacheKind kind,
    File source,
  ) async {
    final relative = _relativePath(contentHash, kind);
    final dest = File(p.join(_root.path, relative));
    await dest.parent.create(recursive: true);
    try {
      await source.rename(dest.path);
    } on FileSystemException {
      // Cross-device rename fallback.
      await source.copy(dest.path);
      await source.delete();
    }
    final size = await dest.length();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.mediaCacheEntries)
        .insertOnConflictUpdate(
          MediaCacheEntriesCompanion.insert(
            contentHash: contentHash,
            kind: _kindName(kind),
            relativePath: relative,
            sizeBytes: size,
            lastAccessedAt: now,
            createdAt: now,
          ),
        );
    await evictIfNeeded();
    return dest;
  }

  Future<File> stagingFile() async {
    final dir = Directory(p.join(_root.path, 'staging'));
    await dir.create(recursive: true);
    return File(
      p.join(
        dir.path,
        'stage_${DateTime.now().microsecondsSinceEpoch}_$hashCode',
      ),
    );
  }

  Future<int> totalBytes(MediaCacheKind kind) async {
    final sum = _db.mediaCacheEntries.sizeBytes.sum();
    final query = _db.selectOnly(_db.mediaCacheEntries)
      ..addColumns([sum])
      ..where(_db.mediaCacheEntries.kind.equals(_kindName(kind)));
    final row = await query.getSingle();
    return row.read(sum) ?? 0;
  }

  Future<void> evictIfNeeded() async {
    await _evictPool(MediaCacheKind.original, originalsCapBytes);
    await _evictPool(MediaCacheKind.thumb, thumbsCapBytes);
  }

  Future<void> _evictPool(MediaCacheKind kind, int capBytes) async {
    var total = await totalBytes(kind);
    if (total <= capBytes) return;
    final rows =
        await (_db.select(_db.mediaCacheEntries)
              ..where((t) => t.kind.equals(_kindName(kind)))
              ..orderBy([(t) => OrderingTerm.asc(t.lastAccessedAt)]))
            .get();
    for (final row in rows) {
      if (total <= capBytes) break;
      final file = File(p.join(_root.path, row.relativePath));
      if (await file.exists()) await file.delete();
      await _deleteEntry(row.contentHash, kind);
      total -= row.sizeBytes;
    }
  }

  Future<void> _deleteEntry(String contentHash, MediaCacheKind kind) async {
    await (_db.delete(_db.mediaCacheEntries)..where(
          (t) =>
              t.contentHash.equals(contentHash) &
              t.kind.equals(_kindName(kind)),
        ))
        .go();
  }
}
```

NOTE: as in Task 4, verify the generated companion/dataclass names in `local_cache_database.g.dart` (`MediaCacheEntriesCompanion`, row type) and adjust if Drift generated different names.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/media_store/media_cache_store_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): content-addressed cache with LRU eviction"
```

---

### Task 10: Upload pipeline + worker + enqueue-on-attach

**Files:**
- Create: `lib/features/media_store/data/media_upload_pipeline.dart`
- Create: `lib/features/media_store/data/media_store_worker.dart`
- Modify: `lib/features/media/data/services/media_import_service.dart` (constructor + after each `createMedia` call)
- Modify: `lib/features/media/presentation/providers/photo_picker_providers.dart:239` (`MediaImportService(` construction)
- Test: `test/features/media_store/media_upload_pipeline_test.dart`

**Interfaces:**
- Consumes: `MediaRepository.getMediaById/stampContentIdentity/stampRemoteUploaded` (Task 3), `MediaTransferQueueRepository` (Task 4), `StoreKeys`/`sha256OfFile` (Task 5), `MediaObjectStore` (Task 6), `MediaSourceResolverRegistry` + `MediaSourceData` variants, `MediaCacheStore.stagingFile()` (Task 9).
- Produces:
```dart
enum UploadOutcome { uploaded, deduplicated, skippedIneligible, failed }

class MediaUploadPipeline {
  MediaUploadPipeline({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
    required MediaObjectStore store,
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
    DateTime Function()? now,
  });
  Future<UploadOutcome> process(MediaTransferQueueEntry entry);
}

class MediaStoreWorker {
  MediaStoreWorker({
    required MediaTransferQueueRepository queue,
    required MediaUploadPipeline pipeline,
    Future<bool> Function()? preflight, // false suspends the drain (marker mismatch, Task 12)
  });
  Future<void> drain(); // single-flight; processes until nextPending is null
  Future<void> enqueueAndKick(String mediaId);
}
```
- `MediaImportService` gains an optional constructor parameter `void Function(String mediaId)? onMediaCreated`, invoked after every successful `createMedia` (both `importLocalFileForDive` and `importPhotosForDive`).

Eligibility (spec section 9): `sourceType` is `platformGallery` or `localFile`, `mediaType != instructorSignature`, and the registry resolver's `canResolveOnThisDevice(item)` is true. Already-confirmed rows (`remoteUploadedAt != null`) mark done immediately.

- [ ] **Step 1: Write the failing pipeline test**

Create `test/features/media_store/media_upload_pipeline_test.dart`. Setup mirrors the media repository test from Task 3 (in-memory `AppDatabase` + repository) plus in-memory `LocalCacheDatabase`, `InMemoryMediaObjectStore`, a temp-dir `MediaCacheStore`, and a stub registry whose `localFile` resolver returns `FileData` pointing at a real temp file. Registry stub: construct a real `MediaSourceResolverRegistry` with a single fake resolver class implementing `MediaSourceResolver` for `MediaSourceType.localFile` (`canResolveOnThisDevice` true, `resolve` returns `FileData(file: fixture)`, `extractMetadata` null, `verify` per interface — copy minimal overrides from `LocalFileResolver`'s signatures).

Test cases (write all five):

```dart
    test('happy path uploads bytes at the content key and stamps the row',
        () async {
      final id = await enqueueLocalFileItem(bytes: [1, 2, 3], name: 'a.jpg');
      final entry = (await queue.nextPending(DateTime.now()))!;
      final outcome = await pipeline.process(entry);
      expect(outcome, UploadOutcome.uploaded);

      final item = (await mediaRepository.getMediaById(id))!;
      expect(item.contentHash, isNotNull);
      expect(item.contentSizeBytes, 3);
      expect(item.remoteUploadedAt, isNotNull);
      final key =
          'smv1/objects/${item.contentHash!.substring(0, 2)}/'
          '${item.contentHash}.jpg';
      expect(fakeStore.objects[key], [1, 2, 3]);
      expect((await queue.allForTesting()).single.state, 'done');
    });

    test('dedup: existing object skips the put but still confirms', () async {
      // Pre-populate the store at the content key of the same bytes.
      // Process; expect UploadOutcome.deduplicated, no duplicate write,
      // remoteUploadedAt stamped.
    });

    test('crash replay: re-processing a done-stamped row is a no-op dedup',
        () async {
      // Process once, force-enqueue a second row for the same media, process:
      // expect deduplicated and exactly one object in the store.
    });

    test('unavailable source marks failed with retry scheduling', () async {
      // localFile resolver returns UnavailableData -> outcome failed,
      // queue row attempts == 1, state pending with nextAttemptAt set.
    });

    test('signature rows are ineligible and complete without store writes',
        () async {
      // mediaType instructorSignature -> skippedIneligible, store empty.
    });
```

Fill each skeleton with real assertions following the first test's style — every commented expectation above becomes an `expect(...)`.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/media_store/media_upload_pipeline_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the pipeline**

Create `lib/features/media_store/data/media_upload_pipeline.dart`:

```dart
import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

enum UploadOutcome { uploaded, deduplicated, skippedIneligible, failed }

/// The six-step upload pipeline (spec section 9), photos + single-shot in
/// Phase 1. Every step is idempotent: a crash mid-item replays harmlessly
/// because the content key is derived from the bytes and the head() dedup
/// check short-circuits completed work.
class MediaUploadPipeline {
  MediaUploadPipeline({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
    required MediaObjectStore store,
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
    DateTime Function()? now,
  }) : _mediaRepository = mediaRepository,
       _queue = queue,
       _store = store,
       _registry = registry,
       _cache = cache,
       _now = now ?? DateTime.now;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository _queue;
  final MediaObjectStore _store;
  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(MediaUploadPipeline);

  static const Set<MediaSourceType> _eligibleSources = {
    MediaSourceType.platformGallery,
    MediaSourceType.localFile,
  };

  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    await _queue.markTransferring(entry.id);
    final item = await _mediaRepository.getMediaById(entry.mediaId);
    if (item == null || !_isEligible(item)) {
      await _queue.markDone(entry.id);
      return UploadOutcome.skippedIneligible;
    }
    if (item.remoteUploadedAt != null) {
      await _queue.markDone(entry.id);
      return UploadOutcome.deduplicated;
    }

    File? staged;
    try {
      staged = await _materialize(item);
      if (staged == null) {
        await _queue.markFailed(entry.id, 'source unavailable on this device');
        return UploadOutcome.failed;
      }

      final digest = await sha256OfFile(staged);
      if (item.contentHash != digest.hash) {
        await _mediaRepository.stampContentIdentity(
          item.id,
          contentHash: digest.hash,
          sizeBytes: digest.sizeBytes,
        );
      }

      final extension = StoreKeys.extensionFor(item.originalFilename);
      final key = StoreKeys.objectKey(digest.hash, extension: extension);
      final existing = await _store.head(key);
      if (existing == null) {
        await _store.putFile(
          key,
          staged,
          contentType: StoreKeys.contentTypeFor(extension),
        );
      }

      await _mediaRepository.stampRemoteUploaded(item.id, uploadedAt: _now());
      await _queue.markDone(entry.id);
      return existing == null
          ? UploadOutcome.uploaded
          : UploadOutcome.deduplicated;
    } on Exception catch (e, stackTrace) {
      _log.error(
        'Upload failed for media ${entry.mediaId}',
        error: e,
        stackTrace: stackTrace,
      );
      await _queue.markFailed(entry.id, e.toString());
      return UploadOutcome.failed;
    } finally {
      if (staged != null && await staged.exists()) {
        await staged.delete();
      }
    }
  }

  bool _isEligible(MediaItem item) {
    if (!_eligibleSources.contains(item.sourceType)) return false;
    if (item.mediaType == MediaType.instructorSignature) return false;
    final resolver = _registry.resolverFor(item.sourceType);
    return resolver.canResolveOnThisDevice(item);
  }

  /// Resolves the item's bytes to a private temp file the pipeline owns.
  Future<File?> _materialize(MediaItem item) async {
    final resolver = _registry.resolverFor(item.sourceType);
    final data = await resolver.resolve(item);
    switch (data) {
      case FileData(file: final f):
        final staged = await _cache.stagingFile();
        await f.copy(staged.path);
        return staged;
      case BytesData(bytes: final b):
        final staged = await _cache.stagingFile();
        await staged.writeAsBytes(b, flush: true);
        return staged;
      case NetworkData():
      case UnavailableData():
        return null;
    }
  }
}
```

- [ ] **Step 4: Implement the worker and the import hook**

Create `lib/features/media_store/data/media_store_worker.dart`:

```dart
import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';

/// Sequential single-flight queue drainer (Phase 1). Phase 2 adds
/// lifecycle/connectivity triggers; Phase 3 adds parallelism and progress.
class MediaStoreWorker {
  MediaStoreWorker({
    required MediaTransferQueueRepository queue,
    required MediaUploadPipeline pipeline,
    Future<bool> Function()? preflight,
  }) : _queue = queue,
       _pipeline = pipeline,
       _preflight = preflight;

  final MediaTransferQueueRepository _queue;
  final MediaUploadPipeline _pipeline;
  final Future<bool> Function()? _preflight;
  final _log = LoggerService.forClass(MediaStoreWorker);
  bool _running = false;

  Future<void> drain() async {
    if (_running) return;
    _running = true;
    try {
      if (_preflight != null && !await _preflight()) {
        _log.warning('Media store preflight failed; drain suspended');
        return;
      }
      while (true) {
        final entry = await _queue.nextPending(DateTime.now());
        if (entry == null) break;
        await _pipeline.process(entry);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> enqueueAndKick(String mediaId) async {
    await _queue.enqueueUpload(mediaId: mediaId);
    unawaited(drain());
  }
}
```

In `media_import_service.dart`: add the field/parameter and call sites:

```dart
  // Constructor gains:
  //   this.onMediaCreated,
  // and the field:
  /// Invoked after every successful createMedia so the media store can
  /// enqueue an upload. Null when no store is configured.
  final void Function(String mediaId)? onMediaCreated;
```
Call `onMediaCreated?.call(saved.id);` immediately after `imported.add(saved);` in `importPhotosForDive`, and after `final created = await _mediaRepository.createMedia(item);` in `importLocalFileForDive` (capture the return into a local before returning: `final created = await _mediaRepository.createMedia(item); onMediaCreated?.call(created.id); return created;`).

In `photo_picker_providers.dart:239`, pass the callback. The enqueue function provider comes from Task 12's providers file; to keep this task self-contained and compiling, add the provider now in a new file `lib/features/media_store/presentation/providers/media_store_enqueue_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bridge consumed by MediaImportService construction. Rebound by
/// media_store_providers.dart (Task 12) once a store runtime exists;
/// default no-op keeps import flows working with no store configured.
final mediaStoreEnqueueProvider = Provider<void Function(String mediaId)>(
  (ref) => (_) {},
);
```
and at the construction site: `onMediaCreated: ref.watch(mediaStoreEnqueueProvider),`.

- [ ] **Step 5: Run to verify it passes**

```bash
flutter test test/features/media_store/media_upload_pipeline_test.dart
flutter test test/features/media/  # import service consumers still compile/pass
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): upload pipeline, worker, enqueue-on-attach"
```

---

### Task 11: MediaStoreResolver + MediaItemView fallback

**Files:**
- Create: `lib/features/media/data/resolvers/media_store_resolver.dart`
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart` (`_resolve()` at line 79)
- Create: `lib/features/media_store/presentation/providers/media_store_providers.dart`
- Test: `test/features/media/data/media_store_resolver_test.dart`
- Test: `test/features/media/presentation/media_item_view_store_fallback_test.dart`

**Interfaces:**
- Consumes: Tasks 5, 6, 9 types; `MediaItem.contentHash/remoteUploadedAt` (Task 3); `MediaSourceData` variants.
- Produces:
```dart
class MediaStoreResolver {
  MediaStoreResolver({required MediaObjectStore store, required MediaCacheStore cache});
  /// Returns FileData when the bytes exist locally-cached or are fetched
  /// and hash-verified from the store; null when this item is not in the
  /// store, no confirmation stamp exists, or any error occurs (the caller
  /// keeps its native UnavailableData).
  Future<MediaSourceData?> tryResolveRemote(MediaItem item, {required bool thumbnail});
}

class MediaStoreRuntime {
  final String storeId;
  final MediaObjectStore store;
  final MediaCacheStore cache;
  final MediaStoreResolver resolver;
  final MediaStoreWorker worker;
}

// media_store_providers.dart
final mediaStoreRuntimeProvider = FutureProvider<MediaStoreRuntime?>(...);
// Lazily loads MediaStoreCredentialsStore; null when unconfigured. On
// success builds S3ApiClient -> S3MediaObjectStore -> cache -> resolver ->
// worker, verifies marker vs MediaStoreAttachState (preflight), rebinds
// mediaStoreEnqueueProvider via override in Task 12, kicks worker.drain().
```
NOTE: `MediaStoreResolver` deliberately does NOT implement `MediaSourceResolver` and is NOT registered in the registry — rows keep their native source type; the view invokes it as a fallback (spec section 10).

- [ ] **Step 1: Write the failing resolver test**

Create `test/features/media/data/media_store_resolver_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../helpers/in_memory_media_object_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('msr_test');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
    resolver = MediaStoreResolver(store: store, cache: cache);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem item({String? hash, DateTime? uploadedAt}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'gone-from-this-device',
    originalFilename: 'reef.jpg',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
  );

  test('returns null without a confirmation stamp', () async {
    expect(
      await resolver.tryResolveRemote(item(hash: 'a' * 64), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveRemote(
        item(uploadedAt: DateTime(2026)),
        thumbnail: false,
      ),
      isNull,
    );
  });

  test('downloads, hash-verifies, caches, and returns FileData', () async {
    final bytes = 'submersion'.codeUnits;
    // Real hash of the bytes so verification passes; compute via
    // sha256OfFile on a temp file.
    final tmp = File('${root.path}/seed');
    await tmp.writeAsBytes(bytes, flush: true);
    final digest = await sha256OfFile(tmp);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = bytes;

    final data = await resolver.tryResolveRemote(
      item(hash: digest.hash, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(data, isA<FileData>());
    expect(
      await (data! as FileData).file.readAsBytes(),
      bytes,
    );

    // Second resolve is a pure cache hit even with an empty store.
    store.objects.clear();
    final again = await resolver.tryResolveRemote(
      item(hash: digest.hash, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(again, isA<FileData>());
  });

  test('hash mismatch is rejected and not cached', () async {
    final wrongHash = 'f' * 64;
    store.objects[StoreKeys.objectKey(wrongHash, extension: 'jpg')] =
        'tampered'.codeUnits;
    final data = await resolver.tryResolveRemote(
      item(hash: wrongHash, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(data, isNull);
    expect(await cache.get(wrongHash, MediaCacheKind.original), isNull);
  });

  test('store errors degrade to null', () async {
    store.failNextWith = Exception('boom');
    final data = await resolver.tryResolveRemote(
      item(hash: 'a' * 64, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(data, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/media/data/media_store_resolver_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the resolver**

Create `lib/features/media/data/resolvers/media_store_resolver.dart`:

```dart
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Store-backed fallback resolution (spec section 10). Deliberately NOT a
/// MediaSourceResolver and never registered under a MediaSourceType: rows
/// keep their native source type, so disconnecting the store degrades every
/// row to exactly the pre-store behavior.
class MediaStoreResolver {
  MediaStoreResolver({
    required MediaObjectStore store,
    required MediaCacheStore cache,
  }) : _store = store,
       _cache = cache;

  final MediaObjectStore _store;
  final MediaCacheStore _cache;
  final _log = LoggerService.forClass(MediaStoreResolver);

  /// Phase 1 ignores [thumbnail] (no thumb objects yet); full originals
  /// serve both roles. Phase 2 routes thumbnail requests to thumb keys.
  Future<MediaSourceData?> tryResolveRemote(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    final hash = item.contentHash;
    if (hash == null || item.remoteUploadedAt == null) return null;
    try {
      final cached = await _cache.get(hash, MediaCacheKind.original);
      if (cached != null) return FileData(file: cached);

      final staging = await _cache.stagingFile();
      final extension = StoreKeys.extensionFor(item.originalFilename);
      await _store.getFile(
        StoreKeys.objectKey(hash, extension: extension),
        staging,
      );
      final digest = await sha256OfFile(staging);
      if (digest.hash != hash) {
        _log.warning('Store object failed hash verification for ${item.id}');
        await staging.delete();
        return null;
      }
      final file = await _cache.put(hash, MediaCacheKind.original, staging);
      return FileData(file: file);
    } on Exception catch (e) {
      _log.warning('Store fallback failed for ${item.id}: $e');
      return null;
    }
  }
}
```

- [ ] **Step 4: Wire the view fallback and the runtime provider**

(a) Create `lib/features/media_store/presentation/providers/media_store_providers.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';

class MediaStoreRuntime {
  final String storeId;
  final MediaObjectStore store;
  final MediaCacheStore cache;
  final MediaStoreResolver resolver;
  final MediaStoreWorker worker;

  const MediaStoreRuntime({
    required this.storeId,
    required this.store,
    required this.cache,
    required this.resolver,
    required this.worker,
  });
}

final mediaStoreCredentialsStoreProvider =
    Provider<MediaStoreCredentialsStore>(
      (ref) => MediaStoreCredentialsStore(),
    );

final mediaStoreAttachStateProvider = Provider<MediaStoreAttachState>(
  (ref) => MediaStoreAttachState(),
);

/// The configured media store runtime, or null when this device has no
/// store attached. Lazy: first watcher (a media view or the settings page)
/// triggers construction and a queue drain. Invalidate after connect or
/// disconnect (Task 12).
final mediaStoreRuntimeProvider = FutureProvider<MediaStoreRuntime?>((
  ref,
) async {
  final config = await ref.watch(mediaStoreCredentialsStoreProvider).load();
  if (config == null) return null;
  final attachedId = await ref
      .watch(mediaStoreAttachStateProvider)
      .attachedStoreId();
  if (attachedId == null) return null;

  final client = S3ApiClient(config);
  ref.onDispose(client.close);
  final store = S3MediaObjectStore(client: client, keyPrefix: config.prefix);

  final supportDir = await getApplicationSupportDirectory();
  final cache = MediaCacheStore(
    database: LocalCacheDatabaseService.instance.database,
    root: Directory(p.join(supportDir.path, 'Submersion', 'media_cache')),
  );
  final resolver = MediaStoreResolver(store: store, cache: cache);

  final pipeline = MediaUploadPipeline(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    queue: MediaTransferQueueRepository(),
    store: store,
    registry: ref.watch(mediaSourceResolverRegistryProvider),
    cache: cache,
  );
  final worker = MediaStoreWorker(
    queue: MediaTransferQueueRepository(),
    pipeline: pipeline,
    preflight: () async {
      final marker = await StoreMarkerStore(store: store).read();
      return marker != null && marker.storeId == attachedId;
    },
  );
  unawaited(worker.drain());

  return MediaStoreRuntime(
    storeId: attachedId,
    store: store,
    cache: cache,
    resolver: resolver,
    worker: worker,
  );
});
```
Check the actual provider names for the media repository and registry (`mediaRepositoryProvider` in `media_providers.dart`, `mediaSourceResolverRegistryProvider` in `media_resolver_providers.dart`) — both verified to exist.

Also rebind the Task 10 enqueue bridge in the same file:

```dart
/// Rebinds mediaStoreEnqueueProvider: when a runtime exists, imports feed
/// the queue and kick the worker.
final mediaStoreEnqueueImplProvider = Provider<void Function(String)>((ref) {
  return (mediaId) {
    unawaited(() async {
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      await runtime?.worker.enqueueAndKick(mediaId);
    }());
  };
});
```
and change `mediaStoreEnqueueProvider` in `media_store_enqueue_provider.dart` to delegate:
```dart
final mediaStoreEnqueueProvider = Provider<void Function(String mediaId)>(
  (ref) => ref.watch(mediaStoreEnqueueImplProvider),
);
```
(moving `mediaStoreEnqueueImplProvider` above it or merging the two files into `media_store_providers.dart` is fine — keep one exported name `mediaStoreEnqueueProvider` used by `photo_picker_providers.dart`).

(b) Modify `media_item_view.dart` `_resolve()` (line 79) to:

```dart
  Future<MediaSourceData> _resolve() async {
    final registry = ref.read(mediaSourceResolverRegistryProvider);
    final resolver = registry.resolverFor(widget.item.sourceType);
    final native = widget.thumbnail && widget.targetSize != null
        ? await resolver.resolveThumbnail(
            widget.item,
            target: widget.targetSize!,
          )
        : await resolver.resolve(widget.item);
    if (native is! UnavailableData) return native;
    // Media store fallback (spec section 10): only engages when the native
    // source cannot produce bytes on this device and the row is confirmed
    // uploaded.
    try {
      final runtime = await ref.read(mediaStoreRuntimeProvider.future);
      final remote = await runtime?.resolver.tryResolveRemote(
        widget.item,
        thumbnail: widget.thumbnail,
      );
      return remote ?? native;
    } catch (_) {
      return native;
    }
  }
```
Add the import for `media_store_providers.dart`.

- [ ] **Step 5: Write and pass the widget test**

Create `test/features/media/presentation/media_item_view_store_fallback_test.dart`: pump `MediaItemView` inside a `ProviderScope` with `mediaStoreRuntimeProvider` overridden (`overrideWith((ref) async => runtime)` built from the in-memory store + temp cache as in the resolver test) for a `platformGallery` item whose asset cannot resolve (the real `PlatformGalleryResolver` will return `UnavailableData` for an unknown asset id — if constructing it requires services, instead override `mediaSourceResolverRegistryProvider` with a registry whose gallery resolver is a fake returning `UnavailableData(kind: UnavailableKind.fromOtherDevice)`). Assert: with store bytes present, the tree eventually contains an `Image` widget and no `UnavailableMediaPlaceholder`; with `mediaStoreRuntimeProvider` overridden to null, the placeholder renders. Remember the drift/fakeAsync trap: wrap post-pump awaits in `tester.runAsync(...)` and use `pumpAndSettle` only after the future completes.

```bash
flutter test test/features/media/data/media_store_resolver_test.dart
flutter test test/features/media/presentation/media_item_view_store_fallback_test.dart
```
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): store fallback resolution in MediaItemView"
```

---

### Task 12: MediaStoreService + Media Storage settings page + l10n + route

**Files:**
- Create: `lib/features/media_store/data/media_store_service.dart`
- Create: `lib/features/media_store/presentation/pages/media_storage_page.dart`
- Create: `lib/features/media_store/data/media_stores_repository.dart`
- Modify: `lib/core/router/app_router.dart` (settings routes, sibling of `cloud-sync` at ~line 894)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (tile next to the Cloud Sync tile — locate with `grep -n "cloud-sync" lib/features/settings/presentation/pages/settings_page.dart`)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/media_store/media_store_service_test.dart`
- Test: `test/features/media_store/media_storage_page_test.dart`

**Interfaces:**
- Consumes: Tasks 7, 8 types; `S3Config` + `S3Config.validate()` + `displayHost`; `AppDatabase`/`_db.mediaStores`; `SyncRepository.markRecordPending` + `SyncEventBus` (same pattern as media_repository.dart:146-151).
- Produces:
```dart
class MediaStoresRepository {
  MediaStoresRepository({AppDatabase? database, SyncRepository? syncRepository});
  Future<void> upsertActive({required String storeId, required String providerType, required String displayHint});
  Future<({String id, String providerType, String displayHint})?> getActive(); // highest-hlc/updatedAt row
}

class MediaStoreConnectResult {
  final String storeId;
  final bool createdNewStore;
}

class MediaStoreService {
  MediaStoreService({
    required MediaStoreCredentialsStore credentials,
    required MediaStoreAttachState attachState,
    required MediaStoresRepository storesRepository,
    MediaObjectStore Function(S3Config config)? storeFactory, // test seam; default builds S3ApiClient + S3MediaObjectStore
  });
  Future<void> testConnection(S3Config config); // probe write/read/delete at 'smv1/.submersion-media-probe'; throws MediaStoreException on failure
  Future<MediaStoreConnectResult> connectS3(S3Config config); // ensure marker -> save credentials -> attach -> upsert descriptor
  Future<void> disconnect(); // clear credentials + attach state; descriptor row and bucket data remain
}
```

- [ ] **Step 1: Write the failing service test**

Create `test/features/media_store/media_store_service_test.dart` using the in-memory store via `storeFactory` and the Task 3 database setup for the repository:

```dart
    test('connectS3 creates the marker, attaches, and writes the descriptor',
        () async {
      final result = await service.connectS3(config);
      expect(result.createdNewStore, isTrue);
      expect(fakeStore.objects.containsKey('smv1/store.json'), isTrue);
      expect(await attachState.attachedStoreId(), result.storeId);
      final active = await storesRepository.getActive();
      expect(active!.providerType, 's3');
      expect(active.displayHint, contains(config.bucket));
      expect(await credentials.load(), isNotNull);
    });

    test('connectS3 against an existing store adopts its storeId', () async {
      final first = await service.connectS3(config);
      await service.disconnect();
      final second = await service.connectS3(config);
      expect(second.createdNewStore, isFalse);
      expect(second.storeId, first.storeId);
    });

    test('testConnection round-trips a probe object and cleans up', () async {
      await service.testConnection(config);
      expect(
        fakeStore.objects.keys.where((k) => k.contains('probe')),
        isEmpty,
      );
    });

    test('disconnect clears credentials and attach state', () async {
      await service.connectS3(config);
      await service.disconnect();
      expect(await credentials.load(), isNull);
      expect(await attachState.attachedStoreId(), isNull);
    });
```

- [ ] **Step 2: Run to verify it fails, then implement**

Run: `flutter test test/features/media_store/media_store_service_test.dart` -> FAIL to compile.

Implement `media_stores_repository.dart` (upsert via `insertOnConflictUpdate` on `_db.mediaStores` with `createdAt/updatedAt` now-ms, then `markRecordPending(entityType: 'mediaStores', recordId: storeId, localUpdatedAt: now)` + `SyncEventBus.notifyLocalChange()`; `getActive` = `SELECT ... ORDER BY updated_at DESC LIMIT 1` mapped to the record). Implement `media_store_service.dart`:

```dart
  Future<void> testConnection(S3Config config) async {
    final store = _storeFactory(config);
    const probeKey = 'smv1/.submersion-media-probe';
    final tmp = await _tempFile('probe');
    try {
      await tmp.writeAsString('probe', flush: true);
      await store.putFile(probeKey, tmp, contentType: 'text/plain');
      final info = await store.head(probeKey);
      if (info == null) {
        throw const MediaStoreException(
          'Probe object vanished after write',
          kind: MediaStoreErrorKind.fatal,
        );
      }
    } finally {
      try {
        await store.delete(probeKey);
      } on MediaStoreException {
        // Best-effort cleanup; the probe object is harmless if it stays.
      }
      if (await tmp.exists()) await tmp.delete();
    }
  }

  Future<MediaStoreConnectResult> connectS3(S3Config config) async {
    final error = config.validate();
    if (error != null) {
      throw MediaStoreException(error, kind: MediaStoreErrorKind.fatal);
    }
    final store = _storeFactory(config);
    final ensured = await StoreMarkerStore(store: store).ensure();
    await _credentials.save(config);
    await _attachState.setAttached(ensured.marker.storeId);
    await _storesRepository.upsertActive(
      storeId: ensured.marker.storeId,
      providerType: 's3',
      displayHint: '${config.bucket} @ ${config.displayHost}',
    );
    return MediaStoreConnectResult(
      storeId: ensured.marker.storeId,
      createdNewStore: ensured.created,
    );
  }

  Future<void> disconnect() async {
    await _credentials.clear();
    await _attachState.clear();
  }
```
(default `_storeFactory`: `(config) { final client = S3ApiClient(config); return S3MediaObjectStore(client: client, keyPrefix: config.prefix); }`; `_tempFile` mirrors the marker store's temp-file helper.)

Run the test again -> PASS.

- [ ] **Step 3: Build the settings page + l10n + route**

(a) Add l10n keys to `lib/l10n/arb/app_en.arb` (and translations to the other 10 — see table below):

```json
  "mediaStorageTitle": "Media Storage",
  "mediaStorageSubtitle": "Store photo and video originals in your own cloud storage",
  "mediaStorageNotConfigured": "No media store connected on this device",
  "mediaStorageConnectedTo": "Connected to {hint}",
  "@mediaStorageConnectedTo": {
    "placeholders": {
      "hint": {
        "type": "String"
      }
    }
  },
  "mediaStorageTestConnection": "Test Connection",
  "mediaStorageTestSuccess": "Connection successful",
  "mediaStorageConnect": "Connect",
  "mediaStorageDisconnect": "Disconnect",
  "mediaStorageDisconnectWarning": "This device stops uploading and fetching media. Nothing in your bucket is deleted.",
```

Translation table (use exactly these values; keep `{hint}` placeholders verbatim):

| key | de | es | fr | it | nl | pt | hu | zh | ar | he |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| mediaStorageTitle | Medienspeicher | Almacenamiento de medios | Stockage des médias | Archiviazione media | Mediaopslag | Armazenamento de mídia | Médiatárhely | 媒体存储 | تخزين الوسائط | אחסון מדיה |
| mediaStorageSubtitle | Foto- und Video-Originale im eigenen Cloud-Speicher ablegen | Guarda los originales de fotos y videos en tu propio almacenamiento en la nube | Stockez les originaux photo et vidéo dans votre propre espace cloud | Conserva gli originali di foto e video nel tuo cloud personale | Bewaar originele foto's en video's in je eigen cloudopslag | Guarde os originais de fotos e vídeos no seu próprio armazenamento em nuvem | Fotó- és videóeredetik tárolása saját felhőtárhelyen | 将照片和视频原件存储在您自己的云存储中 | خزّن النسخ الأصلية للصور والفيديو في التخزين السحابي الخاص بك | שמור מקורות של תמונות ווידאו באחסון הענן שלך |
| mediaStorageNotConfigured | Kein Medienspeicher mit diesem Gerät verbunden | No hay un almacén de medios conectado en este dispositivo | Aucun stockage de médias connecté sur cet appareil | Nessun archivio media collegato su questo dispositivo | Geen mediaopslag verbonden op dit apparaat | Nenhum armazenamento de mídia conectado neste dispositivo | Nincs médiatár csatlakoztatva ezen az eszközön | 此设备未连接媒体存储 | لا يوجد مخزن وسائط متصل على هذا الجهاز | לא מחובר אחסון מדיה במכשיר זה |
| mediaStorageConnectedTo | Verbunden mit {hint} | Conectado a {hint} | Connecté à {hint} | Collegato a {hint} | Verbonden met {hint} | Conectado a {hint} | Csatlakoztatva: {hint} | 已连接到 {hint} | متصل بـ {hint} | מחובר אל {hint} |
| mediaStorageTestConnection | Verbindung testen | Probar conexión | Tester la connexion | Prova connessione | Verbinding testen | Testar conexão | Kapcsolat tesztelése | 测试连接 | اختبار الاتصال | בדיקת חיבור |
| mediaStorageTestSuccess | Verbindung erfolgreich | Conexión correcta | Connexion réussie | Connessione riuscita | Verbinding geslaagd | Conexão bem-sucedida | Sikeres kapcsolat | 连接成功 | نجح الاتصال | החיבור הצליח |
| mediaStorageConnect | Verbinden | Conectar | Connecter | Collega | Verbinden | Conectar | Csatlakozás | 连接 | اتصال | התחבר |
| mediaStorageDisconnect | Trennen | Desconectar | Déconnecter | Disconnetti | Loskoppelen | Desconectar | Leválasztás | 断开连接 | قطع الاتصال | התנתק |
| mediaStorageDisconnectWarning | Dieses Gerät lädt keine Medien mehr hoch oder herunter. In Ihrem Bucket wird nichts gelöscht. | Este dispositivo deja de subir y descargar medios. No se elimina nada de tu bucket. | Cet appareil cesse d'envoyer et de récupérer des médias. Rien n'est supprimé de votre bucket. | Questo dispositivo smette di caricare e scaricare i media. Nulla viene eliminato dal tuo bucket. | Dit apparaat stopt met het uploaden en ophalen van media. Er wordt niets uit je bucket verwijderd. | Este dispositivo deixa de enviar e buscar mídia. Nada é excluído do seu bucket. | Az eszköz nem tölt fel és nem tölt le több médiát. A bucketből semmi sem törlődik. | 此设备将停止上传和获取媒体。您的存储桶中的内容不会被删除。 | يتوقف هذا الجهاز عن رفع الوسائط وجلبها. لن يُحذف أي شيء من الحاوية الخاصة بك. | מכשיר זה יפסיק להעלות ולהוריד מדיה. שום דבר לא יימחק מהדלי שלך. |

For the S3 form field labels, reuse whatever the existing `S3ConfigPage` renders — open `lib/features/settings/presentation/pages/s3_config_page.dart`, find the widgets for endpoint/bucket/access key/secret key/region/prefix labels, and use the same `l10n` getters it uses (they already exist in all locales). Run `flutter gen-l10n` after editing the arb files.

(b) Create `media_storage_page.dart`: a `ConsumerStatefulWidget` structured like `S3ConfigPage` (same controllers/validators/obscure-secret toggle/insecure-http warning), but:
- persistence goes through `MediaStoreService` (`testConnection` / `connectS3` / `disconnect`), never the sync stores;
- default prefix field value `submersion-media/`;
- top status card: `mediaStorageNotConfigured` or `mediaStorageConnectedTo(displayHint)` from `mediaStoreRuntimeProvider`/`MediaStoresRepository.getActive()`;
- after connect or disconnect: `ref.invalidate(mediaStoreRuntimeProvider);`
- a "Copy from Sync" `TextButton` shown when `S3CredentialsStore().load()` returns a config; tapping prefills all fields except the prefix (which stays `submersion-media/`).
Reuse `S3ConfigPage`'s form code as the template — copy its structure, replace persistence and strings; do NOT modify `s3_config_page.dart` itself.

(c) Route in `app_router.dart` — next to the `cloud-sync` route (~line 894), same nesting level:

```dart
              GoRoute(
                path: 'media-storage',
                name: 'media-storage',
                builder: (context, state) => const MediaStoragePage(),
              ),
```
(match the exact shape of the `cloud-sync` GoRoute — include `name:` only if the siblings have it). Settings tile in `settings_page.dart`: duplicate the Cloud Sync `ListTile`/row widget, with `Icons.perm_media_outlined`, title `l10n.mediaStorageTitle`, subtitle `l10n.mediaStorageSubtitle`, `onTap: () => context.push('/settings/media-storage')` (confirm the exact push prefix from the Cloud Sync tile).

- [ ] **Step 4: Widget test**

Create `test/features/media_store/media_storage_page_test.dart`: pump `MediaStoragePage` with provider overrides (`mediaStoreRuntimeProvider` -> null). Assert the not-configured status renders, the connect button exists, and entering an invalid config (empty bucket) surfaces the validator message rather than calling the service (inject a fake `MediaStoreService` via its provider and assert no calls). Check `test/helpers/test_app.dart` and `l10n_test_helpers.dart` for the standard localized pump harness; remember FormSection gotchas (labels may render uppercased; `ensureVisible` before tapping buttons low on the form).

Run: `flutter test test/features/media_store/media_storage_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A
git commit -m "feat(media-store): connect flow, media storage settings page"
```

---

### Task 13: End-to-end round trip + Phase 1 exit verification

**Files:**
- Test: `test/features/media_store/media_store_end_to_end_test.dart`
- Modify (if needed): fixes only.

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write the end-to-end test**

Create `test/features/media_store/media_store_end_to_end_test.dart` — one `InMemoryMediaObjectStore` shared across a simulated device A (repository + queue + pipeline) and device B (fresh `LocalCacheDatabase`, fresh temp cache root, `MediaStoreResolver`):

```dart
    test('device A uploads on attach; device B resolves via the store',
        () async {
      // Device A: create a localFile media row pointing at a real temp file,
      // enqueue, drain.
      final photo = File('${tmpA.path}/reef.jpg')
        ..writeAsBytesSync(List<int>.generate(2048, (i) => (i * 7) % 251));
      final created = await mediaRepositoryA.createMedia(/* localFile item */);
      await workerA.enqueueAndKick(created.id);
      await workerA.drain();

      final uploaded = (await mediaRepositoryA.getMediaById(created.id))!;
      expect(uploaded.remoteUploadedAt, isNotNull);

      // "Sync" the row to device B: in this test, device B just receives the
      // same MediaItem values (that is exactly what sync ships).
      final onB = uploaded.copyWith(platformAssetId: null, localPath: null);

      // Device B: native resolution is impossible; the store fallback must
      // produce the identical bytes.
      final data = await resolverB.tryResolveRemote(onB, thumbnail: false);
      expect(data, isA<FileData>());
      expect(
        await (data! as FileData).file.readAsBytes(),
        await photo.readAsBytes(),
      );
    });

    test('marker mismatch suspends the drain', () async {
      // Attach state says 'store-x' but the marker in the store says
      // otherwise: worker preflight returns false; queue rows stay pending.
    });
```
Fill the second test with real assertions (enqueue one row, run `drain()` with a preflight comparing against a wrong storeId, assert the row is still `pending`).

- [ ] **Step 2: Run the full media-store test set**

```bash
flutter test test/core/services/media_store/ test/features/media_store/ \
  test/features/media/data/media_store_resolver_test.dart \
  test/features/media/data/media_repository_store_stamps_test.dart \
  test/features/media/presentation/media_item_view_store_fallback_test.dart \
  test/core/database/migration_v103_media_store_test.dart \
  test/core/services/sync/sync_media_stores_test.dart
```
Expected: all PASS.

- [ ] **Step 3: Regression sweep of adjacent suites**

```bash
flutter test test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_buddy_roles_test.dart
flutter test test/features/media/
flutter test test/core/database/migration_v99_buddy_roles_test.dart
```
Expected: all PASS.

- [ ] **Step 4: Whole-project gates**

```bash
dart format .
flutter analyze
```
Expected: no formatting changes pending, `No issues found!`.

- [ ] **Step 5: Manual MinIO smoke checklist (document results in the commit message body is NOT needed; verify and report)**

```bash
docker run --rm -d --name submersion-minio -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=submersion -e MINIO_ROOT_PASSWORD=submersion-secret \
  quay.io/minio/minio server /data --console-address ":9001"
docker exec submersion-minio mc alias set local http://localhost:9000 submersion submersion-secret
docker exec submersion-minio mc mb local/dive-media
```
Then `flutter run -d macos`: Settings -> Media Storage -> endpoint `http://localhost:9000`, bucket `dive-media`, keys as above -> Test Connection -> Connect; attach a photo to a dive; verify `docker exec submersion-minio mc ls -r local/dive-media` shows `submersion-media/smv1/store.json` and one object under `smv1/objects/`. This step requires the user's machine/Docker; if Docker is unavailable, note it and rely on the automated suite.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat(media-store): phase 1 end-to-end coverage"
```

---

## Phase 1 exit criteria (from the design spec, section 17)

- [ ] v103 migration + `media_stores` sync registration shipped and tested
- [ ] `MediaObjectStore` + S3 single-shot adapter with contract coverage
- [ ] Transfer queue with retry/backoff; upload-on-attach for photos
- [ ] `MediaStoreResolver` + content-addressed cache with LRU eviction
- [ ] `store.json` written on connect, checked before every drain
- [ ] A photo attached on device A displays on device B via S3 (automated fake-store proof + MinIO manual smoke)


