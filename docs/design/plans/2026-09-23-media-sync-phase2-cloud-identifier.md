# Media Sync Slice 8: PhotoKit Cloud Identifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A gallery photo linked on one Apple device resolves to the exact same photo on another device sharing its iCloud Photos library, even when metadata cannot tell candidates apart (a burst pair shot in the same second).

**Architecture:** A synced, nullable `media.cloud_asset_id` column (schema v226) carries PhotoKit's cloud identifier. It is stamped at link time and on a gallery relink, and back-filled once for this device's own older rows. `AssetResolutionService` maps the candidates it already fetches for the photo's time window to their cloud ids in one batch call, and a unique cloud id match wins before any metadata tier. When a sync hands this device a new cloud id or new upload facts for a row, that row's `unresolved` cache entry is deleted so the next view retries at once.

**Tech Stack:** Flutter, Dart, Drift over SQLite, `photo_manager` 3.12.0 (`PhotoManager.plugin.getCloudIdentifiers`), Riverpod, `flutter_test`, mockito, the two-device media harness.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 6.2. Sub-issue #2116 (reopened 2026-09-23), part of #2090. Closes #1937. Turns scenario S6 green.

## Global Constraints

- Owner decision (2026-09-23): schema rung **226**. Open PR #1978 holds 225. The ladder tolerates the gap (`migrationStepCount` counts entries, and no test demands contiguity).
- Owner decision (2026-09-23): `minimumCompatibleSchemaVersion` stays **224**. The column is new and nullable, which the floor rules at `database.dart` `minimumCompatibleSchemaVersion` explicitly exempt.
- Owner decision (2026-09-23): back-fill **this device's own** gallery rows, once, **after a successful sync**, with **full** photo access, never prompting. Same reasons as the slice 7 origin backfill: the column has no fact group, so a stamp bumps the row clock and republishes the row.
- Every background path that consults the photo library checks `supportsGalleryBrowsing` first (spec 9).
- A cloud id that is null **or empty** means "none known". An empty string is written deliberately by a gallery relink whose new asset has no cloud id, because the sync apply upserts with `nullToAbsent` and a null would never clear a stale id on a peer.
- Repository rules: no em-dashes anywhere; no mention of Claude, Claude Code or Anthropic in commits, PRs or comments; no emojis in code; `dart format .` before every commit; paths built with `p.join`, never a literal `/tmp`.

## Facts the design rests on

- `photo_manager` 3.12.0: `PhotoManager.plugin.getCloudIdentifiers(List<String> ids)` returns `Map<String, String?>` keyed by local id, backed by `PHPhotoLibrary.cloudIdentifierMappingsForLocalIdentifiers`. It returns `{}` without throwing on Android, desktop, iOS below 15 and macOS below 12. `AssetEntity.darwin.cloudIdentifier` is a one-id wrapper over the same call and **throws** off Apple platforms, so this plan uses the batch call everywhere (the spec names the per-entity getter; same data, one call per batch instead of per photo). There is no cloud-to-local lookup, so resolution maps candidates forward.
- `MediaImportService._createMediaItemFromAsset` is the only producer of new gallery rows (`importPhotosForDive`, `importPhotosForSite`). The repair flow's `MediaRepairService.apply` is the only relink (`candidate.isGallery` branch builds `RepairWrite(newPlatformAssetId: ..., newSourceType: platformGallery)`), committed by `MediaRepository.applyRepairWrites`.
- The media merge upserts rows with `nullToAbsent` (comment in `SyncService._mergeEntity` above `mergeFactGroups`), so a synced column travels with no serializer change, and an older peer that omits the key leaves the local value alone.
- `mergeFactGroups` returns `fromRemote`, the groups whose peer clock won. It includes `SyncFactGroups.mediaUpload` whenever the peer's upload facts are newer.
- `local_asset_cache` lives in `LocalCacheDatabase`, not `AppDatabase`, and is never synced. `resolutionMethod` is free text, so `'cloud_id'` needs no schema change. An `unresolved` entry has `localAssetId == null`.
- `MediaRepository.updateMedia` deliberately omits facts written by narrow stampers, so a snapshot write cannot roll them back. `cloudAssetId` joins that list: written by `createMedia`, `applyRepairWrites` and `stampCloudAssetIds` only.
- The two-device harness links gallery photos through `createMedia` directly and passes no width or height, so today S6's burst pair fails every metadata tier on device B. Only the cloud id tier can separate them.

## File Structure

- Modify `lib/core/database/database.dart`: column, v226 rung, helper, backstop, ladder entry, version constant.
- Create `test/core/database/migration_v226_media_cloud_asset_id_test.dart`; relax `test/core/database/migration_v224_media_fact_clocks_test.dart`.
- Modify `lib/features/media/domain/entities/media_item.dart`, `lib/features/media/data/repositories/media_row_mapper.dart`, `lib/features/media/data/repositories/media_repository.dart`: the field end to end.
- Create `lib/features/media/data/services/cloud_identifier_source.dart`: the seam and the photo_manager implementation.
- Modify `test/helpers/fake_photo_picker_service.dart`: `FakeGalleryAsset.cloudId`; the fake implements `CloudIdentifierSource`.
- Modify `lib/features/media/data/services/media_import_service.dart` and `lib/features/media/presentation/providers/photo_picker_providers.dart`: stamp at link time.
- Modify `lib/features/media/data/services/asset_resolution_service.dart` and `lib/features/media/presentation/providers/resolved_asset_providers.dart`: the cloud id tier.
- Modify `lib/features/media/data/services/repair/media_repair_service.dart` and `lib/features/media/presentation/providers/media_repair_providers.dart`: restamp on relink.
- Modify `lib/features/media/data/repositories/local_asset_cache_repository.dart`: `clearUnresolved`.
- Create `lib/core/services/sync/media_resolution_hints.dart`; modify `lib/core/services/sync/sync_service.dart` and `lib/features/settings/presentation/providers/sync_providers.dart`: invalidation.
- Create `lib/features/media/data/services/gallery_cloud_id_backfill.dart` and `lib/features/media/presentation/providers/gallery_cloud_id_backfill_provider.dart`; wire into `sync_providers.dart`.
- Modify `test/helpers/two_device_media_harness.dart` and `test/features/media/two_device/resolution_scenarios_test.dart`.

---

### Task 1: Schema v226 and the field end to end

**Files:**
- Modify: `lib/core/database/database.dart` (media table columns near `originDeviceId`; `currentSchemaVersion`; `migrationVersions`; a helper beside `_assertMediaFactClockColumns`; the rung after `if (from < 224)`; the backstop after the v224 backstop)
- Modify: `lib/features/media/domain/entities/media_item.dart`, `lib/features/media/data/repositories/media_row_mapper.dart`, `lib/features/media/data/repositories/media_repository.dart` (`createMedia`)
- Create: `test/core/database/migration_v226_media_cloud_asset_id_test.dart`
- Modify: `test/core/database/migration_v224_media_fact_clocks_test.dart`
- Test: `test/features/media/data/repositories/media_repository_cloud_asset_id_test.dart` (create)

**Interfaces:**
- Produces: `MediaItem.cloudAssetId` (`String?`, in the constructor, `copyWith` via the `_undefined` sentinel, and `props`); column `media.cloud_asset_id` (`TextColumn get cloudAssetId`), JSON key `cloudAssetId`; `createMedia` persists it.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v226_media_cloud_asset_id_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v226: media.cloud_asset_id, the PhotoKit cloud identifier a
/// gallery link is matched by on another device (media sync program spec
/// 6.2). Rung 226 because open PR #1978 holds 225.
void main() {
  NativeDatabase setupDb({int userVersion = 224}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
        rawDb.execute('CREATE TABLE media (id TEXT PRIMARY KEY, hlc TEXT)');
        rawDb.execute("INSERT INTO media (id, hlc) VALUES ('m1', 'H1')");
      },
    );
  }

  Future<Map<String, int>> mediaColumns(AppDatabase db) async {
    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    return {
      for (final c in cols) c.read<String>('name'): c.read<int>('notnull'),
    };
  }

  test('v226 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 226);
    expect(AppDatabase.migrationVersions, contains(226));
    // Counted from 225 so it holds whether or not #1978's rung has landed.
    expect(AppDatabase.migrationStepCount(225), 1);
  });

  test('the column is additive and did not move the sync floor', () {
    // The floor is 224, raised by the media fact clocks. An older reader
    // never sees a cloud id and leaves it alone (the merge upserts with
    // nullToAbsent), so this rung does not raise it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database has media.cloud_asset_id, nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await mediaColumns(db);
    expect(cols, contains('cloud_asset_id'));
    expect(cols['cloud_asset_id'], 0);
  });

  test('a v224 database upgrades with the column, left empty', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await mediaColumns(db), contains('cloud_asset_id'));
    final row = await db
        .customSelect("SELECT cloud_asset_id FROM media WHERE id = 'm1'")
        .getSingle();
    expect(row.read<String?>('cloud_asset_id'), isNull);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
  });

  test('the backstop re-adds the column at the current version', () async {
    // A version collision on a parallel branch: no rung runs, so only the
    // beforeOpen backstop can put the column back.
    final db = AppDatabase(
      setupDb(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await mediaColumns(db), contains('cloud_asset_id'));
  });
}
```

- [ ] **Step 2: Write the failing repository round-trip test**

Create `test/features/media/data/repositories/media_repository_cloud_asset_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaRepository();
  });

  tearDown(tearDownTestDatabase);

  MediaItem galleryRow({String? cloudAssetId}) => MediaItem(
    id: '',
    platformAssetId: 'A-1',
    cloudAssetId: cloudAssetId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    takenAt: DateTime.utc(2026, 7, 1, 10, 30),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  test('a cloud id written at link time reads back', () async {
    final created = await repo.createMedia(galleryRow(cloudAssetId: 'C-1'));
    expect((await repo.getMediaById(created.id))!.cloudAssetId, 'C-1');
  });

  test('a link with no cloud id reads back null', () async {
    final created = await repo.createMedia(galleryRow());
    expect((await repo.getMediaById(created.id))!.cloudAssetId, isNull);
  });

  test('copyWith can set and clear the cloud id', () {
    final row = galleryRow(cloudAssetId: 'C-1');
    expect(row.copyWith(cloudAssetId: 'C-2').cloudAssetId, 'C-2');
    expect(row.copyWith(cloudAssetId: null).cloudAssetId, isNull);
    expect(row.copyWith().cloudAssetId, 'C-1');
  });

  // A snapshot write must not roll back a stamp that landed after the
  // snapshot was read, as for the upload facts.
  test('updateMedia leaves the cloud id alone', () async {
    final created = await repo.createMedia(galleryRow(cloudAssetId: 'C-1'));
    await repo.updateMedia(created.copyWith(cloudAssetId: null, caption: 'x'));
    expect((await repo.getMediaById(created.id))!.cloudAssetId, 'C-1');
  });
}
```

Before writing the last test, check `updateMedia`'s signature and that `MediaItem` has `caption`; adjust the edited field to any user field the entity has if not.

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/core/database/migration_v226_media_cloud_asset_id_test.dart test/features/media/data/repositories/media_repository_cloud_asset_id_test.dart`
Expected: FAIL to compile (`cloudAssetId` is not defined).

- [ ] **Step 4: Add the column, rung, helper, backstop and ladder entry**

In `database.dart`, in the media table right after `TextColumn get originDeviceId => text().nullable()();`:

```dart
  // v226: PhotoKit's cloud identifier for a gallery link (media sync
  // program spec 6.2), which names the same photo on every device sharing
  // an iCloud Photos library. Null when unknown; empty when a relink found
  // none, since a null never clears a peer's copy (nullToAbsent).
  TextColumn get cloudAssetId => text().nullable()();
```

Set `static const int currentSchemaVersion = 226;`.

Append to `migrationVersions`, after `224,`:

```dart
    // v226: media.cloud_asset_id, the PhotoKit cloud identifier (media sync
    // program spec 6.2). Column only; the one-time backfill runs after a
    // sync, not here. Additive and nullable, so the floor stays at 224.
    // 225 is held by PR #1978 (tissue loading import).
    226,
```

Add the helper right after `_assertMediaFactClockColumns`:

```dart
  Future<void> _assertMediaCloudAssetIdColumn() async {
    final cols = await customSelect("PRAGMA table_info('media')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('cloud_asset_id')) {
      await customStatement(
        'ALTER TABLE media ADD COLUMN cloud_asset_id TEXT',
      );
    }
  }
```

After `if (from < 224) await reportProgress();` in `onUpgrade`:

```dart
        // v226: media.cloud_asset_id. Column only, no backfill.
        if (from < 226) {
          await _assertMediaCloudAssetIdColumn();
        }
        if (from < 226) await reportProgress();
```

After the v224 backstop in `beforeOpen`:

```dart
        // v226 backstop: re-assert media.cloud_asset_id (parallel-branch
        // version-collision self-heal). Column only, so it cannot touch
        // diver data.
        await _assertMediaCloudAssetIdColumn();
```

- [ ] **Step 5: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` gains `cloudAssetId` on `MediaData` and `MediaCompanion`.

- [ ] **Step 6: Add the entity field**

In `media_item.dart`, beside each `originDeviceId` touchpoint:
- field, after `final String? originDeviceId;`:
  ```dart
  /// PhotoKit's cloud identifier for a gallery link: the same photo on any
  /// device sharing this iCloud Photos library (spec 6.2). Null or empty
  /// means none is known; resolution then matches by metadata alone.
  final String? cloudAssetId;
  ```
- constructor: `this.cloudAssetId,` after `this.originDeviceId,`
- `copyWith` parameter: `Object? cloudAssetId = _undefined,` after `originDeviceId`
- `copyWith` body, after the `originDeviceId:` entry:
  ```dart
      cloudAssetId: cloudAssetId == _undefined
          ? this.cloudAssetId
          : cloudAssetId as String?,
  ```
- `props`: `cloudAssetId,` after `originDeviceId,`

In `media_row_mapper.dart` `mediaItemFromRow`, after `originDeviceId: row.originDeviceId,`: `cloudAssetId: row.cloudAssetId,`

In `media_repository.dart` `createMedia`'s companion, after `originDeviceId: Value(effectiveDeviceId),`: `cloudAssetId: Value(item.cloudAssetId),`

In `updateMedia`, add nothing, and extend the comment that begins "The upload facts are absent on purpose" with one sentence: `The cloud asset id is absent for the same reason: the gallery cloud id backfill stamps it narrowly.`

- [ ] **Step 7: Relax the v224 test**

In `migration_v224_media_fact_clocks_test.dart`, test `'v224 is the current schema version and is in the ladder'`:
- replace `expect(AppDatabase.currentSchemaVersion, 224);` with `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(224));`
- replace `expect(AppDatabase.migrationStepCount(223), 1);` with `expect(AppDatabase.migrationStepCount(223), greaterThanOrEqualTo(1));`
- change the leading comment to: `// Relaxed once v226 (media cloud asset id) landed on top; the newest rung owns the exact assertions.`
- rename the test to `'v224 is at or below the current schema version and in the ladder'`.

- [ ] **Step 8: Run the tests, then the database and sync suites**

Run: `flutter test test/core/database/migration_v226_media_cloud_asset_id_test.dart test/features/media/data/repositories/media_repository_cloud_asset_id_test.dart`
Expected: PASS.

Run: `flutter test test/core/database test/core/services/sync test/architecture`
Expected: PASS. If a test pins `currentSchemaVersion` to 224 exactly, relax it the same way (grep: `grep -rn "currentSchemaVersion, 224" test/`).

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/features/media/domain/entities/media_item.dart lib/features/media/data/repositories/media_row_mapper.dart lib/features/media/data/repositories/media_repository.dart test/core/database/migration_v226_media_cloud_asset_id_test.dart test/core/database/migration_v224_media_fact_clocks_test.dart test/features/media/data/repositories/media_repository_cloud_asset_id_test.dart
git commit -m "feat(media): add the synced media.cloud_asset_id column (v226)"
```

---

### Task 2: The cloud identifier seam and stamping at link time

**Files:**
- Create: `lib/features/media/data/services/cloud_identifier_source.dart`
- Create: `test/features/media/data/services/cloud_identifier_source_test.dart`
- Modify: `test/helpers/fake_photo_picker_service.dart`
- Modify: `lib/features/media/data/services/media_import_service.dart`
- Modify: `lib/features/media/presentation/providers/photo_picker_providers.dart` (the `MediaImportService(` construction)
- Test: `test/features/media/data/services/media_import_service_cloud_id_test.dart` (create)

**Interfaces:**
- Consumes: `MediaItem.cloudAssetId` (Task 1).
- Produces:
  - `abstract interface class CloudIdentifierSource { Future<Map<String, String>> cloudIdentifiers(List<String> localIds); }`: only ids with a non-empty cloud id appear in the result.
  - `class PhotoManagerCloudIdentifierSource implements CloudIdentifierSource` with `const PhotoManagerCloudIdentifierSource()` and a `@visibleForTesting` constructor `PhotoManagerCloudIdentifierSource.withFetch({required bool supported, required Future<Map<String, String?>> Function(List<String>) fetch, int chunkSize = 500})`.
  - `FakeGalleryAsset.cloudId` (`String?`); `FakePhotoPickerService implements CloudIdentifierSource`, with `int cloudIdCalls` and `Object? cloudIdError`.
  - `MediaImportService({..., CloudIdentifierSource? cloudIdentifiers})`.

- [ ] **Step 1: Write the failing seam test**

Create `test/features/media/data/services/cloud_identifier_source_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';

void main() {
  test('asks in chunks and drops ids with no cloud id', () async {
    final calls = <List<String>>[];
    final source = PhotoManagerCloudIdentifierSource.withFetch(
      supported: true,
      chunkSize: 2,
      fetch: (ids) async {
        calls.add(ids);
        return {
          for (final id in ids)
            id: switch (id) {
              'a' => 'C-a',
              'b' => null,
              'c' => '',
              _ => 'C-$id',
            },
        };
      },
    );

    final ids = await source.cloudIdentifiers(['a', 'b', 'c', 'd', 'e']);

    expect(calls, [
      ['a', 'b'],
      ['c', 'd'],
      ['e'],
    ]);
    expect(ids, {'a': 'C-a', 'd': 'C-d', 'e': 'C-e'});
  });

  test('off Apple platforms it answers nothing and asks nothing', () async {
    var asked = false;
    final source = PhotoManagerCloudIdentifierSource.withFetch(
      supported: false,
      fetch: (ids) async {
        asked = true;
        return {};
      },
    );

    expect(await source.cloudIdentifiers(['a']), isEmpty);
    expect(asked, isFalse);
  });

  test('an empty request asks nothing', () async {
    var asked = false;
    final source = PhotoManagerCloudIdentifierSource.withFetch(
      supported: true,
      fetch: (ids) async {
        asked = true;
        return {};
      },
    );

    expect(await source.cloudIdentifiers(const []), isEmpty);
    expect(asked, isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media/data/services/cloud_identifier_source_test.dart`
Expected: FAIL to compile (`cloud_identifier_source.dart` does not exist).

- [ ] **Step 3: Write the seam**

Create `lib/features/media/data/services/cloud_identifier_source.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:photo_manager/photo_manager.dart';

/// PhotoKit's cloud identifiers for local gallery asset ids (media sync
/// program spec 6.2). A cloud identifier names the same photo on every
/// device sharing an iCloud Photos library, where local ids differ.
abstract interface class CloudIdentifierSource {
  /// The cloud identifier of each of [localIds] that has one. An id with
  /// none (iCloud Photos off, an OS before iOS 15 or macOS 12, an asset
  /// that is not in the library) is absent from the result.
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds);
}

/// [CloudIdentifierSource] over `PhotoManager.plugin.getCloudIdentifiers`,
/// one platform call per chunk. Not `AssetEntity.darwin.cloudIdentifier`:
/// that is a one-id wrapper over the same call, and it throws off Apple
/// platforms, where this answers nothing instead.
class PhotoManagerCloudIdentifierSource implements CloudIdentifierSource {
  const PhotoManagerCloudIdentifierSource()
    : _supported = null,
      _fetch = null,
      _chunkSize = 500;

  @visibleForTesting
  const PhotoManagerCloudIdentifierSource.withFetch({
    required bool supported,
    required Future<Map<String, String?>> Function(List<String> ids) fetch,
    int chunkSize = 500,
  }) : _supported = supported,
       _fetch = fetch,
       _chunkSize = chunkSize;

  final bool? _supported;
  final Future<Map<String, String?>> Function(List<String> ids)? _fetch;
  final int _chunkSize;

  bool get _isSupported => _supported ?? (Platform.isIOS || Platform.isMacOS);

  Future<Map<String, String?>> _call(List<String> ids) =>
      (_fetch ?? PhotoManager.plugin.getCloudIdentifiers)(ids);

  @override
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds) async {
    if (localIds.isEmpty || !_isSupported) return const {};
    final found = <String, String>{};
    for (var i = 0; i < localIds.length; i += _chunkSize) {
      final end = i + _chunkSize < localIds.length
          ? i + _chunkSize
          : localIds.length;
      final answer = await _call(localIds.sublist(i, end));
      for (final entry in answer.entries) {
        final cloudId = entry.value;
        if (cloudId != null && cloudId.isNotEmpty) found[entry.key] = cloudId;
      }
    }
    return found;
  }
}
```

If `PhotoManager.plugin` is not exported by `package:photo_manager/photo_manager.dart`, import it from where 3.12.0 exports it (check `~/.pub-cache/hosted/pub.dev/photo_manager-3.12.0/lib/photo_manager.dart`), and record the path in the plan's execution notes.

- [ ] **Step 4: Run the seam test to verify it passes**

Run: `flutter test test/features/media/data/services/cloud_identifier_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Teach the fake library cloud ids**

In `test/helpers/fake_photo_picker_service.dart`:
- import `package:submersion/features/media/data/services/cloud_identifier_source.dart`;
- `FakeGalleryAsset` gains `this.cloudId,` in the constructor and the field:
  ```dart
  /// PhotoKit's cloud identifier. Two devices sharing an iCloud library
  /// hold the same photo under different ids and the SAME cloud id.
  final String? cloudId;
  ```
- the class line becomes `class FakePhotoPickerService implements PhotoPickerService, GalleryAssetReader, CloudIdentifierSource {`;
- add, after `metadata`:
  ```dart
  // CloudIdentifierSource

  /// How many batch lookups ran: resolution must not ask for a row that
  /// has no cloud id to match.
  int cloudIdCalls = 0;

  /// When set, the next lookups throw it (a platform channel failure).
  Object? cloudIdError;

  @override
  Future<Map<String, String>> cloudIdentifiers(List<String> localIds) async {
    cloudIdCalls++;
    final error = cloudIdError;
    if (error != null) throw error;
    return {
      for (final id in localIds)
        if (_visible(id)?.cloudId case final cloudId?
            when cloudId.isNotEmpty)
          id: cloudId,
    };
  }
  ```

- [ ] **Step 6: Write the failing import test**

Create `test/features/media/data/services/media_import_service_cloud_id_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import '../../../../helpers/fake_photo_picker_service.dart';
import 'media_import_service_test.mocks.dart';

final _taken = DateTime(2026, 7, 1, 10, 30);

FakeGalleryAsset _asset(String id, {String? cloudId}) => FakeGalleryAsset(
  id: id,
  bytes: Uint8List.fromList([1, 2, 3]),
  takenAt: _taken,
  cloudId: cloudId,
);

void main() {
  late MockMediaRepository repo;
  late FakePhotoPickerService library;

  setUp(() {
    repo = MockMediaRepository();
    library = FakePhotoPickerService(
      assets: [_asset('a1', cloudId: 'C-1'), _asset('a2')],
    );
    when(
      repo.getGalleryLinksForSite(any),
    ).thenAnswer((_) async => <MediaItem>[]);
    when(
      repo.getLinkedLocalPathsForSite(any),
    ).thenAnswer((_) async => <String>{});
    when(repo.createMedia(any)).thenAnswer((invocation) async {
      final item = invocation.positionalArguments.first as MediaItem;
      return item.copyWith(id: 'saved-${item.platformAssetId}');
    });
  });

  MediaImportService service({CloudIdentifierSource? cloudIdentifiers}) =>
      MediaImportService(
        mediaRepository: repo,
        enrichmentService: MockEnrichmentService(),
        cloudIdentifiers: cloudIdentifiers,
      );

  test('a gallery link records its cloud id, in one lookup', () async {
    final result = await service(cloudIdentifiers: library)
        .importPhotosForSite(
          selectedAssets: [_asset('a1').info, _asset('a2').info],
          siteId: 'site-1',
        );

    final byAsset = {for (final m in result.imported) m.platformAssetId: m};
    expect(byAsset['a1']!.cloudAssetId, 'C-1');
    expect(byAsset['a2']!.cloudAssetId, isNull, reason: 'no iCloud copy');
    expect(library.cloudIdCalls, 1);
  });

  // The cloud id is a hint for other devices; a lookup that fails must not
  // cost the user the import.
  test('a failed lookup still links, with no cloud id', () async {
    library.cloudIdError = StateError('channel');

    final result = await service(cloudIdentifiers: library)
        .importPhotosForSite(
          selectedAssets: [_asset('a1').info],
          siteId: 'site-1',
        );

    expect(result.imported, hasLength(1));
    expect(result.imported.single.cloudAssetId, isNull);
  });

  test('a desktop file pick is never looked up', () async {
    await service(cloudIdentifiers: library).importPhotosForSite(
      selectedAssets: [
        AssetInfo(
          id: 'f1',
          type: AssetType.image,
          createDateTime: _taken,
          width: 10,
          height: 10,
          filePath: 'photo.jpg',
        ),
      ],
      siteId: 'site-1',
    );

    expect(library.cloudIdCalls, 0);
  });
}
```

Also add one test to `test/features/media/data/services/media_import_service_test.dart` for the dive path, inside `main` after its existing `setUp` (it already stubs `getGalleryLinksForDive`, `getLinkedLocalPathsForDive` and `createMedia`, and builds `testDive`; check that `createMedia`'s stub returns the passed item with an id, and stub `saveEnrichment` if a dive import reaches it):

```dart
  test('a dive import records each gallery link\'s cloud id', () async {
    final library = FakePhotoPickerService(
      assets: [
        FakeGalleryAsset(
          id: 'asset-1',
          bytes: Uint8List.fromList([1]),
          takenAt: DateTime(2024, 1, 15, 10, 30),
          cloudId: 'C-1',
        ),
      ],
    );
    final withCloud = MediaImportService(
      mediaRepository: mockMediaRepository,
      enrichmentService: mockEnrichmentService,
      cloudIdentifiers: library,
    );

    final result = await withCloud.importPhotosForDive(
      selectedAssets: [library.infoFor('asset-1')],
      dive: testDive,
    );

    expect(result.imported.single.cloudAssetId, 'C-1');
  });
```

and add to `FakePhotoPickerService` a helper `AssetInfo infoFor(String id) => _assets[id]!.info;` (plus the imports the test file needs: `dart:typed_data`, the fake, and `cloud_identifier_source.dart` if not already present).

- [ ] **Step 7: Run the import tests to verify they fail**

Run: `flutter test test/features/media/data/services/media_import_service_cloud_id_test.dart test/features/media/data/services/media_import_service_test.dart`
Expected: FAIL to compile (`cloudIdentifiers` is not a parameter of `MediaImportService`).

- [ ] **Step 8: Stamp at link time**

In `media_import_service.dart`:
- import `package:submersion/features/media/data/services/cloud_identifier_source.dart`;
- constructor gains `CloudIdentifierSource? cloudIdentifiers,` and the initializer `_cloudIdentifiers = cloudIdentifiers`;
- field:
  ```dart
  /// Looks up each picked gallery asset's iCloud identifier, recorded on
  /// the row so another device sharing the library finds the exact photo
  /// (spec 6.2). Null where there is none to ask (tests, and the providers
  /// on hosts with no photo library pass the photo_manager one, which
  /// answers nothing off Apple platforms).
  final CloudIdentifierSource? _cloudIdentifiers;
  ```
- add a helper:
  ```dart
  /// The cloud id of each gallery asset in [assets], in one lookup. Empty
  /// when there is no source or the lookup fails: the id is a hint for
  /// other devices, and a link without one resolves by metadata as before.
  Future<Map<String, String>> _cloudIdsFor(List<AssetInfo> assets) async {
    final source = _cloudIdentifiers;
    final gallery = [
      for (final a in assets)
        if (a.filePath == null || a.filePath!.isEmpty) a.id,
    ];
    if (source == null || gallery.isEmpty) return const {};
    try {
      return await source.cloudIdentifiers(gallery);
    } on Object catch (e, stackTrace) {
      _log.warning(
        'Could not read cloud ids for ${gallery.length} picked assets',
        error: e,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }
  ```
- `_createMediaItemFromAsset` gains `String? cloudAssetId,` in its named parameters and passes `cloudAssetId: isLocalFile ? null : cloudAssetId,` in the `MediaItem(...)`;
- in `importPhotosForDive`, just before `for (final asset in newAssets) {`: `final cloudIds = await _cloudIdsFor(newAssets);`, and the item becomes `_createMediaItemFromAsset(asset, diveId: dive.id, cloudAssetId: cloudIds[asset.id])`;
- the same two changes in `importPhotosForSite` (`siteId: siteId, cloudAssetId: cloudIds[asset.id]`).

In `photo_picker_providers.dart`, in the `MediaImportService(` construction, add `cloudIdentifiers: const PhotoManagerCloudIdentifierSource(),` and the import.

- [ ] **Step 9: Run the import tests to verify they pass**

Run: `flutter test test/features/media/data/services/media_import_service_cloud_id_test.dart test/features/media/data/services/media_import_service_test.dart test/features/media/data/services/media_import_service_site_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/media/data/services/cloud_identifier_source.dart lib/features/media/data/services/media_import_service.dart lib/features/media/presentation/providers/photo_picker_providers.dart test/helpers/fake_photo_picker_service.dart test/features/media/data/services/cloud_identifier_source_test.dart test/features/media/data/services/media_import_service_cloud_id_test.dart test/features/media/data/services/media_import_service_test.dart
git commit -m "feat(media): record a gallery link's iCloud identifier at link time"
```

---

### Task 3: The cloud id resolution tier, and S6

**Files:**
- Modify: `lib/features/media/data/services/asset_resolution_service.dart`
- Modify: `lib/features/media/presentation/providers/resolved_asset_providers.dart`
- Modify: `test/helpers/two_device_media_harness.dart` (device build and `linkGalleryPhoto`)
- Modify: `test/features/media/two_device/resolution_scenarios_test.dart` (S6)
- Test: `test/features/media/data/services/asset_resolution_cloud_id_test.dart` (create)

**Interfaces:**
- Consumes: `CloudIdentifierSource`, `FakeGalleryAsset.cloudId`, `FakePhotoPickerService.cloudIdCalls` / `cloudIdError` (Task 2); `MediaItem.cloudAssetId` (Task 1).
- Produces: `AssetResolutionService({..., CloudIdentifierSource? cloudIdentifiers})`; resolution method string `'cloud_id'`.

- [ ] **Step 1: Write the failing tier tests**

Create `test/features/media/data/services/asset_resolution_cloud_id_test.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

/// Device B's view of a photo device A linked: A's local id does not load
/// here, and B's library holds the photo under its own id (spec 6.2).
void main() {
  late LocalCacheDatabase cacheDb;
  late LocalAssetCacheRepository cache;
  late FakePhotoPickerService library;
  late AssetResolutionService service;
  final taken = DateTime(2026, 7, 1, 10, 30);
  final frame1 = Uint8List.fromList([1]);
  final frame2 = Uint8List.fromList([2]);

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    cache = LocalAssetCacheRepository(database: cacheDb);
    library = FakePhotoPickerService();
    service = AssetResolutionService(
      cacheRepository: cache,
      photoPickerService: library,
      cloudIdentifiers: library,
    );
  });

  tearDown(() => cacheDb.close());

  /// A burst pair: same second, same dimensions, no titles.
  void addBurstPair() {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..add(
        FakeGalleryAsset(
          id: 'B-2',
          bytes: frame2,
          takenAt: taken,
          filename: null,
          cloudId: 'C-2',
        ),
      );
  }

  MediaItem row({String? cloudAssetId, int? width, int? height}) => MediaItem(
    id: 'm1',
    platformAssetId: 'A-1',
    cloudAssetId: cloudAssetId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    width: width,
    height: height,
    // Wall-clock-as-UTC, the stored convention.
    takenAt: DateTime.utc(2026, 7, 1, 10, 30),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  test('a cloud id picks the right frame of a burst pair', () async {
    addBurstPair();

    final r = await service.resolveAssetId(row(cloudAssetId: 'C-2'));

    expect(r.status, ResolutionStatus.resolved);
    expect(r.localAssetId, 'B-2');
    expect((await cache.getCacheEntry('m1'))!.resolutionMethod, 'cloud_id');
  });

  test('without a cloud id the burst pair stays unresolved', () async {
    addBurstPair();

    final r = await service.resolveAssetId(
      row(width: 4032, height: 3024),
    );

    expect(r.status, ResolutionStatus.unavailable);
    expect(library.cloudIdCalls, 0, reason: 'nothing to match, so no lookup');
  });

  test('an empty cloud id is none, and is not looked up', () async {
    addBurstPair();

    await service.resolveAssetId(row(cloudAssetId: ''));

    expect(library.cloudIdCalls, 0);
  });

  test('a cloud id no candidate carries falls through to metadata', () async {
    library.add(
      FakeGalleryAsset(id: 'B-1', bytes: frame1, takenAt: taken, filename: null),
    );

    final r = await service.resolveAssetId(
      row(cloudAssetId: 'C-9', width: 4032, height: 3024),
    );

    expect(r.localAssetId, 'B-1');
    expect(
      (await cache.getCacheEntry('m1'))!.resolutionMethod,
      'exact_timestamp_dimensions',
    );
  });

  test('a failed lookup falls through to metadata', () async {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..cloudIdError = StateError('channel');

    final r = await service.resolveAssetId(
      row(cloudAssetId: 'C-1', width: 4032, height: 3024),
    );

    expect(r.localAssetId, 'B-1');
    expect(
      (await cache.getCacheEntry('m1'))!.resolutionMethod,
      'exact_timestamp_dimensions',
    );
  });

  // Never expected from PhotoKit, but a tie is not an answer.
  test('two candidates with the same cloud id is no match', () async {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..add(
        FakeGalleryAsset(
          id: 'B-2',
          bytes: frame2,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      );

    final r = await service.resolveAssetId(row(cloudAssetId: 'C-1'));

    expect(r.status, ResolutionStatus.unavailable);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/media/data/services/asset_resolution_cloud_id_test.dart`
Expected: FAIL to compile (`cloudIdentifiers` is not a parameter).

- [ ] **Step 3: Add the tier**

In `asset_resolution_service.dart`:
- import `cloud_identifier_source.dart`;
- field `final CloudIdentifierSource? _cloudIdentifiers;`, constructor parameter `CloudIdentifierSource? cloudIdentifiers,` and initializer `_cloudIdentifiers = cloudIdentifiers`;
- update the class doc's resolution list and `resolveAssetId`'s doc: step 3 becomes "Match the time window's candidates by iCloud identifier, then by metadata (tiered matching)";
- between the `candidates.isEmpty` block and `// Tier 1: filename + timestamp`:
  ```dart
    // Tier 0: the iCloud identifier (media sync program spec 6.2). It names
    // one photo on every device sharing the library, so it separates what
    // metadata cannot (a burst pair shot in the same second), and it wins
    // before any metadata tier.
    final cloudMatch = await _matchByCloudIdentifier(item, candidates);
    if (cloudMatch != null) {
      await _cacheRepository.cacheResolution(
        mediaId: item.id,
        localAssetId: cloudMatch,
        method: 'cloud_id',
      );
      _log.debug('Resolved via cloud identifier: $cloudMatch');
      return ResolutionResult(
        localAssetId: cloudMatch,
        status: ResolutionStatus.resolved,
      );
    }
  ```
- add the method after `_verifyAssetLoadable`:
  ```dart
  /// The one candidate whose iCloud identifier is [item]'s, or null: when
  /// the row has none (null, or empty after a relink that found none),
  /// when there is no source, when the lookup fails, or when the match is
  /// not unique. The candidates are the ones the metadata tiers already
  /// fetched for the photo's time window, looked up in one batch; PhotoKit
  /// has no cloud-to-local lookup, so this maps them forward.
  Future<String?> _matchByCloudIdentifier(
    MediaItem item,
    List<AssetInfo> candidates,
  ) async {
    final cloudId = item.cloudAssetId;
    final source = _cloudIdentifiers;
    if (source == null || cloudId == null || cloudId.isEmpty) return null;
    final Map<String, String> ids;
    try {
      ids = await source.cloudIdentifiers([for (final c in candidates) c.id]);
    } on Object catch (e) {
      _log.warning(
        'Cloud identifier lookup failed for media ${item.id}; '
        'matching by metadata',
        error: e,
      );
      return null;
    }
    final matches = [
      for (final c in candidates)
        if (ids[c.id] == cloudId) c.id,
    ];
    return matches.length == 1 ? matches.single : null;
  }
  ```

In `resolved_asset_providers.dart`, `assetResolutionServiceProvider` passes `cloudIdentifiers: const PhotoManagerCloudIdentifierSource(),` (import it).

- [ ] **Step 4: Run the tier tests to verify they pass**

Run: `flutter test test/features/media/data/services/asset_resolution_cloud_id_test.dart test/features/media/data/services/asset_resolution_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the harness and un-skip S6**

In `test/helpers/two_device_media_harness.dart`:
- the device's `AssetResolutionService(` gains `cloudIdentifiers: d.gallery,`;
- `linkGalleryPhoto` records the cloud id the way `MediaImportService` does, from this device's library, one lookup:
  ```dart
    gallery.add(asset);
    // As MediaImportService stamps it at link time (spec 6.2).
    final cloudIds = await gallery.cloudIdentifiers([asset.id]);
    final created = await MediaRepository().createMedia(
      MediaItem(
        ...
        platformAssetId: asset.id,
        cloudAssetId: cloudIds[asset.id],
        ...
  ```
  then reset the lookup counter so tests count only resolution lookups: `gallery.cloudIdCalls = 0;` right after the lookup.

In `resolution_scenarios_test.dart`, S6:
- A's assets get `cloudId: 'C-b1'` and `cloudId: 'C-b2'`; B's get the same `cloudId: 'C-b1'` and `cloudId: 'C-b2'`;
- delete the trailing comment `// Slice 8 gives FakeGalleryAsset a cloudId and stamps it at link time.`;
- remove the `skip:` argument;
- add after the frame assertions:
  ```dart
    expect(
      await h.b.assetCache.getCacheEntry(id1),
      isA<CacheEntry>().having((e) => e.resolutionMethod, 'method', 'cloud_id'),
    );
  ```
  and import `package:submersion/features/media/data/repositories/local_asset_cache_repository.dart`. (If `assetCache` is not public on `HarnessDevice`, it is declared `late LocalAssetCacheRepository assetCache;`; check and make it public if needed.)

- [ ] **Step 6: Run the scenarios**

Run: `flutter test test/features/media/two_device`
Expected: PASS, with S6 no longer skipped.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/media/data/services/asset_resolution_service.dart lib/features/media/presentation/providers/resolved_asset_providers.dart test/features/media/data/services/asset_resolution_cloud_id_test.dart test/helpers/two_device_media_harness.dart test/features/media/two_device/resolution_scenarios_test.dart
git commit -m "feat(media): resolve a peer's gallery photo by its iCloud identifier first"
```

---

### Task 4: A gallery relink restamps the cloud id

**Files:**
- Modify: `lib/features/media/data/services/repair/media_repair_service.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`applyRepairWrites`)
- Modify: `lib/features/media/presentation/providers/media_repair_providers.dart` (the `MediaRepairService(` construction)
- Test: `test/features/media/data/repair/media_repair_service_test.dart`

**Interfaces:**
- Consumes: `CloudIdentifierSource`, `FakePhotoPickerService` (Task 2).
- Produces: `RepairWrite.newCloudAssetId` (`String?`); `MediaRepairService({..., CloudIdentifierSource? cloudIdentifiers})`.

A relink points the row at a different asset, so the old cloud id may name a different photo. The write must replace it, and with `''` rather than null when the new asset has none or the lookup fails, because a null never reaches a peer (`nullToAbsent`) and the peer's cloud tier would keep resolving the old photo.

- [ ] **Step 1: Write the failing tests**

In `media_repair_service_test.dart`, extend the `service(...)` helper with `CloudIdentifierSource? cloudIdentifiers,` passed through, import the fake and `cloud_identifier_source.dart`, and add after `'gallery proposal flips the row to platformGallery'`:

```dart
  RepairProposal galleryProposal(MediaItem item, String assetId) =>
      RepairProposal(
        item: item,
        confidence: RepairConfidence.probable,
        candidate: RepairCandidate.galleryAsset(
          assetId: assetId,
          sizeBytes: null,
        ),
      );

  test('a gallery relink records the new asset\'s cloud id', () async {
    await seed('a');
    final library = FakePhotoPickerService(
      assets: [
        FakeGalleryAsset(
          id: 'asset-9',
          bytes: Uint8List.fromList([1]),
          takenAt: DateTime(2026, 6, 1),
          cloudId: 'C-9',
        ),
      ],
    );

    await service(cloudIdentifiers: library).apply([
      galleryProposal((await repo.getMediaById('a'))!, 'asset-9'),
    ]);

    expect((await repo.getMediaById('a'))!.cloudAssetId, 'C-9');
  });

  // The old id named the old asset. Empty, not null: a null never reaches a
  // peer, whose cloud tier would go on resolving the old photo.
  test('a relink to an asset with no cloud id clears it to empty', () async {
    await seed('a');
    await db.customStatement(
      "UPDATE media SET cloud_asset_id = 'C-old' WHERE id = 'a'",
    );

    await service(cloudIdentifiers: FakePhotoPickerService()).apply([
      galleryProposal((await repo.getMediaById('a'))!, 'asset-9'),
    ]);

    expect((await repo.getMediaById('a'))!.cloudAssetId, '');
  });

  test('a failed lookup clears it to empty too', () async {
    await seed('a');
    await db.customStatement(
      "UPDATE media SET cloud_asset_id = 'C-old' WHERE id = 'a'",
    );
    final library = FakePhotoPickerService()..cloudIdError = StateError('x');

    final report = await service(cloudIdentifiers: library).apply([
      galleryProposal((await repo.getMediaById('a'))!, 'asset-9'),
    ]);

    expect(report.relinked, 1, reason: 'the relink itself still lands');
    expect((await repo.getMediaById('a'))!.cloudAssetId, '');
  });

  test('a file relink leaves the cloud id alone', () async {
    final (file, hash) = await tempFile('a.jpg', 'aaaa');
    await seed(
      'a',
      contentHash: hash,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'dead-asset',
    );
    await db.customStatement(
      "UPDATE media SET cloud_asset_id = 'C-old' WHERE id = 'a'",
    );

    await service(cloudIdentifiers: FakePhotoPickerService()).apply([
      RepairProposal(
        item: (await repo.getMediaById('a'))!,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: file.path, sizeBytes: 4),
      ),
    ]);

    expect((await repo.getMediaById('a'))!.cloudAssetId, 'C-old');
  });
```

(The file relink leaves it because a non-gallery row never reaches the cloud tier, and a later gallery relink replaces it.)

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/media/data/repair/media_repair_service_test.dart`
Expected: FAIL to compile (`cloudIdentifiers` is not a parameter).

- [ ] **Step 3: Implement**

In `media_repair_service.dart`:
- `RepairWrite` gains `this.newCloudAssetId,` and:
  ```dart
  /// The new gallery asset's iCloud identifier, or '' when it has none or
  /// the lookup failed: the old one named the old asset, and an empty
  /// string (unlike null) reaches every peer. Unused for other sources.
  final String? newCloudAssetId;
  ```
- `MediaRepairService` gains `this.cloudIdentifiers,` and the field `final CloudIdentifierSource? cloudIdentifiers;` with a one-line doc ("Looks up a relinked gallery asset's iCloud identifier (spec 6.2); null leaves every relink's cloud id empty.");
- after the Stage A loop and before Stage B, restamp the gallery writes in one lookup:
  ```dart
    // One lookup for every gallery relink in the pass (spec 6.2).
    final galleryIds = [
      for (final w in writes)
        if (w.newSourceType == MediaSourceType.platformGallery &&
            w.newPlatformAssetId != null)
          w.newPlatformAssetId!,
    ];
    var cloudIds = const <String, String>{};
    final source = cloudIdentifiers;
    if (source != null && galleryIds.isNotEmpty) {
      try {
        cloudIds = await source.cloudIdentifiers(galleryIds);
      } on Object catch (e) {
        _log.warning('Could not read cloud ids for relinked assets: $e');
      }
    }
    final stamped = [
      for (final w in writes)
        w.newSourceType == MediaSourceType.platformGallery
            ? RepairWrite(
                mediaId: w.mediaId,
                newLocalPath: w.newLocalPath,
                newBookmarkRef: w.newBookmarkRef,
                newPlatformAssetId: w.newPlatformAssetId,
                newSourceType: w.newSourceType,
                newCloudAssetId: cloudIds[w.newPlatformAssetId] ?? '',
              )
            : w,
    ];
  ```
  and pass `stamped` (not `writes`) to `repository.applyRepairWrites`. Check the name of the Stage B call and of `_log`'s warning method (`LoggerService` has `warning`) when editing.

In `media_repository.dart` `applyRepairWrites`, in the `MediaCompanion`, after `platformAssetId: Value(write.newPlatformAssetId),`:

```dart
            // A relink to the gallery replaces the cloud id with the new
            // asset's ('' when it has none); any other repair leaves it,
            // since only a gallery row is ever resolved by it.
            cloudAssetId: toGallery
                ? Value(write.newCloudAssetId ?? '')
                : const Value.absent(),
```

In `media_repair_providers.dart`, pass `cloudIdentifiers: const PhotoManagerCloudIdentifierSource(),`.

- [ ] **Step 4: Run the repair tests**

Run: `flutter test test/features/media/data/repair`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/media/data/services/repair/media_repair_service.dart lib/features/media/data/repositories/media_repository.dart lib/features/media/presentation/providers/media_repair_providers.dart test/features/media/data/repair/media_repair_service_test.dart
git commit -m "feat(media): a gallery relink restamps the row's iCloud identifier"
```

---

### Task 5: A sync that brings a new hint retries resolution at once

**Files:**
- Modify: `lib/features/media/data/repositories/local_asset_cache_repository.dart`
- Create: `lib/core/services/sync/media_resolution_hints.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (constructor; `_mergeEntity`)
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`syncServiceProvider`)
- Modify: `test/helpers/two_device_media_harness.dart` (`sync`)
- Test: `test/features/media/data/repositories/local_asset_cache_repository_test.dart` (add to it, or create if absent), `test/core/services/sync/media_resolution_hints_test.dart` (create), `test/features/media/two_device/resolution_scenarios_test.dart`

**Interfaces:**
- Consumes: `MediaItem.cloudAssetId`, JSON key `cloudAssetId` (Task 1); `SyncFactGroups.mediaUpload`.
- Produces:
  - `Future<void> LocalAssetCacheRepository.clearUnresolved(Iterable<String> mediaIds)`
  - `bool bringsMediaResolutionHint({required Map<String, dynamic>? local, required Map<String, dynamic> applied, required bool rowFromRemote})`, where `applied` is `mergeFactGroups(...).row`, the row as it will be written. It compares values, not winning groups: a fact group with no clock of its own falls back to the row clock (`_effectiveClock`), so a plain edit from a peer can win the upload group without changing a single upload fact.
  - `SyncService({..., Future<void> Function(Set<String> mediaIds)? onMediaResolutionHints})`
  - harness: `HarnessDevice.assetCache` public (already, or made so in Task 3).

- [ ] **Step 1: Write the failing unit tests**

`clearUnresolved` (add to the cache repository's test file; if none exists, create `test/features/media/data/repositories/local_asset_cache_repository_test.dart` with an in-memory `LocalCacheDatabase` as in Task 3):

```dart
  test('clearUnresolved drops only unresolved entries', () async {
    await cache.cacheResolution(mediaId: 'u', localAssetId: null, method: 'unresolved');
    await cache.cacheResolution(mediaId: 'r', localAssetId: 'B-1', method: 'cloud_id');

    await cache.clearUnresolved(['u', 'r', 'absent']);

    expect(await cache.getCacheEntry('u'), isNull);
    expect((await cache.getCacheEntry('r'))!.localAssetId, 'B-1');
  });
```

Create `test/core/services/sync/media_resolution_hints_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/media_resolution_hints.dart';

void main() {
  test('a new cloud id on a row the peer wins is a hint', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'cloudAssetId': null},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: true,
      ),
      isTrue,
    );
  });

  test('the same cloud id again is not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('an empty cloud id is not a hint', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'cloudAssetId': 'C-1'},
        applied: {'id': 'm1', 'cloudAssetId': ''},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('a cloud id on a row the peer lost is not applied, so no hint', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1'},
        applied: {'id': 'm1', 'cloudAssetId': 'C-1'},
        rowFromRemote: false,
      ),
      isFalse,
    );
  });

  test('a new upload fact is a hint even on a row the peer lost', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'remoteUploadedAt': null},
        applied: {'id': 'm1', 'remoteUploadedAt': 123},
        rowFromRemote: false,
      ),
      isTrue,
    );
  });

  // A group can win on the row clock alone (no fact clock on either side)
  // while carrying the very values this device already has.
  test('upload facts that did not change are not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'remoteUploadedAt': 123, 'contentHash': 'h'},
        applied: {'id': 'm1', 'remoteUploadedAt': 123, 'contentHash': 'h'},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('a cleared upload fact is not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'remoteUploadedAt': 123},
        applied: {'id': 'm1', 'remoteUploadedAt': null},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  test('a verification fact is not', () {
    expect(
      bringsMediaResolutionHint(
        local: {'id': 'm1', 'isOrphaned': false},
        applied: {'id': 'm1', 'isOrphaned': true},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });

  // A row this device has never seen has never been resolved here.
  test('a new row is not', () {
    expect(
      bringsMediaResolutionHint(
        local: null,
        applied: {'id': 'm1', 'cloudAssetId': 'C-1', 'remoteUploadedAt': 1},
        rowFromRemote: true,
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/services/sync/media_resolution_hints_test.dart test/features/media/data/repositories/local_asset_cache_repository_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the two units**

In `local_asset_cache_repository.dart`, after `clearEntry`:

```dart
  /// Drops the `unresolved` entries among [mediaIds], so their next view
  /// searches again instead of waiting out the backoff. Called when a sync
  /// brings a row something new to be found by (spec 6.2). A resolved
  /// mapping stays: it was found, and a failed fetch re-resolves it.
  Future<void> clearUnresolved(Iterable<String> mediaIds) async {
    final ids = mediaIds.toList();
    if (ids.isEmpty) return;
    await (_db.delete(_db.localAssetCache)..where(
          (t) => t.mediaId.isIn(ids) & t.localAssetId.isNull(),
        ))
        .go();
  }
```

Create `lib/core/services/sync/media_resolution_hints.dart`:

```dart
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

/// Whether applying a peer's media row gives this device something new to
/// find the photo by, so a search that gave up on it should run again
/// (media sync program spec 6.2): a cloud id it did not have, or an upload
/// fact it did not have. [applied] is the row as the merge will write it;
/// [rowFromRemote] is whether the peer's row fields (the cloud id among
/// them) were taken.
///
/// Compares values rather than asking which fact groups the peer won: a
/// group with no clock of its own falls back to the row clock, so a plain
/// edit can win the upload group while changing no upload fact at all. A
/// row this device has never seen ([local] null) has no cached search to
/// retry. An empty cloud id, or a cleared fact, is never a hint.
bool bringsMediaResolutionHint({
  required Map<String, dynamic>? local,
  required Map<String, dynamic> applied,
  required bool rowFromRemote,
}) {
  if (local == null) return false;
  for (final key in SyncFactGroups.mediaUpload.columns.keys) {
    final value = applied[key];
    if (value != null && value != local[key]) return true;
  }
  if (!rowFromRemote) return false;
  final cloudId = applied['cloudAssetId'];
  return cloudId is String &&
      cloudId.isNotEmpty &&
      cloudId != local['cloudAssetId'];
}
```

- [ ] **Step 4: Run the unit tests to verify they pass**

Run: `flutter test test/core/services/sync/media_resolution_hints_test.dart test/features/media/data/repositories/local_asset_cache_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing two-device scenarios**

In `resolution_scenarios_test.dart`, add a harness helper need: `HarnessDevice.clearCloudAssetId(String id)` (Task 6 adds it too; add it here if Task 5 runs first):

```dart
  /// Simulates a gallery row linked before links recorded a cloud id.
  Future<void> clearCloudAssetId(String id) async {
    await activate();
    await db.customStatement(
      'UPDATE media SET cloud_asset_id = NULL WHERE id = ?',
      [id],
    );
  }
```

Then the scenarios:

```dart
  test('a peer that gave up on a photo retries as soon as its cloud id '
      'arrives', () async {
    final frame1 = Uint8List.fromList(List<int>.generate(512, (i) => i % 251));
    final frame2 = Uint8List.fromList(
      List<int>.generate(512, (i) => (i * 7) % 251),
    );
    final dive = await h.a.createDive();
    final id1 = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-b1', bytes: frame1, takenAt: taken, cloudId: 'C-b1'),
      diveId: dive,
    );
    await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-b2', bytes: frame2, takenAt: taken, cloudId: 'C-b2'),
      diveId: dive,
    );
    h.b.gallery
      ..add(FakeGalleryAsset(id: 'B-b1', bytes: frame1, takenAt: taken, filename: null, cloudId: 'C-b1'))
      ..add(FakeGalleryAsset(id: 'B-b2', bytes: frame2, takenAt: taken, filename: null, cloudId: 'C-b2'));
    // The row reaches B without its cloud id; B cannot tell the frames apart
    // and backs off.
    await h.a.clearCloudAssetId(id1);
    await h.a.sync();
    await h.b.sync();
    expect((await h.b.tile(id1)).data, isA<UnavailableData>());
    expect(
      (await h.b.assetCache.getCacheEntry(id1))!.resolutionMethod,
      'unresolved',
    );

    // A learns the id again (by the backfill, Task 6, or any stamp) and
    // syncs; the row clock moves so the peer takes the row.
    await h.a.activate();
    await h.a.db.customStatement(
      "UPDATE media SET cloud_asset_id = 'C-b1' WHERE id = ?",
      [id1],
    );
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: id1,
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await h.a.sync();
    await h.b.sync();

    expect(
      await h.b.assetCache.getCacheEntry(id1),
      isNull,
      reason: 'the new cloud id lifted the backoff',
    );
    final tile = await h.b.tile(id1);
    expect((tile.data as BytesData).bytes, frame1);
  });

  test('a plain edit from the peer does not lift the backoff', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkGalleryPhoto(
      FakeGalleryAsset(id: 'A-1', bytes: photo, takenAt: taken),
      diveId: dive,
    );
    await h.a.sync();
    await h.b.sync();
    await h.b.tile(id);
    expect(
      (await h.b.assetCache.getCacheEntry(id))!.resolutionMethod,
      'unresolved',
    );

    await h.a.setManualElapsed(id, 42);
    await h.a.sync();
    await h.b.sync();

    expect(
      (await h.b.assetCache.getCacheEntry(id))!.resolutionMethod,
      'unresolved',
    );
  });
```

Import `SyncRepository` (`package:submersion/core/data/repositories/sync_repository.dart`). Use the harness's own stamp helper instead of the raw update if Task 6 has already landed (`backfillGalleryCloudIds`), keeping the assertion.

- [ ] **Step 6: Run them to verify the first fails**

Run: `flutter test test/features/media/two_device/resolution_scenarios_test.dart --plain-name "retries as soon as"`
Expected: FAIL at `reason: 'the new cloud id lifted the backoff'` (the entry is still `unresolved`).

- [ ] **Step 7: Wire the hook**

In `sync_service.dart`:
- import `media_resolution_hints.dart`;
- constructor parameter `Future<void> Function(Set<String> mediaIds)? onMediaResolutionHints,`, initializer `_onMediaResolutionHints = onMediaResolutionHints`, and the field:
  ```dart
  /// Told which media rows a merge gave something new to be found by, so
  /// their cached "not found here" searches retry at once (spec 6.2).
  /// Optional: most tests build the service without one.
  final Future<void> Function(Set<String> mediaIds)? _onMediaResolutionHints;
  ```
- in `_mergeEntity`, next to `factWrites`'s declaration: `final hinted = <({String id, bool inBatch})>[];`
- in the `!hasUpdatedAt` facts branch, right after `final resolved = mergeFactGroups(...)`:
  ```dart
          if (entityType == 'media' &&
              bringsMediaResolutionHint(
                local: local,
                applied: resolved.row,
                rowFromRemote: rowFromRemote,
              )) {
            hinted.add((id: recordId, inBatch: rowFromRemote));
          }
  ```
  (`recordId` is non-null here; add `!` if the analyzer asks.)
- after the `for (final w in factWrites)` loop, before `return _MergeResult(`:
  ```dart
    // After the writes, so a row the batch failed to write is not retried
    // as if it had landed. The cache is another database and outside this
    // payload's transaction: if the payload later rolls back, the only
    // cost is a search that runs sooner than its backoff.
    final hintIds = {
      for (final h in hinted)
        if (!(batchFailed && h.inBatch)) h.id,
    };
    final onHints = _onMediaResolutionHints;
    if (hintIds.isNotEmpty && onHints != null) {
      try {
        await onHints(hintIds);
      } on Object catch (e) {
        _log.warning('Could not retry resolution for ${hintIds.length} media rows: $e');
      }
    }
  ```

In `sync_providers.dart` `syncServiceProvider`, add
`onMediaResolutionHints: (ids) => ref.read(localAssetCacheRepositoryProvider).clearUnresolved(ids),`
and the import of `resolved_asset_providers.dart`.

In the harness `sync()`, the `SyncService(` gains `onMediaResolutionHints: assetCache.clearUnresolved,`.

- [ ] **Step 8: Run the scenarios and the sync suite**

Run: `flutter test test/features/media/two_device test/core/services/sync`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/media/data/repositories/local_asset_cache_repository.dart lib/core/services/sync/media_resolution_hints.dart lib/core/services/sync/sync_service.dart lib/features/settings/presentation/providers/sync_providers.dart test/helpers/two_device_media_harness.dart test/core/services/sync/media_resolution_hints_test.dart test/features/media/data/repositories/local_asset_cache_repository_test.dart test/features/media/two_device/resolution_scenarios_test.dart
git commit -m "feat(media): a synced cloud id or upload lifts a peer's resolution backoff"
```

---

### Task 6: The one-time cloud id backfill

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (after `stampOriginDevice`)
- Create: `lib/features/media/data/services/gallery_cloud_id_backfill.dart`
- Create: `lib/features/media/presentation/providers/gallery_cloud_id_backfill_provider.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (after the origin backfill call)
- Modify: `test/helpers/two_device_media_harness.dart`
- Test: `test/features/media/data/services/gallery_cloud_id_backfill_test.dart` (create), `test/features/media/two_device/resolution_scenarios_test.dart`

**Interfaces:**
- Consumes: `CloudIdentifierSource`, `FakePhotoPickerService` (Task 2); `GalleryOriginBackfill.isDone` / `doneFlagKey` (slice 7).
- Produces:
  - `Future<List<({String id, String platformAssetId})>> MediaRepository.getOwnGalleryMediaWithoutCloudId(String deviceId)`
  - `Future<int> MediaRepository.stampCloudAssetIds(List<({String id, String platformAssetId, String cloudAssetId})> found)`
  - `class GalleryCloudIdBackfill` with `static const String doneFlagKey = 'media_gallery_cloud_id_backfill_v1'`, `static bool isDone(SharedPreferences)`, `Future<GalleryCloudIdBackfillOutcome?> run()`, where `typedef GalleryCloudIdBackfillOutcome = ({int checked, int stamped})`.
  - `final galleryCloudIdBackfillProvider = Provider<Future<void> Function()>`
  - harness: `HarnessDevice.backfillGalleryCloudIds()`, `HarnessDevice.clearCloudAssetId(String id)`.

- [ ] **Step 1: Write the failing backfill tests**

Create `test/features/media/data/services/gallery_cloud_id_backfill_test.dart`, modelled on the slice 7 origin backfill test (`test/features/media/data/services/gallery_origin_backfill_test.dart`: read it first and reuse its database and preference setup verbatim). The cases, each a `test(...)` with its own arrange/act/assert:

```dart
  // Arrange helpers (in main): a real MediaRepository on setUpTestDatabase(),
  // SharedPreferences.setMockInitialValues({GalleryOriginBackfill.doneFlagKey: true}),
  // a FakePhotoPickerService `library`, and:
  GalleryCloudIdBackfill backfill({
    PhotoPermissionStatus permission = PhotoPermissionStatus.authorized,
    bool supportsGallery = true,
  }) => GalleryCloudIdBackfill(
    mediaRepository: repo,
    cloudIdentifiers: library,
    photos: FakePhotoPickerService(supportsGalleryBrowsing: supportsGallery),
    permissionStatus: () async => permission,
    deviceId: () async => 'me',
    prefs: prefs,
  );

  Future<String> link(String assetId, {String? origin = 'me'}) async {
    final created = await repo.createMedia(MediaItem(
      id: '',
      platformAssetId: assetId,
      originDeviceId: origin,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2026, 7, 1),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    ));
    return created.id;
  }
```

Cases (write each in full):
1. `'stamps this device\'s own rows whose asset has a cloud id, in one lookup'`: library holds `a1` (cloudId `C-1`) and `a2` (no cloud id); link both; run; expect `stamped == 1`, `checked == 2`, row for `a1` has `C-1`, row for `a2` null, `library.cloudIdCalls == 1`, `GalleryCloudIdBackfill.isDone(prefs)` true, and `a1`'s row is sync-pending (query `sync_records` as `MediaRepository` tests do, or via `SyncRepository().getPendingRecords`; pick the helper the origin backfill test uses).
2. `'never touches a peer\'s rows'`: link `a1` with `origin: 'peer'`, library has `a1` with a cloud id; run; row stays null, `checked == 0`.
3. `'restamps a row a relink left empty'`: link `a1`, set `cloud_asset_id = ''` by SQL; run; row has the cloud id.
4. `'waits for the origin backfill'`: `prefs.remove(GalleryOriginBackfill.doneFlagKey)`; run returns null; flag unset; `library.cloudIdCalls == 0`.
5. `'waits for full photo access'`: `permission: PhotoPermissionStatus.limited`; run returns null; flag unset.
6. `'a host with no photo library is done at once'`: `supportsGallery: false`; returns `(checked: 0, stamped: 0)`; flag set; no lookup.
7. `'a failed lookup leaves the flag unset'`: `library.cloudIdError = StateError('x')`; returns null; flag unset; rows unstamped.
8. `'runs once'`: run twice; second returns null; `cloudIdCalls == 1`.
9. `'a sync-delivered cloud id is kept'`: stub the race by making the fake's lookup set the row's cloud id to `C-peer` by SQL before answering (subclass `FakePhotoPickerService` in the test and override `cloudIdentifiers` to run the SQL first, then `super`); run; row keeps `C-peer`, `stamped == 0`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/media/data/services/gallery_cloud_id_backfill_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: The repository queries**

In `media_repository.dart`, after `stampOriginDevice`:

```dart
  /// This device's own gallery rows with no cloud id yet (null, or empty
  /// after a relink that found none), with the asset id each was linked
  /// under: the rows the gallery cloud id backfill looks up (spec 6.2).
  Future<List<({String id, String platformAssetId})>>
  getOwnGalleryMediaWithoutCloudId(String deviceId) async {
    final rows =
        await (_db.select(_db.media)..where(
              (t) =>
                  t.sourceType.equals(MediaSourceType.platformGallery.name) &
                  t.originDeviceId.equals(deviceId) &
                  t.platformAssetId.isNotNull() &
                  t.platformAssetId.equals('').not() &
                  (t.cloudAssetId.isNull() | t.cloudAssetId.equals('')),
            ))
            .get();
    return [
      for (final r in rows) (id: r.id, platformAssetId: r.platformAssetId!),
    ];
  }

  /// Records each of [found]'s cloud id on its row, if the row is still
  /// exactly what was looked up: a gallery row, under the same asset id,
  /// with no cloud id yet. Marks each row it stamps pending. Returns how
  /// many it stamped.
  ///
  /// The cloud id belongs to no fact group, so this bumps the row clock and
  /// republishes the whole row, which is why the backfill runs only right
  /// after a sync (as [stampOriginDevice] does). The guards keep a cloud id
  /// a sync delivered meanwhile, and skip a row relinked meanwhile.
  Future<int> stampCloudAssetIds(
    List<({String id, String platformAssetId, String cloudAssetId})> found,
  ) async {
    if (found.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var stamped = 0;
    await _db.transaction(() async {
      for (final row in found) {
        final written =
            await (_db.update(_db.media)..where(
                  (t) =>
                      t.id.equals(row.id) &
                      t.sourceType.equals(
                        MediaSourceType.platformGallery.name,
                      ) &
                      t.platformAssetId.equals(row.platformAssetId) &
                      (t.cloudAssetId.isNull() | t.cloudAssetId.equals('')),
                ))
                .write(
                  MediaCompanion(
                    cloudAssetId: Value(row.cloudAssetId),
                    updatedAt: Value(now),
                  ),
                );
        if (written == 0) continue;
        stamped++;
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
    });
    if (stamped > 0) SyncEventBus.notifyLocalChange();
    return stamped;
  }
```

- [ ] **Step 4: The backfill**

Create `lib/features/media/data/services/gallery_cloud_id_backfill.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// What one run of [GalleryCloudIdBackfill] did.
typedef GalleryCloudIdBackfillOutcome = ({
  /// This device's gallery rows with no cloud id that were looked up.
  int checked,

  /// Of those, rows whose asset has a cloud id and were stamped.
  int stamped,
});

/// One-time stamp of the iCloud identifier on the gallery rows this device
/// linked before links recorded one (media sync program spec 6.2), so a
/// peer sharing the library can find each exact photo.
///
/// Only this device's own rows (its id is their origin): only here does a
/// row's stored asset id name an asset in this library. So it waits for the
/// origin backfill, which is what makes older rows this device's own; a
/// pass before it would set the flag over rows it could not yet claim.
///
/// Runs after a successful sync, never at launch, for the origin backfill's
/// reason: the cloud id has no fact group, so a stamp bumps the row clock
/// and republishes the row, and right after a pull that is least likely to
/// overwrite a peer's unseen newer edit. Only with full photo access, and
/// never prompting. Flagged in SharedPreferences, set only after a complete
/// pass, so a failed or waiting run tries again after the next sync.
class GalleryCloudIdBackfill {
  GalleryCloudIdBackfill({
    required MediaRepository mediaRepository,
    required CloudIdentifierSource cloudIdentifiers,
    required PhotoPickerService photos,
    required Future<PhotoPermissionStatus> Function() permissionStatus,
    required Future<String> Function() deviceId,
    required SharedPreferences prefs,
  }) : _mediaRepository = mediaRepository,
       _cloudIdentifiers = cloudIdentifiers,
       _photos = photos,
       _permissionStatus = permissionStatus,
       _deviceId = deviceId,
       _prefs = prefs;

  static const String doneFlagKey = 'media_gallery_cloud_id_backfill_v1';

  /// Whether this device has already run the backfill.
  static bool isDone(SharedPreferences prefs) =>
      prefs.getBool(doneFlagKey) ?? false;

  final MediaRepository _mediaRepository;
  final CloudIdentifierSource _cloudIdentifiers;
  final PhotoPickerService _photos;

  /// Reads photo access without asking for it, as the origin backfill does.
  final Future<PhotoPermissionStatus> Function() _permissionStatus;
  final Future<String> Function() _deviceId;
  final SharedPreferences _prefs;
  final _log = LoggerService.forClass(
    GalleryCloudIdBackfill,
    category: LogCategory.media,
  );

  /// Runs the backfill, or returns null when it already ran, is waiting
  /// (for the origin backfill or full photo access), or could not complete
  /// (logged; the flag stays unset).
  Future<GalleryCloudIdBackfillOutcome?> run() async {
    if (isDone(_prefs)) return null;
    try {
      // No photo library here (Windows, Linux): no gallery row was ever
      // linked on this device.
      if (!_photos.supportsGalleryBrowsing) {
        await _prefs.setBool(doneFlagKey, true);
        return (checked: 0, stamped: 0);
      }
      if (!GalleryOriginBackfill.isDone(_prefs)) {
        _log.info('Gallery cloud id backfill waiting for the origin backfill');
        return null;
      }
      if (await _permissionStatus() != PhotoPermissionStatus.authorized) {
        _log.info('Gallery cloud id backfill waiting for full photo access');
        return null;
      }
      final me = await _deviceId();
      final candidates = await _mediaRepository
          .getOwnGalleryMediaWithoutCloudId(me);
      final ids = await _cloudIdentifiers.cloudIdentifiers([
        for (final row in candidates) row.platformAssetId,
      ]);
      final found = [
        for (final row in candidates)
          if (ids[row.platformAssetId] case final cloudId?)
            (
              id: row.id,
              platformAssetId: row.platformAssetId,
              cloudAssetId: cloudId,
            ),
      ];
      final stamped = await _mediaRepository.stampCloudAssetIds(found);
      // Done once nothing is left that this pass did not ask about. Rows
      // whose asset has no cloud id stay candidates, but they were asked; a
      // row linked or relinked during the lookup was not, so it holds the
      // flag open for the next sync.
      final asked = candidates.toSet();
      final unasked = (await _mediaRepository
              .getOwnGalleryMediaWithoutCloudId(me))
          .where((row) => !asked.contains(row))
          .length;
      if (unasked == 0) await _prefs.setBool(doneFlagKey, true);
      _log.info(
        'Gallery cloud id backfill ${unasked == 0 ? 'done' : 'partial'}: '
        'checked ${candidates.length}, stamped $stamped, unasked $unasked',
      );
      return (checked: candidates.length, stamped: stamped);
    } on Object catch (e, stackTrace) {
      _log.error(
        'Gallery cloud id backfill failed; will retry after the next sync',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
```

- [ ] **Step 5: Run the backfill tests**

Run: `flutter test test/features/media/data/services/gallery_cloud_id_backfill_test.dart`
Expected: PASS.

- [ ] **Step 6: The provider and the post-sync call**

Create `lib/features/media/presentation/providers/gallery_cloud_id_backfill_provider.dart`, the same shape as `gallery_origin_backfill_provider.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';
import 'package:submersion/features/media/data/services/gallery_cloud_id_backfill.dart';
import 'package:submersion/features/media/data/services/photo_picker_service_mobile.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

/// Runs [GalleryCloudIdBackfill] once per device, after a successful sync
/// and after the origin backfill. One preference read once it is done.
/// Contains its own failures: the sync has already succeeded.
// no-tick: the value is a CLOSURE, not a query result. Every read happens
// inside it at call time via ref.read, so there is no cached row to go stale.
final galleryCloudIdBackfillProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (GalleryCloudIdBackfill.isDone(prefs)) return;
      final photos = ref.read(photoPickerServiceProvider);
      await GalleryCloudIdBackfill(
        mediaRepository: ref.read(mediaRepositoryProvider),
        cloudIdentifiers: const PhotoManagerCloudIdentifierSource(),
        photos: photos,
        // Read, never asked: this runs after a sync, unasked.
        permissionStatus: photos is PhotoPickerServiceMobile
            ? photos.currentPermission
            : photos.checkPermission,
        deviceId: () => SyncRepository().getDeviceId(),
        prefs: prefs,
      ).run();
    } on Object catch (e, stackTrace) {
      LoggerService.forClass(GalleryCloudIdBackfill).warning(
        'Could not run the gallery cloud id backfill',
        error: e,
        stackTrace: stackTrace,
      );
    }
  };
});
```

In `sync_providers.dart`, right after the origin backfill's `if (!mounted) return;`:

```dart
          // Then the iCloud identifiers of this device's own gallery rows
          // (spec 6.2), for the same reasons, once the origins it relies on
          // are stamped. Once per device, and contains its own failures.
          await _ref.read(galleryCloudIdBackfillProvider)();
          if (!mounted) return;
```

and the import.

- [ ] **Step 7: Harness and the end-to-end scenario**

In the harness, add beside `backfillGalleryOrigins`:

```dart
  /// Runs this device's one-time gallery cloud id backfill. The preference
  /// store is shared by both devices, so the flag is cleared first, and the
  /// origin backfill it waits for is marked done: harness gallery rows
  /// record their origin at link time.
  Future<void> backfillGalleryCloudIds() async {
    await activate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(GalleryCloudIdBackfill.doneFlagKey);
    await prefs.setBool(GalleryOriginBackfill.doneFlagKey, true);
    await GalleryCloudIdBackfill(
      mediaRepository: MediaRepository(),
      cloudIdentifiers: gallery,
      photos: gallery,
      permissionStatus: () async => gallery.permission,
      deviceId: () async => deviceId,
      prefs: prefs,
    ).run();
  }
```

and `clearCloudAssetId` if Task 5 did not add it. Then, in the Task 5 scenario `'a peer that gave up on a photo retries as soon as its cloud id arrives'`, replace the raw SQL update and `markRecordPending` with `await h.a.backfillGalleryCloudIds();` (drop the `SyncRepository` import if it is now unused). The scenario now covers the backfill end to end.

- [ ] **Step 8: Run the media suites**

Run: `flutter test test/features/media test/features/media_store test/features/settings`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/features/media/data/repositories/media_repository.dart lib/features/media/data/services/gallery_cloud_id_backfill.dart lib/features/media/presentation/providers/gallery_cloud_id_backfill_provider.dart lib/features/settings/presentation/providers/sync_providers.dart test/helpers/two_device_media_harness.dart test/features/media/data/services/gallery_cloud_id_backfill_test.dart test/features/media/two_device/resolution_scenarios_test.dart
git commit -m "feat(media): back-fill the iCloud identifier of this device's older gallery links"
```

---

### Task 7: Spec notes, mutation checks, full verification

**Files:**
- Modify: `docs/superpowers/specs/2026-09-18-media-sync-program-design.md` (section 6.2)
- Modify: this plan (an "Execution notes" section at the end)

- [ ] **Step 1: Record the decisions in spec 6.2**

Append to section 6.2:

```markdown
- Decided 2026-09-23 while planning: rung 226 (PR #1978 holds 225); the
  floor stays 224; the batch `getCloudIdentifiers` call everywhere, since
  `AssetEntity.darwin.cloudIdentifier` wraps it one id at a time and throws
  off Apple platforms; the backfill is the slice 7 origin backfill's twin
  (own rows, after a sync, full access, once), not the origin republish
  sweep, and it waits for the origin backfill; a gallery relink restamps
  the cloud id, with an empty string for "none" because a null never
  reaches a peer through the merge's nullToAbsent upsert.
```

- [ ] **Step 2: Mutation-check every guard**

Each mutation must compile and turn its named test red; restore the file after each (copy it aside first, never `git checkout` a file with uncommitted work):

| Mutation | Test that must fail |
| --- | --- |
| `_matchByCloudIdentifier` returns `null` at once | S6; `a cloud id picks the right frame of a burst pair` |
| `matches.length == 1` becomes `matches.isNotEmpty` | `two candidates with the same cloud id is no match` |
| drop `cloudId.isEmpty` from the tier's guard | `an empty cloud id is none, and is not looked up` |
| `_cloudIdsFor` returns `const {}` | `a gallery link records its cloud id, in one lookup` |
| relink writes `write.newCloudAssetId` (no `?? ''`) with `newCloudAssetId: cloudIds[...]` | `a relink to an asset with no cloud id clears it to empty` |
| `clearUnresolved` drops the `localAssetId.isNull()` term | `clearUnresolved drops only unresolved entries` |
| the upload-fact loop in `bringsMediaResolutionHint` removed | `a new upload fact is a hint even on a row the peer lost` |
| `value != null &&` dropped from that loop | `a cleared upload fact is not` |
| the `_mergeEntity` hook call removed | `a peer that gave up on a photo retries as soon as its cloud id arrives` |
| the backfill's origin-done gate removed | `waits for the origin backfill` |
| `stampCloudAssetIds` drops its cloud-id-empty guard | `a sync-delivered cloud id is kept` |
| `getOwnGalleryMediaWithoutCloudId` drops `originDeviceId.equals` | `never touches a peer's rows` |

- [ ] **Step 3: Full verification**

```bash
dart format .
flutter analyze
flutter test
```

Expected: no format changes, no analyzer issues, the full suite green with S6 no longer skipped. Run `test/architecture` explicitly too (it scans all of `lib/`).

- [ ] **Step 4: Commit the notes**

```bash
git add docs/superpowers/specs/2026-09-18-media-sync-program-design.md docs/superpowers/plans/2026-09-23-media-sync-phase2-cloud-identifier.md
git commit -m "docs(spec): record slice 8's decisions in 6.2"
```

The PR body carries `Closes #2116, closes #1937` and `Part of #2090`.

## Execution notes (2026-09-23)

- `PhotoManager.plugin` and `PhotoManagerPlugin` are exported by `package:photo_manager/photo_manager.dart` in 3.12.0; the seam compiles as written.
- Task 2: the plan's import test used `CloudIdentifierSource` without importing it; added. The dive-path test stubs `getGalleryLinksForDive` and echoes the created item, like its neighbours.
- Task 4: the lookup lives in a `_withCloudIds` helper rather than inline in `apply`. The mutation pass showed the null-to-empty fallback was written twice (service and repository), so either copy alone survived its mutation; the service now passes null through and the repository alone writes `''`, which also covers any other caller of `applyRepairWrites`.
- Task 6: one test beyond the plan's nine, `a row linked during the lookup keeps the flag open`, which pins the unasked check.
- Mutation pass: 17 mutations, each compiling and failing its named test (the table above, plus the relink fallback, the file-relink `Value.absent`, the backfill's unasked check, the `rowFromRemote` gate in the hint, and the v226 backstop).
- Review of #2312: the backfill's permanent done flag became a last-run time (`media_gallery_cloud_id_backfill_last_run_v1`), so the pass repeats at most once a day for rows still missing a cloud id; and the sync hook became `MediaResolutionHints` with two kinds, where a changed asset id (a relink) drops the cached mapping whatever it says and a new cloud id or upload fact still clears only an unresolved entry. Both mutation-checked.

